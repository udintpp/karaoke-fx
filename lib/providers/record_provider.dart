import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';

import '../models/camera_effects.dart';
import '../models/recording_item.dart';
import '../services/camera_bg_remover_service.dart';
import '../services/system_audio_fx_service.dart';

enum RecordingMode { video, audioOnly }
enum RecordState { idle, recording, processing, error }

class RecordProvider extends ChangeNotifier {
  final SystemAudioFxService _audioService = SystemAudioFxService();
  final CameraBgRemoverService _cameraService = CameraBgRemoverService();
  final AudioPlayer _playbackPlayer = AudioPlayer();

  // Native Camera State
  int? _textureId;
  int _previewWidth = 720;
  int _previewHeight = 960;
  bool _isCameraInitialized = false;
  bool _isFrontCamera = true;
  bool _hasMultipleCameras = true;
  bool _isFlashOn = false;

  // Recording State
  RecordingMode _mode = RecordingMode.video;
  RecordState _state = RecordState.idle;
  int _recordingSeconds = 0;
  Timer? _timer;
  String? _errorMessage;
  String? _currentRecordingVideoPath;

  // AI Filters, Backdrops, and Background Cutout
  CameraAiFilter _selectedFilter = CameraAiFilter.allFilters[1]; // Default: AI Beauty & Glow
  StudioBackdrop _selectedBackdrop = StudioBackdrop.presets[1]; // Default: Panggung Konser Megah
  double _backdropOpacity = 1.0;
  CutoutMode _cutoutMode = CutoutMode.aiPersonCutout; // Default: AI Background Remover
  double _cutoutSensitivity = 0.65;

  // Saved Recordings
  List<RecordingItem> _savedRecordings = [];
  String? _currentlyPlayingId;
  bool _isPlayingPlayback = false;

  // Video Playback Modal State
  int? _playbackVideoTextureId;
  int _playbackVideoWidth = 720;
  int _playbackVideoHeight = 960;
  bool _isPlayingVideo = false;
  int _videoDurationMs = 0;
  int _videoPositionMs = 0;
  Timer? _videoProgressTimer;

  // Getters
  int? get textureId => _textureId;
  int get previewWidth => _previewWidth;
  int get previewHeight => _previewHeight;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isFrontCamera => _isFrontCamera;
  bool get hasMultipleCameras => _hasMultipleCameras;
  bool get isFlashOn => _isFlashOn;

  RecordingMode get mode => _mode;
  RecordState get state => _state;
  bool get isRecording => _state == RecordState.recording;
  int get recordingSeconds => _recordingSeconds;
  String? get errorMessage => _errorMessage;

  CameraAiFilter get selectedFilter => _selectedFilter;
  StudioBackdrop get selectedBackdrop => _selectedBackdrop;
  double get backdropOpacity => _backdropOpacity;
  CutoutMode get cutoutMode => _cutoutMode;
  double get cutoutSensitivity => _cutoutSensitivity;

  List<RecordingItem> get savedRecordings => _savedRecordings;
  String? get currentlyPlayingId => _currentlyPlayingId;
  bool get isPlayingPlayback => _isPlayingPlayback;

  int? get playbackVideoTextureId => _playbackVideoTextureId;
  int get playbackVideoWidth => _playbackVideoWidth;
  int get playbackVideoHeight => _playbackVideoHeight;
  bool get isPlayingVideo => _isPlayingVideo;
  int get videoDurationMs => _videoDurationMs;
  int get videoPositionMs => _videoPositionMs;

  String get formattedRecordingTime {
    final m = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  RecordProvider() {
    _initPlaybackListener();
  }

  void _initPlaybackListener() {
    _playbackPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing &&
          playerState.processingState != ProcessingState.completed;
      if (_isPlayingPlayback != isPlaying) {
        _isPlayingPlayback = isPlaying;
        if (playerState.processingState == ProcessingState.completed) {
          _currentlyPlayingId = null;
        }
        notifyListeners();
      }
    });
  }

  // ─── Native Camera Management ──────────────────────────────────────────
  Future<void> initCamera() async {
    if (_isCameraInitialized && _textureId != null) return;

    try {
      final camStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (camStatus != PermissionStatus.granted) {
        _errorMessage = 'Izin kamera dibutuhkan untuk Studio Video.';
        notifyListeners();
        return;
      }

      final info = await _cameraService.initCamera(preferFront: true);
      if (info != null && info['textureId'] != null) {
        _textureId = info['textureId'] as int;
        _previewWidth = info['width'] as int? ?? 720;
        _previewHeight = info['height'] as int? ?? 960;
        _hasMultipleCameras = info['hasMultipleCameras'] as bool? ?? true;
        _isFrontCamera = info['isFrontCamera'] as bool? ?? true;
        _isCameraInitialized = true;
        _errorMessage = null;

        // Sync initial effect state to OpenGL ES engine
        await _cameraService.setCutoutMode(_cutoutMode.name, _cutoutSensitivity);
        await _cameraService.setColorFilter(_selectedFilter.matrix, _selectedFilter.isBeauty);
        _syncBackdropToNative();

        notifyListeners();
      } else {
        _errorMessage = 'Gagal inisialisasi surface kamera native.';
        _isCameraInitialized = false;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal inisialisasi kamera: $e';
      _isCameraInitialized = false;
      notifyListeners();
    }
  }

  Future<void> switchCamera() async {
    if (!_hasMultipleCameras) return;
    try {
      final isFront = await _cameraService.switchCamera();
      _isFrontCamera = isFront;
      _isFlashOn = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal ganti kamera: $e';
      notifyListeners();
    }
  }

  Future<void> toggleFlash() async {
    try {
      final active = await _cameraService.setFlash(!_isFlashOn);
      _isFlashOn = active;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> tapToFocus(double nx, double ny) async {
    await _cameraService.tapToFocus(nx, ny);
  }

  // ─── Filter & Backdrop Selection ──────────────────────────────────────
  void setMode(RecordingMode newMode) {
    _mode = newMode;
    notifyListeners();
  }

  void setFilter(CameraAiFilter filter) {
    _selectedFilter = filter;
    _cameraService.setColorFilter(filter.matrix, filter.isBeauty);
    notifyListeners();
  }

  void setBackdrop(StudioBackdrop backdrop) {
    _selectedBackdrop = backdrop;
    _syncBackdropToNative();
    notifyListeners();
  }

  void setBackdropOpacity(double opacity) {
    _backdropOpacity = opacity.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setCutoutMode(CutoutMode mode) {
    _cutoutMode = mode;
    _cameraService.setCutoutMode(mode.name, _cutoutSensitivity);
    notifyListeners();
  }

  void setCutoutSensitivity(double sensitivity) {
    _cutoutSensitivity = sensitivity.clamp(0.05, 1.0);
    _cameraService.setCutoutMode(_cutoutMode.name, _cutoutSensitivity);
    notifyListeners();
  }

  void _syncBackdropToNative() {
    _cameraService.setBackdropMedia(
      mediaType: _selectedBackdrop.mediaType,
      sourceKind: _selectedBackdrop.sourceKind,
      pathOrKey: _selectedBackdrop.pathOrKey,
      motionType: _selectedBackdrop.motionType,
      gradientColors: _selectedBackdrop.gradientColors.map((c) => c.value).toList(),
    );
  }

  Future<void> pickCustomBackdropImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        _selectedBackdrop = StudioBackdrop(
          type: BackdropType.customLocal,
          title: result.files.single.name,
          icon: Icons.image_rounded,
          mediaType: 'image',
          sourceKind: 'file',
          pathOrKey: path,
          gradientColors: const [Color(0xFF1E1E2E), Color(0xFF11111B)],
          localFilePath: path,
        );
        _syncBackdropToNative();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal memilih gambar dari galeri: $e';
      notifyListeners();
    }
  }

  Future<void> pickCustomBackdropVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        _selectedBackdrop = StudioBackdrop(
          type: BackdropType.customLocal,
          title: result.files.single.name,
          icon: Icons.videocam_rounded,
          mediaType: 'video',
          sourceKind: 'file',
          pathOrKey: path,
          gradientColors: const [Color(0xFF1E1E2E), Color(0xFF11111B)],
          localFilePath: path,
        );
        _syncBackdropToNative();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal memilih video dari galeri: $e';
      notifyListeners();
    }
  }

  // ─── Recording Controls ───────────────────────────────────────────────
  Future<void> startRecording() async {
    if (_state == RecordState.recording) return;

    try {
      _errorMessage = null;
      _recordingSeconds = 0;

      if (_mode == RecordingMode.video) {
        if (!_isCameraInitialized || _textureId == null) {
          await initCamera();
        }

        if (_isCameraInitialized) {
          final dir = await _getVideoRecordingsDir();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final targetPath = '${dir.path}/Karaoke_Video_$timestamp.mp4';
          final success = await _cameraService.startVideoRecording(targetPath);
          if (!success) {
            throw Exception('Gagal memulai perekaman video MP4 composited');
          }
          _currentRecordingVideoPath = targetPath;
        } else {
          throw Exception('Kamera belum siap merekam');
        }
      } else {
        // Audio-only lossless WAV recording
        final dir = await _getAudioRecordingsDir();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final wavPath = '${dir.path}/Karaoke_Audio_$timestamp.wav';

        final success = await _audioService.startAudioRecording(wavPath);
        if (!success) {
          throw Exception('Gagal memulai perekaman audio');
        }
      }

      _state = RecordState.recording;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _recordingSeconds++;
        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      _state = RecordState.error;
      _errorMessage = 'Gagal mulai merekam: $e';
      notifyListeners();
    }
  }

  Future<String?> stopRecording() async {
    if (_state != RecordState.recording) return null;

    _timer?.cancel();
    _timer = null;
    _state = RecordState.processing;
    notifyListeners();

    String? savedFilePath;
    try {
      if (_mode == RecordingMode.video) {
        savedFilePath = await _cameraService.stopVideoRecording();
        savedFilePath ??= _currentRecordingVideoPath;
        _currentRecordingVideoPath = null;
      } else {
        savedFilePath = await _audioService.stopAudioRecording();
      }

      await loadSavedRecordings();
      _state = RecordState.idle;
      notifyListeners();
      return savedFilePath;
    } catch (e) {
      _state = RecordState.error;
      _errorMessage = 'Gagal menyimpan rekaman: $e';
      notifyListeners();
      return null;
    }
  }

  // ─── Saved Recordings Management ──────────────────────────────────────
  Future<Directory> _getAudioRecordingsDir() async {
    try {
      final extDir = Directory('/storage/emulated/0/Music/KaraokeFX');
      if (await extDir.exists() ||
          await extDir.create(recursive: true).then((_) => true).catchError((_) => false)) {
        return extDir;
      }
    } catch (_) {}
    final appDir = await getApplicationDocumentsDirectory();
    final fallback = Directory('${appDir.path}/KaraokeFX/Audio');
    if (!await fallback.exists()) await fallback.create(recursive: true);
    return fallback;
  }

  Future<Directory> _getVideoRecordingsDir() async {
    try {
      final extDir = Directory('/storage/emulated/0/Movies/KaraokeFX');
      if (await extDir.exists() ||
          await extDir.create(recursive: true).then((_) => true).catchError((_) => false)) {
        return extDir;
      }
    } catch (_) {}
    final appDir = await getApplicationDocumentsDirectory();
    final fallback = Directory('${appDir.path}/KaraokeFX/Video');
    if (!await fallback.exists()) await fallback.create(recursive: true);
    return fallback;
  }

  Future<void> loadSavedRecordings() async {
    try {
      final List<RecordingItem> list = [];
      final audioDir = await _getAudioRecordingsDir();
      final videoDir = await _getVideoRecordingsDir();

      // Scan audio recordings
      if (await audioDir.exists()) {
        final audioFiles = audioDir.listSync();
        for (final f in audioFiles) {
          if (f is File && f.path.endsWith('.wav')) {
            final stat = f.statSync();
            list.add(RecordingItem(
              id: f.path,
              name: f.uri.pathSegments.last,
              path: f.path,
              dateTime: stat.modified,
              fileSizeBytes: stat.size,
              isVideo: false,
            ));
          }
        }
      }

      // Scan video recordings
      if (await videoDir.exists()) {
        final videoFiles = videoDir.listSync();
        for (final f in videoFiles) {
          if (f is File && f.path.endsWith('.mp4')) {
            final stat = f.statSync();
            list.add(RecordingItem(
              id: f.path,
              name: f.uri.pathSegments.last,
              path: f.path,
              dateTime: stat.modified,
              fileSizeBytes: stat.size,
              isVideo: true,
            ));
          }
        }
      }

      list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      _savedRecordings = list;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> playAudioRecording(RecordingItem item) async {
    try {
      if (_currentlyPlayingId == item.id && _isPlayingPlayback) {
        await _playbackPlayer.pause();
        return;
      }

      _currentlyPlayingId = item.id;
      await _playbackPlayer.setFilePath(item.path);
      await _playbackPlayer.play();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal memutar audio: $e';
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    await _playbackPlayer.stop();
    _currentlyPlayingId = null;
    notifyListeners();
  }

  // ─── Native Recorded MP4 Video Playback ────────────────────────────────
  Future<void> startRecordedVideoPlayback(String filePath) async {
    try {
      await stopPlayback();
      await stopRecordedVideoPlayback();

      final info = await _cameraService.playRecordedVideo(filePath);
      if (info != null && info['textureId'] != null) {
        _playbackVideoTextureId = info['textureId'] as int;
        _playbackVideoWidth = info['videoWidth'] as int? ?? 720;
        _playbackVideoHeight = info['videoHeight'] as int? ?? 960;
        _videoDurationMs = info['durationMs'] as int? ?? 0;
        _isPlayingVideo = true;

        _videoProgressTimer?.cancel();
        _videoProgressTimer =
            Timer.periodic(const Duration(milliseconds: 250), (_) async {
          final posInfo = await _cameraService.getRecordedVideoPosition();
          _videoPositionMs = posInfo['positionMs'] as int? ?? 0;
          _isPlayingVideo = posInfo['isPlaying'] as bool? ?? false;
          notifyListeners();
        });

        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal memutar video: $e';
      notifyListeners();
    }
  }

  Future<void> toggleRecordedVideoPause() async {
    try {
      final isPlaying = await _cameraService.toggleRecordedVideoPause();
      _isPlayingVideo = isPlaying;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> seekRecordedVideo(int positionMs) async {
    await _cameraService.seekRecordedVideo(positionMs);
    _videoPositionMs = positionMs;
    notifyListeners();
  }

  Future<void> stopRecordedVideoPlayback() async {
    _videoProgressTimer?.cancel();
    _videoProgressTimer = null;
    await _cameraService.stopRecordedVideo();
    _playbackVideoTextureId = null;
    _isPlayingVideo = false;
    _videoPositionMs = 0;
    _videoDurationMs = 0;
    notifyListeners();
  }

  Future<void> deleteRecording(RecordingItem item) async {
    try {
      if (_currentlyPlayingId == item.id) {
        await stopPlayback();
      }
      final file = File(item.path);
      if (await file.exists()) {
        await file.delete();
      }
      _savedRecordings.removeWhere((r) => r.id == item.id);
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoProgressTimer?.cancel();
    _playbackPlayer.dispose();
    _cameraService.disposeCamera();
    super.dispose();
  }
}

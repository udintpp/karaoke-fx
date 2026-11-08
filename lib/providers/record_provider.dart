import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';

import '../models/camera_effects.dart';
import '../models/recording_item.dart';
import '../services/system_audio_fx_service.dart';

enum RecordingMode { video, audioOnly }
enum RecordState { idle, recording, processing, error }

class RecordProvider extends ChangeNotifier {
  final SystemAudioFxService _audioService = SystemAudioFxService();
  final AudioPlayer _playbackPlayer = AudioPlayer();

  // Camera State
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;

  // Recording State
  RecordingMode _mode = RecordingMode.video;
  RecordState _state = RecordState.idle;
  int _recordingSeconds = 0;
  Timer? _timer;
  String? _errorMessage;

  // AI Filters & Backdrops
  CameraAiFilter _selectedFilter = CameraAiFilter.allFilters.first;
  StudioBackdrop _selectedBackdrop = StudioBackdrop.presets[1]; // Default: Panggung Konser
  double _backdropOpacity = 0.85;

  // Saved Recordings
  List<RecordingItem> _savedRecordings = [];
  String? _currentlyPlayingId;
  bool _isPlayingPlayback = false;

  // Getters
  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isFlashOn => _isFlashOn;
  bool get hasMultipleCameras => _availableCameras.length > 1;

  RecordingMode get mode => _mode;
  RecordState get state => _state;
  bool get isRecording => _state == RecordState.recording;
  int get recordingSeconds => _recordingSeconds;
  String? get errorMessage => _errorMessage;

  CameraAiFilter get selectedFilter => _selectedFilter;
  StudioBackdrop get selectedBackdrop => _selectedBackdrop;
  double get backdropOpacity => _backdropOpacity;

  List<RecordingItem> get savedRecordings => _savedRecordings;
  String? get currentlyPlayingId => _currentlyPlayingId;
  bool get isPlayingPlayback => _isPlayingPlayback;

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

  // ─── Camera Management ────────────────────────────────────────────────
  Future<void> initCamera() async {
    if (_isCameraInitialized) return;

    try {
      final camStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (camStatus != PermissionStatus.granted) {
        _errorMessage = 'Izin kamera dibutuhkan untuk Studio Video.';
        notifyListeners();
        return;
      }

      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        _errorMessage = 'Tidak ada sensor kamera terdeteksi di perangkat.';
        notifyListeners();
        return;
      }

      // Default to front camera for selfie karaoke if available
      int frontCamIndex = _availableCameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontCamIndex != -1 ? frontCamIndex : 0;

      await _setupCameraController(_availableCameras[_selectedCameraIndex]);
      _isCameraInitialized = true;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal inisialisasi kamera: $e';
      _isCameraInitialized = false;
      notifyListeners();
    }
  }

  Future<void> _setupCameraController(CameraDescription description) async {
    await _cameraController?.dispose();
    _cameraController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController?.initialize();
    _isFlashOn = false;
  }

  Future<void> switchCamera() async {
    if (_availableCameras.length <= 1) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _setupCameraController(_availableCameras[_selectedCameraIndex]);
    notifyListeners();
  }

  Future<void> toggleFlash() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        _isFlashOn = true;
      }
      notifyListeners();
    } catch (_) {}
  }

  // ─── Filter & Backdrop Selection ──────────────────────────────────────
  void setMode(RecordingMode newMode) {
    _mode = newMode;
    notifyListeners();
  }

  void setFilter(CameraAiFilter filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setBackdrop(StudioBackdrop backdrop) {
    _selectedBackdrop = backdrop;
    notifyListeners();
  }

  void setBackdropOpacity(double opacity) {
    _backdropOpacity = opacity.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<void> pickCustomBackdrop() async {
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
          gradientColors: [const Color(0xFF1E1E2E), const Color(0xFF11111B)],
          localFilePath: path,
        );
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal memilih gambar dari galeri: $e';
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
        // Video recording with camera
        if (_cameraController == null || !_cameraController!.value.isInitialized) {
          await initCamera();
        }

        if (_cameraController != null && _cameraController!.value.isInitialized) {
          await _cameraController!.startVideoRecording();
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
        if (_cameraController != null && _cameraController!.value.isRecordingVideo) {
          final xfile = await _cameraController!.stopVideoRecording();
          final dir = await _getVideoRecordingsDir();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final targetPath = '${dir.path}/Karaoke_Video_$timestamp.mp4';
          final savedFile = await File(xfile.path).copy(targetPath);
          savedFilePath = savedFile.path;
          try { await File(xfile.path).delete(); } catch (_) {}
        }
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
      if (await extDir.exists() || await extDir.create(recursive: true).then((_) => true).catchError((_) => false)) {
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
      if (await extDir.exists() || await extDir.create(recursive: true).then((_) => true).catchError((_) => false)) {
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

  Future<void> playRecording(RecordingItem item) async {
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
      _errorMessage = 'Gagal memutar rekaman: $e';
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    await _playbackPlayer.stop();
    _currentlyPlayingId = null;
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
    _cameraController?.dispose();
    _playbackPlayer.dispose();
    super.dispose();
  }
}

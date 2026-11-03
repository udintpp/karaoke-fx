import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/fx_settings.dart';
import '../models/youtube_models.dart';
import '../services/youtube_service.dart';
import '../services/system_audio_fx_service.dart';

enum MediaState { idle, loading, playing, paused, stopped, error }

enum MediaSource { none, localFile, youtubeAudio }

class MediaFxProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final YoutubeService _ytService = YoutubeService();
  final SystemAudioFxService _systemFx = SystemAudioFxService();

  MediaState _state = MediaState.idle;
  MediaSource _source = MediaSource.none;
  MediaFxSettings _settings = MediaFxSettings();

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String? _currentTrackName;
  String? _currentThumbnailUrl;
  String? _currentVideoId;
  String? _errorMessage;
  double _outputLevel = 0.0;
  bool _isExtractingYt = false;

  // ─── System Audio FX State ──────────────────────────────────────────────────
  int _systemVolume = 10;
  int _systemMaxVolume = 15;

  bool _systemEqEnabled = false;
  bool _systemBassBoostEnabled = false;
  double _systemBassBoostStrength = 0.5; // 0.0 to 1.0

  bool _systemVirtualizerEnabled = false;
  double _systemVirtualizerStrength = 0.5; // 0.0 to 1.0

  bool _systemLoudnessEnabled = false;
  double _systemLoudnessGain = 300; // 0 to 1000 mB

  // ─── Getters ────────────────────────────────────────────────────────────────
  MediaState get state => _state;
  MediaSource get source => _source;
  MediaFxSettings get settings => _settings;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get currentTrackName => _currentTrackName;
  String? get currentThumbnailUrl => _currentThumbnailUrl;
  String? get currentVideoId => _currentVideoId;
  String? get errorMessage => _errorMessage;
  double get outputLevel => _outputLevel;
  bool get isPlaying => _state == MediaState.playing;
  bool get hasTrack => _currentTrackName != null;
  bool get isYouTube => _source == MediaSource.youtubeAudio;
  bool get isExtractingYt => _isExtractingYt;

  // System FX Getters
  int get systemVolume => _systemVolume;
  int get systemMaxVolume => _systemMaxVolume;
  bool get systemEqEnabled => _systemEqEnabled;
  List<SystemEqBand> get systemBands => _systemFx.bands;
  int get minLevelMb => _systemFx.minLevelMb;
  int get maxLevelMb => _systemFx.maxLevelMb;

  bool get systemBassBoostEnabled => _systemBassBoostEnabled;
  double get systemBassBoostStrength => _systemBassBoostStrength;

  bool get systemVirtualizerEnabled => _systemVirtualizerEnabled;
  double get systemVirtualizerStrength => _systemVirtualizerStrength;

  bool get systemLoudnessEnabled => _systemLoudnessEnabled;
  double get systemLoudnessGain => _systemLoudnessGain;

  double get progressValue {
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0, 1);
  }

  // ─── Init ────────────────────────────────────────────────────────────────────
  MediaFxProvider() {
    _initListeners();
    initSystemAudioFx();
  }

  Future<void> initSystemAudioFx() async {
    await _systemFx.init();
    final vol = await _systemFx.getSystemVolume();
    _systemVolume = vol['current'] ?? 10;
    _systemMaxVolume = vol['max'] ?? 15;
    notifyListeners();
  }

  void _initListeners() {
    _player.playerStateStream.listen((state) {
      if (state.playing) {
        _state = MediaState.playing;
      } else {
        switch (state.processingState) {
          case ProcessingState.idle:
            _state = MediaState.idle;
          case ProcessingState.loading:
          case ProcessingState.buffering:
            _state = MediaState.loading;
          case ProcessingState.ready:
            _state = MediaState.paused;
          case ProcessingState.completed:
            _state = MediaState.stopped;
        }
      }
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  // ─── System Media FX Controls (Android Global Audio Session) ───────────────

  void setSystemVolume(int vol) {
    _systemVolume = vol.clamp(0, _systemMaxVolume);
    _systemFx.setSystemVolume(_systemVolume);
    notifyListeners();
  }

  void setSystemEqEnabled(bool enabled) {
    _systemEqEnabled = enabled;
    _systemFx.setEqualizerEnabled(enabled);
    notifyListeners();
  }

  void setSystemBandLevel(int bandIndex, int levelMb) {
    _systemFx.setBandLevel(bandIndex, levelMb);
    notifyListeners();
  }

  void setSystemBassBoostEnabled(bool enabled) {
    _systemBassBoostEnabled = enabled;
    _systemFx.setBassBoostEnabled(enabled);
    notifyListeners();
  }

  void setSystemBassBoostStrength(double strength0to1) {
    _systemBassBoostStrength = strength0to1.clamp(0.0, 1.0);
    _systemFx.setBassBoostStrength((_systemBassBoostStrength * 1000).toInt());
    notifyListeners();
  }

  void setSystemVirtualizerEnabled(bool enabled) {
    _systemVirtualizerEnabled = enabled;
    _systemFx.setVirtualizerEnabled(enabled);
    notifyListeners();
  }

  void setSystemVirtualizerStrength(double strength0to1) {
    _systemVirtualizerStrength = strength0to1.clamp(0.0, 1.0);
    _systemFx.setVirtualizerStrength((_systemVirtualizerStrength * 1000).toInt());
    notifyListeners();
  }

  void setSystemLoudnessEnabled(bool enabled) {
    _systemLoudnessEnabled = enabled;
    _systemFx.setLoudnessEnhancerEnabled(enabled);
    notifyListeners();
  }

  void setSystemLoudnessGain(double gainMb) {
    _systemLoudnessGain = gainMb.clamp(0.0, 1000.0);
    _systemFx.setLoudnessGain(_systemLoudnessGain.toInt());
    notifyListeners();
  }

  // ─── Local File ──────────────────────────────────────────────────────────────
  Future<void> loadFile(String filePath, String trackName) async {
    try {
      _setLoading();
      _source = MediaSource.localFile;
      _currentTrackName = trackName;
      _currentThumbnailUrl = null;
      _currentVideoId = null;
      notifyListeners();

      await _player.setFilePath(filePath);
      await _applySettings();
      _state = MediaState.paused;
      notifyListeners();
    } catch (e) {
      _setError('Gagal memuat file: $e');
    }
  }

  // ─── YouTube Audio Stream ─────────────────────────────────────────────────
  Future<void> loadYoutubeAudio(YoutubeSearchResult result) async {
    await _loadYoutubeById(result.videoId, result.title, result.thumbnailUrl);
  }

  Future<void> _loadYoutubeById(
      String videoId, String title, String thumbnailUrl) async {
    try {
      _isExtractingYt = true;
      _setLoading();
      _source = MediaSource.youtubeAudio;
      _currentTrackName = title;
      _currentThumbnailUrl = thumbnailUrl;
      _currentVideoId = videoId;
      notifyListeners();

      final stream = await _ytService.extractAudioStream(videoId);
      await _player.setUrl(
        stream.streamUrl,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/91.0 Safari/537.36',
        },
      );
      await _applySettings();
      _state = MediaState.paused;
    } catch (e) {
      _setError('Gagal stream YouTube: $e');
    } finally {
      _isExtractingYt = false;
      notifyListeners();
    }
  }

  Future<List<YoutubeSearchResult>> searchYoutube(String query) async {
    return _ytService.search('$query karaoke');
  }

  // ─── Playback Controls ────────────────────────────────────────────────────
  Future<void> play() async => _player.play();
  Future<void> pause() async => _player.pause();

  Future<void> stop() async {
    await _player.stop();
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async => _player.seek(position);

  // ─── In-App FX Settings ───────────────────────────────────────────────────
  void updateSettings(MediaFxSettings newSettings) {
    _settings = newSettings;
    _applySettings();
    notifyListeners();
  }

  Future<void> _applySettings() async {
    try {
      await _player.setVolume(_settings.volume);
      await _player.setSpeed(_settings.speed);
    } catch (_) {}
  }

  void _setLoading() {
    _state = MediaState.loading;
    _errorMessage = null;
    _position = Duration.zero;
    _duration = Duration.zero;
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _state = MediaState.error;
    notifyListeners();
  }

  String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    _ytService.dispose();
    super.dispose();
  }
}

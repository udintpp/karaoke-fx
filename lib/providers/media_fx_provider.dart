import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/fx_settings.dart';
import '../models/youtube_models.dart';
import '../services/youtube_service.dart';
import '../services/system_audio_fx_service.dart';
import '../services/wireless_receiver_service.dart';

enum MediaState { idle, loading, playing, paused, stopped, error }

enum MediaSource { none, localFile, youtubeAudio }

class MediaFxProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final YoutubeService _ytService = YoutubeService();
  final SystemAudioFxService _systemFx = SystemAudioFxService();
  final WirelessReceiverService _wirelessReceiver = WirelessReceiverService();

  MediaState _state = MediaState.idle;
  MediaSource _source = MediaSource.none;
  MediaFxSettings _settings = MediaFxSettings();

  bool _isWirelessReceiverRunning = false;
  String _wirelessReceiverUrl = '';
  String _lastReceivedSong = '';

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String? _currentTrackName;
  String? _currentThumbnailUrl;
  String? _currentVideoId;
  String? _errorMessage;
  double _outputLevel = 0.0;
  bool _isExtractingYt = false;

  // ─── System Audio FX & Background Service State ──────────────────────────
  int _systemVolume = 10;
  int _systemMaxVolume = 15;

  bool _systemEqEnabled = false;
  bool _systemBassBoostEnabled = false;
  double _systemBassBoostStrength = 0.5;

  bool _systemVirtualizerEnabled = false;
  double _systemVirtualizerStrength = 0.5;

  bool _systemLoudnessEnabled = false;
  double _systemLoudnessGain = 300;

  bool _backgroundServiceEnabled = false;
  bool _autoStartOnBoot = true;

  // ─── Bluetooth Audio Receiver & Routing State ─────────────────────────────
  bool _isBluetoothEnabled = false;
  String _connectedBtSpeaker = '';
  String _connectedBtMic = '';
  bool _isBtMicEnabled = false;
  bool _isBtSpeakerEnabled = true;
  bool _isLowLatencyEnabled = false;

  bool _isBtReceiverMode = false;
  bool _isBtDiscoverable = false;
  String _btLocalDeviceName = '';
  String _btSenderDeviceName = '';
  String _btSenderDeviceAddress = '';
  bool _isBtReceiverPlaying = false;
  bool _isBtSinkSupported = true;

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

  bool get backgroundServiceEnabled => _backgroundServiceEnabled;
  bool get autoStartOnBoot => _autoStartOnBoot;

  // Bluetooth Getters
  bool get isBluetoothEnabled => _isBluetoothEnabled;
  String get connectedBtSpeaker => _connectedBtSpeaker;
  String get connectedBtMic => _connectedBtMic;
  bool get isBtMicEnabled => _isBtMicEnabled;
  bool get isBtSpeakerEnabled => _isBtSpeakerEnabled;
  bool get isLowLatencyEnabled => _isLowLatencyEnabled;
  bool get hasConnectedBtDevice =>
      _connectedBtSpeaker.isNotEmpty || _connectedBtMic.isNotEmpty;

  // Bluetooth Receiver Getters
  bool get isBtReceiverMode => _isBtReceiverMode;
  bool get isBtDiscoverable => _isBtDiscoverable;
  String get btLocalDeviceName => _btLocalDeviceName;
  String get btSenderDeviceName => _btSenderDeviceName;
  String get btSenderDeviceAddress => _btSenderDeviceAddress;
  bool get isBtReceiverPlaying => _isBtReceiverPlaying;
  bool get isBtSinkSupported => _isBtSinkSupported;
  bool get hasConnectedSender => _btSenderDeviceName.isNotEmpty;

  // Wireless Receiver Getters
  bool get isWirelessReceiverRunning => _isWirelessReceiverRunning;
  String get wirelessReceiverUrl => _wirelessReceiverUrl;
  String get lastReceivedSong => _lastReceivedSong;

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
    await refreshBluetoothStatus();

    final vol = await _systemFx.getSystemVolume();
    _systemVolume = vol['current'] ?? 10;
    _systemMaxVolume = vol['max'] ?? 15;

    // Restore saved settings from Android SharedPreferences
    final saved = await _systemFx.getSavedPreferences();
    _systemEqEnabled = saved['eqEnabled'] ?? false;
    _systemBassBoostEnabled = saved['bassEnabled'] ?? false;
    _systemBassBoostStrength = ((saved['bassStrength'] as num?)?.toDouble() ?? 500) / 1000.0;
    _systemVirtualizerEnabled = saved['virtEnabled'] ?? false;
    _systemVirtualizerStrength = ((saved['virtStrength'] as num?)?.toDouble() ?? 500) / 1000.0;
    _systemLoudnessEnabled = saved['loudEnabled'] ?? false;
    _systemLoudnessGain = (saved['loudGain'] as num?)?.toDouble() ?? 300.0;

    _autoStartOnBoot = saved['autoStartOnBoot'] ?? true;
    _backgroundServiceEnabled = await _systemFx.isForegroundServiceRunning();
    _isBtReceiverMode = saved['btReceiverEnabled'] ?? false;

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

    _wirelessReceiver.onAudioFileReceived = (filePath, fileName) {
      _lastReceivedSong = fileName;
      loadFile(filePath, fileName);
    };

    _wirelessReceiver.onYouTubeUrlReceived = (url) {
      final regExp = RegExp(
        r'(?:v=|\/embed\/|\/1\/|\/v\/|https:\/\/youtu\.be\/|\/shorts\/)([a-zA-Z0-9_-]{11})',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(url);
      final videoId = match?.group(1);
      if (videoId != null) {
        _lastReceivedSong = 'YouTube ($videoId)';
        _loadYoutubeById(
          videoId,
          'YouTube Karaoke ($videoId)',
          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
        );
      }
    };
  }

  // ─── Wireless Web Receiver Controls ────────────────────────────────────────

  Future<void> toggleWirelessReceiver(bool enable) async {
    if (enable) {
      final success = await _wirelessReceiver.startServer();
      _isWirelessReceiverRunning = success;
      _wirelessReceiverUrl = _wirelessReceiver.serverUrl;
    } else {
      await _wirelessReceiver.stopServer();
      _isWirelessReceiverRunning = false;
      _wirelessReceiverUrl = '';
    }
    notifyListeners();
  }

  // ─── Background Service & Auto Start Controls ─────────────────────────────

  Future<void> toggleBackgroundService(bool enable) async {
    _backgroundServiceEnabled = enable;
    if (enable) {
      await _systemFx.startForegroundService();
    } else {
      await _systemFx.stopForegroundService();
    }
    notifyListeners();
  }

  Future<void> toggleAutoStartOnBoot(bool enable) async {
    _autoStartOnBoot = enable;
    await _systemFx.setAutoStartOnBoot(enable);
    notifyListeners();
  }

  // ─── Bluetooth Audio Receiver & Router Controls ───────────────────────────

  Future<void> refreshBluetoothStatus() async {
    final status = await _systemFx.getBluetoothAudioStatus();
    _isBluetoothEnabled = status['isBluetoothEnabled'] ?? false;
    _connectedBtSpeaker = status['connectedSpeaker'] ?? '';
    _connectedBtMic = status['connectedMic'] ?? '';
    _isBtMicEnabled = status['isScoOn'] ?? false;
    _isLowLatencyEnabled = status['isLowLatencyOn'] ?? false;

    final rxStatus = await _systemFx.getBluetoothReceiverStatus();
    _isBtReceiverMode = rxStatus['isReceiverEnabled'] ?? _isBtReceiverMode;
    _isBtDiscoverable = rxStatus['isDiscoverable'] ?? false;
    _btLocalDeviceName = rxStatus['localDeviceName'] ?? '';
    _btSenderDeviceName = rxStatus['connectedSenderName'] ?? '';
    _btSenderDeviceAddress = rxStatus['connectedSenderAddress'] ?? '';
    _isBtReceiverPlaying = rxStatus['isPlayingMusic'] ?? false;
    _isBtSinkSupported = rxStatus['isSinkSupported'] ?? true;

    notifyListeners();
  }

  Future<void> requestBluetoothPermissions() async {
    try {
      await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
      ].request();
      await _systemFx.requestBluetoothPermissions();
    } catch (_) {}
  }

  Future<void> enableBluetooth() async {
    await _systemFx.enableBluetooth();
    await refreshBluetoothStatus();
    notifyListeners();
  }

  Future<void> toggleBluetoothReceiver(bool enable, {int duration = 300}) async {
    _isBtReceiverMode = enable;
    notifyListeners();

    if (enable) {
      await requestBluetoothPermissions();
      await _systemFx.startBluetoothReceiverMode(duration: duration);
    } else {
      await _systemFx.stopBluetoothReceiverMode();
    }
    await refreshBluetoothStatus();
    notifyListeners();
  }

  Future<void> requestBluetoothDiscoverable({int duration = 300}) async {
    await requestBluetoothPermissions();
    await _systemFx.requestBluetoothDiscoverable(duration: duration);
    await refreshBluetoothStatus();
    notifyListeners();
  }

  Future<void> toggleBluetoothMic(bool enable) async {
    _isBtMicEnabled = enable;
    await _systemFx.setBluetoothMicEnabled(enable);
    notifyListeners();
  }

  Future<void> toggleBluetoothSpeaker(bool enable) async {
    _isBtSpeakerEnabled = enable;
    await _systemFx.setBluetoothSpeakerEnabled(enable);
    notifyListeners();
  }

  Future<void> toggleLowLatency(bool enable) async {
    _isLowLatencyEnabled = enable;
    await _systemFx.setLowLatencyMode(enable);
    notifyListeners();
  }

  Future<void> openBluetoothSettings() async {
    await _systemFx.openBluetoothSettings();
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

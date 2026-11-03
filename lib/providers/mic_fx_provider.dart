import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fx_settings.dart';

enum MicState { idle, recording, processing, error }

class MicFxProvider extends ChangeNotifier {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  MicState _state = MicState.idle;
  MicFxSettings _settings = MicFxSettings();
  bool _isInitialized = false;
  double _inputLevel = 0.0; // VU meter: 0.0 - 1.0
  String? _errorMessage;

  // Preset names
  static const List<String> presets = [
    'Dry (No FX)',
    'Studio Vocal',
    'Concert Hall',
    'Karaoke Club',
    'Megaphone',
    'Robot',
    'Deep Voice',
    'Helium',
    'Bathroom',
  ];

  MicState get state => _state;
  MicFxSettings get settings => _settings;
  bool get isRecording => _state == MicState.recording;
  bool get isInitialized => _isInitialized;
  double get inputLevel => _inputLevel;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _loadSavedSettings();

      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _errorMessage = 'Izin mikrofon ditolak';
        _state = MicState.error;
        notifyListeners();
        return;
      }

      await _recorder.openRecorder();
      await _player.openPlayer();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal inisialisasi audio: $e';
      _state = MicState.error;
      notifyListeners();
    }
  }

  Future<void> startMonitoring() async {
    if (!_isInitialized) await initialize();
    if (_state == MicState.error) return;

    try {
      _state = MicState.recording;
      notifyListeners();

      // Start recording for real-time monitoring and VU meter
      await _recorder.startRecorder(
        codec: Codec.aacADTS,
        toFile: 'temp_mic_buffer.aac',
        numChannels: 1,
        sampleRate: 44100,
      );

      // Subscribe to audio level for VU meter
      _recorder.onProgress!.listen((event) {
        if (event.decibels != null) {
          // Convert dB to 0-1 linear scale (-60dB to 0dB)
          final db = event.decibels!.clamp(-60.0, 0.0);
          _inputLevel = (db + 60) / 60;
          notifyListeners();
        }
      });
    } catch (e) {
      _errorMessage = 'Error saat monitoring: $e';
      _state = MicState.error;
      notifyListeners();
    }
  }

  Future<void> stopMonitoring() async {
    try {
      await _recorder.stopRecorder();
      _state = MicState.idle;
      _inputLevel = 0.0;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error saat stop: $e';
      notifyListeners();
    }
  }

  void updateSettings(MicFxSettings newSettings) {
    _settings = newSettings;
    _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('karaoke_mic_settings', jsonEncode(_settings.toMap()));
    } catch (_) {}
  }

  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('karaoke_mic_settings');
      if (savedStr != null) {
        final map = jsonDecode(savedStr) as Map<String, dynamic>;
        _settings = MicFxSettings.fromMap(map);
        notifyListeners();
      }
    } catch (_) {}
  }

  void applyPreset(int presetIndex) {
    switch (presetIndex) {
      case 0: // Dry
        _settings = MicFxSettings();
        break;
      case 1: // Studio Vocal
        _settings = MicFxSettings(
          compressorEnabled: true,
          compressorThreshold: -18,
          compressorRatio: 4.0,
          reverbEnabled: true,
          reverbRoom: 0.3,
          reverbWetMix: 0.15,
          eqEnabled: true,
          eqBass: -3,
          eqMid: 2,
          eqTreble: 3,
        );
        break;
      case 2: // Concert Hall
        _settings = MicFxSettings(
          reverbEnabled: true,
          reverbRoom: 0.85,
          reverbDamping: 0.3,
          reverbWetMix: 0.5,
          echoEnabled: true,
          echoDelay: 400,
          echoFeedback: 0.25,
          echoWetMix: 0.2,
        );
        break;
      case 3: // Karaoke Club
        _settings = MicFxSettings(
          reverbEnabled: true,
          reverbRoom: 0.6,
          reverbWetMix: 0.35,
          echoEnabled: true,
          echoDelay: 300,
          echoFeedback: 0.3,
          echoWetMix: 0.3,
          compressorEnabled: true,
          compressorThreshold: -15,
          compressorRatio: 3.0,
          eqEnabled: true,
          eqBass: 2,
          eqMid: 1,
          eqTreble: 2,
        );
        break;
      case 4: // Megaphone
        _settings = MicFxSettings(
          eqEnabled: true,
          eqBass: -8,
          eqMid: 8,
          eqTreble: -4,
          compressorEnabled: true,
          compressorThreshold: -10,
          compressorRatio: 10.0,
        );
        break;
      case 5: // Robot
        _settings = MicFxSettings(
          pitchEnabled: true,
          pitchSemitones: -5,
          chorusEnabled: true,
          chorusDepth: 0.8,
          chorusRate: 4.0,
          chorusWetMix: 0.6,
        );
        break;
      case 6: // Deep Voice
        _settings = MicFxSettings(
          pitchEnabled: true,
          pitchSemitones: -5,
          eqEnabled: true,
          eqBass: 6,
          eqMid: -2,
          eqTreble: -3,
        );
        break;
      case 7: // Helium
        _settings = MicFxSettings(
          pitchEnabled: true,
          pitchSemitones: 8,
          eqEnabled: true,
          eqBass: -4,
          eqTreble: 4,
        );
        break;
      case 8: // Bathroom
        _settings = MicFxSettings(
          reverbEnabled: true,
          reverbRoom: 0.4,
          reverbDamping: 0.1,
          reverbWetMix: 0.6,
          echoEnabled: true,
          echoDelay: 80,
          echoFeedback: 0.4,
          echoWetMix: 0.3,
        );
        break;
    }
    _saveSettings();
    notifyListeners();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }
}

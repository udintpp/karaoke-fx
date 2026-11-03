import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fx_settings.dart';
import '../services/system_audio_fx_service.dart';

enum MicState { idle, recording, processing, error }

class MicFxProvider extends ChangeNotifier {
  final SystemAudioFxService _audioService = SystemAudioFxService();
  Timer? _vuTimer;

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
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal inisialisasi: $e';
      _state = MicState.error;
      notifyListeners();
    }
  }

  Future<void> startMonitoring() async {
    try {
      _errorMessage = null;

      // 1. Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _errorMessage = 'Izin mikrofon ditolak oleh pengguna';
        _state = MicState.error;
        notifyListeners();
        return;
      }

      // 2. Push current DSP settings to native engine
      await _audioService.updateRealtimeMicSettings(_settings.toMap());

      // 3. Start native low-latency passthrough engine
      final started = await _audioService.startRealtimeMic();
      if (!started) {
        _errorMessage = 'Gagal mengaktifkan mesin mikrofon real-time';
        _state = MicState.error;
        notifyListeners();
        return;
      }

      _state = MicState.recording;
      notifyListeners();

      // 4. Start smooth VU meter polling (~25 updates per second)
      _vuTimer?.cancel();
      _vuTimer = Timer.periodic(const Duration(milliseconds: 40), (_) async {
        if (_state == MicState.recording) {
          final vu = await _audioService.getRealtimeMicVu();
          _inputLevel = vu;
          notifyListeners();
        }
      });
    } catch (e) {
      _errorMessage = 'Error saat menyalakan mikrofon: $e';
      _state = MicState.error;
      notifyListeners();
    }
  }

  Future<void> stopMonitoring() async {
    try {
      _vuTimer?.cancel();
      _vuTimer = null;
      await _audioService.stopRealtimeMic();
      _state = MicState.idle;
      _inputLevel = 0.0;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error saat mematikan mikrofon: $e';
      notifyListeners();
    }
  }

  void updateSettings(MicFxSettings newSettings) {
    _settings = newSettings;
    _saveSettings();
    if (_state == MicState.recording) {
      _audioService.updateRealtimeMicSettings(_settings.toMap());
    }
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
    if (_state == MicState.recording) {
      _audioService.updateRealtimeMicSettings(_settings.toMap());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _vuTimer?.cancel();
    _audioService.stopRealtimeMic();
    super.dispose();
  }
}

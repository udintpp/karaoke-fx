import 'package:flutter/services.dart';

class SystemEqBand {
  final int index;
  final int centerFreqHz;
  int level; // in millibels (e.g. -1500 to +1500)

  SystemEqBand({
    required this.index,
    required this.centerFreqHz,
    required this.level,
  });

  String get formattedFreq {
    if (centerFreqHz >= 1000) {
      final khz = centerFreqHz / 1000;
      return khz == khz.toInt() ? '${khz.toInt()} kHz' : '${khz.toStringAsFixed(1)} kHz';
    }
    return '$centerFreqHz Hz';
  }

  double get dbLevel => level / 100.0;
}

class SystemAudioFxService {
  static const MethodChannel _channel =
      MethodChannel('com.karaokefx.app/system_audio_fx');

  static final SystemAudioFxService _instance = SystemAudioFxService._internal();
  factory SystemAudioFxService() => _instance;
  SystemAudioFxService._internal();

  int minLevelMb = -1500;
  int maxLevelMb = 1500;
  List<SystemEqBand> bands = [];

  Future<void> init() async {
    try {
      final result = await _channel.invokeMethod<Map>('init');
      if (result != null) {
        minLevelMb = (result['minLevel'] as num?)?.toInt() ?? -1500;
        maxLevelMb = (result['maxLevel'] as num?)?.toInt() ?? 1500;
        final rawBands = result['bands'] as List?;
        if (rawBands != null) {
          bands = rawBands.map((b) {
            final m = Map<String, dynamic>.from(b as Map);
            return SystemEqBand(
              index: (m['index'] as num).toInt(),
              centerFreqHz: (m['centerFreqHz'] as num).toInt(),
              level: (m['level'] as num).toInt(),
            );
          }).toList();
        }
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getSavedPreferences() async {
    try {
      final res = await _channel.invokeMethod<Map>('getSavedPreferences');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {
      'autoStartOnBoot': true,
      'backgroundServiceEnabled': false,
      'eqEnabled': false,
      'bassEnabled': false,
      'bassStrength': 500,
      'virtEnabled': false,
      'virtStrength': 500,
      'loudEnabled': false,
      'loudGain': 300,
    };
  }

  Future<void> startForegroundService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } catch (_) {}
  }

  Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }

  Future<bool> isForegroundServiceRunning() async {
    try {
      final res = await _channel.invokeMethod<bool>('isForegroundServiceRunning');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setAutoStartOnBoot(bool enabled) async {
    try {
      await _channel.invokeMethod('setAutoStartOnBoot', {'enabled': enabled});
    } catch (_) {}
  }

  Future<Map<String, int>> getSystemVolume() async {
    try {
      final res = await _channel.invokeMethod<Map>('getSystemVolume');
      if (res != null) {
        return {
          'current': (res['current'] as num).toInt(),
          'max': (res['max'] as num).toInt(),
        };
      }
    } catch (_) {}
    return {'current': 8, 'max': 15};
  }

  Future<void> setSystemVolume(int volume) async {
    try {
      await _channel.invokeMethod('setSystemVolume', {'volume': volume});
    } catch (_) {}
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setEqualizerEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  Future<void> setBandLevel(int bandIndex, int levelMb) async {
    try {
      await _channel.invokeMethod('setEqualizerBandLevel', {
        'band': bandIndex,
        'level': levelMb,
      });
      final band = bands.firstWhere((b) => b.index == bandIndex);
      band.level = levelMb;
    } catch (_) {}
  }

  Future<void> setBassBoostEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setBassBoostEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  Future<void> setBassBoostStrength(int strength0to1000) async {
    try {
      await _channel.invokeMethod('setBassBoostStrength', {
        'strength': strength0to1000,
      });
    } catch (_) {}
  }

  Future<void> setVirtualizerEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setVirtualizerEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  Future<void> setVirtualizerStrength(int strength0to1000) async {
    try {
      await _channel.invokeMethod('setVirtualizerStrength', {
        'strength': strength0to1000,
      });
    } catch (_) {}
  }

  Future<void> setLoudnessEnhancerEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setLoudnessEnhancerEnabled', {
        'enabled': enabled,
      });
    } catch (_) {}
  }

  Future<void> setLoudnessGain(int gainMb) async {
    try {
      await _channel.invokeMethod('setLoudnessGain', {'gainMb': gainMb});
    } catch (_) {}
  }

  // ─── Bluetooth Audio Receiver & Router Methods ─────────────────────────────

  Future<Map<String, dynamic>> getBluetoothAudioStatus() async {
    try {
      final res = await _channel.invokeMethod<Map>('getBluetoothAudioStatus');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {
      'isBluetoothEnabled': false,
      'connectedSpeaker': '',
      'connectedMic': '',
      'isScoOn': false,
      'isLowLatencyOn': false,
    };
  }

  Future<void> setBluetoothMicEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setBluetoothMicEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  Future<void> setBluetoothSpeakerEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setBluetoothSpeakerEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  Future<void> setLowLatencyMode(bool enabled) async {
    try {
      await _channel.invokeMethod('setLowLatencyMode', {'enabled': enabled});
    } catch (_) {}
  }

  Future<void> openBluetoothSettings() async {
    try {
      await _channel.invokeMethod('openBluetoothSettings');
    } catch (_) {}
  }

  // ─── Bluetooth Audio Receiver (A2DP Sink) Methods ──────────────────────────

  Future<Map<String, dynamic>> getBluetoothReceiverStatus() async {
    try {
      final res = await _channel.invokeMethod<Map>('getBluetoothReceiverStatus');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {
      'isReceiverEnabled': false,
      'isBluetoothEnabled': false,
      'isDiscoverable': false,
      'localDeviceName': 'Android Karaoke Device',
      'connectedSenderName': '',
      'connectedSenderAddress': '',
      'isPlayingMusic': false,
      'isSinkSupported': true,
    };
  }

  Future<void> startBluetoothReceiverMode({int duration = 300}) async {
    try {
      await _channel.invokeMethod('startBluetoothReceiverMode', {'duration': duration});
    } catch (_) {}
  }

  Future<void> stopBluetoothReceiverMode() async {
    try {
      await _channel.invokeMethod('stopBluetoothReceiverMode');
    } catch (_) {}
  }

  Future<void> requestBluetoothDiscoverable({int duration = 300}) async {
    try {
      await _channel.invokeMethod('requestDiscoverable', {'duration': duration});
    } catch (_) {}
  }

  Future<void> enableBluetooth() async {
    try {
      await _channel.invokeMethod('enableBluetooth');
    } catch (_) {}
  }

  Future<void> requestBluetoothPermissions() async {
    try {
      await _channel.invokeMethod('requestBluetoothPermissions');
    } catch (_) {}
  }
}

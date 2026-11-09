import 'package:flutter/services.dart';

/// Service bridge to native CameraX + ML Kit Selfie Segmentation + OpenGL ES engine.
class CameraBgRemoverService {
  static const MethodChannel _channel =
      MethodChannel('com.karaokefx.app/camera_bg_remover');

  static final CameraBgRemoverService _instance =
      CameraBgRemoverService._internal();
  factory CameraBgRemoverService() => _instance;

  void Function(int rotation, bool isLandscape)? onOrientationChanged;

  CameraBgRemoverService._internal() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOrientationChanged') {
        final args = call.arguments as Map?;
        final rot = (args?['rotation'] as int?) ?? 0;
        final isLand = (args?['isLandscape'] as bool?) ?? false;
        onOrientationChanged?.call(rot, isLand);
      }
    });
  }

  /// Initialize native camera and GL surface, returns textureId, width, height, isFrontCamera, etc.
  Future<Map<String, dynamic>?> initCamera({bool preferFront = true}) async {
    try {
      final res = await _channel.invokeMethod<Map>('initCamera', {
        'preferFront': preferFront,
      });
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (e) {
      return null;
    }
  }

  /// Toggle front / back camera
  Future<bool> switchCamera() async {
    try {
      final res = await _channel.invokeMethod<bool>('switchCamera');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Toggle flash / torch
  Future<bool> setFlash(bool enabled) async {
    try {
      final res =
          await _channel.invokeMethod<bool>('setFlash', {'enabled': enabled});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Tap to focus at normalized coordinate (0.0 - 1.0)
  Future<void> tapToFocus(double x, double y) async {
    try {
      await _channel.invokeMethod('tapToFocus', {'x': x, 'y': y});
    } catch (_) {}
  }

  /// Set cutout mode: 'none', 'aiCutout', 'aiBlur', 'greenScreen', 'blueScreen'
  Future<void> setCutoutMode(String mode, double sensitivity) async {
    try {
      await _channel.invokeMethod('setCutoutMode', {
        'mode': mode,
        'sensitivity': sensitivity,
      });
    } catch (_) {}
  }

  /// Set 4x5 color matrix for AI Beauty/Stage filters
  Future<void> setColorFilter(List<double>? matrix, bool isBeauty) async {
    try {
      await _channel.invokeMethod('setColorFilter', {
        'matrix': matrix,
        'isBeauty': isBeauty,
      });
    } catch (_) {}
  }

  /// Set studio background: image asset, local file (image or video), or procedural motion stage
  Future<void> setBackdropMedia({
    required String mediaType, // 'none', 'image', 'video'
    required String sourceKind, // 'asset', 'file', 'none'
    required String pathOrKey,
    required String motionType, // 'none', 'concertBeams', 'neonPulse', 'galaxyStars'
    required List<int> gradientColors,
  }) async {
    try {
      await _channel.invokeMethod('setBackdropMedia', {
        'mediaType': mediaType,
        'sourceKind': sourceKind,
        'pathOrKey': pathOrKey,
        'motionType': motionType,
        'gradientColors': gradientColors,
      });
    } catch (_) {}
  }

  /// Start recording composited MP4 (Person + Replaced Backdrop + AI Filter + DSP Karaoke Audio)
  Future<bool> startVideoRecording(String outputPath) async {
    try {
      final res = await _channel.invokeMethod<bool>('startVideoRecording', {
        'outputPath': outputPath,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stop video recording, returns final saved MP4 file path
  Future<String?> stopVideoRecording() async {
    try {
      final res = await _channel.invokeMethod<String>('stopVideoRecording');
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Release camera and OpenGL resources
  Future<void> disposeCamera() async {
    try {
      await _channel.invokeMethod('disposeCamera');
    } catch (_) {}
  }

  // ─── Native Recorded MP4 Video Playback ──────────────────────────────────
  Future<Map<String, dynamic>?> playRecordedVideo(String filePath) async {
    try {
      final res = await _channel.invokeMethod<Map>('playRecordedVideo', {
        'filePath': filePath,
      });
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> toggleRecordedVideoPause() async {
    try {
      final res = await _channel.invokeMethod<bool>('toggleRecordedVideoPause');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> seekRecordedVideo(int positionMs) async {
    try {
      await _channel.invokeMethod('seekRecordedVideo', {
        'positionMs': positionMs,
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getRecordedVideoPosition() async {
    try {
      final res = await _channel.invokeMethod<Map>('getRecordedVideoPosition');
      return res != null
          ? Map<String, dynamic>.from(res)
          : {'positionMs': 0, 'durationMs': 0, 'isPlaying': false};
    } catch (_) {
      return {'positionMs': 0, 'durationMs': 0, 'isPlaying': false};
    }
  }

  Future<void> stopRecordedVideo() async {
    try {
      await _channel.invokeMethod('stopRecordedVideo');
    } catch (_) {}
  }
}

import 'dart:io';

class RecordingItem {
  final String id;
  final String name;
  final String path;
  final DateTime dateTime;
  final int fileSizeBytes;
  final bool isVideo;
  final int durationSeconds;

  RecordingItem({
    required this.id,
    required this.name,
    required this.path,
    required this.dateTime,
    required this.fileSizeBytes,
    required this.isVideo,
    this.durationSeconds = 0,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool exists() {
    return File(path).existsSync();
  }
}

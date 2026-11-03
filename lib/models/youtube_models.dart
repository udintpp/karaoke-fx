import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Model untuk hasil pencarian YouTube
class YoutubeSearchResult {
  final String videoId;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final String duration;
  final String viewCount;

  const YoutubeSearchResult({
    required this.videoId,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    required this.duration,
    required this.viewCount,
  });

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$videoId';
  String get thumbnailHq => 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
}

/// Model untuk audio stream yang sudah diekstrak
class YoutubeAudioStream {
  final String streamUrl;
  final String title;
  final String videoId;
  final String thumbnailUrl;
  final Duration? duration;
  final int? bitrate;
  final String? container; // mp4, webm, dll

  const YoutubeAudioStream({
    required this.streamUrl,
    required this.title,
    required this.videoId,
    required this.thumbnailUrl,
    this.duration,
    this.bitrate,
    this.container,
  });
}

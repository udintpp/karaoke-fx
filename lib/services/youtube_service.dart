import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/youtube_models.dart';

/// Service untuk interaksi dengan YouTube:
/// - Search video
/// - Ekstrak audio stream URL (untuk FX pipeline)
/// - Ambil metadata video
class YoutubeService {
  static final YoutubeService _instance = YoutubeService._internal();
  factory YoutubeService() => _instance;
  YoutubeService._internal();

  final YoutubeExplode _yt = YoutubeExplode();

  /// Cari video YouTube berdasarkan query
  Future<List<YoutubeSearchResult>> search(String query) async {
    try {
      final results = await _yt.search.search(query);
      return results
          .whereType<SearchVideo>()
          .take(20)
          .map((v) => YoutubeSearchResult(
                videoId: v.id.value,
                title: v.title,
                channelName: v.author,
                thumbnailUrl: v.thumbnails.highResUrl,
                duration: _formatDuration(v.duration),
                viewCount: _formatViews(v.engagement.viewCount),
              ))
          .toList();
    } catch (e) {
      throw YoutubeServiceException('Gagal mencari video: $e');
    }
  }

  /// Ambil audio stream URL terbaik dari video YouTube
  /// Mengembalikan URL langsung yang bisa diputar oleh just_audio
  Future<YoutubeAudioStream> extractAudioStream(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // Prioritas: audio-only stream (m4a/opus) — kualitas terbaik
      AudioStreamInfo? bestStream;

      // 1. Coba m4a (AAC) audio-only — paling kompatibel
      final m4aStreams = manifest.audioOnly
          .where((s) => s.codec.mimeType.contains('mp4'))
          .toList();
      if (m4aStreams.isNotEmpty) {
        m4aStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
        bestStream = m4aStreams.first;
      }

      // 2. Fallback: webm/opus
      if (bestStream == null && manifest.audioOnly.isNotEmpty) {
        final opusStreams = manifest.audioOnly.toList();
        opusStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
        bestStream = opusStreams.first;
      }

      if (bestStream == null) {
        throw YoutubeServiceException('Tidak ada audio stream tersedia');
      }

      return YoutubeAudioStream(
        streamUrl: bestStream.url.toString(),
        title: video.title,
        videoId: videoId,
        thumbnailUrl: video.thumbnails.highResUrl,
        duration: video.duration,
        bitrate: bestStream.bitrate.kiloBitsPerSecond.round(),
        container: bestStream.codec.mimeType,
      );
    } catch (e) {
      if (e is YoutubeServiceException) rethrow;
      throw YoutubeServiceException('Gagal ekstrak audio: $e');
    }
  }

  /// Ambil metadata video saja (tanpa stream)
  Future<YoutubeSearchResult?> getVideoInfo(String videoIdOrUrl) async {
    try {
      final id = _parseVideoId(videoIdOrUrl);
      if (id == null) return null;

      final video = await _yt.videos.get(id);
      return YoutubeSearchResult(
        videoId: video.id.value,
        title: video.title,
        channelName: video.author,
        thumbnailUrl: video.thumbnails.highResUrl,
        duration: _formatDuration(video.duration),
        viewCount: _formatViews(video.engagement.viewCount),
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse video ID dari berbagai format URL YouTube:
  /// - https://www.youtube.com/watch?v=xxxxx
  /// - https://youtu.be/xxxxx
  /// - xxxxx (video ID langsung)
  String? _parseVideoId(String input) {
    input = input.trim();
    // Full URL
    final uri = Uri.tryParse(input);
    if (uri != null) {
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }
      if (uri.host == 'youtu.be') {
        return uri.pathSegments.first;
      }
    }
    // Raw ID (11 chars alphanumeric)
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(input)) {
      return input;
    }
    return null;
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  String _formatViews(int? views) {
    if (views == null) return '';
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M views';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(0)}K views';
    return '$views views';
  }

  void dispose() {
    _yt.close();
  }
}

class YoutubeServiceException implements Exception {
  final String message;
  YoutubeServiceException(this.message);

  @override
  String toString() => 'YoutubeServiceException: $message';
}

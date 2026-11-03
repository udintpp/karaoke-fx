import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../providers/media_fx_provider.dart';
import '../models/youtube_models.dart';
import '../theme/app_theme.dart';
import '../services/youtube_service.dart';

/// Screen pencarian dan pemilihan video YouTube.
/// Hybrid:
///  - Video ditampilkan via YoutubePlayerIframe (resmi)
///  - Audio diproses via youtube_explode_dart → just_audio → FX
class YoutubeSearchScreen extends StatefulWidget {
  const YoutubeSearchScreen({super.key});

  @override
  State<YoutubeSearchScreen> createState() => _YoutubeSearchScreenState();
}

class _YoutubeSearchScreenState extends State<YoutubeSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final YoutubeService _yt = YoutubeService();

  List<YoutubeSearchResult> _results = [];
  bool _isSearching = false;
  String? _searchError;

  YoutubePlayerController? _ytPlayerCtrl;
  YoutubeSearchResult? _previewVideo;

  @override
  void initState() {
    super.initState();
    // Default search on open
    _search('karaoke lagu indonesia');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ytPlayerCtrl?.close();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await _yt.search(query);
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Gagal mencari: $e';
        _isSearching = false;
      });
    }
  }

  void _previewVideoInPlayer(YoutubeSearchResult result) {
    _ytPlayerCtrl?.close();
    setState(() {
      _previewVideo = result;
      _ytPlayerCtrl = YoutubePlayerController.fromVideoId(
        videoId: result.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: false,
          mute: false,
        ),
      );
    });
  }

  Future<void> _useForKaraoke(
      BuildContext context, YoutubeSearchResult result) async {
    final media = context.read<MediaFxProvider>();

    // Pause the iframe player before loading audio into the FX pipeline
    _ytPlayerCtrl?.pauseVideo();

    // Load audio stream ke FX pipeline
    await media.loadYoutubeAudio(result);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('▶️ Memutar: ${result.title}'),
          backgroundColor: AppTheme.card,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari di YouTube'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Preview player (tampil saat ada video dipilih preview)
          if (_previewVideo != null && _ytPlayerCtrl != null)
            _buildPreviewPlayer(),

          // Results list
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Cari lagu karaoke...',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() {});
              },
              child: const Icon(Icons.close_rounded,
                  color: AppTheme.textSecondary, size: 18),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _search(_searchCtrl.text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF0000), Color(0xFFCC0000)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPlayer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF0000).withOpacity(0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // YouTube IFrame player (video visual)
          YoutubePlayer(
            controller: _ytPlayerCtrl!,
            aspectRatio: 16 / 9,
          ),
          // Action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _previewVideo!.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Gunakan untuk karaoke (audio via FX pipeline)
                Consumer<MediaFxProvider>(
                  builder: (ctx, media, _) {
                    return GestureDetector(
                      onTap: media.isExtractingYt
                          ? null
                          : () => _useForKaraoke(ctx, _previewVideo!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.mediaColor, AppTheme.accent],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: media.isExtractingYt
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mic_rounded,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Gunakan untuk Karaoke',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.mediaColor),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 40),
            const SizedBox(height: 8),
            Text(_searchError!,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _search(_searchCtrl.text),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text('Tidak ada hasil',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _YoutubeResultTile(
        result: _results[i],
        isSelected: _previewVideo?.videoId == _results[i].videoId,
        onPreview: () => _previewVideoInPlayer(_results[i]),
        onUseKaraoke: () => _useForKaraoke(context, _results[i]),
      ),
    );
  }
}

class _YoutubeResultTile extends StatelessWidget {
  final YoutubeSearchResult result;
  final bool isSelected;
  final VoidCallback onPreview;
  final VoidCallback onUseKaraoke;

  const _YoutubeResultTile({
    required this.result,
    required this.isSelected,
    required this.onPreview,
    required this.onUseKaraoke,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPreview,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.mediaColor.withOpacity(0.1)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.mediaColor.withOpacity(0.5)
                : AppTheme.cardLight,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                bottomLeft: Radius.circular(13),
              ),
              child: Stack(
                children: [
                  Image.network(
                    result.thumbnailHq,
                    width: 110,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 110,
                      height: 70,
                      color: AppTheme.cardLight,
                      child: const Icon(Icons.music_video_rounded,
                          color: AppTheme.textSecondary),
                    ),
                  ),
                  // Duration badge
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        result.duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      result.channelName,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    if (result.viewCount.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.viewCount,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Use for karaoke button
                    GestureDetector(
                      onTap: onUseKaraoke,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.mediaColor, AppTheme.accent],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.headphones_rounded,
                                color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Pakai Karaoke',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

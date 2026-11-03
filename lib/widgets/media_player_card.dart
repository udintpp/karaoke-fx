import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/media_fx_provider.dart';
import '../theme/app_theme.dart';
import '../screens/youtube_search_screen.dart';
import 'vu_meter.dart';

class MediaPlayerCard extends StatelessWidget {
  final MediaFxProvider media;

  const MediaPlayerCard({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.card,
            AppTheme.mediaColor.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: media.isPlaying
              ? AppTheme.mediaColor.withOpacity(0.4)
              : AppTheme.cardLight,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Track info row
          Row(
            children: [
              // Thumbnail atau icon
              _buildAlbumArt(),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (media.isYouTube)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0000),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'YT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            media.currentTrackName ?? 'Belum ada lagu',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      media.hasTrack
                          ? '${media.formatDuration(media.position)} / ${media.formatDuration(media.duration)}'
                          : 'Pilih dari YouTube atau file lokal',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Source buttons
              Column(
                children: [
                  // YouTube button
                  _SourceBtn(
                    icon: Icons.smart_display_rounded,
                    color: const Color(0xFFFF0000),
                    tooltip: 'Cari di YouTube',
                    onTap: () => _openYoutubeSearch(context),
                  ),
                  const SizedBox(height: 4),
                  // File button
                  _SourceBtn(
                    icon: Icons.folder_open_rounded,
                    color: AppTheme.mediaColor,
                    tooltip: 'Buka file lokal',
                    onTap: () => _pickFile(context),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Loading YouTube stream indicator
          if (media.isExtractingYt)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.mediaColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Mengekstrak audio stream YouTube...',
                    style: TextStyle(
                        color: AppTheme.mediaColor, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Error message
          if (media.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                media.errorMessage!,
                style:
                    const TextStyle(color: AppTheme.error, fontSize: 12),
              ),
            ),

          // VU Meter
          VuMeter(
            level: media.outputLevel,
            color: AppTheme.mediaColor,
            label: 'MEDIA OUTPUT',
          ),

          const SizedBox(height: 16),

          // Progress bar
          if (media.hasTrack) ...[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.mediaColor,
                thumbColor: AppTheme.mediaColor,
                inactiveTrackColor: AppTheme.cardLight,
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                overlayColor: AppTheme.mediaColor.withOpacity(0.15),
              ),
              child: Slider(
                value: media.progressValue,
                onChanged: (v) => media.seekTo(Duration(
                  milliseconds:
                      (v * media.duration.inMilliseconds).round(),
                )),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CtrlBtn(
                icon: Icons.replay_10_rounded,
                color: AppTheme.textSecondary,
                size: 28,
                onTap: media.hasTrack
                    ? () => media.seekTo(Duration(
                          seconds: (media.position.inSeconds - 10)
                              .clamp(0, media.duration.inSeconds),
                        ))
                    : null,
              ),
              const SizedBox(width: 16),
              _PlayPauseButton(media: media),
              const SizedBox(width: 16),
              _CtrlBtn(
                icon: Icons.forward_10_rounded,
                color: AppTheme.textSecondary,
                size: 28,
                onTap: media.hasTrack
                    ? () => media.seekTo(Duration(
                          seconds: (media.position.inSeconds + 10)
                              .clamp(0, media.duration.inSeconds),
                        ))
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt() {
    if (media.currentThumbnailUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          media.currentThumbnailUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultIcon(),
        ),
      );
    }
    return _defaultIcon();
  }

  Widget _defaultIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.mediaColor, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  void _openYoutubeSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<MediaFxProvider>(),
          child: const YoutubeSearchScreen(),
        ),
      ),
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      await context.read<MediaFxProvider>().loadFile(file.path!, file.name);
    }
  }
}

class _PlayPauseButton extends StatelessWidget {
  final MediaFxProvider media;
  const _PlayPauseButton({required this.media});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: media.hasTrack
          ? () {
              if (media.isPlaying) {
                media.pause();
              } else {
                media.play();
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: media.hasTrack
              ? const LinearGradient(
                  colors: [AppTheme.mediaColor, AppTheme.accent],
                )
              : null,
          color: media.hasTrack ? null : AppTheme.cardLight,
          boxShadow: media.isPlaying
              ? [
                  BoxShadow(
                    color: AppTheme.mediaColor.withOpacity(0.5),
                    blurRadius: 18,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Icon(
          media.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color:
              media.hasTrack ? Colors.white : AppTheme.textSecondary,
          size: 30,
        ),
      ),
    );
  }
}

class _SourceBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _SourceBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  const _CtrlBtn({
    required this.icon,
    required this.color,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon,
          color: onTap != null ? color : color.withOpacity(0.3)),
      iconSize: size,
      padding: EdgeInsets.zero,
    );
  }
}

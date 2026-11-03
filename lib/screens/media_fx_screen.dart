import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/media_fx_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/fx_slider.dart';
import '../widgets/fx_toggle_card.dart';
import '../widgets/media_player_card.dart';

class MediaFxScreen extends StatelessWidget {
  const MediaFxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaFxProvider>(
      builder: (context, media, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System Global Audio Banner
              _buildSystemInfoCard(context),
              const SizedBox(height: 16),

              // System Media Volume (STREAM_MUSIC)
              _SectionLabel('🔊 VOLUME SISTEM ANDROID', color: AppTheme.mediaColor),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardLight),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          media.systemVolume == 0
                              ? Icons.volume_off_rounded
                              : media.systemVolume < media.systemMaxVolume / 2
                                  ? Icons.volume_down_rounded
                                  : Icons.volume_up_rounded,
                          color: AppTheme.mediaColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Master Volume Media HP',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${((media.systemVolume / (media.systemMaxVolume == 0 ? 1 : media.systemMaxVolume)) * 100).toInt()}%',
                          style: const TextStyle(
                            color: AppTheme.mediaColor,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.mediaColor,
                        thumbColor: AppTheme.mediaColor,
                        inactiveTrackColor: AppTheme.cardLight,
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: media.systemVolume.toDouble(),
                        min: 0,
                        max: media.systemMaxVolume.toDouble() > 0
                            ? media.systemMaxVolume.toDouble()
                            : 15,
                        divisions: media.systemMaxVolume > 0
                            ? media.systemMaxVolume
                            : 15,
                        onChanged: (v) => media.setSystemVolume(v.toInt()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // System Hardware Equalizer
              _SectionLabel('🎛️ SYSTEM HARDWARE EQUALIZER', color: AppTheme.accent),
              FxToggleCard(
                title: 'Equalizer Global Sistem Android',
                icon: Icons.equalizer_rounded,
                color: AppTheme.accent,
                enabled: media.systemEqEnabled,
                onToggle: media.setSystemEqEnabled,
                children: _buildEqBands(media),
              ),
              const SizedBox(height: 12),

              // System Hardware Bass Boost
              FxToggleCard(
                title: 'System Bass Boost',
                icon: Icons.speaker_rounded,
                color: AppTheme.primary,
                enabled: media.systemBassBoostEnabled,
                onToggle: media.setSystemBassBoostEnabled,
                children: [
                  FxSlider(
                    label: 'Bass Strength (Sistem)',
                    value: media.systemBassBoostStrength * 100,
                    min: 0,
                    max: 100,
                    unit: '%',
                    color: AppTheme.primary,
                    onChanged: (v) => media.setSystemBassBoostStrength(v / 100.0),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // System Virtualizer (3D Surround)
              FxToggleCard(
                title: 'System 3D Virtualizer (Surround)',
                icon: Icons.spatial_audio_rounded,
                color: AppTheme.secondary,
                enabled: media.systemVirtualizerEnabled,
                onToggle: media.setSystemVirtualizerEnabled,
                children: [
                  FxSlider(
                    label: 'Surround Width (Sistem)',
                    value: media.systemVirtualizerStrength * 100,
                    min: 0,
                    max: 100,
                    unit: '%',
                    color: AppTheme.secondary,
                    onChanged: (v) =>
                        media.setSystemVirtualizerStrength(v / 100.0),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // System Loudness Booster
              FxToggleCard(
                title: 'System Loudness Enhancer (Booster)',
                icon: Icons.bolt_rounded,
                color: AppTheme.warning,
                enabled: media.systemLoudnessEnabled,
                onToggle: media.setSystemLoudnessEnabled,
                children: [
                  FxSlider(
                    label: 'Gain Boost (mB)',
                    value: media.systemLoudnessGain,
                    min: 0,
                    max: 1000,
                    unit: ' mB',
                    color: AppTheme.warning,
                    onChanged: (v) => media.setSystemLoudnessGain(v),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // In-App Player / YouTube (Opsional jika ingin putar langsung di app)
              _SectionLabel('📺 PEMUTAR MEDIA IN-APP (OPSIONAL)',
                  color: AppTheme.textSecondary),
              MediaPlayerCard(media: media),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.mediaColor.withOpacity(0.15),
            AppTheme.accent.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.mediaColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.mediaColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tune_rounded,
                color: AppTheme.mediaColor, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Efek Audio Sistem Global (Android)',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pengaturan di tab ini langsung mengontrol Hardware Equalizer & Efek Suara Android. Berlaku untuk YouTube resmi, Spotify, TikTok, dan semua pemutar musik di HP Anda.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEqBands(MediaFxProvider media) {
    final bands = media.systemBands;
    final minDb = media.minLevelMb / 100.0;
    final maxDb = media.maxLevelMb / 100.0;

    if (bands.isEmpty) {
      // Default standard 5 bands while system info loads
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Inisialisasi hardware equalizer sistem...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      ];
    }

    return bands.map((b) {
      return FxSlider(
        label: b.formattedFreq,
        value: b.dbLevel,
        min: minDb,
        max: maxDb,
        unit: ' dB',
        color: AppTheme.accent,
        onChanged: (v) {
          final levelMb = (v * 100).toInt();
          media.setSystemBandLevel(b.index, levelMb);
        },
      );
    }).toList();
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

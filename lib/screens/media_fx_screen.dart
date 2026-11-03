import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/media_fx_provider.dart';
import '../models/fx_settings.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Player
              MediaPlayerCard(media: media),
              const SizedBox(height: 20),

              // Volume & Speed
              _SectionLabel('🎵 Playback', color: AppTheme.mediaColor),
              FxSlider(
                label: 'Volume',
                value: media.settings.volume,
                min: 0,
                max: 1.0,
                unit: '',
                color: AppTheme.mediaColor,
                onChanged: (v) => media.updateSettings(
                    media.settings.copyWith(volume: v)),
              ),
              FxSlider(
                label: 'Speed',
                value: media.settings.speed,
                min: 0.5,
                max: 2.0,
                unit: 'x',
                color: AppTheme.mediaColor,
                onChanged: (v) => media.updateSettings(
                    media.settings.copyWith(speed: v)),
              ),
              FxSlider(
                label: 'Pitch',
                value: media.settings.pitch,
                min: 0.5,
                max: 2.0,
                unit: 'x',
                color: AppTheme.mediaColor,
                onChanged: (v) => media.updateSettings(
                    media.settings.copyWith(pitch: v)),
              ),
              const SizedBox(height: 20),

              // 5-Band EQ
              FxToggleCard(
                title: 'Equalizer (5-Band)',
                icon: Icons.equalizer_rounded,
                color: AppTheme.mediaColor,
                enabled: media.settings.eqEnabled,
                onToggle: (v) => media.updateSettings(
                    media.settings.copyWith(eqEnabled: v)),
                children: [
                  FxSlider(
                    label: '60 Hz (Bass)',
                    value: media.settings.eq60Hz,
                    min: -12,
                    max: 12,
                    unit: 'dB',
                    divisions: 24,
                    color: AppTheme.mediaColor,
                    onChanged: (v) => media.updateSettings(
                        media.settings.copyWith(eq60Hz: v)),
                  ),
                  FxSlider(
                    label: '250 Hz (Low Mid)',
                    value: media.settings.eq250Hz,
                    min: -12,
                    max: 12,
                    unit: 'dB',
                    divisions: 24,
                    color: AppTheme.mediaColor,
                    onChanged: (v) => media.updateSettings(
                        media.settings.copyWith(eq250Hz: v)),
                  ),
                  FxSlider(
                    label: '1 kHz (Mid)',
                    value: media.settings.eq1kHz,
                    min: -12,
                    max: 12,
                    unit: 'dB',
                    divisions: 24,
                    color: AppTheme.mediaColor,
                    onChanged: (v) => media.updateSettings(
                        media.settings.copyWith(eq1kHz: v)),
                  ),
                  FxSlider(
                    label: '4 kHz (High Mid)',
                    value: media.settings.eq4kHz,
                    min: -12,
                    max: 12,
                    unit: 'dB',
                    divisions: 24,
                    color: AppTheme.mediaColor,
                    onChanged: (v) => media.updateSettings(
                        media.settings.copyWith(eq4kHz: v)),
                  ),
                  FxSlider(
                    label: '12 kHz (Treble)',
                    value: media.settings.eq12kHz,
                    min: -12,
                    max: 12,
                    unit: 'dB',
                    divisions: 24,
                    color: AppTheme.mediaColor,
                    onChanged: (v) => media.updateSettings(
                        media.settings.copyWith(eq12kHz: v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bass Boost
              FxToggleCard(
                title: 'Bass Boost',
                icon: Icons.speaker_rounded,
                color: AppTheme.primary,
                enabled: media.settings.bassBoostEnabled,
                onToggle: (v) => media.updateSettings(
                    media.settings.copyWith(bassBoostEnabled: v)),
                children: [
                  FxSlider(
                    label: 'Strength',
                    value: media.settings.bassBoostStrength,
                    min: 0,
                    max: 100,
                    unit: '',
                    color: AppTheme.primary,
                    onChanged: (v) => media.updateSettings(
                        media.settings.copyWith(bassBoostStrength: v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stereo Widener
              FxToggleCard(
                title: 'Stereo Widener',
                icon: Icons.spatial_audio_rounded,
                color: AppTheme.secondary,
                enabled: media.settings.stereoWidenEnabled,
                onToggle: (v) => media.updateSettings(
                    media.settings.copyWith(stereoWidenEnabled: v)),
                children: [
                  FxSlider(
                    label: 'Width',
                    value: media.settings.stereoWidth,
                    min: 0,
                    max: 2.0,
                    unit: 'x',
                    color: AppTheme.secondary,
                    onChanged: (v) => media.updateSettings(
                        media.settings.copyWith(stereoWidth: v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Room Reverb
              FxToggleCard(
                title: 'Room Reverb',
                icon: Icons.blur_on_rounded,
                color: AppTheme.accent,
                enabled: media.settings.reverbEnabled,
                onToggle: (v) => media.updateSettings(
                    media.settings.copyWith(reverbEnabled: v)),
                children: [
                  FxSlider(
                    label: 'Wet Mix',
                    value: media.settings.reverbWetMix,
                    min: 0,
                    max: 1.0,
                    unit: '',
                    color: AppTheme.accent,
                    onChanged: (v) => media.updateSettings(
                        media.settings.copyWith(reverbWetMix: v)),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              // Info note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.mediaColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.mediaColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppTheme.mediaColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Media FX dan Mic FX berjalan terpisah. Tidak saling mempengaruhi.',
                        style: TextStyle(
                          color: AppTheme.mediaColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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
            height: 18,
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
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

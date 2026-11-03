import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/mic_fx_provider.dart';
import '../models/fx_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/fx_slider.dart';
import '../widgets/fx_toggle_card.dart';
import '../widgets/vu_meter.dart';
import '../widgets/preset_chips.dart';

class MicFxScreen extends StatelessWidget {
  const MicFxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MicFxProvider>(
      builder: (context, mic, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // VU Meter + Record Button
              _MicControlCard(mic: mic),
              const SizedBox(height: 16),

              // Presets
              PresetChips(
                presets: MicFxProvider.presets,
                color: AppTheme.micColor,
                onSelect: mic.applyPreset,
              ),
              const SizedBox(height: 20),

              // Section: Input
              _SectionLabel('🎤 Input', color: AppTheme.micColor),
              FxSlider(
                label: 'Input Gain',
                value: mic.settings.inputGain,
                min: 0.0,
                max: 2.0,
                unit: 'x',
                color: AppTheme.micColor,
                onChanged: (v) => mic.updateSettings(
                    mic.settings.copyWith(inputGain: v)),
              ),
              const SizedBox(height: 16),

              // Echo / Delay
              FxToggleCard(
                title: 'Echo / Delay',
                icon: Icons.waves_rounded,
                color: AppTheme.micColor,
                enabled: mic.settings.echoEnabled,
                onToggle: (v) => mic.updateSettings(
                    mic.settings.copyWith(echoEnabled: v)),
                children: [
                  FxSlider(
                    label: 'Delay Time',
                    value: mic.settings.echoDelay,
                    min: 50,
                    max: 800,
                    unit: 'ms',
                    color: AppTheme.micColor,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(echoDelay: v)),
                  ),
                  FxSlider(
                    label: 'Feedback',
                    value: mic.settings.echoFeedback,
                    min: 0,
                    max: 0.9,
                    unit: '',
                    color: AppTheme.micColor,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(echoFeedback: v)),
                  ),
                  FxSlider(
                    label: 'Wet Mix',
                    value: mic.settings.echoWetMix,
                    min: 0,
                    max: 1.0,
                    unit: '',
                    color: AppTheme.micColor,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(echoWetMix: v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Reverb
              FxToggleCard(
                title: 'Reverb',
                icon: Icons.blur_on_rounded,
                color: AppTheme.primary,
                enabled: mic.settings.reverbEnabled,
                onToggle: (v) => mic.updateSettings(
                    mic.settings.copyWith(reverbEnabled: v)),
                children: [
                  FxSlider(
                    label: 'Room Size',
                    value: mic.settings.reverbRoom,
                    min: 0,
                    max: 1.0,
                    unit: '',
                    color: AppTheme.primary,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(reverbRoom: v)),
                  ),
                  FxSlider(
                    label: 'Damping',
                    value: mic.settings.reverbDamping,
                    min: 0,
                    max: 1.0,
                    unit: '',
                    color: AppTheme.primary,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(reverbDamping: v)),
                  ),
                  FxSlider(
                    label: 'Wet Mix',
                    value: mic.settings.reverbWetMix,
                    min: 0,
                    max: 1.0,
                    unit: '',
                    color: AppTheme.primary,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(reverbWetMix: v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Pitch Shift
              FxToggleCard(
                title: 'Pitch Shift',
                icon: Icons.music_note_rounded,
                color: AppTheme.secondary,
                enabled: mic.settings.pitchEnabled,
                onToggle: (v) => mic.updateSettings(
                    mic.settings.copyWith(pitchEnabled: v)),
                children: [
                  FxSlider(
                    label: 'Semitones',
                    value: mic.settings.pitchSemitones,
                    min: -12,
                    max: 12,
                    unit: 'st',
                    divisions: 24,
                    color: AppTheme.secondary,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(pitchSemitones: v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Chorus
              FxToggleCard(
                title: 'Chorus',
                icon: Icons.grain_rounded,
                color: AppTheme.accent,
                enabled: mic.settings.chorusEnabled,
                onToggle: (v) => mic.updateSettings(
                    mic.settings.copyWith(chorusEnabled: v)),
                children: [
                  FxSlider(
                    label: 'Depth',
                    value: mic.settings.chorusDepth,
                    min: 0,
                    max: 1.0,
                    unit: '',
                    color: AppTheme.accent,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(chorusDepth: v)),
                  ),
                  FxSlider(
                    label: 'Rate',
                    value: mic.settings.chorusRate,
                    min: 0.1,
                    max: 5.0,
                    unit: 'Hz',
                    color: AppTheme.accent,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(chorusRate: v)),
                  ),
                  FxSlider(
                    label: 'Wet Mix',
                    value: mic.settings.chorusWetMix,
                    min: 0,
                    max: 1.0,
                    unit: '',
                    color: AppTheme.accent,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(chorusWetMix: v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Noise Gate
              FxToggleCard(
                title: 'Noise Gate',
                icon: Icons.noise_aware_rounded,
                color: AppTheme.warning,
                enabled: mic.settings.noiseGateEnabled,
                onToggle: (v) => mic.updateSettings(
                    mic.settings.copyWith(noiseGateEnabled: v)),
                children: [
                  FxSlider(
                    label: 'Threshold',
                    value: mic.settings.noiseGateThreshold,
                    min: -60,
                    max: 0,
                    unit: 'dB',
                    color: AppTheme.warning,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(noiseGateThreshold: v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Compressor
              FxToggleCard(
                title: 'Compressor',
                icon: Icons.compress_rounded,
                color: AppTheme.success,
                enabled: mic.settings.compressorEnabled,
                onToggle: (v) => mic.updateSettings(
                    mic.settings.copyWith(compressorEnabled: v)),
                children: [
                  FxSlider(
                    label: 'Threshold',
                    value: mic.settings.compressorThreshold,
                    min: -40,
                    max: 0,
                    unit: 'dB',
                    color: AppTheme.success,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(compressorThreshold: v)),
                  ),
                  FxSlider(
                    label: 'Ratio',
                    value: mic.settings.compressorRatio,
                    min: 1,
                    max: 20,
                    unit: ':1',
                    color: AppTheme.success,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(compressorRatio: v)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3-Band EQ
              FxToggleCard(
                title: 'Equalizer (3-Band)',
                icon: Icons.equalizer_rounded,
                color: AppTheme.primary,
                enabled: mic.settings.eqEnabled,
                onToggle: (v) => mic.updateSettings(
                    mic.settings.copyWith(eqEnabled: v)),
                children: [
                  FxSlider(
                    label: 'Bass',
                    value: mic.settings.eqBass,
                    min: -12,
                    max: 12,
                    unit: 'dB',
                    divisions: 24,
                    color: AppTheme.primary,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(eqBass: v)),
                  ),
                  FxSlider(
                    label: 'Mid',
                    value: mic.settings.eqMid,
                    min: -12,
                    max: 12,
                    unit: 'dB',
                    divisions: 24,
                    color: AppTheme.primary,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(eqMid: v)),
                  ),
                  FxSlider(
                    label: 'Treble',
                    value: mic.settings.eqTreble,
                    min: -12,
                    max: 12,
                    unit: 'dB',
                    divisions: 24,
                    color: AppTheme.primary,
                    onChanged: (v) => mic.updateSettings(
                        mic.settings.copyWith(eqTreble: v)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MicControlCard extends StatelessWidget {
  final MicFxProvider mic;
  const _MicControlCard({required this.mic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.card,
            AppTheme.micColor.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: mic.isRecording
              ? AppTheme.micColor.withOpacity(0.4)
              : AppTheme.cardLight,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // VU Meter
          VuMeter(
            level: mic.inputLevel,
            color: AppTheme.micColor,
            label: 'MIC INPUT',
          ),
          const SizedBox(height: 16),

          // Error message
          if (mic.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                mic.errorMessage!,
                style: const TextStyle(color: AppTheme.error, fontSize: 12),
              ),
            ),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Monitor toggle button
              GestureDetector(
                onTap: () {
                  if (mic.isRecording) {
                    mic.stopMonitoring();
                  } else {
                    mic.startMonitoring();
                  }
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: mic.isRecording
                        ? const LinearGradient(
                            colors: [AppTheme.micColor, AppTheme.secondary],
                          )
                        : null,
                    color: mic.isRecording ? null : AppTheme.cardLight,
                    boxShadow: mic.isRecording
                        ? [
                            BoxShadow(
                              color: AppTheme.micColor.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    mic.isRecording
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                    color: mic.isRecording
                        ? Colors.white
                        : AppTheme.textSecondary,
                    size: 32,
                  ),
                ),
              )
                  .animate(target: mic.isRecording ? 1 : 0)
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.05, 1.05),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mic.isRecording ? 'Tap to stop monitoring' : 'Tap to start monitoring',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
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

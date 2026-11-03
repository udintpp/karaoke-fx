import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              const SizedBox(height: 14),

              // Background Service & Auto-Start on Boot Card
              _buildBackgroundAndBootCard(media),
              const SizedBox(height: 14),

              // Bluetooth Audio Receiver & Router Card
              _buildBluetoothAudioCard(media, context),
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
              const SizedBox(height: 14),

              // Dedicated Music Volume Booster (Super Loud / 200%)
              _buildVolumeBoosterCard(media, context),
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

  Widget _buildBackgroundAndBootCard(MediaFxProvider media) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Layanan Latar & Otomatisasi',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save_rounded, color: AppTheme.success, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Auto-Save',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Toggle 1: Aktif di Latar Belakang (Foreground Service)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aktif di Latar Belakang',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Efek audio & mic tetap aktif saat membuka YouTube/Spotify atau layar HP mati.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: media.backgroundServiceEnabled,
                onChanged: media.toggleBackgroundService,
                thumbColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppTheme.primary.withOpacity(0.35)
                      : AppTheme.cardLight,
                ),
              ),
            ],
          ),

          const Divider(color: AppTheme.cardLight, height: 16),

          // Toggle 2: Aktif Saat HP Dinyalakan (Auto Start on Boot)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aktif Otomatis saat HP Nyala (Boot)',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Otomatis terapkan efek equalizer & booster tersimpan saat HP baru selesai restart.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: media.autoStartOnBoot,
                onChanged: media.toggleAutoStartOnBoot,
                thumbColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppTheme.accent
                      : AppTheme.textSecondary,
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppTheme.accent.withOpacity(0.35)
                      : AppTheme.cardLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothAudioCard(MediaFxProvider media, BuildContext context) {
    final bool isRxActive = media.isBtReceiverMode;
    final bool hasSender = media.hasConnectedSender;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRxActive
              ? AppTheme.accent.withOpacity(0.5)
              : media.hasConnectedBtDevice
                  ? AppTheme.primary.withOpacity(0.4)
                  : AppTheme.cardLight,
          width: isRxActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isRxActive
                      ? AppTheme.accent.withOpacity(0.2)
                      : AppTheme.cardLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bluetooth_audio_rounded,
                  color: isRxActive ? AppTheme.accent : AppTheme.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Bluetooth Audio Hub',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppTheme.textSecondary,
                tooltip: 'Refresh Perangkat & Status',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: media.refreshBluetoothStatus,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Warning if Bluetooth is OFF
          if (!media.isBluetoothEnabled) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_disabled_rounded,
                      color: AppTheme.warning, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Bluetooth HP Anda sedang nonaktif.',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: media.enableBluetooth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Nyalakan',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ─── SECTION 1: PENERIMA MUSIK NIRKABEL (WEB RECEIVER - REKOMENDASI 100% DIDUKUNG) ─
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: media.isWirelessReceiverRunning
                    ? [
                        AppTheme.accent.withOpacity(0.2),
                        AppTheme.primary.withOpacity(0.1),
                      ]
                    : [
                        AppTheme.cardLight.withOpacity(0.25),
                        AppTheme.cardLight.withOpacity(0.1),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: media.isWirelessReceiverRunning
                    ? AppTheme.accent.withOpacity(0.6)
                    : AppTheme.cardLight,
                width: media.isWirelessReceiverRunning ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.success,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '⭐ 100% DIDUKUNG SEMUA HP & LAPTOP',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Penerima Musik Nirkabel (Web Receiver)',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Kirim lagu dari HP teman / Laptop langsung lewat browser (Chrome/Safari) tanpa instal aplikasi!',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: media.isWirelessReceiverRunning,
                      onChanged: (val) => media.toggleWirelessReceiver(val),
                      thumbColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.selected)
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                      ),
                      trackColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.selected)
                            ? AppTheme.accent.withOpacity(0.35)
                            : AppTheme.cardLight,
                      ),
                    ),
                  ],
                ),

                if (media.isWirelessReceiverRunning) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Buka alamat ini di HP teman atau Laptop Anda:',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                                ),
                                child: Text(
                                  media.wirelessReceiverUrl,
                                  style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: media.wirelessReceiverUrl));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Alamat URL berhasil disalin!')),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.black,
                              ),
                              tooltip: 'Salin Alamat',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '💡 Pastikan kedua HP terhubung ke Wi-Fi yang sama (atau nyalakan Hotspot di HP ini). Di HP teman/laptop buka Chrome, masukkan alamat di atas, lalu pilih lagu MP3!',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.3),
                        ),
                        if (media.lastReceivedSong.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.music_note_rounded, color: AppTheme.success, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Lagu Diterima: ${media.lastReceivedSong}',
                                    style: const TextStyle(
                                        color: AppTheme.success,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── SECTION 2: MODE PENERIMA AUDIO BLUETOOTH ─────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isRxActive
                    ? [
                        AppTheme.accent.withOpacity(0.18),
                        AppTheme.cardLight.withOpacity(0.4),
                      ]
                    : [
                        AppTheme.cardLight.withOpacity(0.2),
                        AppTheme.cardLight.withOpacity(0.1),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRxActive
                    ? AppTheme.accent.withOpacity(0.4)
                    : AppTheme.cardLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'BLUETOOTH SINK',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isRxActive && media.isBtReceiverPlaying)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.graphic_eq_rounded,
                                          color: AppTheme.success, size: 10),
                                      SizedBox(width: 3),
                                      Text(
                                        'STREAMING',
                                        style: TextStyle(
                                          color: AppTheme.success,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Penerima Audio Bluetooth',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Mode siaga koneksi Bluetooth dengan perangkat lain.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isRxActive,
                      onChanged: (val) => media.toggleBluetoothReceiver(val),
                      thumbColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.selected)
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                      ),
                      trackColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.selected)
                            ? AppTheme.accent.withOpacity(0.35)
                            : AppTheme.cardLight,
                      ),
                    ),
                  ],
                ),

                if (isRxActive) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasSender
                          ? AppTheme.success.withOpacity(0.15)
                          : media.isBtDiscoverable
                              ? AppTheme.accent.withOpacity(0.15)
                              : AppTheme.cardLight.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasSender
                            ? AppTheme.success.withOpacity(0.4)
                            : media.isBtDiscoverable
                                ? AppTheme.accent.withOpacity(0.4)
                                : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              hasSender
                                  ? Icons.check_circle_rounded
                                  : media.isBtDiscoverable
                                      ? Icons.radar_rounded
                                      : Icons.radio_button_checked_rounded,
                              color: hasSender
                                  ? AppTheme.success
                                  : media.isBtDiscoverable
                                      ? AppTheme.accent
                                      : AppTheme.textSecondary,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                hasSender
                                    ? 'Tersambung dari: ${media.btSenderDeviceName}'
                                    : media.isBtDiscoverable
                                        ? 'Siaga: Terlihat sebagai "${media.btLocalDeviceName.isNotEmpty ? media.btLocalDeviceName : "HP Ini"}"'
                                        : 'Mode Penerima Aktif (Nama: ${media.btLocalDeviceName.isNotEmpty ? media.btLocalDeviceName : "HP Ini"})',
                                style: TextStyle(
                                  color: hasSender
                                      ? AppTheme.success
                                      : AppTheme.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasSender
                            ? 'Audio dari pengirim otomatis masuk ke Equalizer & Efek Sistem HP ini.'
                            : 'Sambungkan perangkat pengirim (Laptop/HP lain) ke nama Bluetooth di atas.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => media.requestBluetoothDiscoverable(duration: 300),
                          icon: const Icon(Icons.sensors_rounded, size: 14),
                          label: const Text('Buat Terdeteksi', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accent,
                            side: const BorderSide(color: AppTheme.accent),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showBluetoothSpeakerExplanation(context),
                        icon: const Icon(Icons.help_outline_rounded, size: 14),
                        label: const Text('Kenapa Belum Speaker?', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.warning,
                          side: BorderSide(color: AppTheme.warning.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(color: AppTheme.cardLight, height: 1),
          const SizedBox(height: 12),

          // ─── SECTION 2: PERANGKAT & ROUTING PENGIRIM (TRANSMITTER) ─────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ROUTING & TRANSMITTER',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: media.openBluetoothSettings,
                child: const Text(
                  'Buka Pengaturan HP',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Device status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: media.hasConnectedBtDevice
                  ? AppTheme.primary.withOpacity(0.12)
                  : AppTheme.cardLight.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  media.hasConnectedBtDevice
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_disabled_rounded,
                  color: media.hasConnectedBtDevice
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    media.hasConnectedBtDevice
                        ? [
                            if (media.connectedBtSpeaker.isNotEmpty)
                              '🔊 ${media.connectedBtSpeaker}',
                            if (media.connectedBtMic.isNotEmpty)
                              '🎤 ${media.connectedBtMic}',
                          ].join(' | ')
                        : 'Belum ada speaker/mic Bluetooth terhubung',
                    style: TextStyle(
                      color: media.hasConnectedBtDevice
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Toggle: Wireless Bluetooth Mic (SCO)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mic Wireless Bluetooth',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gunakan mikrofon bluetooth eksternal untuk vokal karaoke.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: media.isBtMicEnabled,
                onChanged: media.toggleBluetoothMic,
                thumbColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppTheme.micColor
                      : AppTheme.textSecondary,
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppTheme.micColor.withOpacity(0.35)
                      : AppTheme.cardLight,
                ),
              ),
            ],
          ),

          const Divider(color: AppTheme.cardLight, height: 14),

          // Toggle: Output ke Speaker Bluetooth (A2DP)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Output ke Speaker Bluetooth',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Alirkan suara musik & vokal ke speaker/soundbar bluetooth.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: media.isBtSpeakerEnabled,
                onChanged: media.toggleBluetoothSpeaker,
                thumbColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppTheme.accent
                      : AppTheme.textSecondary,
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppTheme.accent.withOpacity(0.35)
                      : AppTheme.cardLight,
                ),
              ),
            ],
          ),

          const Divider(color: AppTheme.cardLight, height: 14),

          // Toggle: Mode Low-Latency (Anti Delay Vokal)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mode Low Latency (Anti Delay)',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kurangi jeda suara mikrofon saat terhubung ke perangkat Bluetooth.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: media.isLowLatencyEnabled,
                onChanged: media.toggleLowLatency,
                thumbColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppTheme.primary.withOpacity(0.35)
                      : AppTheme.cardLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReceiverHelpDialog(BuildContext context, String localName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bluetooth_audio_rounded, color: AppTheme.accent, size: 24),
            SizedBox(width: 8),
            Text(
              'Cara Kerja Mode Penerima',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mode ini mengubah HP Anda menjadi Receiver (Speaker) Audio Bluetooth untuk menerima musik dari HP lain, Laptop, PC, atau Smart TV:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              _buildStepItem('1', 'Nyalakan saklar "Penerima Musik Bluetooth" di atas.'),
              _buildStepItem('2', 'Tekan "Buat Terdeteksi" agar HP ini bisa dicari di Bluetooth perangkat lain.'),
              _buildStepItem('3', 'Di HP teman / Laptop Anda, buka pengaturan Bluetooth dan sambungkan ke "${localName.isNotEmpty ? localName : "HP Ini"}".'),
              _buildStepItem('4', 'Putar lagu karaoke atau YouTube dari HP teman / Laptop.'),
              _buildStepItem('5', 'Musik akan langsung masuk ke HP ini, diolah oleh Hardware Equalizer & Bass Boost, dan dapat dinyanyikan langsung bersama Mic!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showBluetoothSpeakerExplanation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mengapa Terdeteksi HP, Bukan Speaker?',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Batasan Resmi Sistem Android (Google):',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
              SizedBox(height: 6),
              Text(
                'Semua smartphone Android standar (Samsung, Xiaomi, Oppo, Vivo, Realme, dll.) oleh pabrikan firmware dikunci hanya sebagai "Pengirim Audio (A2DP Source)", bukan "Penerima/Speaker (A2DP Sink)".\n\nKarena batasan sistem operasi Android ini, HP lain atau laptop akan mendeteksi HP ini sebagai Smartphone/Telepon, bukan speaker Bluetooth biasa.',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                '💡 Solusi Resmi Terbaik Tanpa Batasan:',
                style: TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
              SizedBox(height: 6),
              Text(
                'Gunakan fitur "Penerima Musik Nirkabel (Web Receiver)" di bagian atas tab ini! Anda cukup membuka browser (Chrome/Safari) di HP teman atau Laptop Anda untuk langsung mengirim lagu & karaoke ke HP ini tanpa batasan Bluetooth!',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti',
                style: TextStyle(
                    color: AppTheme.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.3),
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

  Widget _buildVolumeBoosterCard(MediaFxProvider media, BuildContext context) {
    final isBoosted = media.systemLoudnessEnabled && media.systemLoudnessGain > 0;
    final boostPercent = media.systemLoudnessPercent;
    final boostDb = media.systemLoudnessDb;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBoosted
              ? [
                  const Color(0xFF2E1700),
                  AppTheme.card,
                ]
              : [
                  AppTheme.card,
                  AppTheme.card,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isBoosted
              ? const Color(0xFFFF9800).withOpacity(0.6)
              : AppTheme.cardLight,
          width: isBoosted ? 1.5 : 1.0,
        ),
        boxShadow: isBoosted
            ? [
                BoxShadow(
                  color: const Color(0xFFFF9800).withOpacity(0.18),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isBoosted
                      ? const Color(0xFFFF9800).withOpacity(0.2)
                      : AppTheme.cardLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: isBoosted
                      ? const Color(0xFFFF9800)
                      : AppTheme.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '🚀 Penguat Volume Musik',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isBoosted ? const Color(0xFFFF9800) : AppTheme.cardLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isBoosted ? '$boostPercent%' : 'OFF',
                            style: TextStyle(
                              color: isBoosted ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Perkeras volume lagu hingga 200% (+20 dB)',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: media.systemLoudnessEnabled,
                activeColor: const Color(0xFFFF9800),
                onChanged: (val) {
                  media.setSystemLoudnessEnabled(val);
                  if (val && media.systemLoudnessGain == 0) {
                    media.setSystemLoudnessGain(600); // Default to +6 dB (130%)
                  }
                },
              ),
            ],
          ),

          if (media.systemLoudnessEnabled) ...[
            const SizedBox(height: 14),
            // Boost Level Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xFFFF9800)),
                      const SizedBox(width: 8),
                      Text(
                        'Ekstra Keras: $boostPercent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '+${boostDb.toStringAsFixed(1)} dB',
                    style: const TextStyle(
                      color: Color(0xFFFF9800),
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFFF9800),
                thumbColor: const Color(0xFFFF9800),
                inactiveTrackColor: AppTheme.cardLight,
                trackHeight: 6,
                overlayColor: const Color(0xFFFF9800).withOpacity(0.2),
              ),
              child: Slider(
                value: media.systemLoudnessGain,
                min: 0,
                max: 2000,
                divisions: 20,
                onChanged: (v) => media.setSystemLoudnessGain(v),
              ),
            ),

            // Preset Quick Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBoostChip(
                  label: '100% (Normal)',
                  active: media.systemLoudnessGain == 0,
                  onTap: () => media.setVolumeBoostPreset(0),
                ),
                _buildBoostChip(
                  label: '130% (+6dB)',
                  active: (media.systemLoudnessGain - 600).abs() < 50,
                  onTap: () => media.setVolumeBoostPreset(600),
                ),
                _buildBoostChip(
                  label: '160% (+12dB)',
                  active: (media.systemLoudnessGain - 1200).abs() < 50,
                  onTap: () => media.setVolumeBoostPreset(1200),
                ),
                _buildBoostChip(
                  label: '200% MAX',
                  active: media.systemLoudnessGain >= 1950,
                  color: const Color(0xFFFF5722),
                  onTap: () => media.setVolumeBoostPreset(2000),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '💡 Bekerja otomatis untuk semua pemutar musik, YouTube, Spotify, dan Speaker Bluetooth',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBoostChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    Color color = const Color(0xFFFF9800),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : AppTheme.cardLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : AppTheme.textSecondary,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
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

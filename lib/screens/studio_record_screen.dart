import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/record_provider.dart';
import '../providers/mic_fx_provider.dart';
import '../models/camera_effects.dart';
import '../models/recording_item.dart';
import '../theme/app_theme.dart';

class StudioRecordScreen extends StatefulWidget {
  const StudioRecordScreen({super.key});

  @override
  State<StudioRecordScreen> createState() => _StudioRecordScreenState();
}

class _StudioRecordScreenState extends State<StudioRecordScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rec = context.read<RecordProvider>();
      rec.initCamera();
      rec.loadSavedRecordings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RecordProvider, MicFxProvider>(
      builder: (context, rec, mic, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Mode Switcher & Library Button
              _buildTopBar(context, rec),
              const SizedBox(height: 12),

              // Main Preview Area (Composited Camera + Stage Backdrop or Audio Studio)
              rec.mode == RecordingMode.video
                  ? _buildCameraStudioStage(context, rec, mic)
                  : _buildAudioStudioStage(context, rec, mic),

              const SizedBox(height: 16),

              // Recording Action Control Bar (Big Record Button + Timer)
              _buildRecordControls(context, rec),
              const SizedBox(height: 20),

              // AI Video Filters & Background Cutout Sections
              if (rec.mode == RecordingMode.video) ...[
                // Background Cutout Section (Person Only)
                _buildSectionHeader(
                  title: '🎭 Hapus Background (AI Background Remover)',
                  subtitle:
                      'Isolasi tubuh orang secara real-time & ganti ruangan dengan media gambar atau video',
                ),
                const SizedBox(height: 8),
                _buildCutoutModesList(rec),
                const SizedBox(height: 10),
                if (rec.cutoutMode != CutoutMode.none)
                  _buildCutoutSensitivitySlider(rec),
                const SizedBox(height: 20),

                _buildSectionHeader(
                  title: '✨ Efek Kamera AI & Stage Lighting',
                  subtitle:
                      'Filter kecantikan wajah (skin glow) & pencahayaan panggung konser',
                ),
                const SizedBox(height: 8),
                _buildAiFiltersList(rec),
                const SizedBox(height: 20),

                // Background Studio & Backdrop Section
                _buildSectionHeader(
                  title: '🖼️ Background Panggung (Gambar / Video)',
                  subtitle:
                      'Pilih panggung bawaan atau unggah foto/video animasi dari galeri',
                ),
                const SizedBox(height: 8),
                _buildBackdropsList(rec),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, RecordProvider rec) {
    return Row(
      children: [
        // Mode Selector: Video vs Audio
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeTabButton(
                    title: '📹 Video + Musik',
                    selected: rec.mode == RecordingMode.video,
                    onTap: () => rec.setMode(RecordingMode.video),
                  ),
                ),
                Expanded(
                  child: _ModeTabButton(
                    title: '🎙️ Audio Saja',
                    selected: rec.mode == RecordingMode.audioOnly,
                    onTap: () => rec.setMode(RecordingMode.audioOnly),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Saved Recordings Library Button
        IconButton.filledTonal(
          onPressed: () => _showRecordingsLibrary(context, rec),
          icon: Badge(
            label: Text('${rec.savedRecordings.length}'),
            isLabelVisible: rec.savedRecordings.isNotEmpty,
            child: const Icon(Icons.folder_special_rounded, color: Colors.white),
          ),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.card,
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          tooltip: 'Hasil Rekaman',
        ),
      ],
    );
  }

  Widget _buildCameraStudioStage(
      BuildContext context, RecordProvider rec, MicFxProvider mic) {
    return Builder(
      builder: (boxContext) {
        return GestureDetector(
          onTapUp: (details) {
            final box = boxContext.findRenderObject() as RenderBox?;
            if (box != null && box.size.width > 0 && box.size.height > 0) {
              final local = box.globalToLocal(details.globalPosition);
              final nx = (local.dx / box.size.width).clamp(0.05, 0.95);
              final ny = (local.dy / box.size.height).clamp(0.05, 0.95);
              rec.tapToFocus(nx, ny);

              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎯 Fokus & Pencahayaan Terkunci pada Objek'),
                  duration: Duration(milliseconds: 900),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: AspectRatio(
            aspectRatio: MediaQuery.of(context).orientation == Orientation.landscape ? 4 / 3 : 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. OpenGL ES Composited Native Surface (Person Cutout + Replaced Image/Video + Motion FX + AI Color/Beauty Filter)
                  if (rec.isCameraInitialized && rec.textureId != null)
                    Texture(textureId: rec.textureId!)
                  else
                    Container(
                      color: AppTheme.card,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppTheme.primary),
                            const SizedBox(height: 12),
                            Text(
                              rec.errorMessage ??
                                  'Menyiapkan kamera & AI Background Remover...',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. Stage Frame / Vignette Effect & Recording Highlight Border
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: rec.isRecording
                            ? Colors.redAccent.withOpacity(0.85)
                            : Colors.white12,
                        width: rec.isRecording ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // 3. Live Soundwave Visualizer Overlay (Reacting to real-time mic volume)
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: _LiveSoundwaveOverlay(vuLevel: mic.inputLevel),
                  ),

                  // 4. Camera Control Actions (Switch Cam, Flash)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Column(
                      children: [
                        if (rec.hasMultipleCameras)
                          _CircleActionButton(
                            icon: Icons.flip_camera_ios_rounded,
                            onTap: rec.switchCamera,
                            tooltip: 'Ganti Kamera Depan/Belakang',
                          ),
                        const SizedBox(height: 8),
                        _CircleActionButton(
                          icon: rec.isFlashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: rec.isFlashOn ? Colors.amber : Colors.white,
                          onTap: rec.toggleFlash,
                          tooltip: 'Lampu Flash',
                        ),
                      ],
                    ),
                  ),

                  // 5. Active Filter & Backdrop Badges
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rec.selectedFilter.type != AiFilterType.none)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: rec.selectedFilter.primaryColor
                                  .withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(rec.selectedFilter.icon,
                                    size: 13, color: Colors.black87),
                                const SizedBox(width: 4),
                                Text(
                                  rec.selectedFilter.name,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        if (rec.selectedBackdrop.type != BackdropType.none)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  rec.selectedBackdrop.isVideo
                                      ? Icons.videocam_rounded
                                      : rec.selectedBackdrop.icon,
                                  size: 13,
                                  color: rec.selectedBackdrop.isVideo
                                      ? AppTheme.accent
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rec.selectedBackdrop.title,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioStudioStage(
      BuildContext context, RecordProvider rec, MicFxProvider mic) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: rec.isRecording
              ? Colors.redAccent.withOpacity(0.7)
              : Colors.white12,
          width: rec.isRecording ? 2 : 1,
        ),
        gradient: const RadialGradient(
          colors: [Color(0xFF2E1A47), Color(0xFF141421)],
          radius: 0.9,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withOpacity(0.15),
              border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
            ),
            child: Icon(
              Icons.mic_external_on_rounded,
              size: 48,
              color: rec.isRecording ? Colors.redAccent : AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            rec.isRecording
                ? 'Sedang Merekam Vokal & Musik...'
                : 'Studio Rekaman Audio Lossless (WAV)',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rec.isRecording
                ? rec.formattedRecordingTime
                : 'Menangkap output audio mic realtime + musik karaoke',
            style: TextStyle(
              color: rec.isRecording ? Colors.redAccent : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordControls(BuildContext context, RecordProvider rec) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Timer display
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rec.isRecording ? Colors.redAccent : Colors.white30,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rec.formattedRecordingTime,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),

          // Central Record Button
          GestureDetector(
            onTap: () async {
              if (rec.isRecording) {
                final path = await rec.stopRecording();
                if (path != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Rekaman disimpan: ${path.split("/").last}'),
                      backgroundColor: Colors.green[700],
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                await rec.startRecording();
              }
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rec.isRecording ? Colors.redAccent : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: (rec.isRecording ? Colors.redAccent : Colors.red)
                        .withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                rec.isRecording
                    ? Icons.stop_rounded
                    : Icons.fiber_manual_record_rounded,
                color: Colors.white,
                size: rec.isRecording ? 32 : 36,
              ),
            ),
          ),

          // Audio Mic Indicator
          Consumer<MicFxProvider>(
            builder: (_, mic, __) => Row(
              children: [
                Icon(
                  Icons.mic,
                  size: 18,
                  color: mic.isRecording ? AppTheme.micColor : Colors.white30,
                ),
                const SizedBox(width: 4),
                Text(
                  mic.isRecording ? 'MIC ON' : 'MIC OFF',
                  style: TextStyle(
                    color: mic.isRecording ? AppTheme.micColor : Colors.white30,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCutoutModesList(RecordProvider rec) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: CutoutOption.options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final opt = CutoutOption.options[index];
          final isSelected = rec.cutoutMode == opt.mode;

          return GestureDetector(
            onTap: () => rec.setCutoutMode(opt.mode),
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accent.withOpacity(0.2)
                    : AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.accent : Colors.white10,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    opt.icon,
                    color: isSelected ? AppTheme.accent : Colors.white70,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opt.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCutoutSensitivitySlider(RecordProvider rec) {
    String label = 'Sensitivitas Deteksi AI:';
    if (rec.cutoutMode == CutoutMode.aiBlurBackground) {
      label = 'Tingkat Blur Latar Bokeh:';
    } else if (rec.cutoutMode == CutoutMode.greenScreen) {
      label = 'Sensitivitas Layar Hijau:';
    } else if (rec.cutoutMode == CutoutMode.blueScreen) {
      label = 'Sensitivitas Layar Biru:';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Expanded(
                child: Slider(
                  value: rec.cutoutSensitivity,
                  min: 0.1,
                  max: 1.0,
                  activeColor: AppTheme.accent,
                  onChanged: rec.setCutoutSensitivity,
                ),
              ),
              Text(
                '${(rec.cutoutSensitivity * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 4),
            child: Text(
              CutoutOption.options
                  .firstWhere((o) => o.mode == rec.cutoutMode)
                  .description,
              style: TextStyle(
                  fontSize: 10.5, color: Colors.white.withOpacity(0.55)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiFiltersList(RecordProvider rec) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: CameraAiFilter.allFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = CameraAiFilter.allFilters[index];
          final isSelected = rec.selectedFilter.type == filter.type;

          return GestureDetector(
            onTap: () => rec.setFilter(filter),
            child: Container(
              width: 105,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? filter.primaryColor.withOpacity(0.2)
                    : AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? filter.primaryColor : Colors.white10,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(filter.icon, color: filter.primaryColor, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    filter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackdropsList(RecordProvider rec) {
    return SizedBox(
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // 1. Pick Custom Photo from Gallery
          GestureDetector(
            onTap: rec.pickCustomBackdropImage,
            child: Container(
              width: 115,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: rec.selectedBackdrop.type == BackdropType.customLocal &&
                        !rec.selectedBackdrop.isVideo
                    ? AppTheme.accent.withOpacity(0.25)
                    : AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: rec.selectedBackdrop.type == BackdropType.customLocal &&
                          !rec.selectedBackdrop.isVideo
                      ? AppTheme.accent
                      : Colors.white24,
                  width: rec.selectedBackdrop.type == BackdropType.customLocal &&
                          !rec.selectedBackdrop.isVideo
                      ? 2
                      : 1,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      color: AppTheme.accent, size: 22),
                  SizedBox(height: 4),
                  Text(
                    '+ Foto Galeri',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Pick Custom Video from Gallery
          GestureDetector(
            onTap: rec.pickCustomBackdropVideo,
            child: Container(
              width: 115,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: rec.selectedBackdrop.type == BackdropType.customLocal &&
                        rec.selectedBackdrop.isVideo
                    ? AppTheme.primary.withOpacity(0.25)
                    : AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: rec.selectedBackdrop.type == BackdropType.customLocal &&
                          rec.selectedBackdrop.isVideo
                      ? AppTheme.primary
                      : Colors.white24,
                  width: rec.selectedBackdrop.type == BackdropType.customLocal &&
                          rec.selectedBackdrop.isVideo
                      ? 2
                      : 1,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_collection_rounded,
                      color: AppTheme.primary, size: 22),
                  SizedBox(height: 4),
                  Text(
                    '+ Video Galeri',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Preset Backdrops
          ...StudioBackdrop.presets.map((b) {
            final isSelected = rec.selectedBackdrop.type == b.type;
            return GestureDetector(
              onTap: () => rec.setBackdrop(b),
              child: Container(
                width: 110,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withOpacity(0.25)
                      : AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : Colors.white10,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(b.icon, color: Colors.white, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      b.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      {required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
        ),
      ],
    );
  }

  void _showRecordingsLibrary(BuildContext context, RecordProvider rec) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181825),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<RecordProvider>(
          builder: (_, recordProv, __) {
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '📁 Galeri Rekaman Karaoke',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${recordProv.savedRecordings.length} File',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      Expanded(
                        child: recordProv.savedRecordings.isEmpty
                            ? const Center(
                                child: Text(
                                  'Belum ada rekaman tersimpan.\nMulai rekam video atau audio sekarang!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 13),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: recordProv.savedRecordings.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final item = recordProv.savedRecordings[i];
                                  final isPlaying =
                                      recordProv.currentlyPlayingId == item.id &&
                                          recordProv.isPlayingPlayback;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isPlaying
                                          ? AppTheme.primary.withOpacity(0.15)
                                          : AppTheme.card,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isPlaying
                                            ? AppTheme.primary
                                            : Colors.white10,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.isVideo
                                              ? Icons.videocam_rounded
                                              : Icons.audiotrack_rounded,
                                          color: item.isVideo
                                              ? AppTheme.accent
                                              : AppTheme.primary,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item.formattedDate} • ${item.formattedSize}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white
                                                      .withOpacity(0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Play / View Button for Video
                                        if (item.isVideo)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.play_circle_fill_rounded,
                                              color: AppTheme.accent,
                                              size: 30,
                                            ),
                                            tooltip: 'Tonton Video',
                                            onPressed: () {
                                              _showVideoPlayerDialog(
                                                  context, recordProv, item);
                                            },
                                          ),
                                        // Play / Pause Button for Audio
                                        if (!item.isVideo)
                                          IconButton(
                                            icon: Icon(
                                              isPlaying
                                                  ? Icons
                                                      .pause_circle_filled_rounded
                                                  : Icons
                                                      .play_circle_fill_rounded,
                                              color: AppTheme.primary,
                                              size: 30,
                                            ),
                                            tooltip: 'Putar Audio',
                                            onPressed: () =>
                                                recordProv.playAudioRecording(item),
                                          ),
                                        // Delete Button
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent,
                                              size: 20),
                                          onPressed: () =>
                                              recordProv.deleteRecording(item),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showVideoPlayerDialog(
      BuildContext context, RecordProvider rec, RecordingItem item) {
    rec.startRecordedVideoPlayback(item.path);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF141421),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Consumer<RecordProvider>(
            builder: (_, prov, __) {
              final dur = prov.videoDurationMs;
              final pos = prov.videoPositionMs;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70),
                          onPressed: () {
                            prov.stopRecordedVideoPlayback();
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Video Texture Container
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: prov.playbackVideoTextureId != null
                            ? Texture(textureId: prov.playbackVideoTextureId!)
                            : Container(
                                color: Colors.black,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: AppTheme.accent),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Progress Slider
                    if (dur > 0)
                      Slider(
                        value: pos.clamp(0, dur).toDouble(),
                        min: 0.0,
                        max: dur.toDouble(),
                        activeColor: AppTheme.accent,
                        onChanged: (val) {
                          prov.seekRecordedVideo(val.toInt());
                        },
                      ),
                    // Playback Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            prov.isPlayingVideo
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 44,
                            color: AppTheme.accent,
                          ),
                          onPressed: prov.toggleRecordedVideoPause,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ).then((_) {
      rec.stopRecordedVideoPlayback();
    });
  }
}

class _ModeTabButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTabButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;

  const _CircleActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black54,
        padding: const EdgeInsets.all(8),
      ),
      tooltip: tooltip,
    );
  }
}

class _LiveSoundwaveOverlay extends StatelessWidget {
  final double vuLevel; // 0.0 - 1.0

  const _LiveSoundwaveOverlay({required this.vuLevel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(18, (i) {
          final barScale = ((i - 9).abs() / 9.0);
          final barHeight =
              (8 + (vuLevel * 28 * (1.0 - barScale * 0.5))).clamp(4.0, 36.0);
          final color =
              Color.lerp(AppTheme.primary, AppTheme.accent, i / 18.0) ??
                  AppTheme.primary;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 3.5,
            height: barHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

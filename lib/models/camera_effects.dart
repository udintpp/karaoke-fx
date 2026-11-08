import 'package:flutter/material.dart';

enum AiFilterType {
  none,
  beauty,
  neonCyberpunk,
  goldenConcert,
  kpopIdol,
  vintageCinema,
  noirBlackWhite,
}

class CameraAiFilter {
  final AiFilterType type;
  final String name;
  final IconData icon;
  final Color primaryColor;
  final List<double>? matrix;
  final bool isBeauty;
  final double exposureOffset;

  const CameraAiFilter({
    required this.type,
    required this.name,
    required this.icon,
    required this.primaryColor,
    this.matrix,
    this.isBeauty = false,
    this.exposureOffset = 0.0,
  });

  ColorFilter? get colorFilter =>
      matrix != null ? ColorFilter.matrix(matrix!) : null;

  static const List<CameraAiFilter> allFilters = [
    CameraAiFilter(
      type: AiFilterType.none,
      name: 'Original',
      icon: Icons.filter_none_rounded,
      primaryColor: Colors.white,
      matrix: null,
      isBeauty: false,
    ),
    CameraAiFilter(
      type: AiFilterType.beauty,
      name: 'AI Beauty & Glow',
      icon: Icons.auto_awesome_rounded,
      primaryColor: Color(0xFFFF8DA1),
      isBeauty: true,
      // Soft skin warming & glow luminance
      matrix: [
        1.08, 0.02, 0.02, 0.0, 10.0,
        0.02, 1.05, 0.02, 0.0, 8.0,
        0.02, 0.02, 1.02, 0.0, 6.0,
        0.0,  0.0,  0.0,  1.0, 0.0,
      ],
    ),
    CameraAiFilter(
      type: AiFilterType.neonCyberpunk,
      name: 'AI Cyberpunk',
      icon: Icons.electric_bolt_rounded,
      primaryColor: Color(0xFF00E5FF),
      isBeauty: false,
      // Vibrant neon stage (cyan-magenta pop)
      matrix: [
        1.3, -0.1,  0.2, 0.0, 15.0,
        -0.1, 1.1,  0.3, 0.0, -5.0,
        0.1,  0.2,  1.4, 0.0, 20.0,
        0.0,  0.0,  0.0, 1.0, 0.0,
      ],
    ),
    CameraAiFilter(
      type: AiFilterType.goldenConcert,
      name: 'Panggung Emas',
      icon: Icons.wb_sunny_rounded,
      primaryColor: Color(0xFFFFB300),
      isBeauty: false,
      // Warm golden concert lighting
      matrix: [
        1.25, 0.1,  0.0,  0.0, 20.0,
        0.1,  1.15, 0.0,  0.0, 10.0,
        0.0,  0.0,  0.85, 0.0, -10.0,
        0.0,  0.0,  0.0,  1.0, 0.0,
      ],
    ),
    CameraAiFilter(
      type: AiFilterType.kpopIdol,
      name: 'K-Pop Idol',
      icon: Icons.stars_rounded,
      primaryColor: Color(0xFFE040FB),
      isBeauty: false,
      // Bright pastel punch & vibrant highlights
      matrix: [
        1.15, 0.05, 0.1,  0.0, 15.0,
        0.05, 1.12, 0.05, 0.0, 12.0,
        0.1,  0.05, 1.25, 0.0, 25.0,
        0.0,  0.0,  0.0,  1.0, 0.0,
      ],
    ),
    CameraAiFilter(
      type: AiFilterType.vintageCinema,
      name: 'Vintage Retro',
      icon: Icons.movie_filter_rounded,
      primaryColor: Color(0xFFFF7043),
      isBeauty: false,
      // Warm film grain / 70s nostalgia
      matrix: [
        1.1,  0.1,  0.0,  0.0, 10.0,
        0.05, 0.95, 0.05, 0.0, 5.0,
        0.0,  0.1,  0.8,  0.0, -15.0,
        0.0,  0.0,  0.0,  1.0, 0.0,
      ],
    ),
    CameraAiFilter(
      type: AiFilterType.noirBlackWhite,
      name: 'B&W Jazz Club',
      icon: Icons.camera_rounded,
      primaryColor: Color(0xFFB0BEC5),
      isBeauty: false,
      // High contrast dramatic noir monochrome
      matrix: [
        0.33, 0.59, 0.11, 0.0, 5.0,
        0.33, 0.59, 0.11, 0.0, 5.0,
        0.33, 0.59, 0.11, 0.0, 5.0,
        0.0,  0.0,  0.0,  1.0, 0.0,
      ],
    ),
  ];
}

enum BackdropType {
  none,
  concertStadium,
  galaxyStage,
  neonClub,
  acousticCafe,
  sunsetBeach,
  customLocal,
}

class StudioBackdrop {
  final BackdropType type;
  final String title;
  final IconData icon;
  final String mediaType; // 'none', 'image', 'video'
  final String sourceKind; // 'none', 'asset', 'file'
  final String pathOrKey;
  final String motionType; // 'none', 'concertBeams', 'neonPulse', 'galaxyStars'
  final List<Color> gradientColors;
  final String? localFilePath;

  const StudioBackdrop({
    required this.type,
    required this.title,
    required this.icon,
    required this.mediaType,
    required this.sourceKind,
    required this.pathOrKey,
    this.motionType = 'none',
    required this.gradientColors,
    this.localFilePath,
  });

  bool get isVideo => mediaType == 'video';

  static const List<StudioBackdrop> presets = [
    StudioBackdrop(
      type: BackdropType.none,
      title: 'Transparan / Polos',
      icon: Icons.block_rounded,
      mediaType: 'none',
      sourceKind: 'none',
      pathOrKey: '',
      gradientColors: [Color(0xFF1E1E2E), Color(0xFF11111B)],
    ),
    StudioBackdrop(
      type: BackdropType.concertStadium,
      title: 'Panggung Konser Megah',
      icon: Icons.stadium_rounded,
      mediaType: 'image',
      sourceKind: 'asset',
      pathOrKey: 'assets/images/bg_concert_stage.png',
      motionType: 'concertBeams',
      gradientColors: [Color(0xFF2A0845), Color(0xFF6441A5), Color(0xFFFF416C)],
    ),
    StudioBackdrop(
      type: BackdropType.galaxyStage,
      title: 'Galaxy Cyberpunk',
      icon: Icons.blur_circular_rounded,
      mediaType: 'image',
      sourceKind: 'asset',
      pathOrKey: 'assets/images/bg_galaxy_stage.jpg',
      motionType: 'galaxyStars',
      gradientColors: [Color(0xFF0575E6), Color(0xFF00F260), Color(0xFF11111B)],
    ),
    StudioBackdrop(
      type: BackdropType.neonClub,
      title: 'Neon VIP Karaoke',
      icon: Icons.nightlife_rounded,
      mediaType: 'image',
      sourceKind: 'asset',
      pathOrKey: 'assets/images/bg_neon_vip.png',
      motionType: 'neonPulse',
      gradientColors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
    ),
    StudioBackdrop(
      type: BackdropType.acousticCafe,
      title: 'Kafe Akustik Warm',
      icon: Icons.coffee_rounded,
      mediaType: 'image',
      sourceKind: 'asset',
      pathOrKey: 'assets/images/bg_acoustic_cafe.jpg',
      motionType: 'none',
      gradientColors: [Color(0xFF3E2723), Color(0xFF5D4037), Color(0xFFD7CCC8)],
    ),
    StudioBackdrop(
      type: BackdropType.sunsetBeach,
      title: 'Sunset Pantai Tropis',
      icon: Icons.beach_access_rounded,
      mediaType: 'image',
      sourceKind: 'asset',
      pathOrKey: 'assets/images/bg_sunset_beach.png',
      motionType: 'none',
      gradientColors: [Color(0xFFFA709A), Color(0xFFFEE140), Color(0xFF302B63)],
    ),
  ];
}

enum CutoutMode {
  none,
  aiPersonCutout,
  aiBlurBackground,
  greenScreen,
  blueScreen,
}

class CutoutOption {
  final CutoutMode mode;
  final String title;
  final IconData icon;
  final String description;

  const CutoutOption({
    required this.mode,
    required this.title,
    required this.icon,
    required this.description,
  });

  static const List<CutoutOption> options = [
    CutoutOption(
      mode: CutoutMode.none,
      title: 'Kamera Asli',
      icon: Icons.crop_free_rounded,
      description: 'Tampilkan seluruh ruangan tanpa pemotongan background',
    ),
    CutoutOption(
      mode: CutoutMode.aiPersonCutout,
      title: 'AI Background Remover (Rekomendasi)',
      icon: Icons.person_pin_rounded,
      description: 'Hapus latar belakang ruangan & ganti dengan panggung/video pilihan',
    ),
    CutoutOption(
      mode: CutoutMode.aiBlurBackground,
      title: 'AI Bokeh Blur Background',
      icon: Icons.blur_on_rounded,
      description: 'Fokuskan orang di kamera, buramkan latar belakang seperti kamera DSLR',
    ),
    CutoutOption(
      mode: CutoutMode.greenScreen,
      title: 'Chroma Key Hijau',
      icon: Icons.auto_fix_high_rounded,
      description: 'Hapus layar hijau studio di belakang Anda 100% transparan',
    ),
    CutoutOption(
      mode: CutoutMode.blueScreen,
      title: 'Chroma Key Biru',
      icon: Icons.auto_fix_normal_rounded,
      description: 'Hapus layar biru studio di belakang Anda 100% transparan',
    ),
  ];
}

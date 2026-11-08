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
  final ColorFilter? colorFilter;
  final double exposureOffset;

  const CameraAiFilter({
    required this.type,
    required this.name,
    required this.icon,
    required this.primaryColor,
    this.colorFilter,
    this.exposureOffset = 0.0,
  });

  static const List<CameraAiFilter> allFilters = [
    CameraAiFilter(
      type: AiFilterType.none,
      name: 'Original',
      icon: Icons.filter_none_rounded,
      primaryColor: Colors.white,
      colorFilter: null,
    ),
    CameraAiFilter(
      type: AiFilterType.beauty,
      name: 'AI Beauty & Glow',
      icon: Icons.auto_awesome_rounded,
      primaryColor: Color(0xFFFF8DA1),
      // Soft skin warming & glow luminance
      colorFilter: ColorFilter.matrix([
        1.08, 0.02, 0.02, 0, 10,
        0.02, 1.05, 0.02, 0, 8,
        0.02, 0.02, 1.02, 0, 6,
        0,    0,    0,    1, 0,
      ]),
    ),
    CameraAiFilter(
      type: AiFilterType.neonCyberpunk,
      name: 'AI Cyberpunk',
      icon: Icons.electric_bolt_rounded,
      primaryColor: Color(0xFF00E5FF),
      // Vibrant neon stage (cyan-magenta pop)
      colorFilter: ColorFilter.matrix([
        1.3, -0.1,  0.2, 0, 15,
        -0.1, 1.1,  0.3, 0, -5,
        0.1,  0.2,  1.4, 0, 20,
        0,    0,    0,   1, 0,
      ]),
    ),
    CameraAiFilter(
      type: AiFilterType.goldenConcert,
      name: 'Panggung Emas',
      icon: Icons.wb_sunny_rounded,
      primaryColor: Color(0xFFFFB300),
      // Warm golden concert lighting
      colorFilter: ColorFilter.matrix([
        1.25, 0.1,  0.0,  0, 20,
        0.1,  1.15, 0.0,  0, 10,
        0.0,  0.0,  0.85, 0, -10,
        0,    0,    0,    1, 0,
      ]),
    ),
    CameraAiFilter(
      type: AiFilterType.kpopIdol,
      name: 'K-Pop Idol',
      icon: Icons.stars_rounded,
      primaryColor: Color(0xFFE040FB),
      // Bright pastel punch & vibrant highlights
      colorFilter: ColorFilter.matrix([
        1.15, 0.05, 0.1,  0, 15,
        0.05, 1.12, 0.05, 0, 12,
        0.1,  0.05, 1.25, 0, 25,
        0,    0,    0,    1, 0,
      ]),
    ),
    CameraAiFilter(
      type: AiFilterType.vintageCinema,
      name: 'Vintage Retro',
      icon: Icons.movie_filter_rounded,
      primaryColor: Color(0xFFFF7043),
      // Warm film grain / 70s nostalgia
      colorFilter: ColorFilter.matrix([
        1.1,  0.1,  0.0,  0, 10,
        0.05, 0.95, 0.05, 0, 5,
        0.0,  0.1,  0.8,  0, -15,
        0,    0,    0,    1, 0,
      ]),
    ),
    CameraAiFilter(
      type: AiFilterType.noirBlackWhite,
      name: 'B&W Jazz Club',
      icon: Icons.camera_rounded,
      primaryColor: Color(0xFFB0BEC5),
      // High contrast dramatic noir monochrome
      colorFilter: ColorFilter.matrix([
        0.33, 0.59, 0.11, 0, 5,
        0.33, 0.59, 0.11, 0, 5,
        0.33, 0.59, 0.11, 0, 5,
        0,    0,    0,    1, 0,
      ]),
    ),
  ];
}

enum BackdropType {
  none,
  concertStadium,
  neonClub,
  galaxyStage,
  acousticCafe,
  sunsetBeach,
  customLocal,
}

class StudioBackdrop {
  final BackdropType type;
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final String? localFilePath;

  const StudioBackdrop({
    required this.type,
    required this.title,
    required this.icon,
    required this.gradientColors,
    this.localFilePath,
  });

  static const List<StudioBackdrop> presets = [
    StudioBackdrop(
      type: BackdropType.none,
      title: 'Transparan / Polos',
      icon: Icons.block_rounded,
      gradientColors: [Color(0xFF1E1E2E), Color(0xFF11111B)],
    ),
    StudioBackdrop(
      type: BackdropType.concertStadium,
      title: 'Panggung Konser',
      icon: Icons.stadium_rounded,
      gradientColors: [Color(0xFF2A0845), Color(0xFF6441A5), Color(0xFFFF416C)],
    ),
    StudioBackdrop(
      type: BackdropType.neonClub,
      title: 'Neon VIP Karaoke',
      icon: Icons.nightlife_rounded,
      gradientColors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
    ),
    StudioBackdrop(
      type: BackdropType.galaxyStage,
      title: 'Galaxy Cyberpunk',
      icon: Icons.blur_circular_rounded,
      gradientColors: [Color(0xFF0575E6), Color(0xFF00F260), Color(0xFF11111B)],
    ),
    StudioBackdrop(
      type: BackdropType.acousticCafe,
      title: 'Kafe Akustik',
      icon: Icons.coffee_rounded,
      gradientColors: [Color(0xFF3E2723), Color(0xFF5D4037), Color(0xFFD7CCC8)],
    ),
    StudioBackdrop(
      type: BackdropType.sunsetBeach,
      title: 'Sunset Pantai',
      icon: Icons.beach_access_rounded,
      gradientColors: [Color(0xFFFA709A), Color(0xFFFEE140), Color(0xFF302B63)],
    ),
  ];
}

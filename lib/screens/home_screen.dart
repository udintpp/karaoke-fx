import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/mic_fx_provider.dart';
import '../providers/media_fx_provider.dart';
import '../theme/app_theme.dart';
import 'mic_fx_screen.dart';
import 'media_fx_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTab = _tabController.index);
    });

    // Initialize mic provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MicFxProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  MicFxScreen(),
                  MediaFxScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Logo / Title
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Karaoke FX',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Professional Audio Effects',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Status indicators
          Consumer<MicFxProvider>(
            builder: (_, mic, __) => _StatusDot(
              color: mic.isRecording ? AppTheme.micColor : AppTheme.textSecondary,
              label: 'MIC',
              active: mic.isRecording,
            ),
          ),
          const SizedBox(width: 8),
          Consumer<MediaFxProvider>(
            builder: (_, media, __) => _StatusDot(
              color: media.isPlaying ? AppTheme.mediaColor : AppTheme.textSecondary,
              label: 'MED',
              active: media.isPlaying,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2);
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: _selectedTab == 0
                ? [AppTheme.primary, AppTheme.secondary]
                : [AppTheme.accent, AppTheme.accent.withBlue(200)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.mic_rounded, size: 20),
            text: 'Microphone FX',
            iconMargin: EdgeInsets.only(bottom: 2),
            height: 52,
          ),
          Tab(
            icon: Icon(Icons.music_note_rounded, size: 20),
            text: 'Media FX',
            iconMargin: EdgeInsets.only(bottom: 2),
            height: 52,
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool active;

  const _StatusDot({
    required this.color,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: active
                ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)]
                : null,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.3, 1.3),
              duration: 800.ms,
            )
            .then()
            .scale(
              begin: const Offset(1.3, 1.3),
              end: const Offset(1, 1),
              duration: 800.ms,
            ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

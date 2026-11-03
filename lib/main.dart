import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_session/audio_session.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/mic_fx_provider.dart';
import 'providers/media_fx_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure audio session for karaoke use
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MicFxProvider()),
        ChangeNotifierProvider(create: (_) => MediaFxProvider()),
      ],
      child: const KaraokeFxApp(),
    ),
  );
}

class KaraokeFxApp extends StatelessWidget {
  const KaraokeFxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karaoke FX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}

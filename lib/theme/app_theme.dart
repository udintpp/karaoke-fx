import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF7C3AED);      // Purple
  static const Color secondary = Color(0xFFEC4899);    // Pink
  static const Color accent = Color(0xFF06B6D4);       // Cyan
  static const Color surface = Color(0xFF1E1B2E);      // Dark purple bg
  static const Color card = Color(0xFF2D2A3E);         // Card bg
  static const Color cardLight = Color(0xFF3D3A52);    // Light card
  static const Color textPrimary = Color(0xFFF1F0F5);
  static const Color textSecondary = Color(0xFFA09DB5);
  static const Color micColor = Color(0xFFEC4899);     // Pink for mic
  static const Color mediaColor = Color(0xFF06B6D4);   // Cyan for media
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: const CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        overlayColor: primary.withOpacity(0.2),
        inactiveTrackColor: cardLight,
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary.withOpacity(0.4)
              : cardLight,
        ),
      ),
    );
  }
}

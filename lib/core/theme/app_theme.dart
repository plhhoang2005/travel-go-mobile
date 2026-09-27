import 'package:flutter/material.dart';

class AppTheme {
  // Palette derived directly from Travel-Go Mobile App Prototype (Figma Make)
  static const Color primaryColor = Color(0xFF086C61); // Deep Coastal Teal
  static const Color primaryDark = Color(0xFF034B46); // Dark Teal Canvas
  static const Color primarySoft = Color(0xFFE4F4F1); // Light Teal Tint
  static const Color secondaryColor = Color(0xFFFF7657); // Coral Orange Accent
  static const Color aiColor = Color(0xFF5A46C8); // AI Royal Indigo
  static const Color aiSoft = Color(0xFFEDEAFD);
  static const Color bgSurface = Color(0xFFF5F7F6);
  static const Color border = Color(0xFFDFE6E4);
  static const Color textMain = Color(0xFF172422);
  static const Color textMuted = Color(0xFF65726F);
  static const Color ratingBg = Color(0xFFFFF3DC);
  static const Color ratingText = Color(0xFFA65B0B);

  // Classic slate & legacy aliases
  static const Color navy = Color(0xFF092D39);
  static const Color accentOrange = Color(0xFFFF7657);
  static const Color accentEmerald = Color(0xFF16875D);
  static const Color accentAmber = Color(0xFFC97817);
  static const Color cream = Color(0xFFF8F7F3);
  static const Color slate50 = Color(0xFFF5F7F6);
  static const Color slate100 = Color(0xFFEEF1F0);
  static const Color slate200 = Color(0xFFDFE6E4);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF65726F);
  static const Color slate600 = Color(0xFF475569);
  static const Color line = Color(0xFFDFE6E4);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF172422);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentOrange,
        tertiary: navy,
        surface: slate50,
      ),
      scaffoldBackgroundColor: slate50,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: slate900,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: slate800),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: slate200, width: 1),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
        inactiveTrackColor: slate200,
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        selectedColor: primaryColor.withValues(alpha: 0.15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

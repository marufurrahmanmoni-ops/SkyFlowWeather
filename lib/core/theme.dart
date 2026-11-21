import 'package:material_ui/material_ui.dart';

/// SkyFlow colour palette: dark navy and charcoal with a cyan accent.
class AppColors {
  AppColors._();

  static const Color navy = Color(0xFF09111F);
  static const Color navyLight = Color(0xFF101B2E);
  static const Color charcoal = Color(0xFF151B25);
  static const Color charcoalHigh = Color(0xFF1C2431);
  static const Color panel = Color(0xEB121A28);
  static const Color panelSolid = Color(0xFF121A28);
  static const Color stroke = Color(0x22FFFFFF);
  static const Color accent = Color(0xFF4CC3FF);
  static const Color accentDeep = Color(0xFF1E88E5);
  static const Color amber = Color(0xFFFFB547);
  static const Color danger = Color(0xFFFF5A5F);
  static const Color success = Color(0xFF3DDC97);
  static const Color textPrimary = Color(0xFFEAF1FA);
  static const Color textSecondary = Color(0xFF9AA8BA);
  static const Color textMuted = Color(0xFF6B7A8F);

  /// Distinct, colour-blind-friendly colours for weather-model series.
  static const List<Color> series = [
    Color(0xFF4CC3FF),
    Color(0xFFFFB547),
    Color(0xFF3DDC97),
    Color(0xFFFF6B8B),
    Color(0xFFB38CFF),
    Color(0xFFFFE066),
    Color(0xFF6EE7F9),
    Color(0xFFFF8A3D),
    Color(0xFFA3E635),
    Color(0xFFF472B6),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: const Color(0xFF00243A),
      secondary: AppColors.amber,
      onSecondary: const Color(0xFF2B1800),
      surface: AppColors.charcoal,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.navy,
      surfaceContainerLow: const Color(0xFF111824),
      surfaceContainer: AppColors.charcoal,
      surfaceContainerHigh: AppColors.charcoalHigh,
      surfaceContainerHighest: const Color(0xFF232D3C),
      outline: const Color(0xFF3A4658),
      outlineVariant: const Color(0xFF263142),
      error: AppColors.danger,
    );

    const textTheme = TextTheme(
      displayLarge: TextStyle(
          fontSize: 64, fontWeight: FontWeight.w300, letterSpacing: -2),
      displayMedium: TextStyle(
          fontSize: 48, fontWeight: FontWeight.w300, letterSpacing: -1.2),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      titleSmall: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      bodyLarge: TextStyle(fontSize: 16, height: 1.35),
      bodyMedium: TextStyle(fontSize: 14, height: 1.35),
      bodySmall: TextStyle(fontSize: 12, height: 1.3),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.navy,
      canvasColor: AppColors.navy,
      textTheme: textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.charcoal,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.stroke),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.navyLight,
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        height: 66,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.panelSolid,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.charcoalHigh,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.charcoalHigh,
        selectedColor: AppColors.accent.withValues(alpha: 0.22),
        side: const BorderSide(color: AppColors.stroke),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
        thumbColor: Colors.white,
        overlayColor: AppColors.accent.withValues(alpha: 0.15),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.stroke,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.charcoalHigh,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.accent,
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.start,
      ),
    );
  }
}

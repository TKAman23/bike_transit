import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Light and dark themes built from one recipe so every page stays consistent.
class AppTheme {
  AppTheme._();

  static const Color brandBlue = Color(0xFF1769AA);
  static const Color _lightBackground = Color(0xFFF4F7FB);
  static const Color _darkBackground = Color(0xFF0F161D);

  static ThemeData get lightTheme => _build(
        ColorScheme.fromSeed(seedColor: brandBlue).copyWith(
          primary: brandBlue,
          onPrimary: Colors.white,
          secondary: const Color(0xFF168A83),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF1C2630),
          onSurfaceVariant: const Color(0xFF5A6875),
          surfaceContainerLow: const Color(0xFFF6F8FB),
          surfaceContainer: const Color(0xFFF0F3F7),
          surfaceContainerHigh: const Color(0xFFE8EDF2),
          surfaceContainerHighest: const Color(0xFFE1E7ED),
          outlineVariant: const Color(0xFFDDE3EA),
        ),
        _lightBackground,
      );

  static ThemeData get darkTheme => _build(
        ColorScheme.fromSeed(seedColor: brandBlue, brightness: Brightness.dark)
            .copyWith(
          primary: const Color(0xFF8AB4F8),
          onPrimary: const Color(0xFF08213A),
          secondary: const Color(0xFF80CBC4),
          onSecondary: const Color(0xFF003731),
          surface: const Color(0xFF18222B),
          onSurface: const Color(0xFFE3EAF1),
          onSurfaceVariant: const Color(0xFFA5B3C0),
          surfaceContainerLow: const Color(0xFF1B252E),
          surfaceContainer: const Color(0xFF1F2A34),
          surfaceContainerHigh: const Color(0xFF26323D),
          surfaceContainerHighest: const Color(0xFF2E3B47),
          outlineVariant: const Color(0xFF34424F),
        ),
        _darkBackground,
      );

  static ThemeData _build(ColorScheme colors, Color background) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: 'Roboto',
    );
    final text = base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    final radius12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final radius14 = BorderRadius.circular(14);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: colors.surface,
      textTheme: text,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: colors.onSurface),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.surfaceContainerHigh,
          foregroundColor: colors.onSurface,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: radius12,
          textStyle: text.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: radius12,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colors.outlineVariant),
          shape: radius12,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(radius12),
          side: WidgetStatePropertyAll(BorderSide(color: colors.outlineVariant)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.surfaceContainer),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? colors.onPrimary
                  : colors.onSurfaceVariant),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: radius14, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceContainerHighest,
        thumbColor: colors.primary,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        showValueIndicator: ShowValueIndicator.never,
      ),
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
            ? const Icon(Icons.check, size: 14)
            : null),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surface),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: radius12,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.primaryContainer,
        labelStyle: TextStyle(color: colors.onSurface, fontSize: 13),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: colors.onSurfaceVariant),
      listTileTheme: ListTileThemeData(
        iconColor: colors.onSurfaceVariant,
        shape: radius12,
      ),
    );
  }
}

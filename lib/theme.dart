import 'package:flutter/material.dart';

class AppTheme {
  static const Color _brandBlue = Color(0xFF1769AA);
  static const Color _lightBackground = Color(0xFFF7F9FC);
  static const Color _darkBackground = Color(0xFF101820);

  static ThemeData get lightTheme {
    final colors =
        ColorScheme.fromSeed(
          seedColor: _brandBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: _brandBlue,
          onPrimary: Colors.white,
          secondary: const Color(0xFF168A83),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF202A33),
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: colors,
      scaffoldBackgroundColor: _lightBackground,
      canvasColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF202A33),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 70, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 60, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 50, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 20, height: 1.4),
        bodyMedium: TextStyle(fontSize: 15, height: 1.4),
        labelLarge: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE1E7ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: colors.primaryContainer,
        elevation: 2,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0F4F8),
        selectedColor: colors.primaryContainer,
        labelStyle: TextStyle(color: colors.onSurface, fontSize: 13),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E9EF),
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF52616F)),
    );
  }

  static ThemeData get darkTheme {
    final colors =
        ColorScheme.fromSeed(
          seedColor: _brandBlue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF8AB4F8),
          onPrimary: const Color(0xFF08213A),
          secondary: const Color(0xFF80CBC4),
          onSecondary: const Color(0xFF003731),
          surface: const Color(0xFF1B252E),
          onSurface: const Color(0xFFE3EAF1),
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: colors,
      scaffoldBackgroundColor: _darkBackground,
      canvasColor: const Color(0xFF1B252E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B252E),
        foregroundColor: Color(0xFFE3EAF1),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 70, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 60, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 50, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 20, height: 1.4),
        bodyMedium: TextStyle(fontSize: 15, height: 1.4),
        labelLarge: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A), // Matte dark grey/black
          foregroundColor: Colors.white, // Clean white text
          elevation: 0, // Minimalist flat look to match the fields
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              16,
            ), // Rounded corners matching your inputs
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF25323D),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF354451)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1B252E),
        indicatorColor: const Color(0xFF31465D),
        elevation: 2,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF25323D),
        selectedColor: const Color(0xFF31465D),
        labelStyle: TextStyle(color: colors.onSurface, fontSize: 13),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF354451),
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: Color(0xFFB0BEC9)),
    );
  }
}

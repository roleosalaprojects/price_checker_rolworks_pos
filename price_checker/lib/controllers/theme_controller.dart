import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

const String _themeModeKey = 'theme_mode';

/// App theme definitions for light and dark modes
class AppTheme {
  // Accent color used across the app
  static const Color accentColor = Color(0xFFf48d92);

  // Light theme colors
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightPrimaryText = Color(0xFF212121);
  static const Color lightSecondaryText = Color(0xFF757575);

  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFFB3B3B3);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBackground,
        colorScheme: const ColorScheme.light(
          primary: accentColor,
          secondary: accentColor,
          surface: lightCard,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: lightPrimaryText,
        ),
        cardTheme: CardThemeData(
          color: lightCard,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: lightBackground,
          foregroundColor: lightPrimaryText,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accentColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 14,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accentColor,
          ),
        ),
        iconTheme: const IconThemeData(
          color: lightSecondaryText,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: accentColor,
          secondary: accentColor,
          surface: darkCard,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: darkPrimaryText,
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBackground,
          foregroundColor: darkPrimaryText,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accentColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 14,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accentColor,
          ),
        ),
        iconTheme: const IconThemeData(
          color: darkSecondaryText,
        ),
      );
}

/// Controller to manage theme mode with persistence
class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Box<dynamic>? _hiveBox;

  ThemeMode get themeMode => _themeMode;

  ThemeController(Box<dynamic>? hiveBox) {
    _hiveBox = hiveBox;
    _loadThemeMode();
  }

  void _loadThemeMode() {
    final savedMode = _hiveBox?.get(_themeModeKey);
    if (savedMode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => ThemeMode.system,
      );
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _hiveBox?.put(_themeModeKey, mode.name);
      notifyListeners();
    }
  }

  /// Helper to get current theme colors based on context
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).cardTheme.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCard
            : AppTheme.lightCard);
  }

  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color getPrimaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkPrimaryText
        : AppTheme.lightPrimaryText;
  }

  static Color getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSecondaryText
        : AppTheme.lightSecondaryText;
  }
}

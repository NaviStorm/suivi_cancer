// ===== $HOME/suivi_cancer/lib/common/theme/app_theme.dart =====
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Importer Cupertino

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    // Utiliser les couleurs Cupertino comme base pour le thème Material
    primaryColor: CupertinoColors.systemBlue,
    colorScheme: ColorScheme.light(
      primary: CupertinoColors.systemBlue,
      secondary: CupertinoColors.systemGreen,
      surface: CupertinoColors.systemBackground,
      error: CupertinoColors.systemRed,
      onPrimary: CupertinoColors.white,
      onSecondary: CupertinoColors.white,
      onSurface: CupertinoColors.label,
      onError: CupertinoColors.white,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: CupertinoColors.secondarySystemBackground,
      elevation: 0,
      titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: CupertinoColors.label // Texte noir sur fond clair
      ),
      iconTheme: IconThemeData(color: CupertinoColors.systemBlue), // Icônes bleues
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CupertinoColors.systemBlue,
        foregroundColor: CupertinoColors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: CupertinoColors.separator),
      ),
      filled: true,
      fillColor: CupertinoColors.secondarySystemGroupedBackground,
    ),
    cardTheme: CardThemeData(
      elevation: 0, // Les cartes iOS sont généralement plates
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: CupertinoColors.secondarySystemGroupedBackground,
      margin: EdgeInsets.zero, // La marge sera gérée par le widget parent
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: CupertinoColors.secondarySystemBackground,
      selectedItemColor: CupertinoColors.systemBlue,
      unselectedItemColor: CupertinoColors.systemGrey,
    ),
  );
}
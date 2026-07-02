import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Material 3 dark theme wired to the NetWix tokens. Type family: **Kanit**
/// (Thai + Latin display/body) — clean, geometric, on-brand for NetWix.
class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final kanit = GoogleFonts.kanitTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: T.screen,
      canvasColor: T.screen,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: T.accent,
        onPrimary: T.onAccent,
        secondary: T.purple,
        surface: T.surface,
        onSurface: T.textPrimary,
      ),
      textTheme: kanit.apply(
        bodyColor: T.textSecondary,
        displayColor: T.textPrimary,
      ),
      primaryTextTheme: GoogleFonts.kanitTextTheme(base.textTheme),
      iconTheme: const IconThemeData(color: T.textSecondary),
      dividerColor: T.hairline,
      splashColor: T.accentSoft,
      highlightColor: T.accentSoft,
    );
  }

  /// Kanit display style (headings, numerals).
  static TextStyle display(double size,
          {FontWeight weight = FontWeight.w600, Color color = T.textPrimary, double? letterSpacing}) =>
      GoogleFonts.kanit(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.15,
      );

  /// Kanit body/label style.
  static TextStyle body(double size,
          {FontWeight weight = FontWeight.w400, Color color = T.textSecondary, double height = 1.35}) =>
      GoogleFonts.kanit(fontSize: size, fontWeight: weight, color: color, height: height);
}

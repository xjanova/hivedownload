import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Material 3 dark theme wired to the Hivedownload tokens.
/// Display/headings/numerals → Bai Jamjuree; body/labels → Anuphan.
class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final anuphan = GoogleFonts.anuphanTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: T.screen,
      canvasColor: T.screen,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: T.accent,
        onPrimary: T.onAccent,
        secondary: T.accentHi,
        surface: T.screen,
        onSurface: T.textPrimary,
      ),
      textTheme: anuphan.apply(
        bodyColor: T.textSecondary,
        displayColor: T.textPrimary,
      ),
      primaryTextTheme: GoogleFonts.baiJamjureeTextTheme(base.textTheme),
      iconTheme: const IconThemeData(color: T.textSecondary),
      dividerColor: T.hairline,
      splashColor: T.accentSoft,
      highlightColor: T.accentSoft,
    );
  }

  /// Bai Jamjuree display style (headings, numerals).
  static TextStyle display(double size,
          {FontWeight weight = FontWeight.w600, Color color = T.textPrimary, double? letterSpacing}) =>
      GoogleFonts.baiJamjuree(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.15,
      );

  /// Anuphan body/label style.
  static TextStyle body(double size,
          {FontWeight weight = FontWeight.w400, Color color = T.textSecondary, double height = 1.35}) =>
      GoogleFonts.anuphan(fontSize: size, fontWeight: weight, color: color, height: height);
}

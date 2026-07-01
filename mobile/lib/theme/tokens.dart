import 'package:flutter/material.dart';

/// Design tokens transcribed from the Hivedownload mobile design handoff
/// (theme "honey", background tone "warm"). All accent values are centralised
/// so re-tinting to a real brand palette is a one-file change.
class T {
  T._();

  // ---- surfaces (warm, near-black) ----
  static const board = Color(0xFF0D0B08); // outermost canvas
  static const screen = Color(0xFF14110B); // phone screen base
  static const bezelTop = Color(0xFF2A2117);
  static const bezelBottom = Color(0xFF100D09);

  // ---- text ----
  static const textPrimary = Color(0xFFF5EEDF); // warm cream
  static const textSecondary = Color(0xFFC9BFA9);
  static const textMuted = Color(0xFF9A8F79);
  static const textFaint = Color(0xFF8A8069);
  static const textInactive = Color(0xFF7A7260);

  static const hairline = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const hairlineStrong = Color(0x1AFFFFFF); // .1

  // ---- accent (honey) ----
  static const accent = Color(0xFFF5A623);
  static const accentHi = Color(0xFFFFD766);
  static const accentLo = Color(0xFFE07B00);
  static const onAccent = Color(0xFF2A1C05);
  static const accentSoft = Color(0x24F5A623); // rgba(245,166,35,.14)
  static const accentGlow = Color(0x80F5A623); // .5
  static const accentSoftGlow = Color(0x2EF5A623); // .18

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentHi, accent, accentLo],
    stops: [0.0, 0.55, 1.0],
  );

  /// Faceted "gem / crystal" fill (approximation of the CSS conic-gradient).
  static const SweepGradient gemGradient = SweepGradient(
    center: Alignment(0.0, -0.16),
    startAngle: 3.6, // ~208deg
    endAngle: 3.6 + 6.283,
    colors: [
      Color(0xFFFFEEBC),
      Color(0xFFF5A623),
      Color(0xFFA85400),
      Color(0xFFFFD766),
      Color(0xFFE07B00),
      Color(0xFFFFEEBC),
    ],
    stops: [0.0, 0.22, 0.44, 0.60, 0.80, 1.0],
  );

  // ---- radii ----
  static const rScreen = 0.0; // real device edge
  static const rCard = 16.0;
  static const rMedia = 14.0;
  static const rPill = 100.0;
  static const rButton = 16.0;

  // ---- ambient screen background (layered glow over screen base) ----
  static BoxDecoration get screenBackground => const BoxDecoration(
        color: screen,
        gradient: RadialGradient(
          center: Alignment(0.0, -1.1),
          radius: 1.2,
          colors: [accentSoftGlow, Colors.transparent],
          stops: [0.0, 0.56],
        ),
      );

  // ---- glass card ----
  static BoxDecoration glass({double radius = rCard}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x16FFFFFF), Color(0x05FFFFFF)],
        ),
        border: Border.all(color: hairlineStrong),
        boxShadow: const [
          BoxShadow(color: Color(0xBF000000), blurRadius: 30, offset: Offset(0, 12), spreadRadius: -16),
        ],
      );

  // ---- cinematic "key-art" poster placeholder fills ----
  static const List<LinearGradient> posterFills = [
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF241A12), Color(0xFF0E0B08)]),
    LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF121A1C), Color(0xFF0B0B0C)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF181425), Color(0xFF0C0A10)]),
  ];

  static LinearGradient posterFill(int seed) => posterFills[seed % posterFills.length];
}

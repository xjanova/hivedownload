import 'package:flutter/material.dart';

/// Design tokens for the **NetWix** brand — neon crimson→violet on a cool,
/// cinematic near-black. All accent values are centralised so a re-tint is a
/// one-file change. (Rebranded from the original "honey" Hive Download theme.)
class T {
  T._();

  // ---- surfaces (cool, near-black) ----
  static const board = Color(0xFF07050C); // outermost canvas
  static const screen = Color(0xFF0B0712); // phone screen base
  static const surface = Color(0xFF120E1A); // cards / sheets
  static const bezelTop = Color(0xFF1C1730);
  static const bezelBottom = Color(0xFF0A0712);

  // ---- text ----
  static const textPrimary = Color(0xFFF4F1F8); // cool white
  static const textSecondary = Color(0xFFC9C2D6);
  static const textMuted = Color(0xFF938BA6);
  static const textFaint = Color(0xFF7C7392);
  static const textInactive = Color(0xFF655C7A);

  static const hairline = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const hairlineStrong = Color(0x1AFFFFFF); // .1

  // ---- accent (NetWix crimson) ----
  static const accent = Color(0xFFFF2D55);
  static const accentHi = Color(0xFFFF6B85);
  static const accentLo = Color(0xFFC81E45);
  static const onAccent = Color(0xFFFFFFFF);
  static const accentSoft = Color(0x24FF2D55); // rgba(255,45,85,.14)
  static const accentGlow = Color(0x80FF2D55); // .5
  static const accentSoftGlow = Color(0x2EFF2D55); // .18

  // ---- secondary (electric violet) ----
  static const purple = Color(0xFFB026FF);
  static const purpleHi = Color(0xFFCB6BFF);
  static const purpleLo = Color(0xFF8B2FF0);

  /// Signature crimson→violet CTA gradient.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentHi, accent, purple],
    stops: [0.0, 0.5, 1.0],
  );

  /// Faceted "gem / crystal" fill (neon sweep).
  static const SweepGradient gemGradient = SweepGradient(
    center: Alignment(0.0, -0.16),
    startAngle: 3.6, // ~208deg
    endAngle: 3.6 + 6.283,
    colors: [
      Color(0xFFFF6B85),
      Color(0xFFFF2D55),
      Color(0xFF8B2FF0),
      Color(0xFFCB6BFF),
      Color(0xFFB026FF),
      Color(0xFFFF6B85),
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

  // ---- cinematic "key-art" poster placeholder fills (cool neon-tinted) ----
  static const List<LinearGradient> posterFills = [
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A1220), Color(0xFF0B0712)]),
    LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF1A1030), Color(0xFF0A0712)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF201430), Color(0xFF0C0910)]),
  ];

  static LinearGradient posterFill(int seed) => posterFills[seed % posterFills.length];
}

import 'package:flutter/material.dart';

import 'tokens.dart';

/// The brand hexagon: flat-side clip
/// `polygon(50% 0, 100% 25%, 100% 75%, 50% 100%, 0 75%, 0 25%)`.
class HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A child clipped into the brand hexagon.
class HexBox extends StatelessWidget {
  const HexBox({super.key, required this.size, required this.child});
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: HexClipper(),
        child: SizedBox(width: size, height: size, child: child),
      );
}

/// Faceted "gem / crystal" hex crest with accent glow — used for hero marks.
class GemCrest extends StatelessWidget {
  const GemCrest({super.key, this.size = 96, this.icon});
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: T.accentGlow, blurRadius: 36, spreadRadius: -10, offset: const Offset(0, 16)),
        ],
      ),
      child: HexBox(
        size: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: T.gemGradient),
          child: icon == null
              ? null
              : Icon(icon, color: T.onAccent, size: size * 0.42),
        ),
      ),
    );
  }
}

/// A hexagonal avatar (image or gradient placeholder).
class HexAvatar extends StatelessWidget {
  const HexAvatar({super.key, this.size = 40, this.child});
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) => HexBox(
        size: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4A3A24), Color(0xFF241A12)],
            ),
          ),
          child: child,
        ),
      );
}

/// Small hex icon used in nav / list rows.
class HexIcon extends StatelessWidget {
  const HexIcon({super.key, required this.icon, this.color, this.size = 30, this.iconSize});
  final IconData icon;
  final Color? color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => HexBox(
        size: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: (color ?? T.accent).withValues(alpha: 0.16)),
          child: Icon(icon, color: color ?? T.accent, size: iconSize ?? size * 0.5),
        ),
      );
}

/// A gently floating wrapper (hero gem crests float 0 → -6px, ~5s).
class Floating extends StatefulWidget {
  const Floating({super.key, required this.child, this.distance = 6});
  final Widget child;
  final double distance;

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curve,
      builder: (_, child) =>
          Transform.translate(offset: Offset(0, -widget.distance * curve.value), child: child),
      child: widget.child,
    );
  }
}

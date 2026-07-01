import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Primary accent-gradient button (54px, glow shadow).
class AccentButton extends StatelessWidget {
  const AccentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(T.rButton),
          onTap: enabled ? onPressed : null,
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              gradient: T.accentGradient,
              borderRadius: BorderRadius.circular(T.rButton),
              boxShadow: [
                BoxShadow(color: T.accentGlow, blurRadius: 26, offset: const Offset(0, 12), spreadRadius: -8),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, color: T.onAccent, size: 20), const SizedBox(width: 8)],
                  Text(label, style: AppTheme.display(15, weight: FontWeight.w700, color: T.onAccent)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Transparent, hairline-bordered secondary button.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed, this.height = 50});
  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(T.rButton),
        onTap: onPressed,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(T.rButton),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          alignment: Alignment.center,
          child: Text(label, style: AppTheme.body(14, weight: FontWeight.w600, color: T.textPrimary)),
        ),
      ),
    );
  }
}

/// Frosted glass card container.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = T.rCard});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) =>
      Container(decoration: T.glass(radius: radius), padding: padding, child: child);
}

/// Rounded pill badge (free / new / episode count / meta).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    this.filled = false,
    this.color = T.accent,
    this.textColor,
    this.icon,
  });

  final String text;
  final bool filled;
  final Color color;
  final Color? textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? (filled ? T.onAccent : color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(T.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: fg), const SizedBox(width: 3)],
          Text(text, style: AppTheme.body(10, weight: FontWeight.w600, color: fg, height: 1.1)),
        ],
      ),
    );
  }
}

/// "Section title  ·  ทั้งหมด ›" header row.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing, this.badge, this.onTrailingTap});
  final String title;
  final String? trailing;
  final Widget? badge;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(title, style: AppTheme.display(16, weight: FontWeight.w600)),
          if (badge != null) ...[const SizedBox(width: 8), badge!],
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(trailing!, style: AppTheme.body(12, color: T.textFaint)),
            ),
        ],
      ),
    );
  }
}

// Neumorphic (soft UI) design helpers — a light base with paired light/dark
// shadows so elements look softly extruded or pressed-in. Brand blue is kept
// for accents (icons, active states) so it stays on-brand.

import 'package:flutter/material.dart';

class Neu {
  // Soft neutral base + its two shadow tones.
  static const Color base = Color(0xFFEBEFF5);
  static const Color light = Color(0xFFFFFFFF);
  static const Color dark = Color(0xFFC9D2E3);

  /// Extruded (raised) surface — cards, buttons at rest.
  static BoxDecoration raised({double radius = 18, Color? color, bool circle = false}) => BoxDecoration(
        color: color ?? base,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        boxShadow: const [
          BoxShadow(color: dark, offset: Offset(5, 5), blurRadius: 12),
          BoxShadow(color: light, offset: Offset(-5, -5), blurRadius: 12),
        ],
      );

  /// Pressed-in (inset) surface — inputs, stat wells. Approximated with a
  /// subtle inner-shadow look via a gradient + tight shadows.
  static BoxDecoration pressed({double radius = 14, Color? color}) => BoxDecoration(
        color: color ?? base,
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDCE2EC), Color(0xFFF3F6FB)],
        ),
        boxShadow: [
          BoxShadow(color: dark.withValues(alpha: 0.6), offset: const Offset(2, 2), blurRadius: 4),
          BoxShadow(color: light.withValues(alpha: 0.9), offset: const Offset(-2, -2), blurRadius: 4),
        ],
      );

  /// A smaller floating control (icon button).
  static BoxDecoration control() => raised(circle: true);
}

/// A tappable neumorphic surface. [pressedStyle] renders the inset look.
class NeuBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool circle;
  final bool pressedStyle;
  final Color? color;
  final VoidCallback? onTap;

  const NeuBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.circle = false,
    this.pressedStyle = false,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: pressedStyle
          ? Neu.pressed(radius: radius, color: color)
          : Neu.raised(radius: radius, circle: circle, color: color),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      onTap: onTap,
      borderRadius: circle ? null : BorderRadius.circular(radius),
      customBorder: circle ? const CircleBorder() : null,
      child: box,
    );
  }
}

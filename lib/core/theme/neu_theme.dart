import 'package:flutter/material.dart';

/// Soft neumorphism design tokens.
/// Background: [bg] — a cool-blue grey that reads both as elevated and inset.
/// Every shadow pair has one dark (bottom-right) and one white (top-left) shadow.
class NeuTheme {
  NeuTheme._();

  // Neumorphism surface colour (warm-blue grey)
  static const Color bg = Color(0xFFE8EDF4);

  static const Color _dark = Color(0xFFBDCADB);
  static const Color _light = Color(0xFFFFFFFF);

  // Raised card — the default "button" feel
  static BoxDecoration raised({double radius = 18}) => BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: _dark, offset: Offset(6, 6), blurRadius: 14, spreadRadius: 1),
          BoxShadow(color: _light, offset: Offset(-6, -6), blurRadius: 14, spreadRadius: 1),
        ],
      );

  // Slightly smaller shadow — for tighter spaces
  static BoxDecoration sm({double radius = 14}) => BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: _dark, offset: Offset(4, 4), blurRadius: 8),
          BoxShadow(color: _light, offset: Offset(-4, -4), blurRadius: 8),
        ],
      );

  // Inset / pressed feel — used for active states or inputs
  static BoxDecoration inset({double radius = 14}) => BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: _dark, offset: Offset(3, 3), blurRadius: 6),
          BoxShadow(color: _light, offset: Offset(-3, -3), blurRadius: 6),
        ],
      );

  // Circular variant (avatar buttons, FABs)
  static BoxDecoration circle({bool pressed = false}) => BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: pressed
            ? const [
                BoxShadow(color: _dark, offset: Offset(2, 2), blurRadius: 5),
                BoxShadow(color: _light, offset: Offset(-2, -2), blurRadius: 5),
              ]
            : const [
                BoxShadow(color: _dark, offset: Offset(5, 5), blurRadius: 10),
                BoxShadow(color: _light, offset: Offset(-5, -5), blurRadius: 10),
              ],
      );
}

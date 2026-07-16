// Responsive Utilities - Adaptive Layouts for All Devices

import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1024;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1024;
  
  // Height-based responsiveness for cards/text
  static bool isTiny(BuildContext context) => MediaQuery.of(context).size.height < 550;
  static bool isSmall(BuildContext context) => MediaQuery.of(context).size.height < 700;
  static bool isLarge(BuildContext context) => MediaQuery.of(context).size.height >= 800;
  
  static double width(BuildContext context) => MediaQuery.of(context).size.width;
  static double height(BuildContext context) => MediaQuery.of(context).size.height;
  static EdgeInsets padding(BuildContext context) => MediaQuery.of(context).padding;
  
  // Responsive value based on screen size
  static T value<T>(BuildContext context, {required T mobile, T? tablet, T? desktop}) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
  
  // Responsive spacing
  static double sp(BuildContext context, double base) {
    if (isDesktop(context)) return base * 1.5;
    if (isTablet(context)) return base * 1.25;
    return base;
  }
  
  // Responsive font size
  static double fs(BuildContext context, double base) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return base * 1.15;
    if (width >= 600) return base * 1.08;
    if (width < 360) return base * 0.9;
    return base;
  }
  
  // Max content width for centering on large screens
  static double maxContentWidth(BuildContext context) {
    if (isDesktop(context)) return 480;
    if (isTablet(context)) return 400;
    return double.infinity;
  }
  
  // Horizontal padding based on screen
  static double horizontalPadding(BuildContext context) {
    if (isDesktop(context)) return 48;
    if (isTablet(context)) return 36;
    return 24;
  }
}

// Spacing Constants
class Spacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

// Border Radius Constants
class Radii {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double full = 100;
}

// Premium Shadow Styles
class PremiumShadows {
  static List<BoxShadow> soft(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
    BoxShadow(color: color.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
  ];
  
  static List<BoxShadow> medium(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 32, offset: const Offset(0, 12)),
    BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
  ];
  
  static List<BoxShadow> elevated(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 48, offset: const Offset(0, 20)),
    BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 8)),
  ];
  
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 32, spreadRadius: 0),
    BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 64, spreadRadius: -8),
  ];
}

// Premium App Colors - Logo-Based Color Scheme (Blue + Black + White)

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Colors (From Brand Kit - Techy mascot identity)
  static const Color primaryBlue = Color(0xFF1495FF);  // Brand blue
  static const Color primaryDark = Color(0xFF0B72D8);  // Darker blue (pressed/gradients)
  static const Color primaryLight = Color(0xFF6EC6FF); // Light blue
  static const Color primaryAccent = Color(0xFFE6F2FF); // Pale blue surface tint
  static const Color brandNavy = Color(0xFF0D1B2A);    // Deep navy (ink / dark surfaces)

  // Secondary Colors (Navy from brand kit)
  static const Color secondaryBlack = Color(0xFF0D1B2A);
  static const Color secondaryDark = Color(0xFF16283C);

  // Premium Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6EC6FF), Color(0xFF1495FF), Color(0xFF0B72D8)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D1B2A), Color(0xFF16283C), Color(0xFF1E3A55)],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF4F9FF), Color(0xFFE6F2FF)],
  );

  static const LinearGradient blueBlackGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1495FF), Color(0xFF0B72D8), Color(0xFF0D1B2A)],
  );

  // Neutral Palette
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF1495FF);

  // Text Colors (navy-tinted ink from brand kit)
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF51677A);
  static const Color textTertiary = Color(0xFF8298A9);
  static const Color textHint = Color(0xFFB0B0B0);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Surface Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color scaffoldBackground = Color(0xFFFAFAFA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
}

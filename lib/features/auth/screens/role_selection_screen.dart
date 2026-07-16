// Premium Role Selection Screen - Professional Design with Brand Colors

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final isVerySmall = size.height < 600;
    final isTiny = size.height < 550; // Extra small phones
    final horizontalPadding = isTiny
        ? 16.0
        : isVerySmall
        ? 18.0
        : isSmall
        ? 20.0
        : 24.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.04),
              Colors.white,
              AppColors.primaryBlue.withValues(alpha: 0.02),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isTiny
                    ? 16
                    : isVerySmall
                    ? 20
                    : isSmall
                    ? 24
                    : 32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isSmall ? 420 : 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(isSmall, isVerySmall, isTiny),
                    SizedBox(
                      height: isTiny
                          ? 20
                          : isVerySmall
                          ? 24
                          : isSmall
                          ? 32
                          : 40,
                    ),
                    _buildHeader(isSmall, isVerySmall, isTiny),
                    SizedBox(
                      height: isTiny
                          ? 24
                          : isVerySmall
                          ? 28
                          : isSmall
                          ? 36
                          : 48,
                    ),
                    _buildRoleCards(isSmall, isVerySmall, isTiny),
                    SizedBox(
                      height: isTiny
                          ? 24
                          : isVerySmall
                          ? 28
                          : isSmall
                          ? 36
                          : 48,
                    ),
                    _buildContinueButton(isSmall, isVerySmall, isTiny),
                    SizedBox(
                      height: isTiny
                          ? 12
                          : isVerySmall
                          ? 16
                          : isSmall
                          ? 20
                          : 24,
                    ),
                    _buildTermsText(isVerySmall, isTiny),
                    SizedBox(height: isTiny ? 16 : isVerySmall ? 20 : 24),
                    _buildAdminAccess(isTiny),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isSmall, bool isVerySmall, bool isTiny) {
    final size = MediaQuery.of(context).size;
    // Use screen width percentage for better responsiveness
    final baseSize = size.width * 0.35;
    // Apply min/max constraints
    final logoSize = baseSize.clamp(
      isTiny
          ? 100.0
          : isVerySmall
          ? 110.0
          : 120.0, // minimum
      isTiny
          ? 120.0
          : isVerySmall
          ? 130.0
          : isSmall
          ? 150.0
          : 170.0, // maximum
    );

    return Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Image.asset(
            AppAssets.logo,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(logoSize),
          ),
        )
        .animate()
        .fadeIn(duration: 700.ms)
        .scale(
          begin: const Offset(0.6, 0.6),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
          duration: 900.ms,
        );
  }

  Widget _buildFallbackLogo(double size) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.handyman_rounded,
              size: size * 0.35,
              color: Colors.white,
            ),
            SizedBox(width: size * 0.05),
            Text(
              'T',
              style: TextStyle(
                fontSize: size * 0.3,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmall, bool isVerySmall, bool isTiny) {
    return Column(
      children: [
        Text(
              'Welcome!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTiny
                    ? 26
                    : isVerySmall
                    ? 28
                    : isSmall
                    ? 32
                    : 38,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.8,
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 200.ms)
            .slideY(begin: 0.2, end: 0),

        SizedBox(
          height: isTiny
              ? 6
              : isVerySmall
              ? 8
              : 12,
        ),

        Text(
          'How would you like to use the app?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isTiny
                ? 13
                : isVerySmall
                ? 14
                : isSmall
                ? 15
                : 16,
            color: AppColors.textSecondary,
            height: 1.5,
            letterSpacing: 0.2,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 350.ms),
      ],
    );
  }

  Widget _buildRoleCards(bool isSmall, bool isVerySmall, bool isTiny) {
    return Column(
      children: [
        _buildRoleCard(
          role: 'user',
          icon: Icons.person_rounded,
          title: 'I Need Services',
          subtitle: 'Find and book trusted\nhome service providers',
          index: 0,
          isSmall: isSmall,
          isVerySmall: isVerySmall,
          isTiny: isTiny,
        ),
        SizedBox(
          height: isTiny
              ? 10
              : isVerySmall
              ? 12
              : isSmall
              ? 14
              : 16,
        ),
        _buildRoleCard(
          role: 'provider',
          icon: Icons.engineering_rounded,
          title: 'I Provide Services',
          subtitle: 'Join as a professional and\ngrow your business',
          index: 1,
          isSmall: isSmall,
          isVerySmall: isVerySmall,
          isTiny: isTiny,
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
    required int index,
    required bool isSmall,
    required bool isVerySmall,
    required bool isTiny,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
          onTap: () => setState(() => _selectedRole = role),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.all(
              isTiny
                  ? 14
                  : isVerySmall
                  ? 16
                  : isSmall
                  ? 18
                  : isSelected
                  ? 20
                  : 18,
            ),
            decoration: BoxDecoration(
              gradient: isSelected ? AppColors.primaryGradient : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: isSelected
                  ? null
                  : Border.all(color: AppColors.grey200, width: 2),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Icon container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isTiny
                      ? 52
                      : isVerySmall
                      ? 56
                      : isSmall
                      ? 60
                      : 68,
                  height: isTiny
                      ? 52
                      : isVerySmall
                      ? 56
                      : isSmall
                      ? 60
                      : 68,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: isTiny
                        ? 26
                        : isVerySmall
                        ? 28
                        : isSmall
                        ? 30
                        : 34,
                    color: isSelected ? Colors.white : AppColors.primaryBlue,
                  ),
                ),
                SizedBox(
                  width: isTiny
                      ? 10
                      : isVerySmall
                      ? 12
                      : isSmall
                      ? 14
                      : 16,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isTiny
                              ? 15
                              : isVerySmall
                              ? 16
                              : isSmall
                              ? 17
                              : 18,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(
                        height: isTiny
                            ? 2
                            : isVerySmall
                            ? 3
                            : 4,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isTiny
                              ? 11
                              : isVerySmall
                              ? 12
                              : isSmall
                              ? 13
                              : 14,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppColors.textSecondary,
                          height: 1.45,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isVerySmall ? 8 : 12),
                // Checkbox
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isVerySmall ? 26 : 28,
                  height: isVerySmall ? 26 : 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.white : AppColors.grey50,
                    border: isSelected
                        ? null
                        : Border.all(color: AppColors.grey300, width: 2),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: isVerySmall ? 16 : 18,
                          color: AppColors.primaryBlue,
                        )
                      : null,
                ),
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 500 + (index * 100)))
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildContinueButton(bool isSmall, bool isVerySmall, bool isTiny) {
    final isEnabled = _selectedRole != null;

    return GestureDetector(
          onTap: isEnabled
              ? () => Navigator.pushNamed(
                  context,
                  _selectedRole == 'user' ? '/login' : '/provider/login',
                )
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: isTiny
                ? 50
                : isVerySmall
                ? 54
                : isSmall
                ? 56
                : 60,
            decoration: BoxDecoration(
              gradient: isEnabled ? AppColors.primaryGradient : null,
              color: isEnabled ? null : AppColors.grey100,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: isTiny
                          ? 14
                          : isVerySmall
                          ? 15
                          : isSmall
                          ? 16
                          : 17,
                      fontWeight: FontWeight.w700,
                      color: isEnabled ? Colors.white : AppColors.grey400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (isEnabled) ...[
                    SizedBox(
                      width: isTiny
                          ? 5
                          : isVerySmall
                          ? 6
                          : 8,
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: isTiny
                          ? 17
                          : isVerySmall
                          ? 18
                          : 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 800.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildTermsText(bool isVerySmall, bool isTiny) {
    return Text(
      'By continuing, you agree to our Terms of Service\nand Privacy Policy',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: isTiny
            ? 10
            : isVerySmall
            ? 11
            : 12,
        color: AppColors.textTertiary,
        height: 1.6,
        letterSpacing: 0.1,
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 950.ms);
  }

  Widget _buildAdminAccess(bool isTiny) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/admin/login'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isTiny ? 8 : 10),
        decoration: BoxDecoration(
          color: AppColors.grey100.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.grey200.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_rounded,
              size: isTiny ? 14 : 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              'Management Portal',
              style: TextStyle(
                fontSize: isTiny ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 1100.ms);
  }
}

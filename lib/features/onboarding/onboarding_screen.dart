// Premium Onboarding Screen - Professional Design with Brand Colors

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      icon: Icons.home_repair_service_rounded,
      title: 'Home Services\nMade Easy',
      subtitle:
          'Book verified professionals for all your home repair and maintenance needs.',
    ),
    OnboardingData(
      icon: Icons.verified_user_rounded,
      title: 'Trusted &\nVerified Experts',
      subtitle:
          'Every provider is background-checked to ensure your safety and satisfaction.',
    ),
    OnboardingData(
      icon: Icons.schedule_rounded,
      title: 'Track & Manage',
      subtitle:
          'Real-time tracking, instant chat, and complete booking management.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final isVerySmall = size.height < 600;
    final horizontalPadding = isSmall ? 20.0 : 24.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.03),
              Colors.white,
              AppColors.primaryBlue.withValues(alpha: 0.06),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isSmall ? 12 : 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPageIndicator(isSmall),
                    _buildSkipButton(isSmall),
                  ],
                ),
              ),
              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) => _buildPage(
                    index,
                    isSmall,
                    isVerySmall,
                    horizontalPadding,
                  ),
                ),
              ),
              // Bottom
              _buildBottomSection(horizontalPadding, isSmall, isVerySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(bool isSmall) {
    return Row(
      children: List.generate(3, (i) {
        final isActive = _currentPage == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 8),
          width: isActive ? (isSmall ? 24 : 28) : 8,
          height: isSmall ? 7 : 8,
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.primaryGradient : null,
            color: isActive ? null : AppColors.grey200,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSkipButton(bool isSmall) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, '/role-selection'),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 14 : 16,
          vertical: isSmall ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppColors.grey200, width: 1.5),
        ),
        child: Text(
          'Skip',
          style: TextStyle(
            fontSize: isSmall ? 13 : 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.2, end: 0);
  }

  Widget _buildPage(
    int index,
    bool isSmall,
    bool isVerySmall,
    double horizontalPadding,
  ) {
    final page = _pages[index];
    final iconSize = isVerySmall
        ? 110.0
        : isSmall
        ? 130.0
        : 150.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Spacer(flex: isVerySmall ? 1 : 2),

          // Icon container with 3D effect and brand colors
          Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(iconSize * 0.28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.25),
                      blurRadius: 35,
                      offset: const Offset(0, 18),
                    ),
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      blurRadius: 60,
                      offset: const Offset(0, 30),
                    ),
                  ],
                ),
                child: Icon(
                  page.icon,
                  size: iconSize * 0.48,
                  color: Colors.white,
                ),
              )
              .animate()
              .fadeIn(duration: 700.ms)
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack,
                duration: 900.ms,
              )
              .then()
              .shimmer(duration: 1500.ms, delay: 500.ms),

          SizedBox(
            height: isVerySmall
                ? 32
                : isSmall
                ? 40
                : 56,
          ),

          // Title
          Text(
                page.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isVerySmall
                      ? 26
                      : isSmall
                      ? 30
                      : 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.15,
                  letterSpacing: -0.8,
                ),
              )
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .slideY(begin: 0.2, end: 0),

          SizedBox(
            height: isVerySmall
                ? 12
                : isSmall
                ? 14
                : 18,
          ),

          // Subtitle
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isSmall ? 340 : 420),
            child: Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isVerySmall
                    ? 14
                    : isSmall
                    ? 15
                    : 16,
                color: AppColors.textSecondary,
                height: 1.65,
                letterSpacing: 0.2,
              ),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 350.ms),

          Spacer(flex: isVerySmall ? 2 : 3),
        ],
      ),
    );
  }

  Widget _buildBottomSection(
    double horizontalPadding,
    bool isSmall,
    bool isVerySmall,
  ) {
    final isLast = _currentPage == 2;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isVerySmall
            ? 16
            : isSmall
            ? 20
            : 24,
      ),
      child: Row(
        children: [
          // Back button
          if (_currentPage > 0)
            GestureDetector(
              onTap: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              ),
              child: Container(
                width: isSmall ? 52 : 56,
                height: isSmall ? 52 : 56,
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.grey200, width: 1.5),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                  size: isSmall ? 22 : 24,
                ),
              ),
            ).animate().fadeIn(duration: 300.ms).scaleXY(begin: 0.8, end: 1.0)
          else
            SizedBox(width: isSmall ? 52 : 56),

          const Spacer(),

          // Next/Get Started button
          GestureDetector(
            onTap: () {
              if (isLast) {
                Navigator.pushReplacementNamed(context, '/role-selection');
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              }
            },
            child: Container(
              height: isSmall ? 52 : 56,
              padding: EdgeInsets.symmetric(
                horizontal: isLast ? (isSmall ? 24 : 28) : (isSmall ? 20 : 24),
              ),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLast ? 'Get Started' : 'Next',
                    style: TextStyle(
                      fontSize: isSmall ? 15 : 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: isSmall ? 6 : 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: isSmall ? 18 : 20,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.3, end: 0),
        ],
      ),
    );
  }
}

class OnboardingData {
  final IconData icon;
  final String title;
  final String subtitle;
  OnboardingData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

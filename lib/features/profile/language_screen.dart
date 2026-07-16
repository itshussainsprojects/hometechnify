// Language Selection Screen - Premium Design

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/constants.dart';

class LanguageScreen extends StatefulWidget {
  final String currentLanguage;

  const LanguageScreen({super.key, this.currentLanguage = 'English'});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _selectedLanguage;

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'subtitle': 'English', 'code': 'US'},
    {'name': 'Urdu', 'subtitle': 'اردو', 'code': 'PK'},
    {'name': 'Punjabi', 'subtitle': 'پنجابی', 'code': 'PJ'},
    {'name': 'Pashto', 'subtitle': 'پښتو', 'code': 'PS'},
    {'name': 'Turkish', 'subtitle': 'Türkçe', 'code': 'TR'},
  ];

  // Flag colors for each country
  final Map<String, List<Color>> _flagColors = {
    'US': [const Color(0xFF3C3B6E), const Color(0xFFB22234)],
    'PK': [const Color(0xFF01411C), const Color(0xFFFFFFFF)],
    'PJ': [const Color(0xFFFF9933), const Color(0xFF138808)],
    'PS': [const Color(0xFF000000), const Color(0xFF007A3D)],
    'TR': [const Color(0xFFE30A17), const Color(0xFFFFFFFF)],
  };

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        children: [
          // Custom Header with gradient
          _buildHeader(),
          // Language List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final language = _languages[index];
                final isSelected = _selectedLanguage == language['name'];
                
                return _buildLanguageCard(
                  name: language['name']!,
                  subtitle: language['subtitle']!,
                  code: language['code']!,
                  isSelected: isSelected,
                  index: index,
                );
              },
            ),
          ),
          // Save Button
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 20,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Change Language',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40), // Balance the back button
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildLanguageCard({
    required String name,
    required String subtitle,
    required String code,
    required bool isSelected,
    required int index,
  }) {
    final colors = _flagColors[code] ?? [AppColors.primaryBlue, AppColors.primaryDark];
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLanguage = name);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.08) : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.grey200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] : [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Flag Icon with gradient
            Container(
              width: 48,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.grey300, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors[0] == Colors.white || colors[0] == const Color(0xFFFFFFFF) 
                        ? AppColors.textPrimary 
                        : Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Language name and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.primaryGradient : null,
                color: isSelected ? null : Colors.transparent,
                shape: BoxShape.circle,
                border: isSelected ? null : Border.all(color: AppColors.grey300, width: 2),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: isSelected 
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: index * 60)).slideX(begin: 0.1, end: 0);
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () {
            Navigator.pop(context, _selectedLanguage);
          },
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2, end: 0);
  }
}

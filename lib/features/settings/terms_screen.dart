// Terms of Service Screen

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/constants.dart';

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  bool _isAgreed = false;

  final List<Map<String, String>> _termsData = [
    {
      'title': '1. Platform Overview',
      'content': 'Home Technify connects users with independent providers. We do not provide services directly and are not an employer or agent of providers.',
      'icon': 'api_rounded'
    },
    {
      'title': '2. User Eligibility',
      'content': 'Users must be 18+ years old and provide accurate information during registration to use the platform.',
      'icon': 'verified_user_rounded'
    },
    {
      'title': '3. Responsibilities',
      'content': 'Users must use the platform lawfully and ethically. Fraudulent, abusive, or harmful activities are strictly prohibited.',
      'icon': 'gavel_rounded'
    },
    {
      'title': '4. Service Providers',
      'content': 'Providers are independent contractors. Home Technify is not responsible for the quality or outcome of services provided.',
      'icon': 'work_rounded'
    },
    {
      'title': '5. Payments',
      'content': 'Payments are processed via secure third-party gateways. All applicable fees and commissions will be clearly disclosed.',
      'icon': 'payments_rounded'
    },
    {
      'title': '6. Account Termination',
      'content': 'We reserve the right to suspend or terminate accounts for term violations, fraud, or security threats without prior notice.',
      'icon': 'block_rounded'
    },
    {
      'title': '7. Intellectual Property',
      'content': 'All content, logos, and materials on the platform are the exclusive property of Home Technify.',
      'icon': 'psychology_rounded'
    },
    {
      'title': '8. Data Privacy',
      'content': 'User data is processed in accordance with our Privacy Policy. By using the platform, you consent to this data processing.',
      'icon': 'security_rounded'
    },
    {
      'title': '9. Liability Limitation',
      'content': 'Home Technify is not liable for provider actions or indirect damages. Use of the platform is at your own risk.',
      'icon': 'priority_high_rounded'
    },
    {
      'title': '10. Changes & Law',
      'content': 'Terms may be updated at any time. Continued use indicates acceptance. Disputes are resolved via arbitration or competent courts.',
      'icon': 'update_rounded'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              itemCount: _termsData.length,
              itemBuilder: (context, index) {
                final item = _termsData[index];
                return _buildAmazingSection(
                  item['title']!, 
                  item['content']!, 
                  _getIcon(item['icon']!),
                  index
                );
              },
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'api_rounded': return Icons.api_rounded;
      case 'verified_user_rounded': return Icons.verified_user_rounded;
      case 'gavel_rounded': return Icons.gavel_rounded;
      case 'work_rounded': return Icons.work_rounded;
      case 'payments_rounded': return Icons.payments_rounded;
      case 'block_rounded': return Icons.block_rounded;
      case 'psychology_rounded': return Icons.psychology_rounded;
      case 'security_rounded': return Icons.security_rounded;
      case 'priority_high_rounded': return Icons.priority_high_rounded;
      case 'update_rounded': return Icons.update_rounded;
      default: return Icons.description_rounded;
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Terms & Conditions',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildAmazingSection(String title, String content, IconData icon, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.grey100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: AppColors.primaryBlue,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 20, color: AppColors.primaryBlue),
                          const SizedBox(width: 10),
                          Text(
                            title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        content,
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (index * 50).ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _isAgreed = !_isAgreed),
              child: Row(
                children: [
                  Checkbox(
                    value: _isAgreed,
                    onChanged: (val) => setState(() => _isAgreed = val ?? false),
                    activeColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  const Expanded(
                    child: Text(
                      'I, as a provider, agree to all Home Technify Terms and Conditions.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isAgreed ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you for agreeing to the terms!'), backgroundColor: AppColors.primaryBlue),
                  );
                  Navigator.pop(context);
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  disabledBackgroundColor: AppColors.grey300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: _isAgreed ? 4 : 0,
                  shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                ),
                child: const Text(
                  'Accept and Continue',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(begin: 0.1, end: 0);
  }
}


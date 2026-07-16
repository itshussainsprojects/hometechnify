// Privacy Policy Screen - Amazing Style
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  final List<Map<String, dynamic>> _policyData = const [
    {
      'title': '1. Information We Collect',
      'content': 'Personal info (name, phone, email), location data, service history, messages, ratings, and device/technical data for app functionality.',
      'icon': Icons.folder_open_rounded
    },
    {
      'title': '2. How We Use Your Information',
      'content': 'To provide services, connect users with providers, improve app performance, send updates, prevent fraud, and comply with legal obligations.',
      'icon': Icons.settings_rounded
    },
    {
      'title': '3. Information Sharing',
      'content': 'We do not sell your data. Information is shared only with service providers, trusted partners (payments, analytics), or when required by law.',
      'icon': Icons.share_rounded
    },
    {
      'title': '4. Data Protection & Security',
      'content': 'We use secure servers, limit data access, and follow international standards. However, no system is 100% secure.',
      'icon': Icons.security_rounded
    },
    {
      'title': '5. Data Retention',
      'content': 'Personal data is retained only as long as needed to provide services, comply with laws, and resolve disputes.',
      'icon': Icons.storage_rounded
    },
    {
      'title': '6. Your Rights',
      'content': 'You may access, correct, or delete your data, withdraw consent, or restrict processing. Submit requests via app or support.',
      'icon': Icons.verified_user_rounded
    },
    {
      'title': '7. Third-Party Services',
      'content': 'Our app may link to third-party sites. We are not responsible for their privacy practices.',
      'icon': Icons.link_rounded
    },
    {
      'title': '8. Children\'s Privacy',
      'content': 'Our services are not for children under 13. We do not knowingly collect data from minors.',
      'icon': Icons.child_care_rounded
    },
    {
      'title': '9. International Transfers',
      'content': 'Your data may be stored or processed in different countries. By using our services, you consent to this transfer.',
      'icon': Icons.public_rounded
    },
    {
      'title': '10. Policy Updates',
      'content': 'We may update this policy at any time. Continued use after updates means acceptance of changes.',
      'icon': Icons.update_rounded
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
              itemCount: _policyData.length,
              itemBuilder: (context, index) {
                final item = _policyData[index];
                return _buildPolicySection(
                  item['title'] as String,
                  item['content'] as String,
                  item['icon'] as IconData,
                  index,
                );
              },
            ),
          ),
        ],
      ),
    );
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
      child: Row(
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
                'Privacy Policy',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildPolicySection(String title, String content, IconData icon, int index) {
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
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                            ),
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
}

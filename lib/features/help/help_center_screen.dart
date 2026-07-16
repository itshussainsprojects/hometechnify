// Help Center Screen

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  int? _expandedIndex;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I book a service?',
      'answer': 'Simply browse the services, select the one you need, choose a provider, and confirm your booking with your preferred time slot.',
    },
    {
      'question': 'How can I cancel a booking?',
      'answer': 'You can cancel a booking from the "My Bookings" section. Tap on the booking and select "Cancel Booking". Note that cancellation charges may apply.',
    },
    {
      'question': 'Are all providers verified?',
      'answer': 'Yes, all providers go through a verification process including CNIC verification and background checks to ensure your safety.',
    },
    {
      'question': 'What payment methods are accepted?',
      'answer': 'We accept cash, credit/debit cards, and digital wallets. You can select your preferred payment method during booking.',
    },
    {
      'question': 'How do I contact customer support?',
      'answer': 'You can contact us via the in-app chat, email at info.hometechnify@gmail.com, or call our helpline at +92 371 9267771.',
    },
    {
      'question': 'Can I reschedule my booking?',
      'answer': 'Yes, you can reschedule from the booking details page. Select a new date and time and confirm the changes.',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary)),
        title: const Text('Help Center', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(horizontalPadding),
          _buildContactInfo(horizontalPadding),
          _buildQuickActions(horizontalPadding),
          Expanded(child: _buildFAQList(horizontalPadding)),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Widget _buildContactInfo(double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Us',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _launch('tel:03719267771'),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.call_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Phone', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('03719267771', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _launch('mailto:info.hometechnify@gmail.com'),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.email_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('info.hometechnify@gmail.com', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 50.ms);
  }

  Widget _buildSearchBar(double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Container(
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for help...',
            hintStyle: TextStyle(color: AppColors.textHint),
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.grey400),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildQuickActions(double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          Expanded(child: _buildActionCard('Call Us', Icons.call_rounded, AppColors.success, onTap: () => _launch('tel:03719267771'))),
          const SizedBox(width: 12),
          Expanded(child: _buildActionCard('Email', Icons.email_outlined, AppColors.primaryBlue, onTap: () => _launch('mailto:info.hometechnify@gmail.com'))),
          const SizedBox(width: 12),
          Expanded(child: _buildActionCard('Chat', Icons.chat_bubble_outline_rounded, AppColors.warning, onTap: () => Navigator.pushNamed(context, '/chats'))),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildActionCard(String label, IconData icon, Color color, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQList(double horizontalPadding) {
    return ListView(
      padding: EdgeInsets.all(horizontalPadding),
      children: [
        const SizedBox(height: 8),
        const Text('Frequently Asked Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ...List.generate(_faqs.length, (index) => _buildFAQItem(index)),
      ],
    );
  }

  Widget _buildFAQItem(int index) {
    final faq = _faqs[index];
    final isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isExpanded ? AppColors.primaryBlue : AppColors.grey200)),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
            contentPadding: const EdgeInsets.all(16),
            title: Text(faq['question']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            trailing: Icon(
              isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: isExpanded ? AppColors.primaryBlue : AppColors.grey400,
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Text(faq['answer']!, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: index * 50));
  }
}

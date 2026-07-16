// User Profile Screen - Premium Modern Design

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/firebase_auth_service.dart';
import 'providers/profile_provider.dart';
import '../auth/data/models/user_model.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/theme/neu_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuthService.getUserId();
      if (userId != null) {
        context.read<ProfileProvider>().fetchProfile(userId);
      }
    });
  }

  void _showLanguageSelector() async {
    final result = await Navigator.pushNamed(
      context,
      '/language',
      arguments: {'currentLanguage': _selectedLanguage},
    );
    
    if (result != null && result is String) {
      setState(() => _selectedLanguage = result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Language changed to $result'),
            backgroundColor: AppColors.primaryBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;

    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        final user = provider.user ?? UserModel(
          id: FirebaseAuthService.getUserId() ?? 'user',
          name: FirebaseAuthService.getUserName(),
          email: FirebaseAuthService.getUserEmail() ?? '',
          phone: FirebaseAuthService.getUserPhone() ?? '',
          joinDate: DateTime.now(),
        );

        if (provider.isLoading) {
           return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          backgroundColor: NeuTheme.bg,
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildModernHeader(context, size, user),
                SizedBox(height: size.height < 700 ? 12 : 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    children: [
                      _buildStatsCards(size, user),
                      const SizedBox(height: 24),
                      _buildMenuSection(context, 'Account', [
                        MenuItem(icon: Icons.person_outline_rounded, title: 'Edit Profile', onTap: () => Navigator.pushNamed(context, '/edit-profile')),
                        MenuItem(icon: Icons.location_on_outlined, title: 'My Addresses', onTap: () => Navigator.pushNamed(context, '/my-addresses')),
                        MenuItem(icon: Icons.payment_outlined, title: 'Payment Methods', onTap: () => Navigator.pushNamed(context, '/payment-methods')),
                        MenuItem(
                          icon: Icons.favorite_rounded, 
                          title: 'Favorite Providers', 
                          trailing: favoritesService.favoritesCount > 0 ? '${favoritesService.favoritesCount}' : null,
                          onTap: () => Navigator.pushNamed(context, '/favorite-providers'),
                        ),
                        MenuItem(
                          icon: Icons.work_outline_rounded, 
                          title: 'My Posted Jobs', 
                          onTap: () => Navigator.pushNamed(context, '/my-jobs'),
                        ),
                      ], size),
                      const SizedBox(height: 20),
                      _buildMenuSection(context, 'General', [
                        MenuItem(icon: Icons.notifications_outlined, title: 'Notifications', onTap: () => Navigator.pushNamed(context, '/notifications')),
                        MenuItem(icon: Icons.language_outlined, title: 'Language', trailing: _selectedLanguage, onTap: () => _showLanguageSelector()),
                        MenuItem(icon: Icons.help_outline_rounded, title: 'Help Center', onTap: () => _showHelpCenter()),
                      ], size),
                      const SizedBox(height: 20),
                      _buildLogoutButton(context, size),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHelpCenter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Help Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    Text('How can we help you?', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Contact Options
            Row(
              children: [
                Expanded(child: _buildContactOption(Icons.call_rounded, 'Call Us', '03719267771', 'tel:03719267771')),
                const SizedBox(width: 12),
                Expanded(child: _buildContactOption(Icons.email_rounded, 'Email', 'info.hometechnify@gmail.com', 'mailto:info.hometechnify@gmail.com')),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Frequently Asked Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildFAQItem('How do I book a service?', 'Go to the home screen, select a service category, choose a provider, and tap "Book Now" to schedule your service.'),
                  _buildFAQItem('How can I cancel a booking?', 'Go to My Bookings, select the booking you want to cancel, and tap "Cancel Booking". Cancellation policy may apply.'),
                  _buildFAQItem('What payment methods are accepted?', 'We accept Cash on Delivery, JazzCash, and EasyPaisa payments.'),
                  _buildFAQItem('How do I rate a service provider?', 'After your service is completed, you\'ll receive a notification to rate your experience.'),
                  _buildFAQItem('How can I become a service provider?', 'Select "Provider" during registration and complete the verification process with your CNIC.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String title, String value, String url) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        iconColor: AppColors.primaryBlue,
        collapsedIconColor: AppColors.grey400,
        children: [
          Text(
            answer,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, Size size, UserModel user) {
    final isSmall = size.height < 700;
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isSmall ? 16 : 20),
        bottom: isSmall ? 24 : 32,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue,
            const Color(0xFF1E88E5),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => context.read<NavigationProvider>().setIndex(0),
                child: Container(
                  width: isSmall ? 40 : 44,
                  height: isSmall ? 40 : 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: isSmall ? 20 : 22),
                ),
              ),
              Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmall ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/settings'),
                child: Container(
                  width: isSmall ? 40 : 44,
                  height: isSmall ? 40 : 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.settings_outlined, color: Colors.white, size: isSmall ? 20 : 22),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 20 : 28),
          // Avatar with Camera Icon
          Stack(
            children: [
              Container(
                width: isSmall ? 90 : 100,
                height: isSmall ? 90 : 100,
                decoration: BoxDecoration(
                  gradient: (user.profileImage == null || user.profileImage!.isEmpty) 
                      ? AppColors.primaryGradient 
                      : null,
                  color: (user.profileImage != null && user.profileImage!.isNotEmpty) 
                      ? AppColors.grey100 
                      : null,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  image: (user.profileImage != null && user.profileImage!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(user.profileImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (user.profileImage == null || user.profileImage!.isEmpty)
                    ? Center(
                        child: Text(
                          user.name.substring(0, min(2, user.name.length)).toUpperCase(),
                          style: TextStyle(
                            fontSize: isSmall ? 32 : 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/edit-profile'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 14 : 18),
          // Name
          Text(
            user.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmall ? 22 : 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          // Phone
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_rounded, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(width: 6),
                Text(
                  '+92 ${user.phone}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0);
  }

  int min(int a, int b) => a < b ? a : b;

  Widget _buildStatsCards(Size size, UserModel user) {
    final isSmall = size.height < 700;
    
    // Formatting spent amount
    String spentLabel = 'Spent';
    String spentValue = 'Rs. ${user.totalSpent.toInt()}';
    if (user.totalSpent >= 1000000) {
      spentValue = '${(user.totalSpent / 1000000).toStringAsFixed(1)}M';
    } else if (user.totalSpent >= 1000) {
      spentValue = '${(user.totalSpent / 1000).toStringAsFixed(1)}k';
    }

    // Formatting booking count
    String bookingValue = user.totalBookings.toString();
    if (user.totalBookings >= 1000) {
      bookingValue = '${(user.totalBookings / 1000).toStringAsFixed(1)}k';
    }
    
    return Row(
      children: [
        Expanded(child: _buildStatCard(bookingValue, 'Bookings', Icons.calendar_today_rounded, AppColors.primaryBlue, isSmall)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(user.rating.toStringAsFixed(1), 'Rating', Icons.star_rounded, AppColors.primaryBlue, isSmall)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(spentValue, spentLabel, Icons.account_balance_wallet_rounded, AppColors.primaryBlue, isSmall)),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms);
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color, bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: NeuTheme.sm(radius: 18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: isSmall ? 18 : 20, color: color),
          ),
          SizedBox(height: isSmall ? 8 : 10),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmall ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, String title, List<MenuItem> items, Size size) {
    final isSmall = size.height < 700;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: isSmall ? 13 : 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: NeuTheme.sm(radius: 20),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  _buildMenuItem(context, item, isSmall),
                  if (index < items.length - 1)
                    Divider(height: 1, color: NeuTheme.bg, indent: 64, endIndent: 16, thickness: 1.5),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildMenuItem(BuildContext context, MenuItem item, bool isSmall) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: isSmall ? 14 : 16, vertical: isSmall ? 4 : 6),
      leading: Container(
        width: isSmall ? 42 : 46,
        height: isSmall ? 42 : 46,
        decoration: NeuTheme.sm(radius: 12),
        child: Icon(item.icon, color: AppColors.primaryBlue, size: isSmall ? 20 : 22),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontSize: isSmall ? 14 : 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: item.trailing != null
          ? Text(
              item.trailing!,
              style: TextStyle(
                fontSize: isSmall ? 13 : 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            )
          : Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: isSmall ? 20 : 22),
      onTap: item.onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context, Size size) {
    final isSmall = size.height < 700;
    
    return GestureDetector(
    onTap: () {
      // Show logout confirmation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.logout_rounded, color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Logout?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: const Text('Are you sure you want to logout?', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primaryBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Sign out from Firebase
                      await FirebaseAuthService.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 14 : 16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.white, size: isSmall ? 20 : 22),
            const SizedBox(width: 10),
            Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmall ? 15 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
}

class MenuItem {
  final IconData icon;
  final String title;
  final String? trailing;
  final bool hasSwitch;
  final VoidCallback onTap;

  MenuItem({
    required this.icon,
    required this.title,
    this.trailing,
    this.hasSwitch = false,
    required this.onTap,
  });
}

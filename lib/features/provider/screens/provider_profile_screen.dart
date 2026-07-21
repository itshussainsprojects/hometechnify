// Provider Profile Screen - Matching Reference Design

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/provider_controller.dart';
import '../data/models/provider_model.dart';
import 'edit_profile_screen.dart';
import 'dart:io';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  bool _pushNotifications = true;

  Future<void> _deleteAccount() async {
    final success = await context.read<ProviderController>().deleteAccount();
    if (success && mounted) {
      context.read<AuthProvider>().logout();
      Navigator.pushNamedAndRemoveUntil(context, '/provider/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted successfully.')));
    } else {
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<ProviderController>().errorMessage ?? 'Failed to delete account')));
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete your provider account? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Choose Image Source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _updateProfileImage(ImageSource.camera);
                  },
                ),
                _buildImageSourceOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _updateProfileImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _updateProfileImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile == null || !mounted) return;

    final controller = context.read<ProviderController>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await controller.uploadAndSetProfileImage(File(pickedFile.path));
    if (!mounted) return;

    if (success) {
      // Keep the signed-in user in sync so the avatar updates everywhere, not
      // just on this screen.
      final auth = context.read<AuthProvider>();
      final newUrl = controller.selectedProvider?.profileImage;
      if (newUrl != null && auth.user != null) {
        auth.updateProfileImage(newUrl);
      }
      messenger.showSnackBar(const SnackBar(
        content: Text('Profile image updated successfully!'),
        backgroundColor: AppColors.primaryBlue,
      ));
    } else {
      // A failed upload used to do nothing at all, so it just looked like the
      // button was dead.
      messenger.showSnackBar(SnackBar(
        content: Text(controller.errorMessage ?? 'Failed to update profile image'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize notification state from User Model
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _pushNotifications = user.isNotificationsEnabled;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        context.read<ProviderController>().fetchProviderDetails(userId);
        context.read<ProviderController>().fetchDashboardStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    
    // Watch provider controller for changes
    final providerController = context.watch<ProviderController>();
    final provider = providerController.selectedProvider;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF), // Subtle blue tint
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(horizontalPadding, isSmall)),
          if (providerController.isLoading && provider == null)
             const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else ...[
             SliverToBoxAdapter(child: _buildProfileInfo(horizontalPadding, isSmall, provider)),
             SliverToBoxAdapter(child: _buildVerificationStatus(horizontalPadding, isSmall, provider)),
             SliverToBoxAdapter(child: _buildProviderInfo(horizontalPadding, isSmall, provider, providerController.dashboardStats)),
             SliverToBoxAdapter(child: _buildServiceMenu(horizontalPadding, isSmall)),
             SliverToBoxAdapter(child: _buildOtherMenu(horizontalPadding, isSmall)),
             SliverToBoxAdapter(child: _buildSettingsMenu(horizontalPadding, isSmall)),
             SliverToBoxAdapter(child: _buildDangerZoneMenu(horizontalPadding, isSmall)),
             SliverToBoxAdapter(child: const SizedBox(height: 120)),
          ]
        ],
      ),
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader(double horizontalPadding, bool isSmall) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: 12,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'My Profile',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildProfileInfo(double horizontalPadding, bool isSmall, dynamic provider) {
    // Fallback to Auth User if provider details not fully loaded but we have auth
    final authUser = context.read<AuthProvider>().user;
    final name = provider?.name ?? authUser?.name ?? 'Provider';
    final email = provider?.email ?? authUser?.email ?? 'No Email';
    final imagePath = provider?.profileImage ?? authUser?.profileImage;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: isSmall ? 100 : 115,
                  height: isSmall ? 100 : 115,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: isSmall ? 90 : 105,
                      height: isSmall ? 90 : 105,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.white,
                        image: imagePath != null
                            ? DecorationImage(image: NetworkImage(imagePath), fit: BoxFit.cover)
                            : null,
                      ),
                      child: imagePath == null
                          ? Icon(Icons.person_rounded, size: 55, color: AppColors.primaryBlue.withValues(alpha: 0.2))
                          : null,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Name
          Text(
            name,
            style: TextStyle(
              fontSize: isSmall ? 20 : 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          // Email
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              email,
              style: TextStyle(
                fontSize: isSmall ? 12 : 13,
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Edit Profile Button
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildVerificationStatus(double horizontalPadding, bool isSmall, dynamic provider) {
    // Determine verification status from provider data (assuming 'is_verified' is boolean on User/ProviderModel)
    // The ProviderModel doesn't strictly have isVerified, so we check if ID exists or some other flag
    // For now, let's assume we use the 'rating' or existing logic
    // Actually ProviderModel has isVerified? No, schema says User has is_verified.
    // ProviderModel in Dart currently: has reviewCount, rating... 
    // We added fields in ProviderModel.dart but let's recheck.
    // Wait, let's blindly map what we have. 
    // Ideally we should have isVerified in ProviderModel.
    
    final isVerified = provider is ProviderModel && provider.isVerified;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VERIFICATION CENTER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryBlue, letterSpacing: 1.0)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isVerified ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isVerified ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
                        color: isVerified ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVerified ? 'Account Verified' : 'Verification Under Review',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            isVerified ? 'Your account is live and active.' : 'Admin is reviewing your documents.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Hide CNIC preview for now as it makes screen too long and we are focusing on wallet
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderInfo(double horizontalPadding, bool isSmall, dynamic provider, Map<String, dynamic> stats) {
    // Live balance comes from dashboard stats (refreshed on every visit and
    // after top-ups); selectedProvider is only a fallback.
    final walletBalance = double.tryParse(
            stats['walletBalance']?.toString() ?? '') ??
        provider?.walletBalance ??
        0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.primaryBlue, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet Balance',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'PKR ${walletBalance.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/provider/wallet'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Top Up',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.1);
  }

  Widget _buildServiceMenu(double horizontalPadding, bool isSmall) {
    final menuItems = [
      {'icon': Icons.account_balance_wallet_outlined, 'title': 'Wallet History', 'route': '/provider/wallet-history'},
      {'icon': Icons.grid_view_rounded, 'title': 'My Trade & Services', 'route': '/provider/services'},
      {'icon': Icons.campaign_rounded, 'title': 'Advertise Your Service', 'route': '/provider/advertise'},
    ];

    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        children: [
          Text(
            'Service',
            style: TextStyle(
              fontSize: isSmall ? 16 : 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: menuItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    _buildMenuItem(
                      icon: item['icon'] as IconData,
                      title: item['title'] as String,
                      onTap: () => Navigator.pushNamed(context, item['route'] as String),
                      isSmall: isSmall,
                    ),
                    if (index < menuItems.length - 1)
                      const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 76),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Premium Bank Detail Card - Designed specifically to match user's image reference
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/provider/bank-detail'),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.blueBlackGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_balance_outlined, color: AppColors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bank & Wallet',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Payment Detail',
                          style: TextStyle(
                            fontSize: 17,
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Manage',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideY(begin: 0.2),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildOtherMenu(double horizontalPadding, bool isSmall) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OTHER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryBlue, letterSpacing: 1.0)),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildToggleItem(
                  icon: Icons.notifications_none_rounded,
                  title: 'Push Notification',
                  value: _pushNotifications,
                  onChanged: (val) async {
                    setState(() => _pushNotifications = val);
                    final providerCtrl = context.read<ProviderController>();
                    final authProvider = context.read<AuthProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await providerCtrl.toggleNotifications(val);
                    if (!mounted) return;
                    if (success) {
                       authProvider.checkAuthStatus();
                    } else {
                       setState(() => _pushNotifications = !val);
                       messenger.showSnackBar(const SnackBar(content: Text('Failed to update settings')));
                    }
                  },
                  isSmall: isSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 250.ms);
  }

  Widget _buildSettingsMenu(double horizontalPadding, bool isSmall) {
    final menuItems = [
      {'icon': Icons.language_rounded, 'title': 'App Language', 'route': '/language'},
      {'icon': Icons.lock_outline_rounded, 'title': 'Change Password', 'route': '/provider/password'},
      {'icon': Icons.info_outline_rounded, 'title': 'About', 'route': '/provider/about'},
    ];


    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SETTING', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryBlue, letterSpacing: 1.0)),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: menuItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    _buildMenuItem(
                      icon: item['icon'] as IconData,
                      title: item['title'] as String,
                      onTap: () => Navigator.pushNamed(context, item['route'] as String),
                      isSmall: isSmall,
                    ),
                    if (index < menuItems.length - 1)
                      const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 76),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildDangerZoneMenu(double horizontalPadding, bool isSmall) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DANGER ZONE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.error, letterSpacing: 1.0)),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete Account',
                  onTap: _showDeleteConfirmation,
                  isSmall: isSmall,
                  iconColor: AppColors.error,
                  textColor: AppColors.error,
                ),
                const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 76),
                _buildMenuItem(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  onTap: () {
                    context.read<AuthProvider>().logout();
                    Navigator.pushNamedAndRemoveUntil(context, '/provider/login', (route) => false);
                  },
                  isSmall: isSmall,
                  iconColor: AppColors.error,
                  textColor: AppColors.error,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 350.ms);
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isSmall,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 8 : 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: (val) {
              onChanged(val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title ${val ? 'enabled' : 'disabled'}'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: AppColors.primaryBlue,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            activeThumbColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isSmall,
    Color? iconColor,
    Color? textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 14 : 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF), // Exact light blue from image
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: iconColor ?? AppColors.primaryBlue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800, // Very bold like the image
                  color: textColor ?? AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'iconOutlined': Icons.home_outlined, 'label': 'Home'},
      {'icon': Icons.calendar_today_rounded, 'iconOutlined': Icons.calendar_today_outlined, 'label': 'Bookings'},
      {'icon': Icons.person_rounded, 'iconOutlined': Icons.person_outline_rounded, 'label': 'Profile'},
    ];

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.grey200)),
      ),
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final isSelected = index == 2; // Profile is selected
            return GestureDetector(
              onTap: () {
                if (index == 0) {
                  Navigator.pushReplacementNamed(context, '/provider/dashboard');
                } else if (index == 1) {
                  Navigator.pushReplacementNamed(context, '/provider/jobs');
                } else if (index == 2) {
                  // Already on Profile
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? items[index]['icon'] as IconData : items[index]['iconOutlined'] as IconData,
                    size: 24,
                    color: isSelected ? AppColors.primaryBlue : AppColors.grey400,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[index]['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.primaryBlue : AppColors.grey400,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

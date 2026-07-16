// Settings Screen - Premium Design with Logo Colors

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';
import '../auth/providers/auth_provider.dart';
import 'package:home_technify/features/profile/providers/profile_provider.dart';

import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/theme/neu_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool _notifications = false;
  bool _locationServices = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    // Check Provider State (User Preference)
    final provider = context.read<ProfileProvider>();
    
    // Check System Status just to know (could show warning if mismatch)
    // bool sysLoc = await Geolocator.isLocationServiceEnabled();
    
    if (mounted) {
      setState(() {
        _locationServices = provider.appLocationEnabled;
        _notifications = provider.appNotificationEnabled;
      });
    }
  }
  
  Future<void> _handleLocationToggle(bool value) async {
    final provider = context.read<ProfileProvider>();

    if (value) {
      try {
        LocationPermission p = await Geolocator.checkPermission();
        if (p == LocationPermission.denied) {
          p = await Geolocator.requestPermission();
        }

        if (p == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied. Please enable it in Settings.')),
            );
            await Geolocator.openAppSettings();
          }
          return;
        }

        if (p == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission is required to find nearby providers.')),
            );
          }
          return;
        }

        // whileInUse or always — permission granted
        provider.setAppLocation(true);
        if (mounted) setState(() => _locationServices = true);
      } catch (_) {
        provider.setAppLocation(true);
        if (mounted) setState(() => _locationServices = true);
      }
    } else {
      provider.setAppLocation(false);
      if (mounted) setState(() => _locationServices = false);
    }
  }

  Future<void> _handleNotificationToggle(bool value) async {
    final provider = context.read<ProfileProvider>();

    if (value) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission();
        final granted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        if (granted) {
          provider.setAppNotification(true);
          if (mounted) setState(() => _notifications = true);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable notifications in your device settings.')),
          );
        }
      } catch (_) {
        // Firebase unavailable — save preference anyway
        provider.setAppNotification(true);
        if (mounted) setState(() => _notifications = true);
      }
    } else {
      provider.setAppNotification(false);
      if (mounted) setState(() => _notifications = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: NeuTheme.bg,
      body: Column(
        children: [
          // Premium Gradient Header
          _buildHeader(context, isSmall),
          // Settings Content
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(horizontalPadding),
              children: [
                const SizedBox(height: 16),
                _buildSection('Preferences', [
                  _SettingItem(
                    icon: Icons.notifications_rounded,
                    title: 'Push Notifications',
                    subtitle: 'Receive booking updates and messages',
                    hasSwitch: true,
                    switchValue: _notifications,
                    onSwitchChanged: _handleNotificationToggle,
                  ),
                  _SettingItem(
                    icon: Icons.location_on_rounded,
                    title: 'Location Services',
                    subtitle: 'Find nearby providers',
                    hasSwitch: true,
                    switchValue: _locationServices,
                    onSwitchChanged: _handleLocationToggle,
                  ),
                ], isSmall, 0),
                const SizedBox(height: 24),
                _buildSection('Account Actions', [
                  _SettingItem(
                    icon: Icons.lock_reset_rounded,
                    title: 'Change Password',
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                  _SettingItem(
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account and data',
                    onTap: () => _showDeleteAccountDialog(context),
                  ),
                ], isSmall, 50),
                 const SizedBox(height: 24),
                _buildSection('About', [
                  _SettingItem(
                    icon: Icons.info_outline_rounded,
                    title: 'App Version',
                    trailing: '1.0.0',
                  ),
                  _SettingItem(
                    icon: Icons.build_rounded,
                    title: 'Build Number',
                    trailing: '100',
                  ),
                  _SettingItem(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    hasArrow: true,
                    onTap: () => Navigator.pushNamed(context, '/terms'),
                  ),
                  _SettingItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    hasArrow: true,
                    onTap: () => Navigator.pushNamed(context, '/privacy'),
                  ),
                ], isSmall, 100),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSmall) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 24,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.35),
            blurRadius: 20,
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildSection(String title, List<_SettingItem> items, bool isSmall, int delayMs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
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
                  _buildSettingTile(item, isSmall),
                  if (index < items.length - 1)
                    Divider(height: 1, color: NeuTheme.bg, indent: 70, endIndent: 16, thickness: 1.5),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: delayMs)).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSettingTile(_SettingItem item, bool isSmall) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: EdgeInsets.all(isSmall ? 14 : 16),
        color: Colors.transparent,
        child: Row(
          children: [
            // Icon container
            Container(
              width: isSmall ? 46 : 50,
              height: isSmall ? 46 : 50,
              decoration: NeuTheme.sm(radius: 14),
              child: Icon(item.icon, size: isSmall ? 22 : 24, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 14),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: isSmall ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: isSmall ? 12 : 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Trailing widget
            if (item.hasSwitch)
              Transform.scale(
                scale: isSmall ? 0.85 : 0.9,
                child: Switch(
                  value: item.switchValue ?? false,
                  onChanged: item.onSwitchChanged,
                  activeThumbColor: AppColors.primaryBlue,
                  activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                  inactiveThumbColor: AppColors.grey400,
                  inactiveTrackColor: AppColors.grey200,
                ),
              )
            else if (item.trailing != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.trailing!,
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
              )
            else if (item.hasArrow)
              Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: 24),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(labelText: 'Current Password'),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              final success = await authProvider.changePassword(
                currentPasswordController.text,
                newPasswordController.text,
              );
              if (!mounted) return;
              if (success) {
                messenger.showSnackBar(const SnackBar(content: Text('Password changed successfully')));
              } else {
                messenger.showSnackBar(SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to change password'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              Navigator.pop(context);
              final success = await authProvider.deleteAccount();
              if (!mounted) return;
              if (success) {
                navigator.pushNamedAndRemoveUntil('/onboarding', (route) => false);
              } else {
                messenger.showSnackBar(SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to delete account'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final bool hasSwitch;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final bool hasArrow;
  final VoidCallback? onTap;

  _SettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.hasSwitch = false,
    this.switchValue,
    this.onSwitchChanged,
    this.hasArrow = false,
    this.onTap,
  });
}

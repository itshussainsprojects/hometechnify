// Profile Actions Screen - Handles Theme, Password, and About
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:home_technify/core/constants/constants.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileActionsScreen extends StatefulWidget {
  final String type; // 'theme', 'password', 'about'
  
  const ProfileActionsScreen({super.key, required this.type});

  @override
  State<ProfileActionsScreen> createState() => _ProfileActionsScreenState();
}

class _ProfileActionsScreenState extends State<ProfileActionsScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedTheme = 'Light';
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String title = '';
    switch (widget.type) {
      case 'theme': title = 'App Theme'; break;
      case 'password': title = 'Change Password'; break;
      case 'about': title = 'About App'; break;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (widget.type) {
      case 'theme': return _buildThemeContent();
      case 'password': return _buildPasswordContent();
      case 'about': return _buildAboutContent();
      default: return const Center(child: Text('Coming Soon'));
    }
  }

  Widget _buildThemeContent() {
    final themes = ['Light', 'Dark', 'System Default'];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: themes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final theme = themes[index];
        final isSelected = _selectedTheme == theme;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedTheme = theme);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$theme theme applied!'), backgroundColor: AppColors.primaryBlue),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? AppColors.primaryBlue : AppColors.grey200),
            ),
            child: Row(
              children: [
                Icon(
                  theme == 'Light' ? Icons.wb_sunny_rounded : 
                  theme == 'Dark' ? Icons.nightlight_round : Icons.settings_brightness_rounded,
                  color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                ),
                const SizedBox(width: 16),
                Text(theme, style: TextStyle(
                  fontSize: 16, 
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                )),
                const Spacer(),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPasswordContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPasswordField('Current Password', _oldPasswordController),
          const SizedBox(height: 16),
          _buildPasswordField('New Password', _newPasswordController),
          const SizedBox(height: 16),
          _buildPasswordField('Confirm Password', _confirmPasswordController),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Update Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final oldPass = _oldPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);

    final success = await context.read<AuthProvider>().changePassword(oldPass, newPass);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully!'), backgroundColor: AppColors.success));
        Navigator.pop(context);
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<AuthProvider>().errorMessage ?? 'Failed to change password'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildPasswordField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue)),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutContent() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      children: [
        Center(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 180,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.app_shortcut_rounded, size: 80, color: AppColors.primaryBlue),
                ),
              ),
              const SizedBox(height: 6),
              const Text('Version 1.0.0', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildAboutItem('Terms of Service', Icons.description_rounded, () {
          Navigator.pushNamed(context, '/terms');
        }),
        const Divider(height: 1),
        _buildAboutItem('Privacy Policy', Icons.privacy_tip_rounded, () {
          Navigator.pushNamed(context, '/privacy');
        }),
      ],
    );
  }

  Widget _buildAboutItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryBlue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

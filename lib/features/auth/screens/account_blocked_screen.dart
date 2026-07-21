// Account Blocked Screen — shown the instant admin blocks this account
// (real-time via Socket.IO, not just the next failed API call), and also
// reachable as a fallback if a 403 slips through first.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/constants.dart';

class AccountBlockedScreen extends StatelessWidget {
  /// 'CUSTOMER' | 'PROVIDER' | null — decides which login screen "Logout"
  /// sends them to. Captured by AuthProvider before logout() wipes the role.
  final String? role;

  const AccountBlockedScreen({super.key, this.role});

  void _logout(BuildContext context) {
    final loginRoute = role == 'PROVIDER' ? '/provider/login' : '/login';
    Navigator.pushNamedAndRemoveUntil(context, loginRoute, (route) => false);
  }

  Future<void> _call(BuildContext context) async {
    final uri = Uri.parse('tel:03719267771');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _email(BuildContext context) async {
    final uri = Uri.parse('mailto:info.hometechnify@gmail.com');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // A blocked account has no legitimate reason to see its own real
          // data behind this — unlike the pending-verification screen, this
          // is a plain brand-gradient backdrop, blurred, not the live app.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryBlue.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_person_rounded, size: 48, color: AppColors.error),
                      ).animate().scale(delay: 100.ms, duration: 500.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 24),
                      const Text(
                        'Account Blocked',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'The HomeTechnify team has blocked your account. Please contact our helpline for more details.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _call(context),
                              icon: const Icon(Icons.call_rounded, size: 18),
                              label: const Text('Call'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryBlue,
                                side: BorderSide(color: AppColors.primaryBlue),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _email(context),
                              icon: const Icon(Icons.email_rounded, size: 18),
                              label: const Text('Email'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryBlue,
                                side: BorderSide(color: AppColors.primaryBlue),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => _logout(context),
                          child: Text(
                            'Logout',
                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Account Blocked Screen — shown the instant admin blocks this account
// (real-time via Socket.IO, not just the next failed API call), and also
// reachable as a fallback if a 403 slips through first.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/constants.dart';
import '../../../core/theme/neu_theme.dart';

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
    // Always reached via pushNamedAndRemoveUntil (socket block event or the
    // 403 fallback), which clears the whole stack — there is nothing left to
    // pop back to. Without this, the system back button had nowhere to go,
    // which read as a black-screen glitch. A blocked account has no route
    // out via back anyway — Logout or the helpline buttons are the only way
    // off this screen.
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                    decoration: NeuTheme.raised(radius: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: NeuTheme.circle(),
                          child: Icon(Icons.lock_person_rounded, size: 44, color: AppColors.error),
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
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: NeuTheme.inset(radius: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.email_outlined, size: 16, color: AppColors.primaryBlue),
                              const SizedBox(width: 8),
                              Text(
                                'info.hometechnify@gmail.com',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(child: _NeuActionButton(icon: Icons.call_rounded, label: 'Call', onTap: () => _call(context))),
                            const SizedBox(width: 16),
                            Expanded(child: _NeuActionButton(icon: Icons.email_rounded, label: 'Email', onTap: () => _email(context))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: _NeuActionButton(
                            icon: Icons.logout_rounded,
                            label: 'Logout',
                            color: AppColors.error,
                            onTap: () => _logout(context),
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
      ),
    );
  }
}

/// A tappable neumorphic pill: raised at rest, presses in on tap.
class _NeuActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _NeuActionButton({required this.icon, required this.label, required this.onTap, this.color});

  @override
  State<_NeuActionButton> createState() => _NeuActionButtonState();
}

class _NeuActionButtonState extends State<_NeuActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primaryBlue;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: _pressed ? NeuTheme.inset(radius: 14) : NeuTheme.sm(radius: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(widget.label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

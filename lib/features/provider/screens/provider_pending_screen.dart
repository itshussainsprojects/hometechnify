import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'provider_dashboard_screen.dart';

/// The real dashboard renders underneath, blurred and non-interactive — so a
/// pending provider sees what's waiting for them instead of a blank page —
/// with the verification notice as a card on top, matching how a modal
/// blocks its backdrop elsewhere in the app.
class ProviderPendingScreen extends StatelessWidget {
  const ProviderPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AbsorbPointer(
            absorbing: true,
            child: ProviderDashboardScreen(),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
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
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.hourglass_top_rounded, size: 56, color: AppColors.warning),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Verification Pending',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Your verification is pending. The HomeTechnify team is reviewing your documents — you\'ll get a notification the moment you\'re approved.',
                        style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            context.read<AuthProvider>().logout();
                            // This screen has a live ProviderDashboardScreen sitting behind
                            // the blur — pushReplacementNamed only swaps the top route, so
                            // that (now user-less) dashboard stayed one route behind the
                            // login screen in the stack, and the back button surfaced it,
                            // crashing since it reads AuthProvider.user fields directly.
                            Navigator.pushNamedAndRemoveUntil(context, '/provider/login', (route) => false);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: AppColors.primaryBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Logout',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
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

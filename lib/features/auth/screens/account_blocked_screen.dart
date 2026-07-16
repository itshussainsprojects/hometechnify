// Account Blocked Screen - Premium Design
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';

class AccountBlockedScreen extends StatelessWidget {
  const AccountBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Illustration
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_person_rounded,
                    size: 72,
                    color: AppColors.error,
                  ),
                ),
              ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
              
              const SizedBox(height: 48),
              
              const Text(
                'Account Blocked',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 16),
              
              Text(
                'Your account has been restricted by the administrator. You no longer have access to features and bookings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 48),
              
              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Simulated support contact
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connecting to support...')),
                    );
                  },
                  icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
                  label: const Text('CONTACT SUPPORT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () {
                  // Logout if necessary
                  Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
                },
                child: const Text(
                  'LOGOUT FROM DEVICE',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ).animate().fadeIn(delay: 1000.ms),
            ],
          ),
        ),
      ),
    );
  }
}

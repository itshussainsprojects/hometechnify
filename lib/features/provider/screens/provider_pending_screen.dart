import 'package:flutter/material.dart';
import '../../../core/constants/constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ProviderPendingScreen extends StatelessWidget {
  const ProviderPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.hourglass_top_rounded, size: 60, color: AppColors.warning),
              ),
              const SizedBox(height: 32),
              const Text(
                'Verification Pending',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your provider account is currently under review. access to the dashboard will be granted once your documents are verified.',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    context.read<AuthProvider>().logout();
                    Navigator.pushReplacementNamed(context, '/provider/login');
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
    );
  }
}

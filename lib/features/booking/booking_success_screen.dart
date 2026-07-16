// Booking Success Screen

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final isSmall = Responsive.isSmall(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6EC6FF), // Light blue from brand kit
              Color(0xFF1495FF), // Primary blue
              Color(0xFFFFFFFF), // White at bottom
            ],
            stops: [0.0, 0.3, 0.5],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: isSmall ? 100 : 120,
                  height: isSmall ? 100 : 120,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 15))],
                  ),
                  child: Icon(Icons.check_rounded, size: isSmall ? 48 : 60, color: Colors.white),
                ).animate().scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 800.ms),
                SizedBox(height: isSmall ? 24 : 32),
                Text('Booking Confirmed!', style: TextStyle(fontSize: isSmall ? 24 : 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)).animate().fadeIn(delay: 300.ms),
                SizedBox(height: isSmall ? 8 : 12),
                Text('Your service has been booked successfully.\nThe provider will contact you shortly.', textAlign: TextAlign.center, style: TextStyle(fontSize: isSmall ? 13 : 15, color: AppColors.textSecondary, height: 1.6)).animate().fadeIn(delay: 400.ms),
                SizedBox(height: isSmall ? 24 : 32),
                Container(
                  padding: EdgeInsets.all(isSmall ? 16 : 20),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey200)),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.calendar_today_rounded, 'Date', 'Today, Dec 25', isSmall),
                      SizedBox(height: isSmall ? 12 : 16),
                      _buildInfoRow(Icons.access_time_rounded, 'Time', '10:00 AM', isSmall),
                      SizedBox(height: isSmall ? 12 : 16),
                      _buildInfoRow(Icons.person_rounded, 'Provider', 'Ahmed Khan', isSmall),
                      SizedBox(height: isSmall ? 12 : 16),
                      _buildInfoRow(Icons.payments_rounded, 'Amount', 'Rs. 550', isSmall),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/chats'),
                        child: Container(
                          height: isSmall ? 48 : 56,
                          decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(14)),
                          child: Center(child: Text('Chat', style: TextStyle(fontSize: isSmall ? 14 : 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(context, '/track-provider'),
                        child: Container(
                          height: isSmall ? 48 : 56,
                          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))]),
                          child: Center(child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on_rounded, color: Colors.white, size: isSmall ? 18 : 20),
                              const SizedBox(width: 8),
                              Text('Track Provider', style: TextStyle(fontSize: isSmall ? 14 : 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          )),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 600.ms),
                SizedBox(height: isSmall ? 16 : 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isSmall) {
    return Row(
      children: [
        Container(
          width: isSmall ? 36 : 40,
          height: isSmall ? 36 : 40,
          decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: isSmall ? 18 : 20, color: AppColors.primaryBlue),
        ),
        SizedBox(width: isSmall ? 12 : 14),
        Expanded(child: Text(label, style: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.textSecondary))),
        Text(value, style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}

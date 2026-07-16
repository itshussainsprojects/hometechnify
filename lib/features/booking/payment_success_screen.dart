// Payment Success Screen - User App
// Final confirmation after payment

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/techy_buddy.dart';
import 'data/models/booking_model.dart';
import 'providers/booking_provider.dart';

/// Receipt shown after a job is paid for.
///
/// Every field on this screen used to be a literal — "Ahmad Hassan", "Rs. 2,500",
/// "TXN123456789", "17 Jan 2024" — so every customer, on every booking, was shown
/// the same invented receipt. It now reads the real booking passed in via the
/// route arguments.
class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final horizontalPadding = Responsive.horizontalPadding(context);

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final bookingId = args?['bookingId'] as String?;

    BookingModel? booking = args?['booking'] as BookingModel?;
    if (booking == null && bookingId != null) {
      try {
        booking = context.watch<BookingProvider>().bookings.firstWhere((b) => b.id == bookingId);
      } catch (_) {/* not loaded yet — fall through to the placeholders below */}
    }

    final money = NumberFormat('#,##0', 'en_US');
    final when = booking?.completedAt ?? booking?.updatedAt;

    final Map<String, dynamic> paymentData = {
      // The booking id IS the receipt reference — there is no separate txn id
      // for cash, and inventing one would be a lie on a receipt.
      'transactionId': booking != null
          ? '#${booking.id.substring(booking.id.length - 8).toUpperCase()}'
          : '—',
      'date': when != null ? DateFormat('dd MMM yyyy').format(when.toLocal()) : '—',
      'time': when != null ? DateFormat('h:mm a').format(when.toLocal()) : '—',
      'service': booking?.serviceName ?? '—',
      'provider': booking?.providerName ?? '—',
      'amount': booking != null ? 'Rs. ${money.format(booking.price)}' : '—',
      'paymentMethod': 'Cash',
    };

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            children: [
              SizedBox(height: isSmall ? 30 : 50),
              
              // Success Animation - Techy celebrates the booking with the
              // user, with a small check badge tucked at his side.
              SizedBox(
                width: isSmall ? 130 : 160,
                height: isSmall ? 130 : 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TechyBuddy(
                      height: isSmall ? 130 : 160,
                      celebrateOnStart: true,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 6,
                      child: Container(
                        width: isSmall ? 34 : 40,
                        height: isSmall ? 34 : 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primaryBlue.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: isSmall ? 20 : 24,
                          color: Colors.white,
                        ),
                      )
                          .animate()
                          .scale(
                              begin: const Offset(0, 0),
                              curve: Curves.elasticOut,
                              duration: 700.ms,
                              delay: 350.ms)
                          .fadeIn(delay: 350.ms, duration: 200.ms),
                    ),
                  ],
                ),
              ).animate().scale(begin: const Offset(0.5, 0.5), curve: Curves.easeOutBack, duration: 500.ms).fadeIn(),
              
              SizedBox(height: isSmall ? 20 : 28),
              
              Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: isSmall ? 24 : 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ).animate().fadeIn(delay: 300.ms),
              
              SizedBox(height: isSmall ? 8 : 10),
              
              Text(
                'Your service has been completed successfully',
                style: TextStyle(
                  fontSize: isSmall ? 13 : 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms),
              
              SizedBox(height: isSmall ? 28 : 40),
              
              // Receipt Card
              Container(
                padding: EdgeInsets.all(isSmall ? 18 : 24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Amount
                    Text(
                      paymentData['amount'],
                      style: TextStyle(
                        fontSize: isSmall ? 32 : 38,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    
                    SizedBox(height: isSmall ? 4 : 6),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'PAID',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: isSmall ? 20 : 28),
                    
                    // Divider
                    Container(
                      height: 1,
                      color: AppColors.grey100,
                    ),
                    
                    SizedBox(height: isSmall ? 16 : 20),
                    
                    // Details
                    _buildDetailRow('Transaction ID', paymentData['transactionId'], isSmall),
                    SizedBox(height: isSmall ? 12 : 14),
                    _buildDetailRow('Date', paymentData['date'], isSmall),
                    SizedBox(height: isSmall ? 12 : 14),
                    _buildDetailRow('Time', paymentData['time'], isSmall),
                    SizedBox(height: isSmall ? 12 : 14),
                    _buildDetailRow('Service', paymentData['service'], isSmall),
                    SizedBox(height: isSmall ? 12 : 14),
                    _buildDetailRow('Provider', paymentData['provider'], isSmall),
                    SizedBox(height: isSmall ? 12 : 14),
                    _buildDetailRow('Payment Method', paymentData['paymentMethod'], isSmall),
                  ],
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
              
              SizedBox(height: isSmall ? 28 : 40),
              
              // Back to Home Button
              GestureDetector(
                onTap: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                },
                child: Container(
                  width: double.infinity,
                  height: isSmall ? 52 : 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Back to Home',
                      style: TextStyle(
                        fontSize: isSmall ? 15 : 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms),
              
              SizedBox(height: isSmall ? 14 : 18),
              
              // View Booking Details
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/my-bookings');
                },
                child: Text(
                  'View Booking Details',
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              
              SizedBox(height: isSmall ? 20 : 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isSmall) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 12 : 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmall ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

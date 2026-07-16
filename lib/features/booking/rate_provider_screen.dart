// Rate Provider Screen - User App
// Rate and review provider after service completion

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'providers/booking_provider.dart';
import 'data/models/booking_model.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';

class RateProviderScreen extends StatefulWidget {
  const RateProviderScreen({super.key});

  @override
  State<RateProviderScreen> createState() => _RateProviderScreenState();
}

class _RateProviderScreenState extends State<RateProviderScreen> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  
  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    // Get arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? bookingId = args?['bookingId'];
    // final booking = args?['booking'] as BookingModel?; // If passed full object

    if (bookingId == null) {
       return Scaffold(body: Center(child: Text("Error: Booking ID missing")));
    }
    
    // We can fetch booking using provider if not passed
    // Assuming context.read<BookingProvider>() has it.
    final provider = context.watch<BookingProvider>(); 
    BookingModel? booking;
    try {
      booking = provider.bookings.firstWhere((b) => b.id == bookingId);
    } catch (_) {
       return Scaffold(body: Center(child: Text("Booking not found locally")));
    }

    final providerData = {
      'name': booking.providerName,
      'service': booking.serviceName,
    };

    final serviceData = {
      'date': '${booking.bookingDate.day}/${booking.bookingDate.month}/${booking.bookingDate.year}', // Format nicely
      'time': 'Completed',
      'duration': '1h 30m', // Mock duration or calc
      'amount': 'Rs. ${booking.price}',
    };

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Rate Your Experience',
          style: TextStyle(
            fontSize: isSmall ? 17 : 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          children: [
            // Success Icon
            Container(
              width: isSmall ? 70 : 80,
              height: isSmall ? 70 : 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.check_rounded,
                size: isSmall ? 36 : 42,
                color: Colors.white,
              ),
            ).animate().scale(begin: const Offset(0.5, 0.5)).fadeIn(),
            
            SizedBox(height: isSmall ? 16 : 20),
            
            Text(
              'Service Completed!',
              style: TextStyle(
                fontSize: isSmall ? 22 : 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 200.ms),
            
            SizedBox(height: isSmall ? 6 : 8),
            
            Text(
              'How was your experience with ${providerData['name']}?',
              style: TextStyle(
                fontSize: isSmall ? 13 : 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
            
            SizedBox(height: isSmall ? 24 : 32),
            
            // Provider Card
            Container(
              padding: EdgeInsets.all(isSmall ? 14 : 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: isSmall ? 48 : 54,
                    height: isSmall ? 48 : 54,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        providerData['name']!.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerData['name']!,
                          style: TextStyle(
                            fontSize: isSmall ? 15 : 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          providerData['service']!,
                          style: TextStyle(
                            fontSize: isSmall ? 12 : 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        serviceData['amount']!,
                        style: TextStyle(
                          fontSize: isSmall ? 16 : 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        serviceData['duration']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
            
            SizedBox(height: isSmall ? 24 : 32),
            
            // Rating Section
            Text(
              'Tap to rate',
              style: TextStyle(
                fontSize: isSmall ? 14 : 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            
            SizedBox(height: isSmall ? 12 : 16),
            
            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 6),
                    child: Icon(
                      index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: isSmall ? 40 : 48,
                      color: index < _rating ? AppColors.warning : AppColors.grey300,
                    ),
                  ),
                ).animate(delay: Duration(milliseconds: 100 * index)).scale(begin: const Offset(0.5, 0.5)).fadeIn();
              }),
            ),
            
            if (_rating > 0) ...[
              SizedBox(height: isSmall ? 8 : 12),
              Text(
                _rating == 5 ? 'Excellent!' : _rating == 4 ? 'Great!' : _rating == 3 ? 'Good' : _rating == 2 ? 'Fair' : 'Poor',
                style: TextStyle(
                  fontSize: isSmall ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ).animate().fadeIn(),
            ],
            
            SizedBox(height: isSmall ? 20 : 24),
            
            // Review TextField
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.grey200),
              ),
              child: TextField(
                controller: _reviewController,
                maxLines: 4,
                style: TextStyle(fontSize: isSmall ? 13 : 14),
                decoration: InputDecoration(
                  hintText: 'Write a review (optional)',
                  hintStyle: TextStyle(color: AppColors.textHint, fontSize: isSmall ? 13 : 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(isSmall ? 14 : 16),
                ),
              ),
            ).animate().fadeIn(delay: 500.ms),
            
            SizedBox(height: isSmall ? 24 : 32),
            
            // Submit Button
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else
            GestureDetector(
              onTap: _rating > 0 ? () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final success = await provider.rateBooking(bookingId, _rating.toDouble(), _reviewController.text);
                if (!mounted) return;
                if (success) {
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(content: Text('Review submitted successfully!'), backgroundColor: AppColors.success));
                } else {
                  messenger.showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Failed to submit review'), backgroundColor: Colors.red));
                }
              } : null,
              child: Container(
                width: double.infinity,
                height: isSmall ? 50 : 54,
                decoration: BoxDecoration(
                  gradient: _rating > 0 ? AppColors.primaryGradient : null,
                  color: _rating > 0 ? null : AppColors.grey200,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _rating > 0 ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ] : null,
                ),
                child: Center(
                  child: Text(
                    'Submit Review',
                    style: TextStyle(
                      fontSize: isSmall ? 15 : 16,
                      fontWeight: FontWeight.w700,
                      color: _rating > 0 ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: isSmall ? 12 : 16),
            
            // Skip Button
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Skip Review',
                style: TextStyle(
                  fontSize: isSmall ? 13 : 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

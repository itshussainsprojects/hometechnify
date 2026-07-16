// Service Complete Screen - Final screen with payment, time, customer profile

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/date_formatter.dart';
import '../../booking/data/models/booking_model.dart';
import '../../booking/providers/booking_provider.dart';

class ServiceCompleteScreen extends StatefulWidget {
  final BookingModel booking;
  final int elapsedSeconds;

  const ServiceCompleteScreen({
    super.key,
    required this.booking,
    this.elapsedSeconds = 0,
  });

  @override
  State<ServiceCompleteScreen> createState() => _ServiceCompleteScreenState();
}

class _ServiceCompleteScreenState extends State<ServiceCompleteScreen> {
  bool _hasRated = false;
  double _selectedRating = 0;

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showRateCustomerDialog() {
    double tempRating = _selectedRating > 0 ? _selectedRating : 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Rate Customer', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.booking.customerName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              // Star rating row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starValue = (i + 1).toDouble();
                  return GestureDetector(
                    onTap: () => setDialogState(() => tempRating = starValue),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < tempRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 36,
                        color: AppColors.warning,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _ratingLabel(tempRating),
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: 'Leave a comment (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _submitRating(tempRating, commentController.text);
              },
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(double rating) {
    if (rating >= 5) return 'Excellent!';
    if (rating >= 4) return 'Very Good';
    if (rating >= 3) return 'Good';
    if (rating >= 2) return 'Fair';
    return 'Poor';
  }

  Future<void> _submitRating(double rating, String comment) async {
    try {
      final success = await context.read<BookingProvider>().rateBooking(
        widget.booking.id,
        rating,
        comment,
      );
      if (!mounted) return;
      if (success) {
        setState(() {
          _hasRated = true;
          _selectedRating = rating;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted! Thank you.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit rating: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildSuccessAnimation(isSmall),
              const SizedBox(height: 24),
              _buildCompletionMessage(isSmall),
              const SizedBox(height: 30),
              _buildPaymentCard(isSmall),
              const SizedBox(height: 20),
              _buildCustomerProfile(isSmall),
              const SizedBox(height: 20),
              _buildServiceSummary(isSmall),
              const SizedBox(height: 30),
              _buildDoneButton(context, horizontalPadding),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessAnimation(bool isSmall) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_circle_rounded,
        size: 80,
        color: AppColors.primaryBlue,
      ),
    ).animate()
      .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 500.ms, curve: Curves.elasticOut)
      .fadeIn(duration: 400.ms);
  }

  Widget _buildCompletionMessage(bool isSmall) {
    return Column(
      children: [
        Text(
          'Service Completed!',
          style: TextStyle(
            fontSize: isSmall ? 24 : 28,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Great job! The service has been\nsuccessfully completed.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildPaymentCard(bool isSmall) {
    final isCash = widget.booking.paymentStatus.toUpperCase() != 'PAID';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 16 : 20,
        vertical: isSmall ? 14 : 18,
      ),
      decoration: BoxDecoration(
        gradient: isCash
          ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
          : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isCash ? const Color(0xFFF59E0B) : AppColors.primaryBlue).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCash ? Icons.payments_rounded : Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: isSmall ? 18 : 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCash ? 'Collect Cash Payment' : 'Payment Received',
                style: TextStyle(
                  fontSize: isSmall ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 10 : 12),
          Text(
            'Rs. ${widget.booking.price}',
            style: TextStyle(
              fontSize: isSmall ? 28 : 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isSmall ? 8 : 10),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 12 : 14,
              vertical: isSmall ? 5 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCash ? Icons.handshake_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: isSmall ? 14 : 16,
                ),
                const SizedBox(width: 5),
                Text(
                  isCash ? 'Collect from Customer' : 'Added to Wallet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isSmall ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          if (isCash) ...[
            SizedBox(height: isSmall ? 8 : 10),
            Text(
              'Please collect cash from the customer',
              style: TextStyle(
                fontSize: isSmall ? 10 : 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildCustomerProfile(bool isSmall) {
    final name = widget.booking.customerName;
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.split(' ').map((e) => e[0]).take(2).join(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (_hasRated)
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 14,
                      color: AppColors.warning,
                    )),
                  )
                else
                  Text('Tap to rate this customer', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _hasRated ? null : _showRateCustomerDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _hasRated
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _hasRated
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.primaryBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _hasRated ? '✓ Rated' : 'Rate',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _hasRated ? AppColors.success : AppColors.primaryBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  Widget _buildServiceSummary(bool isSmall) {
    final duration = widget.elapsedSeconds > 0
        ? _formatTime(widget.elapsedSeconds)
        : '—';

    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Service', widget.booking.serviceName),
          Divider(height: 16, color: AppColors.grey100),
          _buildSummaryRow('Date', DateFormatter.formatDate(widget.booking.bookingDate)),
          Divider(height: 16, color: AppColors.grey100),
          _buildSummaryRow('Time', DateFormatter.formatTime(widget.booking.bookingDate)),
          Divider(height: 16, color: AppColors.grey100),
          _buildSummaryRow('Duration', duration),
          Divider(height: 16, color: AppColors.grey100),
          _buildSummaryRow('Location', widget.booking.address, isLong: true),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 500.ms);
  }

  Widget _buildSummaryRow(String label, String value, {bool isLong = false}) {
    return Row(
      crossAxisAlignment: isLong ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: isLong ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDoneButton(BuildContext context, double horizontalPadding) {
    return GestureDetector(
      onTap: () {
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.pushReplacementNamed(context, '/provider/dashboard');
      },
      child: Container(
        width: double.infinity,
        height: 54,
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
        child: const Center(
          child: Text(
            'Back to Dashboard',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 600.ms);
  }
}

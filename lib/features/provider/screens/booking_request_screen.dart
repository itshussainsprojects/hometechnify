// Booking Request Screen - Accept/Decline with customer profile & location

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/date_formatter.dart';
import '../../booking/providers/booking_provider.dart';
import '../../booking/data/models/booking_model.dart';

class BookingRequestScreen extends StatefulWidget {
  final BookingModel booking;
  
  const BookingRequestScreen({super.key, required this.booking});

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    final booking = widget.booking;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: Text('Booking Request', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomerProfile(booking, isSmall),
            const SizedBox(height: 20),
            _buildBookingDetails(booking, isSmall),
            const SizedBox(height: 20),
            _buildLocationCard(booking, isSmall),
            const SizedBox(height: 20),
            _buildPriceCard(booking, isSmall),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionButtons(horizontalPadding, booking),
    );
  }

  Widget _buildCustomerProfile(BookingModel booking, bool isSmall) {
    final name = booking.customerName;
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.split(' ').map((e) => e[0]).take(2).join(),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Name
          Text(
            name,
            style: TextStyle(fontSize: isSmall ? 18 : 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _buildContactButton(Icons.phone_rounded, 'Call', () {
            Navigator.pushNamed(context, '/voice-call', arguments: {
              'name': name,
            });
          }),

        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildContactButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingDetails(BookingModel booking, bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Booking Details', style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(isSmall ? 14 : 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            children: [
              _buildDetailRow('Service', booking.serviceName, Icons.build_rounded),
              Divider(height: 20, color: AppColors.grey100),
              _buildDetailRow('Date', DateFormatter.formatDate(booking.bookingDate), Icons.calendar_today_rounded),
              Divider(height: 20, color: AppColors.grey100),
              _buildDetailRow('Time', DateFormatter.formatTime(booking.bookingDate), Icons.access_time_rounded),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLocationCard(BookingModel booking, bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Customer Location', style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(isSmall ? 14 : 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking.address, 
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildPriceCard(BookingModel booking, bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service Price',
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs. ${booking.price}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildActionButtons(double horizontalPadding, BookingModel booking) {
    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Decline button
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : () => _handleDecline(booking),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text('Decline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.error)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Accept button
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _isLoading ? null : () => _handleAccept(booking),
                child: Container(
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
                  child: Center(
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Accept', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDecline(BookingModel booking) async {
    setState(() => _isLoading = true);
    try {
      // 'REJECTED' is not a booking status at all — the enum is
      // PENDING / NEGOTIATING / ACCEPTED / ONGOING / COMPLETED / CANCELLED —
      // so this call was blowing up on the server every time a provider
      // declined a request.
      final result = await context.read<BookingProvider>()
          .updateBookingStatus(booking.id, 'CANCELLED');
      if (!mounted) return;
      if (result.isSuccess) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error?.message ?? 'Failed to decline booking'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAccept(BookingModel booking) async {
    setState(() => _isLoading = true);
    try {
        // Accepting MUST go through accept-offer. Writing status='ACCEPTED'
        // directly skipped every guard behind it: no start OTP was minted (so the
        // work lock could never be opened), the job post stayed OPEN for other
        // providers to keep quoting on, competing bids were never cancelled, and
        // the "one job at a time" rule never ran.
        final bookingProvider = context.read<BookingProvider>();
        final ok = await bookingProvider.acceptOffer(booking.id);

        if (!mounted) return;

        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking Accepted! Starting job...'),
              backgroundColor: AppColors.success,
            )
          );

          // Pop back to dashboard then push ongoing screen
          Navigator.pop(context);
          Navigator.pushNamed(
            context,
            '/provider/ongoing',
            arguments: {'bookingId': booking.id},
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // e.g. "You already have an active job. Complete it first."
              content: Text(bookingProvider.errorMessage ?? 'Failed to accept booking'),
              backgroundColor: AppColors.error,
            )
          );
        }

    } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          )
        );
    } finally {
        if (mounted) setState(() => _isLoading = false);
    }
  }
}

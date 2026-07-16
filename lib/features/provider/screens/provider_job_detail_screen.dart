// Provider Job Detail Screen - Provider sees job details and sets their rate
// Shows job media, description, customer info, and price input

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/marketplace_controller.dart';
import '../widgets/insufficient_funds_dialog.dart';

class ProviderJobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> jobData;

  const ProviderJobDetailScreen({
    super.key,
    required this.jobData,
  });

  @override
  State<ProviderJobDetailScreen> createState() => _ProviderJobDetailScreenState();
}

class _ProviderJobDetailScreenState extends State<ProviderJobDetailScreen> {
  final _priceController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _submitQuote() {
    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final price = double.tryParse(_priceController.text) ?? 0;
    final commission = marketplaceController.calculateCommission(price);
    
    // Check wallet balance before accepting
    if (!marketplaceController.canAcceptJob('p1', price)) {
      InsufficientFundsDialog.show(
        context,
        currentBalance: marketplaceController.balance('p1'),
        requiredCommission: commission,
        shortfall: marketplaceController.getShortfall('p1', price),
        serviceName: widget.jobData['serviceName'],
        onAddFunds: () {
          Navigator.pushNamed(context, '/provider/wallet');
        },
      );
      return;
    }

    setState(() => _isSubmitting = true);
    
    // Deduct commission from wallet
    final jobId = 'JOB${DateTime.now().millisecondsSinceEpoch}';
    final result = marketplaceController.acceptJob(
      providerId: 'p1',
      jobPrice: price,
      jobId: jobId,
      serviceName: widget.jobData['serviceName'],
      customerName: widget.jobData['customerName'],
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (result.success) {
          _showSuccessDialog(commission);
        }
      }
    });
  }

  void _showSuccessDialog(double commission) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Quote Sent!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your quote of Rs.${_priceController.text} has been sent to the customer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Commission breakdown
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Commission Deducted:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text('Rs. ${commission.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('New Balance:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Text(marketplaceController.getFormattedBalance('p1'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Jobs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _declineJob() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Decline Job?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        content: const Text(
          'Are you sure you want to decline this job request?',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.grey300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Job declined successfully'),
                        backgroundColor: AppColors.primaryBlue,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Decline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    // Sample job data
    final serviceName = widget.jobData['serviceName'] ?? 'Plumber';
    final customerName = widget.jobData['customerName'] ?? 'Ahmed Ali';
    final distance = widget.jobData['distance'] ?? '1.5 km';
    final description = widget.jobData['description'] ?? 'Need to fix a leaking pipe in the kitchen. The pipe is under the sink and has been leaking for 2 days.';
    final mediaType = widget.jobData['mediaType'] ?? 'image';
    final postedTime = widget.jobData['postedTime'] ?? '5 min ago';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.08),
              Colors.white,
              AppColors.primaryBlue.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(horizontalPadding, isSmall),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: isSmall ? 16 : 24),
                      _buildCustomerInfo(customerName, serviceName, distance, postedTime, isSmall),
                      SizedBox(height: isSmall ? 16 : 20),
                      _buildMediaSection(mediaType, isSmall),
                      SizedBox(height: isSmall ? 16 : 20),
                      _buildDescription(description, isSmall),
                      SizedBox(height: isSmall ? 20 : 28),
                      _buildPriceInput(isSmall),
                      SizedBox(height: isSmall ? 20 : 28),
                      _buildActionButtons(isSmall),
                      SizedBox(height: isSmall ? 24 : 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(double horizontalPadding, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isSmall ? 12 : 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: isSmall ? 44 : 48,
              height: isSmall ? 44 : 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.grey200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: isSmall ? 20 : 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Job Request',
              style: TextStyle(
                fontSize: isSmall ? 20 : 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: AppColors.primaryBlue, size: 8),
                SizedBox(width: 6),
                Text(
                  'New',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildCustomerInfo(String name, String service, String distance, String time, bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isSmall ? 26 : 30,
            backgroundColor: AppColors.primaryBlue,
            child: Text(
              name[0],
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmall ? 20 : 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: isSmall ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: AppColors.primaryBlue, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      distance,
                      style: TextStyle(
                        fontSize: isSmall ? 12 : 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time_rounded, color: AppColors.grey400, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: isSmall ? 12 : 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/chat', arguments: {
              'name': name,
              'service': service,
            }),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildMediaSection(String mediaType, bool isSmall) {
    // Handle no media case
    if (mediaType == 'none' || mediaType.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attached Media',
            style: TextStyle(
              fontSize: isSmall ? 15 : 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.attach_file_rounded, color: AppColors.textTertiary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'No media attached - Check description',
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 14,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
    }

    IconData mediaIcon;
    String mediaLabel;
    Color mediaColor;

    switch (mediaType) {
      case 'video':
        mediaIcon = Icons.videocam_rounded;
        mediaLabel = 'Video attached';
        mediaColor = AppColors.primaryBlue;
        break;
      case 'voice':
        mediaIcon = Icons.mic_rounded;
        mediaLabel = 'Voice message';
        mediaColor = AppColors.primaryDark;
        break;
      default:
        mediaIcon = Icons.photo_rounded;
        mediaLabel = 'Photo attached';
        mediaColor = AppColors.primaryLight;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attached Media',
          style: TextStyle(
            fontSize: isSmall ? 15 : 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: isSmall ? 160 : 180,
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: mediaColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(mediaIcon, color: mediaColor, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  mediaLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: mediaColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mediaType == 'video' ? Icons.play_arrow_rounded : Icons.visibility_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mediaType == 'video' ? 'Play Video' : 'View',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildDescription(String description, bool isSmall) {
    final hasDescription = description.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Job Description',
          style: TextStyle(
            fontSize: isSmall ? 15 : 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasDescription ? Colors.white : AppColors.primaryBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: hasDescription ? AppColors.grey200 : AppColors.primaryBlue.withValues(alpha: 0.2)),
          ),
          child: hasDescription 
            ? Text(
                description,
                style: TextStyle(
                  fontSize: isSmall ? 14 : 15,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              )
            : Row(
                children: [
                  Icon(Icons.videocam_rounded, color: AppColors.primaryBlue, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No description provided - Check attached media',
                      style: TextStyle(
                        fontSize: isSmall ? 13 : 14,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 250.ms);
  }

  Widget _buildPriceInput(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Quote',
          style: TextStyle(
            fontSize: isSmall ? 15 : 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryBlue, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  'Rs.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.grey300,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the amount you want to charge for this job',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildActionButtons(bool isSmall) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _declineJob,
            child: Container(
              height: isSmall ? 52 : 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: const Center(
                child: Text(
                  'Decline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _isSubmitting ? null : _submitQuote,
            child: Container(
              height: isSmall ? 52 : 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Send Quote',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 350.ms).slideY(begin: 0.1, end: 0);
  }
}

// Set Price Screen - Provider sets their price for job

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/theme/neu_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../job/data/models/job_post_model.dart';
import '../../job/providers/job_post_provider.dart';
import '../providers/provider_controller.dart';
import 'package:provider/provider.dart';

class SetPriceScreen extends StatefulWidget {
  final JobPostModel job;
  
  const SetPriceScreen({super.key, required this.job});

  @override
  State<SetPriceScreen> createState() => _SetPriceScreenState();
}

class _SetPriceScreenState extends State<SetPriceScreen> {
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  // Live admin-set commission rate and wallet balance. `watch` (not `read`) so
  // the screen re-renders the moment a top-up lands — reading them once meant a
  // provider who topped up still saw the old balance here.
  double get _commissionRate =>
      context.watch<ProviderController>().commissionRate.clamp(0.0, 1.0);
  int get _commissionPct =>
      context.watch<ProviderController>().commissionPercent.round();
  double get _walletBalance => context.watch<ProviderController>().walletBalance;

  double get _enteredPrice => double.tryParse(_priceController.text) ?? 0;
  double get _commission => _enteredPrice * _commissionRate;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(() => setState(() {}));
    // Pull a fresh balance + commission on open: the provider may have topped up
    // on another screen since the dashboard last loaded.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProviderController>().fetchDashboardStats();
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    final job = widget.job;

    return Scaffold(
      backgroundColor: NeuTheme.bg,
      appBar: AppBar(
        backgroundColor: NeuTheme.bg,
        surfaceTintColor: NeuTheme.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: const Text('Set Your Price', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildJobSummary(job, isSmall),
            const SizedBox(height: 30),
            _buildPriceInput(isSmall),
            const SizedBox(height: 16),
            _buildCommissionSummary(isSmall),
            const SizedBox(height: 24),
            _buildNoteInput(isSmall),
            const SizedBox(height: 20),
            _buildSuggestedPrices(isSmall),
          ],
        ),
      ),
      bottomNavigationBar: _buildSubmitButton(horizontalPadding, job),
    );
  }

  Widget _buildJobSummary(JobPostModel job, bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(12),
              image: job.mediaUrls.isNotEmpty
                  ? DecorationImage(image: NetworkImage(job.mediaUrls.first), fit: BoxFit.cover)
                  : null,
            ),
            child: job.mediaUrls.isEmpty ? Center(
              child: Text(
                job.customerId.split(' ').map((e) => e[0]).take(2).join(),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer ${job.customerId.substring(0, 4)}', style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(job.title, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(job.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildPriceInput(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Price',
          style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryBlue, width: 2),
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
                child: Text(
                  'Rs. ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: AppColors.grey300, fontSize: 28, fontWeight: FontWeight.w700),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildCommissionSummary(bool isSmall) {
    final walletBalance = _walletBalance;
    final commission = _commission;
    final hasEnough = walletBalance >= commission;

    return AnimatedOpacity(
      opacity: _enteredPrice > 0 ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: EdgeInsets.all(isSmall ? 14 : 16),
        decoration: BoxDecoration(
          color: hasEnough
              ? AppColors.success.withValues(alpha: 0.06)
              : AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasEnough
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            _summaryRow(
              'Platform Commission ($_commissionPct%)',
              'Rs. ${commission.toStringAsFixed(0)}',
              AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            _summaryRow(
              'Your Wallet Balance',
              'Rs. ${walletBalance.toStringAsFixed(0)}',
              hasEnough ? AppColors.success : AppColors.error,
            ),
            const Divider(height: 20),
            _summaryRow(
              'You Receive',
              'Rs. ${(_enteredPrice - commission).toStringAsFixed(0)}',
              AppColors.primaryBlue,
              bold: true,
            ),
            if (!hasEnough && _enteredPrice > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Insufficient balance. Add Rs. ${(commission - walletBalance).toStringAsFixed(0)} to your wallet.',
                      style: TextStyle(
                        fontSize: isSmall ? 11 : 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _summaryRow(String label, String value, Color valueColor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildNoteInput(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Note (Optional)',
          style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey200),
          ),
          child: TextField(
            controller: _noteController,
            maxLines: 3,
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Add any notes about your service...',
              hintStyle: TextStyle(color: AppColors.textHint),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }

  Widget _buildSuggestedPrices(bool isSmall) {
    final suggestedPrices = ['500', '1000', '1500', '2000', '2500'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Select',
          style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: suggestedPrices.map((price) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _priceController.text = price;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _priceController.text == price 
                      ? AppColors.primaryBlue 
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _priceController.text == price 
                        ? AppColors.primaryBlue 
                        : AppColors.grey200,
                  ),
                ),
                child: Text(
                  'Rs. $price',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _priceController.text == price 
                        ? Colors.white 
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildSubmitButton(double horizontalPadding, JobPostModel job) {
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
        child: GestureDetector(
          onTap: _isSubmitting ? null : () async {
            if (_priceController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter your price'), backgroundColor: AppColors.error),
              );
              return;
            }

            final price = _enteredPrice;
            final commission = price * _commissionRate;
            final walletBalance = _walletBalance;

            if (walletBalance < commission) {
              _showInsufficientFundsDialog(walletBalance, commission);
              return;
            }

            setState(() => _isSubmitting = true);

            final success = await context.read<JobPostProvider>().acceptJob(job.id, _priceController.text);

            setState(() => _isSubmitting = false);

            if (!mounted) return;

            if (success) {
              context.read<ProviderController>().fetchDashboardStats();
              _showPriceSubmittedDialog();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.read<JobPostProvider>().errorMessage ?? 'Failed to submit offer'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
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
              child: _isSubmitting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text(
                  'Submit Offer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInsufficientFundsDialog(double balance, double required) {
    final shortfall = required - balance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.error, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Insufficient Balance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _dialogRow('Commission Required', 'Rs. ${required.toStringAsFixed(0)}', AppColors.textPrimary),
                  const SizedBox(height: 8),
                  _dialogRow('Your Balance', 'Rs. ${balance.toStringAsFixed(0)}', AppColors.error),
                  const Divider(height: 16),
                  _dialogRow('Top Up Needed', 'Rs. ${shortfall.toStringAsFixed(0)}', AppColors.primaryBlue, bold: true),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add at least Rs. ${shortfall.toStringAsFixed(0)} to your wallet to submit this offer.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/provider/wallet');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Top Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogRow(String label, String value, Color valueColor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showPriceSubmittedDialog() {
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
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 50),
            ),
            const SizedBox(height: 20),
            const Text(
              'Offer Sent!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Your offer of Rs. ${_priceController.text} has been sent to the customer. Waiting for their response.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context); // Close dialog
                Navigator.popUntil(context, (route) => route.isFirst);
                Navigator.pushReplacementNamed(context, '/provider/dashboard');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('Back to Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

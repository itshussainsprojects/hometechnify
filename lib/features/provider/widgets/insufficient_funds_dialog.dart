// Insufficient Funds Dialog - Premium dialog for wallet balance check
// Shows when provider tries to accept job but balance is too low

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';

class InsufficientFundsDialog extends StatelessWidget {
  final double currentBalance;
  final double requiredCommission;
  final double shortfall;
  final String? serviceName;
  final VoidCallback onAddFunds;
  final VoidCallback onCancel;

  const InsufficientFundsDialog({
    super.key,
    required this.currentBalance,
    required this.requiredCommission,
    required this.shortfall,
    this.serviceName,
    required this.onAddFunds,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.warning,
                size: 36,
              ),
            ).animate().scale(
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Insufficient Funds',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 12),

            // Message
            Text(
              'Your balance is too low to accept this job. Please add funds to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 24),

            // Balance Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Column(
                children: [
                  _buildBalanceRow(
                    'Current Balance',
                    'Rs. ${currentBalance.toStringAsFixed(0)}',
                    AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  _buildBalanceRow(
                    'Required Commission',
                    'Rs. ${requiredCommission.toStringAsFixed(0)}',
                    AppColors.textSecondary,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  _buildBalanceRow(
                    'Add at least',
                    'Rs. ${shortfall.toStringAsFixed(0)}',
                    AppColors.error,
                    isBold: true,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                // Cancel Button
                Expanded(
                  child: GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Add Funds Button
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: onAddFunds,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Add Funds',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ).animate().scale(
            duration: 300.ms,
            curve: Curves.easeOutBack,
          ),
    );
  }

  Widget _buildBalanceRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            color: valueColor,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Show the dialog as a static method
  static Future<bool?> show(
    BuildContext context, {
    required double currentBalance,
    required double requiredCommission,
    required double shortfall,
    String? serviceName,
    required VoidCallback onAddFunds,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.black.withValues(alpha: 0.5),
      builder: (context) => InsufficientFundsDialog(
        currentBalance: currentBalance,
        requiredCommission: requiredCommission,
        shortfall: shortfall,
        serviceName: serviceName,
        onAddFunds: () {
          Navigator.pop(context, true);
          onAddFunds();
        },
        onCancel: () => Navigator.pop(context, false),
      ),
    );
  }
}

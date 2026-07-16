import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../providers/provider_controller.dart';

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderController>().fetchWalletHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF4),
      appBar: AppBar(
        title: const Text('Wallet History', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<ProviderController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage != null) {
            return Center(child: Text(controller.errorMessage!, style: const TextStyle(color: AppColors.error)));
          }

          if (controller.walletHistory.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: controller.walletHistory.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final transaction = controller.walletHistory[index];
              return _buildTransactionCard(transaction)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (50 * index).ms)
                  .slideX(begin: 0.1);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, size: 60, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 20),
          const Text('No Transactions Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Completed jobs will appear here.', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildTransactionCard(dynamic transaction) {
    // Handling potential nulls safely
    final serviceName = transaction['service']?['name'] ?? 'Service';
    final customerName = transaction['customer']?['name'] ?? 'Customer';
    // Handle total_amount as either num or String (Prisma Decimal returns String)
    final rawAmount = transaction['total_amount'];
    final amount = rawAmount is num 
        ? rawAmount.toDouble() 
        : (rawAmount is String ? double.tryParse(rawAmount) ?? 0.0 : 0.0);
    final dateStr = transaction['updated_at'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : DateTime.now();
    final formattedDate = date != null ? DateFormat('MMM d, y • h:mm a').format(date) : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  customerName,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                if (formattedDate.isNotEmpty)
                  Text(
                    formattedDate,
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+ PKR ${amount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

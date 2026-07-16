// Provider Earnings Screen - Wired to Real API Data

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../../core/theme/neu_theme.dart';
import '../../../core/utils/responsive.dart';
import '../providers/provider_controller.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  @override
  void initState() {
    super.initState();
    final controller = context.read<ProviderController>();
    controller.fetchDashboardStats();
    controller.fetchWalletHistory();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

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
        title: const Text('My Earnings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: Consumer<ProviderController>(
        builder: (context, controller, child) {
          final stats = controller.dashboardStats;
          final walletHistory = controller.walletHistory;
          final isLoading = controller.isLoading && stats.isEmpty;

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final totalEarnings = (stats['totalEarnings'] ?? 0).toDouble();

          // Calculate "today" and "this week" from wallet history
          final now = DateTime.now();
          double todayEarnings = 0;
          double weekEarnings = 0;

          for (final booking in walletHistory) {
            final updatedAt = booking['updated_at'] ?? booking['updatedAt'];
            if (updatedAt == null) continue;
            final date = updatedAt is String ? DateTime.tryParse(updatedAt) : null;
            if (date == null) continue;
            final amount = (booking['total_amount'] ?? booking['totalAmount'] ?? 0).toDouble();

            if (date.year == now.year && date.month == now.month && date.day == now.day) {
              todayEarnings += amount;
            }
            if (now.difference(date).inDays < 7) {
              weekEarnings += amount;
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              await controller.fetchDashboardStats();
              await controller.fetchWalletHistory();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTotalEarnings(isSmall, totalEarnings),
                  const SizedBox(height: 24),
                  _buildPeriodStats(isSmall, todayEarnings, weekEarnings),
                  const SizedBox(height: 24),
                  _buildEarningsList(isSmall, walletHistory),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalEarnings(bool isSmall, double total) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 20 : 24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Total Earnings',
                style: TextStyle(
                  fontSize: isSmall ? 14 : 15,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Rs. ${NumberFormat('#,##0').format(total)}',
            style: TextStyle(
              fontSize: isSmall ? 32 : 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All Time',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPeriodStats(bool isSmall, double today, double week) {
    return Row(
      children: [
        Expanded(
          child: _buildPeriodCard('Today', 'Rs. ${NumberFormat('#,##0').format(today)}', Icons.today_rounded, isSmall),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPeriodCard('This Week', 'Rs. ${NumberFormat('#,##0').format(week)}', Icons.date_range_rounded, isSmall),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildPeriodCard(String period, String amount, IconData icon, bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const SizedBox(width: 10),
              Text(
                period,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: TextStyle(
              fontSize: isSmall ? 18 : 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsList(bool isSmall, List<dynamic> history) {
    if (history.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Earnings', style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long_rounded, size: 60, color: AppColors.grey300),
                const SizedBox(height: 12),
                Text('No earnings yet', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Earnings',
          style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildEarningItem(history[index], isSmall),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildEarningItem(dynamic booking, bool isSmall) {
    final serviceName = booking['service']?['name'] ?? 'Service';
    final customerName = booking['customer']?['name'] ?? 'Customer';
    final amount = (booking['total_amount'] ?? booking['totalAmount'] ?? 0).toDouble();
    final updatedAt = booking['updated_at'] ?? booking['updatedAt'] ?? '';
    final date = updatedAt is String ? DateTime.tryParse(updatedAt) : null;
    final dateStr = date != null ? DateFormat('dd MMM yyyy').format(date) : '';

    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(serviceName, style: TextStyle(fontSize: isSmall ? 14 : 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(customerName, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs. ${NumberFormat('#,##0').format(amount)}',
                style: TextStyle(
                  fontSize: isSmall ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 2),
              Text(dateStr, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// Provider Wallet Screen - Balance, Commission, TopUp, Withdraw
// With pending commission, pay commission button, and commission history

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/neu_theme.dart';
import '../providers/provider_controller.dart';

class ProviderWalletScreen extends StatefulWidget {
  const ProviderWalletScreen({super.key});

  @override
  State<ProviderWalletScreen> createState() => _ProviderWalletScreenState();
}

class _ProviderWalletScreenState extends State<ProviderWalletScreen> with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderController>().fetchWalletHistory();
      context.read<ProviderController>().fetchDashboardStats();
      context.read<ProviderController>().fetchActiveBookings();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    final providerController = context.watch<ProviderController>();
    final provider = providerController.selectedProvider;
    // Balance comes from dashboard stats (always fetched on this screen);
    // selectedProvider is only a fallback and is often null here.
    final walletBalance = double.tryParse(
            providerController.dashboardStats['walletBalance']?.toString() ??
                '') ??
        provider?.walletBalance ??
        0.0;
    final totalEarnings = providerController.dashboardStats['totalEarnings'] ?? 0.0;
    
    // Transform wallet history to transaction list
    final transactions = providerController.walletHistory.map((booking) {
      final dateStr = booking['updated_at'] as String?;
      final date = dateStr != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr)) : 'Unknown';
      final rawAmount = booking['total_amount'];
      final amount = rawAmount is num ? rawAmount.toDouble() : double.tryParse(rawAmount.toString()) ?? 0.0;
      return {
        'title': booking['service']?['name'] ?? 'Service',
        'date': date,
        'amount': amount,
        'type': 'credit',
      };
    }).toList();

    // Pending commission from active bookings (via /providers/bookings/active API)
    final pendingCommission = providerController.pendingCommission;

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
        title: const Text('My Wallet', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(isSmall, walletBalance, totalEarnings),
            const SizedBox(height: 16),
            // Pending Commission is hardcoded for now or 0
            _buildPendingCommissionCard(isSmall, pendingCommission),
            const SizedBox(height: 16),
            _buildQuickActions(isSmall),
            const SizedBox(height: 20),
            _buildHistoryTabs(isSmall, transactions),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(bool isSmall, double balance, dynamic earnings) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Available Balance',
                style: TextStyle(fontSize: isSmall ? 13 : 14, color: Colors.white.withValues(alpha: 0.9)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Lifetime',
                  style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'PKR ${balance.toStringAsFixed(0)}',
            style: TextStyle(fontSize: isSmall ? 28 : 32, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Total Earnings: PKR ${earnings.toString()}',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPendingCommissionCard(bool isSmall, double pendingCommission) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        gradient: AppColors.blueBlackGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isSmall ? 44 : 48,
            height: isSmall ? 44 : 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.pending_actions_rounded, color: Colors.white, size: isSmall ? 22 : 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Commission',
                  style: TextStyle(fontSize: isSmall ? 12 : 13, color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 3),
                Text(
                  'PKR ${pendingCommission.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: isSmall ? 20 : 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showPayCommissionDialog(pendingCommission),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 14 : 16, vertical: isSmall ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Pay Now',
                style: TextStyle(
                  fontSize: isSmall ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildQuickActions(bool isSmall) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showTopUpDialog(),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: isSmall ? 14 : 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue),
              ),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add_rounded, color: AppColors.primaryBlue, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text('Top Up', style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _showWithdrawDialog(),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: isSmall ? 14 : 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.arrow_upward_rounded, color: AppColors.primaryLight, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text('Withdraw', style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }

  Widget _buildHistoryTabs(bool isSmall, List<Map<String, dynamic>> transactions) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            indicator: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Transactions'),
              Tab(text: 'Commission'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 320,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionList(isSmall, transactions),
              _buildCommissionList(isSmall), // Still hardcoded or using empty
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildTransactionList(bool isSmall, List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) {
        return const Center(child: Text("No transactions yet"));
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey100),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: transactions.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.grey100),
        itemBuilder: (context, index) {
          final txn = transactions[index];
          final type = txn['type'];
          final isCredit = type == 'credit';
          final isPending = type == 'pending';
          
          Color displayColor;
          IconData displayIcon;
          
          if (isPending) {
            displayColor = AppColors.warning; 
            displayIcon = Icons.access_time_rounded;
          } else if (isCredit) {
            displayColor = AppColors.primaryBlue;
            displayIcon = Icons.arrow_downward_rounded;
          } else {
            displayColor = AppColors.error;
            displayIcon = Icons.arrow_upward_rounded;
          }

          return Padding(
            padding: EdgeInsets.all(isSmall ? 12 : 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: displayColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    displayIcon,
                    color: displayColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(txn['title'], style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isPending) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: displayColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('PENDING', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: displayColor)),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(txn['date'], style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isPending ? '' : (isCredit ? '+' : '-')} PKR ${txn['amount']}',
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: isPending ? displayColor : (isCredit ? AppColors.primaryBlue : AppColors.error),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommissionList(bool isSmall) {
    // The REAL ledger. This used to re-derive commission from completed bookings
    // at a hardcoded 10%, so it disagreed with the admin-set rate the backend
    // actually charged. These rows carry the amount that left the wallet.
    final commissions = context
        .watch<ProviderController>()
        .transactions
        .where((t) => t['type'] == 'COMMISSION')
        .toList();

    if (commissions.isEmpty) {
      return const Center(
        child: Text('No commission history yet', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final entries = commissions.map((t) {
      final raw = t['amount'];
      final commission = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.0;
      final dateStr = t['created_at'] as String?;
      final date = dateStr != null
          ? DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr).toLocal())
          : 'Unknown';
      return {
        // e.g. "Commission 12% of Rs. 1500 (booking abc...)" — written by the
        // backend at the moment it charged, so it can never drift.
        'detail': (t['response_message'] as String?) ?? 'Commission',
        'date': date,
        'commission': commission,
      };
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey100),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: entries.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.grey100),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Padding(
            padding: EdgeInsets.all(isSmall ? 12 : 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.percent_rounded, color: AppColors.warning, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['detail'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry['date'] as String,
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '- Rs. ${(entry['commission'] as double).toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPayCommissionDialog(double pendingCommission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.payment_rounded, color: AppColors.primaryBlue),
            const SizedBox(width: 10),
            const Text('Pay Commission', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount Due', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('PKR ${pendingCommission.toStringAsFixed(0)}', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryBlue)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Payment Method', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildPaymentOption(Icons.account_balance_wallet_rounded, 'Wallet', AppColors.primaryBlue),
            const SizedBox(height: 8),
            _buildPaymentOption(Icons.phone_android_rounded, 'Easypaisa', const Color(0xFF00A651)),
            const SizedBox(height: 8),
            _buildPaymentOption(Icons.phone_android_rounded, 'JazzCash', const Color(0xFFE30613)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment integration coming soon')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  void _showTopUpDialog() {
    _amountController.clear();
    String selectedMethod = 'JazzCash';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.add_card_rounded, color: AppColors.primaryBlue),
              const SizedBox(width: 10),
              const Text('Top Up Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (PKR)',
                  prefixText: 'Rs. ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(height: 8),
              ...['JazzCash', 'Easypaisa'].map((method) {
                final isSelected = selectedMethod == method;
                return GestureDetector(
                  onTap: () => setDialogState(() => selectedMethod = method),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.primaryBlue : AppColors.grey200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_android_rounded, color: method == 'JazzCash' ? const Color(0xFFE30613) : const Color(0xFF00A651)),
                        const SizedBox(width: 12),
                        Text(method, style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (isSelected) Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final amount = double.tryParse(_amountController.text);
                if (amount == null || amount < 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Minimum top-up is Rs. 100')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                // DEV MOCK: credits instantly (no payment gateway yet) so
                // the job flow can be tested end to end.
                final newBalance = await context
                    .read<ProviderController>()
                    .topUpWallet(amount, selectedMethod.toUpperCase());
                if (!mounted) return;
                if (newBalance != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Rs. ${amount.toStringAsFixed(0)} added via $selectedMethod — Balance: Rs. ${newBalance.toStringAsFixed(0)}'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Top-up failed. Please try again.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Top Up', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawDialog() {
    _amountController.clear();
    final accountController = TextEditingController();
    String selectedMethod = 'JazzCash';

    // Pre-fill bank details if available
    final provider = context.read<ProviderController>().selectedProvider;
    if (provider?.accountNumber != null) {
      accountController.text = provider!.accountNumber!;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.arrow_upward_rounded, color: AppColors.primaryLight),
              const SizedBox(width: 10),
              const Text('Withdraw Funds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (PKR)',
                  prefixText: 'Rs. ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  helperText: 'Minimum Rs. 100',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Account Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Withdraw To', style: TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(height: 8),
              ...['JazzCash', 'Easypaisa', 'Bank Transfer'].map((method) {
                final isSelected = selectedMethod == method;
                return GestureDetector(
                  onTap: () => setDialogState(() => selectedMethod = method),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.primaryBlue : AppColors.grey200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          method == 'Bank Transfer' ? Icons.account_balance_rounded : Icons.phone_android_rounded,
                          color: method == 'JazzCash' ? const Color(0xFFE30613) : (method == 'Easypaisa' ? const Color(0xFF00A651) : AppColors.primaryBlue),
                        ),
                        const SizedBox(width: 12),
                        Text(method, style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (isSelected) Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final amount = double.tryParse(_amountController.text);
                final accNo = accountController.text.trim();

                if (amount == null || amount < 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Minimum withdrawal is Rs. 100')),
                  );
                  return;
                }
                if (accNo.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter account number')),
                  );
                  return;
                }

                Navigator.pop(ctx);

                final result = await context.read<ProviderController>().requestWithdrawal({
                  'amount': amount,
                  'payment_method': selectedMethod,
                  'account_number': accNo,
                });

                if (mounted) {
                  final success = result['success'] == true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? (success ? 'Withdrawal requested' : 'Failed')),
                      backgroundColor: success ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Withdraw', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  Map<String, dynamic>? _finance;
  Map<String, dynamic>? _settings; // commission_percent + provider_radius_km
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await adminApiService.fetchFinanceStats();
      Map<String, dynamic>? settings;
      try { settings = await adminApiService.fetchPlatformSettings(); } catch (_) {}
      setState(() { _finance = data; _settings = settings; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Edit commission % or search radius. Saving broadcasts to every provider
  // live — commission applies on their next job completion automatically.
  Future<void> _editSetting({required bool isCommission}) async {
    final current = isCommission
        ? (_settings?['commission_percent'] as num?)?.toDouble() ?? 12
        : (_settings?['provider_radius_km'] as num?)?.toDouble() ?? 20;
    final controller = TextEditingController(text: current.toStringAsFixed(0));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCommission ? 'Commission (%)' : 'Provider Search Radius (km)'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            suffixText: isCommission ? '%' : 'km',
            helperText: isCommission
                ? 'Deducted from every provider\'s wallet per completed job (0–50)'
                : 'Customers only see providers within this distance (1–200)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null) return;
    final min = isCommission ? 0.0 : 1.0;
    final max = isCommission ? 50.0 : 200.0;
    if (value < min || value > max) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Value must be between ${min.toInt()} and ${max.toInt()}'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    final ok = await adminApiService.setPlatformSettings(
      commissionPercent: isCommission ? value : null,
      providerRadiusKm: isCommission ? null : value,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _settings ??= {};
        _settings![isCommission ? 'commission_percent' : 'provider_radius_km'] = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isCommission
            ? 'Commission set to ${value.toStringAsFixed(0)}% — applies to ALL providers now'
            : 'Search radius set to ${value.toStringAsFixed(0)} km — applies to all searches now'),
        backgroundColor: AppColors.success,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to update setting'), backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_finance == null) return const Center(child: Text('Failed to load finance data'));

    final totalRevenue = (_finance!['totalRevenue'] as num).toDouble();
    final totalWithdrawn = (_finance!['totalWithdrawn'] as num).toDouble();
    final netRevenue = (_finance!['netRevenue'] as num).toDouble();
    final pendingWithdrawals = (_finance!['pendingWithdrawals'] as List?) ?? [];
    final recentTransactions = (_finance!['recentTransactions'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Stat cards
        Row(children: [
          Expanded(child: _statCard('Total Revenue', 'Rs. ${totalRevenue.toStringAsFixed(0)}', Icons.trending_up_rounded, AppColors.success)),
          const SizedBox(width: 16),
          Expanded(child: _statCard('Total Paid Out', 'Rs. ${totalWithdrawn.toStringAsFixed(0)}', Icons.payments_outlined, AppColors.warning)),
          const SizedBox(width: 16),
          Expanded(child: _statCard('Net Revenue', 'Rs. ${netRevenue.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded, AppColors.primaryBlue)),
        ]).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
        const SizedBox(height: 24),
        // Platform settings — live commission % + provider search radius
        const Text('Platform Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _settingCard(
            'Commission',
            '${((_settings?['commission_percent'] as num?)?.toDouble() ?? 12).toStringAsFixed(0)}%',
            'Per completed job, all providers',
            Icons.percent_rounded,
            AppColors.primaryBlue,
            () => _editSetting(isCommission: true),
          )),
          const SizedBox(width: 16),
          Expanded(child: _settingCard(
            'Search Radius',
            '${((_settings?['provider_radius_km'] as num?)?.toDouble() ?? 20).toStringAsFixed(0)} km',
            'Nearby providers only (inDrive-style)',
            Icons.radar_rounded,
            AppColors.success,
            () => _editSetting(isCommission: false),
          )),
        ]).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
        const SizedBox(height: 32),
        // Pending withdrawals
        if (pendingWithdrawals.isNotEmpty) ...[
          const Text('Pending Withdrawals', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...pendingWithdrawals.map((w) {
            final p = w['provider'] as Map<String, dynamic>?;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p?['name'] ?? 'Provider', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${w['payment_method']} • ${w['account_number']}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ])),
                Text('Rs. ${(w['amount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.warning)),
              ]),
            );
          }),
          const SizedBox(height: 24),
        ],
        // Recent transactions
        const Text('Recent Transactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...recentTransactions.take(15).map((t) {
          final type = t['type'] as String? ?? '';
          final user = t['user'] as Map<String, dynamic>?;
          final date = DateTime.tryParse(t['created_at'] ?? '') ?? DateTime.now();
          final isCredit = type == 'PAYMENT';
          final amount = (t['amount'] as num).toDouble();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey100),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isCredit ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: isCredit ? AppColors.success : AppColors.error, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(type, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(user?['name'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${isCredit ? "+" : "-"}Rs. ${amount.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: isCredit ? AppColors.success : AppColors.error)),
                Text('${date.day}/${date.month}/${date.year}', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
              ]),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _settingCard(String label, String value, String hint, IconData icon, Color color, VoidCallback onEdit) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
            Text(hint, style: TextStyle(fontSize: 10, color: AppColors.textHint)),
          ])),
          Icon(Icons.edit_rounded, size: 18, color: color),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }
}

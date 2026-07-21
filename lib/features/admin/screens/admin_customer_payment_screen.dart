// Customer Payment Select — which customers picked Cash vs Wallet (and which
// wallet), synced live from the customer app's own Payment Methods screen.
// This used to be saved only on the customer's device (SharedPreferences);
// admin had no visibility into it at all until it started syncing here.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';
import '../../../core/services/socket_service.dart';

class AdminCustomerPaymentScreen extends StatefulWidget {
  const AdminCustomerPaymentScreen({super.key});

  @override
  State<AdminCustomerPaymentScreen> createState() => _AdminCustomerPaymentScreenState();
}

class _AdminCustomerPaymentScreenState extends State<AdminCustomerPaymentScreen> {
  List<dynamic> _rows = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    // Live: a customer changing their payment method on their own device
    // updates this list immediately, no manual refresh needed.
    SocketService().onCustomerPaymentUpdated = _onCustomerPaymentUpdated;
  }

  @override
  void dispose() {
    SocketService().onCustomerPaymentUpdated = null;
    _searchController.dispose();
    super.dispose();
  }

  void _onCustomerPaymentUpdated(Map<String, dynamic> data) {
    if (!mounted) return;
    final userId = data['userId'];
    final index = _rows.indexWhere((r) => r['id'] == userId);
    if (index == -1) {
      // Not currently in the loaded list (e.g. a filtered search) — ignore,
      // it'll be correct on next load.
      return;
    }
    setState(() {
      _rows[index] = {
        ..._rows[index] as Map<String, dynamic>,
        'preferred_payment_method': data['preferred_payment_method'],
        'preferred_wallet': data['preferred_wallet'],
      };
    });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await adminApiService.fetchCustomerPaymentMethods(
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() { _rows = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Failed to load: $_error'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _rows.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 120),
                              Center(child: Text('No customers yet')),
                            ])
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _rows.length,
                              separatorBuilder: (_, i) => const SizedBox(height: 10),
                              itemBuilder: (context, i) => _buildRow(_rows[i] as Map<String, dynamic>),
                            ),
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Customer Payment Select',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _load(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search name/email/phone',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> row) {
    final method = (row['preferred_payment_method'] ?? 'cash') as String;
    final wallet = row['preferred_wallet'] as String?;
    final isWallet = method == 'wallet';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
            backgroundImage: (row['profileImage'] as String?)?.isNotEmpty == true
                ? NetworkImage(row['profileImage'])
                : null,
            child: (row['profileImage'] as String?)?.isNotEmpty == true
                ? null
                : Text(
                    ((row['name'] as String?)?.isNotEmpty == true ? row['name'][0] : '?').toUpperCase(),
                    style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  row['email'] ?? row['phone'] ?? '',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isWallet ? AppColors.primaryBlue : AppColors.success).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isWallet ? Icons.account_balance_wallet_rounded : Icons.money_rounded,
                  size: 14,
                  color: isWallet ? AppColors.primaryBlue : AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  isWallet ? (wallet == 'easypaisa' ? 'EasyPaisa' : 'JazzCash') : 'Cash',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isWallet ? AppColors.primaryBlue : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

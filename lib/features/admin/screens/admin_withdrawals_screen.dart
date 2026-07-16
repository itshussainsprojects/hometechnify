import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen> {
  List<dynamic> _withdrawals = [];
  bool _isLoading = true;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await adminApiService.fetchWithdrawals(status: _statusFilter == 'all' ? null : _statusFilter);
      setState(() { _withdrawals = data; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processWithdrawal(String id, bool approve, {String? providerName}) async {
    String? adminNote;
    if (!approve) {
      adminNote = await showDialog<String>(
        context: context,
        builder: (_) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: const Text('Rejection Reason'),
            content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Reason (optional)')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Reject')),
            ],
          );
        },
      );
      if (adminNote == null) return;
    }
    final ok = await adminApiService.updateWithdrawal(id, approve: approve, adminNote: adminNote);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Withdrawal ${approve ? "approved" : "rejected"} for ${providerName ?? "provider"}'),
        backgroundColor: approve ? AppColors.success : AppColors.error,
      ));
      _load();
    }
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING': return AppColors.warning;
      case 'APPROVED': return AppColors.success;
      case 'REJECTED': return AppColors.error;
      default: return AppColors.grey400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        color: AppColors.white,
        child: Row(children: [
          ...['all', 'PENDING', 'APPROVED', 'REJECTED'].map((s) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () { setState(() => _statusFilter = s); _load(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: _statusFilter == s ? AppColors.primaryGradient : null,
                  color: _statusFilter == s ? null : AppColors.grey100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(s.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusFilter == s ? Colors.white : AppColors.textSecondary)),
              ),
            ),
          )),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ]),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _withdrawals.isEmpty
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.payments_outlined, size: 60, color: AppColors.grey300),
                    SizedBox(height: 16),
                    Text('No withdrawal requests', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _withdrawals.length,
                    itemBuilder: (ctx, i) {
                      final w = _withdrawals[i] as Map<String, dynamic>;
                      final provider = w['provider'] as Map<String, dynamic>?;
                      final status = w['status'] as String? ?? 'PENDING';
                      final isPending = status == 'PENDING';
                      final amount = (w['amount'] as num?)?.toDouble() ?? 0;
                      final date = DateTime.tryParse(w['created_at'] ?? '') ?? DateTime.now();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isPending ? AppColors.warning.withValues(alpha: 0.4) : AppColors.grey100),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                              backgroundImage: provider?['profileImage'] != null ? NetworkImage(provider!['profileImage'] as String) : null,
                              child: provider?['profileImage'] == null
                                  ? Text((provider?['name'] ?? 'P')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryBlue)) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(provider?['name'] ?? 'Provider', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              // Challan / reference (provider-id based)
                              if (w['challan'] != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 2, bottom: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                                  child: Text('Challan: ${w['challan']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                                ),
                              Text(w['payment_method'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(w['account_number'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Text('Rs. ${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primaryDark)),
                                const Spacer(),
                                Text('${date.day}/${date.month}/${date.year}', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                              ]),
                              if (w['admin_note'] != null && (w['admin_note'] as String).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Note: ${w['admin_note']}', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                                ),
                            ])),
                            const SizedBox(width: 12),
                            Column(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _statusColor(status))),
                              ),
                              if (isPending) ...[
                                const SizedBox(height: 8),
                                Row(children: [
                                  InkWell(
                                    onTap: () => _processWithdrawal(w['id'], true, providerName: provider?['name']),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.check_rounded, color: AppColors.success, size: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _processWithdrawal(w['id'], false, providerName: provider?['name']),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.close_rounded, color: AppColors.error, size: 18),
                                    ),
                                  ),
                                ]),
                              ],
                              const SizedBox(height: 8),
                              // Manage payment records for this provider
                              InkWell(
                                onTap: () => _showTransactions(provider?['id'] as String?, provider?['name'] as String?, amount),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(8)),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.receipt_long_rounded, size: 13, color: AppColors.textSecondary),
                                    SizedBox(width: 4),
                                    Text('Records', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                                  ]),
                                ),
                              ),
                            ]),
                          ]),
                        ),
                      ).animate(delay: Duration(milliseconds: i * 40)).fadeIn(duration: 300.ms);
                    },
                  ),
      ),
    ]);
  }

  // Payment records for a provider — add / edit / mark paid-unpaid / delete.
  void _showTransactions(String? providerId, String? providerName, double suggestedAmount) {
    if (providerId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _TransactionsSheet(providerId: providerId, providerName: providerName ?? 'Provider', suggestedAmount: suggestedAmount),
    );
  }
}

// ── Provider payment records sheet (real-time CRUD) ──
class _TransactionsSheet extends StatefulWidget {
  final String providerId;
  final String providerName;
  final double suggestedAmount;
  const _TransactionsSheet({required this.providerId, required this.providerName, required this.suggestedAmount});

  @override
  State<_TransactionsSheet> createState() => _TransactionsSheetState();
}

class _TransactionsSheetState extends State<_TransactionsSheet> {
  List<dynamic> _txns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await adminApiService.fetchProviderTransactions(widget.providerId);
      if (mounted) setState(() { _txns = t; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrEdit({Map<String, dynamic>? existing}) async {
    final amountCtrl = TextEditingController(text: ((existing?['amount'] as num?)?.toStringAsFixed(0)) ?? widget.suggestedAmount.toStringAsFixed(0));
    final noteCtrl = TextEditingController(text: existing?['response_message'] ?? '');
    String status = existing?['status'] ?? 'SUCCESS';
    String method = existing?['payment_method'] ?? 'EASYPAISA';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existing == null ? 'Record Payment' : 'Edit Record'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (Rs.)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'EASYPAISA', child: Text('EasyPaisa')),
              DropdownMenuItem(value: 'JAZZCASH', child: Text('JazzCash')),
              DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'MANUAL', child: Text('Manual / Cash')),
            ],
            onChanged: (v) => method = v ?? method,
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Status:'),
            const SizedBox(width: 12),
            ChoiceChip(label: const Text('Paid'), selected: status == 'SUCCESS', onSelected: (_) => setD(() => status = 'SUCCESS')),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('Not paid'), selected: status == 'PENDING', onSelected: (_) => setD(() => status = 'PENDING')),
          ]),
          const SizedBox(height: 12),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      )),
    );
    if (saved != true) return;
    final amount = double.tryParse(amountCtrl.text) ?? 0;
    bool ok;
    if (existing == null) {
      ok = await adminApiService.createTransaction(userId: widget.providerId, amount: amount, type: 'WITHDRAWAL', paymentMethod: method, status: status, note: noteCtrl.text);
    } else {
      ok = await adminApiService.updateTransaction(existing['id'], amount: amount, status: status, paymentMethod: method, note: noteCtrl.text);
    }
    if (ok) _load();
  }

  Future<void> _delete(String id) async {
    final ok = await adminApiService.deleteTransaction(id);
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${widget.providerName} — Payment Records', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _addOrEdit(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Record a payment'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _txns.isEmpty
                    ? const Center(child: Text('No payment records yet', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.separated(
                        itemCount: _txns.length,
                        separatorBuilder: (_, i) => const Divider(height: 12),
                        itemBuilder: (c, i) {
                          final t = _txns[i] as Map<String, dynamic>;
                          final paid = t['status'] == 'SUCCESS';
                          final amount = (t['amount'] as num?)?.toDouble() ?? 0;
                          return Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: (paid ? AppColors.success : AppColors.warning).withValues(alpha: 0.12), shape: BoxShape.circle),
                              child: Icon(paid ? Icons.check_rounded : Icons.hourglass_bottom_rounded, size: 16, color: paid ? AppColors.success : AppColors.warning),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Rs. ${amount.toStringAsFixed(0)} · ${t['type'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              Text('${t['payment_method'] ?? ''} · ${paid ? 'Paid' : 'Not paid'}${(t['response_message'] != null && (t['response_message'] as String).isNotEmpty) ? ' · ${t['response_message']}' : ''}',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ])),
                            IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primaryBlue), onPressed: () => _addOrEdit(existing: t)),
                            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), onPressed: () => _delete(t['id'])),
                          ]);
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

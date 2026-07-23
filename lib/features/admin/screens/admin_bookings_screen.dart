import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';
import '../../../core/services/socket_service.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  List<dynamic> _bookings = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String _statusFilter = 'all';
  String _categoryFilter = 'all';

  final _statusFilters = ['all', 'PENDING', 'ACCEPTED', 'ONGOING', 'COMPLETED', 'CANCELLED', 'NEGOTIATING'];

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
    // A booking was created or changed status, in any trade — refetch so the
    // list updates live instead of waiting for a manual refresh.
    SocketService().onAdminBookingUpdated = (_) {
      if (mounted) _load();
    };
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await adminApiService.fetchCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {/* trade filter just stays status-only if this fails */}
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await adminApiService.fetchBookings(
        status: _statusFilter == 'all' ? null : _statusFilter,
        categoryId: _categoryFilter == 'all' ? null : _categoryFilter,
      );
      setState(() { _bookings = data; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Widget _tradeChip(String label, String value) {
    final isSelected = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () { setState(() => _categoryFilter = value); _load(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryDark : AppColors.grey100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? AppColors.primaryDark : AppColors.grey200),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.engineering_rounded, size: 12, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING': return AppColors.warning;
      case 'ACCEPTED': return AppColors.primaryBlue;
      case 'ONGOING': return AppColors.primaryDark;
      case 'COMPLETED': return AppColors.success;
      case 'CANCELLED': return AppColors.error;
      case 'NEGOTIATING': return AppColors.primaryAccent;
      default: return AppColors.grey400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        color: AppColors.white,
        child: Column(children: [
          Row(children: [
            Text('${_bookings.length} Bookings', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          ]),
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
            children: _statusFilters.map((s) {
              final isSelected = _statusFilter == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () { setState(() => _statusFilter = s); _load(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppColors.primaryGradient : null,
                      color: isSelected ? null : AppColors.grey100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textSecondary)),
                  ),
                ),
              );
            }).toList(),
          )),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
              children: [
                _tradeChip('All Trades', 'all'),
                ..._categories.map((c) => _tradeChip(
                      (c as Map<String, dynamic>)['name'] as String? ?? 'Trade',
                      c['id'] as String,
                    )),
              ],
            )),
          ],
        ]),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _bookings.isEmpty
                ? const Center(child: Text('No bookings found', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (ctx, i) {
                      final b = _bookings[i] as Map<String, dynamic>;
                      final status = (b['status'] as String? ?? 'UNKNOWN');
                      final customer = b['customer'] as Map<String, dynamic>?;
                      final provider = b['provider'] as Map<String, dynamic>?;
                      final service = b['service'] as Map<String, dynamic>?;
                      final category = (service?['category'] as Map<String, dynamic>?)?['name'] as String?;
                      final price = (b['total_amount'] as num?)?.toDouble() ?? (service?['price'] as num?)?.toDouble() ?? 0;
                      final date = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
                      final hasReview = b['review'] != null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.grey100),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(Icons.flash_on_rounded, color: AppColors.primaryBlue, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(service?['name'] ?? 'Service', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: _getStatusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _getStatusColor(status))),
                              ),
                            ]),
                            if (category != null && category.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(category, style: TextStyle(fontSize: 11.5, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                            ],
                            const SizedBox(height: 12),
                            Row(children: [
                              const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textHint),
                              const SizedBox(width: 4),
                              Text(customer?['name'] ?? 'Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 16),
                              const Icon(Icons.engineering_rounded, size: 14, color: AppColors.textHint),
                              const SizedBox(width: 4),
                              Text(provider?['name'] ?? 'Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.monetization_on, size: 14, color: AppColors.textHint),
                              const SizedBox(width: 4),
                              Text('Rs. ${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success, fontSize: 13)),
                              const Spacer(),
                              Text('${date.day}/${date.month}/${date.year}', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                              if (hasReview) ...[
                                const SizedBox(width: 8),
                                Row(children: [
                                  const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                  Text(' ${(b['review']!['rating'] as num).toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ]),
                              ],
                            ]),
                          ]),
                        ),
                      ).animate(delay: Duration(milliseconds: i * 30)).fadeIn(duration: 300.ms);
                    },
                  ),
      ),
    ]);
  }
}

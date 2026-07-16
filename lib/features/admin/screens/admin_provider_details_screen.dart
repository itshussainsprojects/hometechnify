// Admin — Provider Details (service by service / area)
// Every provider grouped by the SERVICE they provide, with earnings, rating,
// registration documents (CNIC front/back + live selfie), bank details and
// full profile. Search, verify, block/unblock, delete — all live to the DB.

import 'package:flutter/material.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminProviderDetailsScreen extends StatefulWidget {
  const AdminProviderDetailsScreen({super.key});

  @override
  State<AdminProviderDetailsScreen> createState() => _AdminProviderDetailsScreenState();
}

class _AdminProviderDetailsScreenState extends State<AdminProviderDetailsScreen> {
  List<dynamic> _providers = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _groupBy = 'city'; // 'city' or 'service'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await adminApiService.fetchProviders();
      setState(() { _providers = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // Group providers by city (area) or by the service they provide.
  Map<String, List<dynamic>> get _grouped {
    final q = _search.trim().toLowerCase();
    final map = <String, List<dynamic>>{};
    for (final p in _providers) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final profile = p['provider_profile'] as Map<String, dynamic>?;
      final cat = (profile?['category']?['name'] ?? 'Uncategorized').toString();
      final city = (profile?['city']?.toString().trim().isNotEmpty ?? false) ? profile!['city'].toString() : 'Area not set';
      if (q.isNotEmpty && !name.contains(q) && !cat.toLowerCase().contains(q) && !city.toLowerCase().contains(q)) continue;
      final key = _groupBy == 'city' ? city : cat;
      map.putIfAbsent(key, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.grey400),
        const SizedBox(height: 12),
        const Text('Could not load providers'),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }

    final groups = _grouped;
    final totalShown = groups.values.fold<int>(0, (s, l) => s + l.length);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Provider Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('$totalShown providers · grouped by ${_groupBy == 'city' ? 'area / city' : 'service'}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            // Group-by toggle
            Row(children: [
              _toggleChip('By City / Area', 'city', Icons.location_city_rounded),
              const SizedBox(width: 8),
              _toggleChip('By Service', 'service', Icons.build_rounded),
            ]),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by name, city or service…',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: groups.isEmpty
                ? ListView(children: [const SizedBox(height: 80), Center(child: Text('No providers found', style: TextStyle(color: AppColors.textSecondary)))])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: groups.entries.map((e) => _serviceGroup(e.key, e.value)).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _toggleChip(String label, String value, IconData icon) {
    final active = _groupBy == value;
    return GestureDetector(
      onTap: () => setState(() => _groupBy = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryBlue : AppColors.grey100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: active ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _serviceGroup(String service, List<dynamic> providers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Service (area) heading
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
              child: Icon(_groupBy == 'city' ? Icons.location_city_rounded : Icons.build_rounded, size: 16, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 10),
            Text(service, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(20)),
              child: Text('${providers.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
            ),
          ]),
        ),
        ...providers.map(_providerCard),
      ],
    );
  }

  Widget _providerCard(dynamic p) {
    final profile = p['provider_profile'] as Map<String, dynamic>?;
    final rating = (profile?['rating'] as num?)?.toDouble() ?? 0;
    final earnings = (p['totalEarnings'] as num?)?.toDouble() ?? 0;
    final isBlocked = p['is_blocked'] == true;
    final isVerified = p['is_verified'] == true;
    final flag = p['ratingFlag']?.toString() ?? 'none';

    return GestureDetector(
      onTap: () => _openDetail(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isBlocked ? AppColors.error.withValues(alpha: 0.4) : AppColors.grey200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          _avatar(p),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(p['name'] ?? 'Provider', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 5),
                if (isVerified) const Icon(Icons.verified_rounded, size: 14, color: AppColors.primaryBlue),
                // low-rating warning (red) vs good
                if (flag == 'low') const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.error)),
                if (flag == 'good') const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.thumb_up_rounded, size: 13, color: AppColors.success)),
              ]),
              const SizedBox(height: 2),
              // Service + city so both are visible regardless of grouping
              Text(
                '${profile?['category']?['name'] ?? 'No service'}${(profile?['city']?.toString().trim().isNotEmpty ?? false) ? ' · ${profile!['city']}' : ''}',
                style: TextStyle(fontSize: 11.5, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.star_rounded, size: 13, color: AppColors.warning),
                const SizedBox(width: 2),
                Text(rating > 0 ? rating.toStringAsFixed(1) : 'New', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                const Icon(Icons.payments_rounded, size: 13, color: AppColors.success),
                const SizedBox(width: 3),
                Text('Rs. ${earnings.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          if (isBlocked)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: const Text('Blocked', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.error)))
          else if (!isVerified)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: const Text('Pending', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB7791F)))),
          const Icon(Icons.chevron_right_rounded, color: AppColors.grey400),
        ]),
      ),
    );
  }

  Widget _avatar(dynamic p) {
    final img = p['profileImage']?.toString();
    if (img != null && img.isNotEmpty) return CircleAvatar(radius: 22, backgroundImage: NetworkImage(img));
    final name = (p['name'] ?? '?').toString();
    final initials = name.trim().isNotEmpty ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase() : '?';
    return CircleAvatar(radius: 22, backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12), child: Text(initials, style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w800)));
  }

  void _openDetail(dynamic p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProviderDetailSheet(
        provider: p,
        onChanged: _load,
      ),
    );
  }
}

// ─── Full profile + documents bottom sheet ───
class _ProviderDetailSheet extends StatefulWidget {
  final dynamic provider;
  final VoidCallback onChanged;
  const _ProviderDetailSheet({required this.provider, required this.onChanged});

  @override
  State<_ProviderDetailSheet> createState() => _ProviderDetailSheetState();
}

class _ProviderDetailSheetState extends State<_ProviderDetailSheet> {
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action, String okMsg) async {
    setState(() => _busy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? okMsg : 'Action failed'), backgroundColor: ok ? AppColors.success : AppColors.error));
    if (ok) { widget.onChanged(); Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final profile = p['provider_profile'] as Map<String, dynamic>?;
    final isBlocked = p['is_blocked'] == true;
    final isVerified = p['is_verified'] == true;
    final rating = (profile?['rating'] as num?)?.toDouble() ?? 0;
    final earnings = (p['totalEarnings'] as num?)?.toDouble() ?? 0;
    final services = (profile?['services'] as List?)?.cast<dynamic>() ?? [];
    final lat = profile?['current_lat'];
    final lng = profile?['current_lng'];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            // Header
            Row(children: [
              CircleAvatar(radius: 30, backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                backgroundImage: (p['profileImage'] != null && '${p['profileImage']}'.isNotEmpty) ? NetworkImage('${p['profileImage']}') : null,
                child: (p['profileImage'] == null || '${p['profileImage']}'.isEmpty) ? Text('${p['name'] ?? '?'}'.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primaryBlue)) : null),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(p['name'] ?? 'Provider', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                  if (isVerified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified_rounded, size: 18, color: AppColors.primaryBlue)),
                ]),
                Text(profile?['category']?['name']?.toString() ?? 'No service', style: TextStyle(color: AppColors.textSecondary)),
              ])),
            ]),
            const SizedBox(height: 16),
            // Stats row
            Row(children: [
              _stat('Rating', rating > 0 ? rating.toStringAsFixed(1) : '—', Icons.star_rounded, AppColors.warning),
              _stat('Earnings', 'Rs. ${earnings.toStringAsFixed(0)}', Icons.payments_rounded, AppColors.success),
              _stat('Jobs', '${profile?['jobs_completed'] ?? 0}', Icons.work_rounded, AppColors.primaryBlue),
            ]),
            const SizedBox(height: 8),
            _section('Contact & Area'),
            _row('Email', p['email']?.toString() ?? '—'),
            _row('Phone', p['phone']?.toString() ?? '—'),
            _row('Location', (lat != null && lng != null) ? '$lat, $lng' : 'Not set'),
            _row('Experience', profile?['experience']?.toString() ?? '—'),
            _row('Hourly rate', 'Rs. ${(profile?['hourly_rate'] as num?)?.toStringAsFixed(0) ?? '0'}'),
            if (services.isNotEmpty) _row('Services', services.join(', ')),

            _section('Bank Details'),
            _row('Bank', profile?['bank_name']?.toString() ?? '—'),
            _row('Account title', profile?['account_title']?.toString() ?? '—'),
            _row('Account no.', profile?['account_number']?.toString() ?? '—'),

            _section('Registration Documents'),
            Row(children: [
              _doc('CNIC Front', profile?['cnic_front']?.toString()),
              _doc('CNIC Back', profile?['cnic_back']?.toString()),
              _doc('Live Selfie', profile?['selfie_url']?.toString()),
            ]),

            const SizedBox(height: 22),
            // Actions
            if (_busy) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else ...[
              Row(children: [
                if (!isVerified)
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _run(() => adminApiService.verifyProvider(p['id'], verify: true), 'Provider verified'),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Verify'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  )),
                if (!isVerified) const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _run(() => adminApiService.blockProvider(p['id'], block: !isBlocked), isBlocked ? 'Provider unblocked' : 'Provider blocked'),
                  icon: Icon(isBlocked ? Icons.lock_open_rounded : Icons.block_rounded, size: 18),
                  label: Text(isBlocked ? 'Unblock' : 'Block'),
                  style: ElevatedButton.styleFrom(backgroundColor: isBlocked ? AppColors.primaryBlue : AppColors.warning, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                )),
              ]),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(p['id']),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete provider'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), minimumSize: const Size(double.infinity, 46)),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete provider?'),
      content: const Text('This moves the provider to the recycle bin.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); _run(() => adminApiService.deleteProvider(id), 'Provider deleted'); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), child: const Text('Delete')),
      ],
    ));
  }

  Widget _stat(String label, String value, IconData icon, Color color) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    ),
  );

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 8), child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)));

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _doc(String label, String? url) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(children: [
        GestureDetector(
          onTap: (url != null && url.isNotEmpty) ? () => _viewImage(url, label) : null,
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey200),
              image: (url != null && url.isNotEmpty) ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
            ),
            child: (url == null || url.isEmpty) ? const Icon(Icons.image_not_supported_outlined, color: AppColors.grey400) : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    ),
  );

  void _viewImage(String url, String title) {
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
        ])),
        Flexible(child: InteractiveViewer(child: Image.network(url, errorBuilder: (c, e, s) => const Padding(padding: EdgeInsets.all(40), child: Text('Could not load image', style: TextStyle(color: Colors.white)))))),
        const SizedBox(height: 12),
      ]),
    ));
  }
}

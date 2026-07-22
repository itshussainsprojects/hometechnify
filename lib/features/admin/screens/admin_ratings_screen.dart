// Admin Ratings management.
// - Lists every provider with their rating (worst first).
// - Header lets the admin SET a threshold: providers below it show a RED flag
//   (with a quick Block button); at/above it show a green "Good".
// - Admin can Edit (set) or Remove (reset) any provider's rating.
// - Customer-given ratings already update the provider's profile automatically.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';
import '../../../core/services/socket_service.dart';

class AdminRatingsScreen extends StatefulWidget {
  const AdminRatingsScreen({super.key});

  @override
  State<AdminRatingsScreen> createState() => _AdminRatingsScreenState();
}

class _AdminRatingsScreenState extends State<AdminRatingsScreen> {
  List<dynamic> _rows = [];
  double _threshold = 2.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // A customer just rated a provider — refetch so the new average and
    // red/good flag show up without waiting for a manual pull-to-refresh.
    SocketService().onProviderRatingUpdated = (_) {
      if (mounted) _load();
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await adminApiService.fetchRatings();
      setState(() {
        _threshold = res['threshold'] as double;
        _rows = res['data'] as List;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load ratings: $e')));
        setState(() => _loading = false);
      }
    }
  }

  int get _flaggedCount => _rows.where((r) => r['flag'] == 'low').length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildThresholdHeader(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _rows.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No providers yet'))])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _rows.length,
                          separatorBuilder: (_, i) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _buildRow(_rows[i] as Map<String, dynamic>, i),
                        ),
                ),
        ),
      ],
    );
  }

  // ── Threshold setting (header feature) ──
  Widget _buildThresholdHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.gpp_maybe_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Auto-flag threshold', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                Text('Providers below ${_threshold.toStringAsFixed(1)}★ are flagged red · $_flaggedCount flagged now',
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.star_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(_threshold.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _editThreshold,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.tune_rounded, color: AppColors.primaryBlue, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _editThreshold() {
    double temp = _threshold;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Set Rating Threshold'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Providers below ${temp.toStringAsFixed(1)}★ will be flagged red so you can block them.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star_rounded, color: AppColors.warning),
              Expanded(
                child: Slider(
                  value: temp, min: 0, max: 5, divisions: 10,
                  label: temp.toStringAsFixed(1),
                  activeColor: AppColors.primaryBlue,
                  onChanged: (v) => setD(() => temp = v),
                ),
              ),
              Text(temp.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await adminApiService.setRatingThreshold(temp);
                if (ok) _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Threshold set to ${temp.toStringAsFixed(1)}★' : 'Failed to set threshold')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> p, int index) {
    final rating = (p['rating'] as num?)?.toDouble() ?? 0;
    final flag = p['flag'] as String? ?? 'none';
    final isBlocked = p['is_blocked'] == true;
    final reviewCount = p['reviewCount'] as int? ?? 0;
    final isLow = flag == 'low';
    final isGood = flag == 'good';

    final flagColor = isLow ? AppColors.error : (isGood ? AppColors.success : AppColors.grey400);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLow ? AppColors.error.withValues(alpha: 0.4) : AppColors.grey200, width: isLow ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: flagColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: (p['profileImage'] != null && (p['profileImage'] as String).isNotEmpty)
                    ? ClipOval(child: Image.network(p['profileImage'], width: 46, height: 46, fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Text(_initials(p['name']), style: TextStyle(color: flagColor, fontWeight: FontWeight.w800))))
                    : Text(_initials(p['name']), style: TextStyle(color: flagColor, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(p['name'] ?? 'Provider', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                      if (isBlocked) ...[
                        const SizedBox(width: 6),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: const Text('Blocked', style: TextStyle(fontSize: 9, color: AppColors.error, fontWeight: FontWeight.w800))),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text('${p['category'] ?? 'General'} · $reviewCount reviews', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.star_rounded, size: 16, color: rating > 0 ? AppColors.warning : AppColors.grey400),
                      const SizedBox(width: 3),
                      Text(rating > 0 ? rating.toStringAsFixed(1) : 'No rating', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: flagColor)),
                      const SizedBox(width: 8),
                      // Red flag / Good badge
                      if (isLow)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.error),
                            SizedBox(width: 3),
                            Text('Low', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w800)),
                          ]),
                        )
                      else if (isGood)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
                            SizedBox(width: 3),
                            Text('Good', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                    ]),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) {
                  if (v == 'edit') {
                    _editRating(p);
                  } else if (v == 'remove') {
                    _removeRating(p);
                  } else if (v == 'block') {
                    _toggleBlock(p, !isBlocked);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit rating')])),
                  const PopupMenuItem(value: 'remove', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Remove rating')])),
                  PopupMenuItem(value: 'block', child: Row(children: [Icon(isBlocked ? Icons.lock_open_rounded : Icons.block_rounded, size: 18, color: isBlocked ? AppColors.success : AppColors.error), const SizedBox(width: 8), Text(isBlocked ? 'Unblock' : 'Block')])),
                ],
              ),
            ],
          ),
          // Quick block button for low-rated providers
          if (isLow && !isBlocked) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _toggleBlock(p, true),
                icon: const Icon(Icons.block_rounded, size: 16),
                label: const Text('Block this low-rated provider'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ],
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 30)).fadeIn(duration: 260.ms);
  }

  String _initials(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '?';
    return n.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
  }

  void _editRating(Map<String, dynamic> p) {
    double temp = (p['rating'] as num?)?.toDouble() ?? 0;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Set rating · ${p['name']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${temp.toStringAsFixed(1)} ★', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.warning)),
            Slider(value: temp, min: 0, max: 5, divisions: 10, label: temp.toStringAsFixed(1), activeColor: AppColors.warning, onChanged: (v) => setD(() => temp = v)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await adminApiService.setProviderRating(p['id'], temp);
                if (ok) _load();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Rating updated' : 'Failed to update')));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeRating(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove rating?'),
        content: Text("Reset ${p['name']}'s rating to 0? This clears their displayed rating."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await adminApiService.resetProviderRating(p['id']);
              if (ok) _load();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Rating removed' : 'Failed')));
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _toggleBlock(Map<String, dynamic> p, bool block) async {
    final ok = await adminApiService.blockProvider(p['id'], block: block);
    if (ok) _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? (block ? 'Provider blocked' : 'Provider unblocked') : 'Action failed'), backgroundColor: block ? AppColors.error : AppColors.success),
      );
    }
  }
}

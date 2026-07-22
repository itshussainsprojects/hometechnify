// Admin — Provider accounts & access.
//
// Real providers from the backend with the actions an admin actually has:
// verify / unverify, block / unblock, move to recycle bin. This screen used to
// render an in-memory mock list whose buttons changed nothing.
//
// Verification matters: an unverified provider receives no jobs at all, so this
// is where a new provider is let into the marketplace.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminProviderAuthScreen extends StatefulWidget {
  const AdminProviderAuthScreen({super.key});

  @override
  State<AdminProviderAuthScreen> createState() => _AdminProviderAuthScreenState();
}

class _AdminProviderAuthScreenState extends State<AdminProviderAuthScreen> {
  final _searchCtrl = TextEditingController();
  String _status = 'all';
  List<dynamic> _providers = [];
  bool _loading = true;
  String? _error;

  static const _filters = {
    'all': 'All',
    'unverified': 'Pending',
    'verified': 'Verified',
    'blocked': 'Blocked',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await adminApiService.fetchProviders(
        status: _status,
        search: _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _providers = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Set a provider's trade.
  ///
  /// Job matching is by CATEGORY, and nothing in the app could ever set one: the
  /// provider app never sent it, so the backend filed every provider under
  /// whatever category was first in the table. Fourteen of them were listed as
  /// plumbers regardless of what they actually do — and any new category an admin
  /// created stayed empty forever, so its jobs reached nobody.
  Future<void> _setTrade(Map<String, dynamic> p) async {
    final messenger = ScaffoldMessenger.of(context);
    final profile = (p['provider_profile'] as Map<String, dynamic>?) ?? {};
    final current = (profile['category'] as Map<String, dynamic>?)?['id'] as String?;

    List<dynamic> categories;
    try {
      categories = await adminApiService.fetchCategories();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Could not load categories: $e'), backgroundColor: AppColors.error));
      return;
    }
    if (!mounted) return;

    final chosen = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text("Set ${p['name'] ?? 'this provider'}'s trade"),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'They will only receive jobs in this trade.',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ),
          ...categories.map((c) {
            final m = c as Map<String, dynamic>;
            final isCurrent = m['id'] == current;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m),
              child: Row(
                children: [
                  Icon(
                    isCurrent
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: isCurrent ? AppColors.primaryBlue : AppColors.grey300,
                  ),
                  const SizedBox(width: 10),
                  Text(m['name'] ?? '',
                      style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500)),
                ],
              ),
            );
          }),
        ],
      ),
    );

    if (chosen == null || !mounted) return;
    if (chosen['id'] == current) return;

    await _run(
      () => adminApiService.setProviderCategory(p['id'] as String, chosen['id'] as String),
      "Trade set to ${chosen['name']} — they now receive ${chosen['name']} jobs",
    );
  }

  Future<void> _run(Future<bool> Function() action, String okMsg) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await action();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(ok ? okMsg : 'Action failed'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
      if (ok) _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Move to recycle bin?'),
        content: Text(
            '${p['name'] ?? 'This provider'} will be taken offline and lose access immediately. You can restore them from the Recycle Bin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => adminApiService.deleteProvider(p['id'] as String), 'Moved to recycle bin');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildControls(),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _providers.isEmpty
                        ? const Center(
                            child: Text('No providers match this filter',
                                style: TextStyle(color: AppColors.textSecondary)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              itemCount: _providers.length,
                              separatorBuilder: (_, i) => const SizedBox(height: 10),
                              itemBuilder: (context, i) =>
                                  _buildProviderCard(_providers[i] as Map<String, dynamic>),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Provider Accounts',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5)),
          SizedBox(height: 4),
          Text('Verify a provider to let them receive jobs. Unverified providers get none.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      );

  Widget _buildSearchField() => TextField(
        controller: _searchCtrl,
        onSubmitted: (_) => _load(),
        decoration: InputDecoration(
          hintText: 'Search by name, email or phone',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            onPressed: _load,
          ),
        ),
      );

  Widget _buildFilterChips() => Wrap(
        spacing: 6,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ..._filters.entries.map((e) => ChoiceChip(
                label: Text(e.value),
                selected: _status == e.key,
                onSelected: (_) {
                  setState(() => _status = e.key);
                  _load();
                },
              )),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      );

  // A single Row (search + 4 chips + refresh) squeezed hard below desktop
  // width. On a narrow admin window, stack the search field above a wrapping
  // row of chips instead of forcing everything onto one line.
  Widget _buildControls() => LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Row(
            children: [
              Expanded(child: _buildSearchField()),
              const SizedBox(width: 8),
              _buildFilterChips(),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchField(),
            const SizedBox(height: 12),
            _buildFilterChips(),
          ],
        );
      });

  Widget _buildProviderCard(Map<String, dynamic> p) {
    final profile = (p['provider_profile'] as Map<String, dynamic>?) ?? {};
    final blocked = p['is_blocked'] == true;
    final verified = p['is_verified'] == true || profile['is_verified'] == true;
    final online = profile['is_online'] == true;
    final category = (profile['category'] as Map<String, dynamic>?)?['name'] as String?;
    final image = p['profileImage'] as String?;
    final joined = p['created_at'] as String?;

    // A provider with no real trade receives nothing: job matching is by
    // category, and "Uncategorized" is the internal parking bucket, not a job
    // anyone posts against.
    final hasTrade = category != null && category.isNotEmpty && category != 'Uncategorized';

    // A provider only receives work when they are verified, available, AND
    // actually filed under a trade.
    final receivesJobs = verified && online && !blocked && hasTrade;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: blocked ? AppColors.error.withValues(alpha: 0.4) : AppColors.grey200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.grey100,
            backgroundImage: (image != null && image.isNotEmpty) ? NetworkImage(image) : null,
            child: (image == null || image.isEmpty)
                ? const Icon(Icons.engineering_rounded, color: AppColors.textSecondary, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(p['name'] ?? 'Unnamed',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    _chip(verified ? 'VERIFIED' : 'PENDING',
                        verified ? AppColors.success : AppColors.warning),
                    if (blocked) ...[
                      const SizedBox(width: 6),
                      _chip('BLOCKED', AppColors.error),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    hasTrade ? category : 'NO TRADE SET',
                    p['email'] ?? '',
                  ].where((s) => s.toString().isNotEmpty).join(' • '),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: hasTrade ? FontWeight.w400 : FontWeight.w700,
                    color: hasTrade ? AppColors.textSecondary : AppColors.error,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  receivesJobs
                      ? 'Receiving $category jobs'
                      : blocked
                          ? 'Blocked — receives no jobs'
                          : !hasTrade
                              ? 'No trade set — receives no jobs at all. Tap "Set Trade".'
                              : !verified
                                  ? 'Not verified — receives no jobs'
                                  : 'Offline — receives no jobs until they go Available',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: receivesJobs
                        ? AppColors.success
                        : (!hasTrade ? AppColors.error : AppColors.textHint),
                  ),
                ),
                if (joined != null)
                  Text(
                      'Joined ${DateFormat('dd MMM yyyy').format(DateTime.parse(joined).toLocal())}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
          // Set Trade + Verify/Unverify + Block/Unblock + Delete side by side
          // next to a name/status column with no fixed width overflowed hard
          // on a narrow admin window. One icon regardless of width.
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (action) {
              if (action == 'trade') _setTrade(p);
              if (action == 'verify') {
                _run(
                  () => adminApiService.verifyProvider(p['id'] as String, verify: !verified),
                  verified ? 'Verification removed' : 'Verified — they can now receive jobs',
                );
              }
              if (action == 'block') {
                _run(
                  () => adminApiService.blockProvider(p['id'] as String, block: !blocked),
                  blocked ? 'Unblocked' : 'Blocked',
                );
              }
              if (action == 'delete') _delete(p);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'trade',
                child: Row(children: [
                  Icon(Icons.category_rounded, color: hasTrade ? AppColors.primaryBlue : AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  const Text('Set Trade'),
                ]),
              ),
              PopupMenuItem(
                value: 'verify',
                child: Row(children: [
                  Icon(verified ? Icons.close_rounded : Icons.verified_rounded,
                      color: verified ? AppColors.warning : AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(verified ? 'Unverify' : 'Verify'),
                ]),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(children: [
                  Icon(blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                      color: blocked ? AppColors.success : AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Text(blocked ? 'Unblock' : 'Block'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Text('Move to recycle bin'),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Could not load: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
}

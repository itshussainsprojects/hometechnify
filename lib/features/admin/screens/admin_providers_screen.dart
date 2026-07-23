import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';
import '../../../core/services/socket_service.dart';

class AdminProvidersScreen extends StatefulWidget {
  const AdminProvidersScreen({super.key});

  @override
  State<AdminProvidersScreen> createState() => _AdminProvidersScreenState();
}

class _AdminProvidersScreenState extends State<AdminProvidersScreen> {
  List<dynamic> _providers = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedProvider;
  // Tracks whether the narrow-screen details sheet is open, so a block/
  // delete/verify action can close it explicitly instead of leaving it open
  // over now-stale data.
  bool _detailSheetOpen = false;

  final _filters = ['all', 'verified', 'unverified', 'blocked'];

  @override
  void initState() {
    super.initState();
    _load();
    // A customer just rated a provider — refetch so the rating/flag shown on
    // the card updates live instead of waiting for a manual refresh.
    SocketService().onProviderRatingUpdated = (_) {
      if (mounted) _load();
    };
    // A provider toggled Available/Not Available — same, no manual refresh
    // needed to see it change.
    SocketService().onProviderAvailabilityUpdated = (_) {
      if (mounted) _load();
    };
    // A provider updated their own profile — bank details, category, CNIC/
    // selfie docs, etc. — same, refresh live.
    SocketService().onProviderProfileUpdated = (_) {
      if (mounted) _load();
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await adminApiService.fetchProviders(
        status: _selectedFilter == 'all' ? null : _selectedFilter,
        search: _search.isEmpty ? null : _search,
      );
      setState(() { _providers = data; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
  }

  Future<void> _verify(String id, String name, bool isVerified) async {
    final ok = await adminApiService.verifyProvider(id, verify: !isVerified);
    if (!mounted) return;
    if (ok) { _showSuccess('Provider ${isVerified ? "unverified" : "verified"}'); _load(); if (_selectedProvider?['id'] == id) setState(() => _selectedProvider!['is_verified'] = !isVerified); }
  }

  Future<void> _block(String id, String name, bool isBlocked) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isBlocked ? 'Unblock Provider' : 'Block Provider'),
        content: Text('${isBlocked ? "Unblock" : "Block"} provider "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isBlocked ? AppColors.success : AppColors.error),
            child: Text(isBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await adminApiService.blockProvider(id, block: !isBlocked);
      if (!mounted) return;
      if (ok) {
        _showSuccess('Provider ${isBlocked ? "unblocked" : "blocked"}');
        _load();
        setState(() => _selectedProvider = null);
        _closeSheetIfOpen();
      }
    }
  }

  // The narrow-screen detail sheet is a separate route — resetting
  // _selectedProvider alone doesn't dismiss it, so it would sit open showing
  // the pre-action (now stale) state until manually swiped away.
  void _closeSheetIfOpen() {
    if (_detailSheetOpen && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Provider'),
        content: Text('Delete provider "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await adminApiService.deleteProvider(id);
      if (!mounted) return;
      _showSuccess('Provider deleted');
      _load();
      setState(() => _selectedProvider = null);
      _closeSheetIfOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Row(
      children: [
        Expanded(flex: isWide && _selectedProvider != null ? 2 : 1, child: _buildList()),
        if (isWide && _selectedProvider != null)
          Expanded(flex: 3, child: _buildDetailPanel()),
      ],
    );
  }

  // On a wide window the side panel shows inline. Below that width there's no
  // room for it, so it just silently never appeared — verify/block/delete for
  // a provider were completely unreachable from a narrower admin window. Open
  // the same detail panel as a full-height sheet instead.
  void _openDetails(Map<String, dynamic> p) {
    setState(() => _selectedProvider = p);
    final isWide = MediaQuery.of(context).size.width >= 900;
    if (isWide) return;
    _detailSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _buildDetailPanel(onClose: () => Navigator.of(sheetContext).pop()),
      ),
    ).then((_) {
      _detailSheetOpen = false;
      if (mounted) setState(() => _selectedProvider = null);
    });
  }

  Widget _buildList() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        color: AppColors.white,
        child: Column(children: [
          Row(children: [
            Text('${_providers.length} Providers', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _searchController,
              onChanged: (v) { _search = v; if (v.isEmpty || v.length > 2) _load(); },
              decoration: InputDecoration(
                hintText: 'Search providers...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _search = ''; _load(); }) : null,
                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
            children: _filters.map((f) {
              final isSelected = _selectedFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () { setState(() => _selectedFilter = f); _load(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppColors.primaryGradient : null,
                      color: isSelected ? null : AppColors.grey100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(f.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textSecondary)),
                  ),
                ),
              );
            }).toList(),
          )),
        ]),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _providers.isEmpty ? const Center(child: Text('No providers found', style: TextStyle(color: AppColors.textSecondary)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _providers.length,
                itemBuilder: (ctx, i) => _buildProviderCard(_providers[i], i),
              ),
      ),
    ]);
  }

  Widget _buildProviderCard(Map<String, dynamic> p, int index) {
    final isVerified = p['is_verified'] == true;
    final isBlocked = p['is_blocked'] == true;
    final profile = p['provider_profile'] as Map<String, dynamic>?;
    final isSelected = _selectedProvider?['id'] == p['id'];

    return GestureDetector(
      onTap: () => _openDetails(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primaryBlue : (isBlocked ? AppColors.error.withValues(alpha: 0.3) : AppColors.grey100), width: isSelected ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            Stack(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                backgroundImage: p['profileImage'] != null ? NetworkImage(p['profileImage'] as String) : null,
                child: p['profileImage'] == null ? Text((p['name'] ?? 'P')[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primaryBlue)) : null,
              ),
              if (isVerified)
                Positioned(right: 0, bottom: 0, child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                )),
              if (isBlocked)
                Positioned(right: 0, bottom: 0, child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  child: const Icon(Icons.block, size: 10, color: Colors.white),
                )),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(p['name'] ?? 'Provider', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1),
                  Text(p['email'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis, maxLines: 1),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isVerified) _statusChip('VERIFIED', AppColors.success),
                      if (!isVerified && !isBlocked) _statusChip('PENDING', AppColors.warning),
                      if (isBlocked) _statusChip('BLOCKED', AppColors.error),
                      // Availability toggle state (mirrors what customers see)
                      if (profile != null)
                        _statusChip(
                            profile['is_online'] == true
                                ? 'AVAILABLE'
                                : 'NOT AVAILABLE',
                            profile['is_online'] == true
                                ? AppColors.primaryBlue
                                : AppColors.grey400),
                      if (profile != null && profile['rating'] != null)
                        Builder(builder: (_) {
                          final flag = p['ratingFlag'] as String? ?? 'none';
                          final low = flag == 'low';
                          final good = flag == 'good';
                          final c = low ? AppColors.error : (good ? AppColors.success : AppColors.grey500);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Red warning for low-rated (so admin can block fast); star otherwise
                                Icon(low ? Icons.warning_amber_rounded : Icons.star_rounded, size: 12, color: low ? AppColors.error : Colors.amber),
                                Text(' ${(profile['rating'] as num).toStringAsFixed(1)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
                                if (low) const Text(' Low', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.error)),
                                if (good) const Text(' Good', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.success)),
                              ],
                            ),
                          );
                        }),
                    ]
                  ),
                ]
              )
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: Icon(isVerified ? Icons.verified_rounded : Icons.check_circle_outline_rounded,
                    color: isVerified ? AppColors.success : AppColors.grey400, size: 22),
                onPressed: () => _verify(p['id'], p['name'] ?? '', isVerified),
                tooltip: isVerified ? 'Revoke Verification' : 'Verify',
              ),
              // Block/Delete used to live only in the detail panel, which only
              // renders on wide windows — on a narrower admin view there was no
              // way to reach them at all. Same quick menu as the Users screen,
              // reachable regardless of window width.
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (action) {
                  if (action == 'block') _block(p['id'], p['name'] ?? '', isBlocked);
                  if (action == 'delete') _delete(p['id'], p['name'] ?? '');
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'block',
                    child: Row(children: [
                      Icon(isBlocked ? Icons.lock_open_rounded : Icons.block_rounded, color: isBlocked ? AppColors.success : AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Text(isBlocked ? 'Unblock' : 'Block'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      const Text('Delete'),
                    ]),
                  ),
                ],
              ),
            ]),
          ]),
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 40)).fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _buildDetailPanel({VoidCallback? onClose}) {
    final p = _selectedProvider!;
    final isVerified = p['is_verified'] == true;
    final isBlocked = p['is_blocked'] == true;
    final profile = p['provider_profile'] as Map<String, dynamic>?;
    final cnicFront = profile?['cnic_front'] as String?;
    final cnicBack = profile?['cnic_back'] as String?;
    final selfieUrl = profile?['selfie_url'] as String?;

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.grey100)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Provider Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: onClose ?? () => setState(() => _selectedProvider = null),
            ),
          ]),
          const SizedBox(height: 20),
          // Profile header
          Center(child: Column(children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: p['profileImage'] != null ? NetworkImage(p['profileImage'] as String) : null,
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
              child: p['profileImage'] == null ? Text((p['name'] ?? 'P')[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primaryBlue)) : null,
            ),
            const SizedBox(height: 12),
            Text(p['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(p['email'] ?? '', style: TextStyle(color: AppColors.textSecondary)),
            if (p['phone'] != null) Text(p['phone'] as String, style: TextStyle(color: AppColors.textHint)),
          ])),
          const SizedBox(height: 24),
          // Stats
          if (profile != null) ...[
            _infoRow('Category', profile['category']?['name'] ?? 'N/A', Icons.category_rounded),
            _infoRow('Availability', profile['is_online'] == true ? 'Available' : 'Not Available', Icons.power_settings_new_rounded),
            _infoRow('Rating', '${profile['rating'] ?? 0}', Icons.star_rounded),
            // Pricing here is per-job/negotiated at booking time, not a fixed
            // hourly rate the provider sets — this field is unused by that
            // flow and only confused admins into thinking it meant something.
            _infoRow('Bank', profile['bank_name'] ?? 'N/A', Icons.account_balance_rounded),
            _infoRow('Account #', profile['account_number'] ?? 'N/A', Icons.credit_card_rounded),
            const Divider(height: 32),
          ],
          // Verification documents
          const Text('Verification Documents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),
          // A fixed 3-wide Row squeezes hard in the narrow-screen sheet this
          // panel also renders inside — same width-aware wrap used on the
          // Verify Documents screen.
          LayoutBuilder(builder: (context, constraints) {
            const spacing = 12.0;
            final perRow = constraints.maxWidth < 360 ? 2 : 3;
            final tileWidth = (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(width: tileWidth, child: _buildDocImage('CNIC Front', cnicFront)),
                SizedBox(width: tileWidth, child: _buildDocImage('CNIC Back', cnicBack)),
                SizedBox(width: tileWidth, child: _buildDocImage('Selfie', selfieUrl)),
              ],
            );
          }),
          const SizedBox(height: 24),
          // Action buttons
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _verify(p['id'], p['name'] ?? '', isVerified),
              icon: Icon(isVerified ? Icons.close_rounded : Icons.check_rounded),
              label: Text(isVerified ? 'Revoke Verification' : 'Verify Provider'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isVerified ? AppColors.warning : AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _block(p['id'], p['name'] ?? '', isBlocked),
              icon: Icon(isBlocked ? Icons.lock_open_rounded : Icons.block_rounded),
              label: Text(isBlocked ? 'Unblock' : 'Block Provider'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isBlocked ? AppColors.success : AppColors.error,
                side: BorderSide(color: isBlocked ? AppColors.success : AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _delete(p['id'], p['name'] ?? ''),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1);
  }

  Widget _buildDocImage(String label, String? url) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grey200),
          image: url != null && url.isNotEmpty ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
        ),
        child: url == null || url.isEmpty ? const Center(child: Icon(Icons.image_not_supported_rounded, color: AppColors.grey400, size: 32)) : null,
      ),
    ]);
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.primaryBlue),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

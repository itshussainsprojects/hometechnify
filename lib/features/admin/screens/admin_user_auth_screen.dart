// Admin — Customer accounts & access.
//
// Real accounts from the backend with the actions an admin actually has:
// block / unblock / move to recycle bin. This screen used to render an in-memory
// mock list of invented people whose buttons changed nothing.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminUserAuthScreen extends StatefulWidget {
  const AdminUserAuthScreen({super.key});

  @override
  State<AdminUserAuthScreen> createState() => _AdminUserAuthScreenState();
}

class _AdminUserAuthScreenState extends State<AdminUserAuthScreen> {
  final _searchCtrl = TextEditingController();
  String _status = 'all';
  List<dynamic> _users = [];
  bool _loading = true;
  String? _error;

  static const _filters = {
    'all': 'All',
    'active': 'Active',
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
      final data = await adminApiService.fetchUsers(
        status: _status,
        search: _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _users = data;
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

  Future<void> _setBlocked(Map<String, dynamic> user, bool block) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await adminApiService.blockUser(user['id'] as String, block: block);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(ok
            ? '${user['name'] ?? 'User'} ${block ? 'blocked' : 'unblocked'}'
            : 'Action failed'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
      if (ok) _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Move to recycle bin?'),
        content: Text(
            '${user['name'] ?? 'This user'} will lose access immediately. You can restore them from the Recycle Bin.'),
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

    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await adminApiService.deleteUser(user['id'] as String);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(ok ? 'Moved to recycle bin' : 'Delete failed'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
      if (ok) _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
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
                    : _users.isEmpty
                        ? const Center(
                            child: Text('No customer accounts match this filter',
                                style: TextStyle(color: AppColors.textSecondary)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              itemCount: _users.length,
                              separatorBuilder: (_, i) => const SizedBox(height: 10),
                              itemBuilder: (context, i) =>
                                  _buildUserCard(_users[i] as Map<String, dynamic>),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Accounts',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('${_users.length} account${_users.length == 1 ? '' : 's'} • block, unblock or remove access',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      );

  Widget _buildControls() => Row(
        children: [
          Expanded(
            child: TextField(
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
            ),
          ),
          const SizedBox(width: 12),
          ..._filters.entries.map((e) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _status == e.key,
                  onSelected: (_) {
                    setState(() => _status = e.key);
                    _load();
                  },
                ),
              )),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      );

  Widget _buildUserCard(Map<String, dynamic> user) {
    final blocked = user['is_blocked'] == true;
    final image = user['profileImage'] as String?;
    final joined = user['created_at'] as String?;
    final bookings = (user['_count'] as Map<String, dynamic>?)?['bookings_as_customer'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: blocked ? AppColors.error.withValues(alpha: 0.4) : AppColors.grey200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.grey100,
            backgroundImage: (image != null && image.isNotEmpty) ? NetworkImage(image) : null,
            child: (image == null || image.isEmpty)
                ? const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 20)
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
                      child: Text(user['name'] ?? 'Unnamed',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    if (blocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('BLOCKED',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.error)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    user['email'] ?? '',
                    if ((user['phone'] ?? '').toString().isNotEmpty) user['phone'],
                  ].where((s) => s.toString().isNotEmpty).join(' • '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 3),
                Text(
                  '$bookings booking${bookings == 1 ? '' : 's'}'
                  '${joined != null ? ' • joined ${DateFormat('dd MMM yyyy').format(DateTime.parse(joined).toLocal())}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _setBlocked(user, !blocked),
            child: Text(blocked ? 'Unblock' : 'Block',
                style: TextStyle(color: blocked ? AppColors.success : AppColors.warning)),
          ),
          IconButton(
            tooltip: 'Move to recycle bin',
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
            onPressed: () => _delete(user),
          ),
        ],
      ),
    );
  }

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

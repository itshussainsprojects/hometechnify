import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await adminApiService.fetchUsers(
        status: _selectedFilter == 'all' ? null : _selectedFilter,
        search: _search.isEmpty ? null : _search,
      );
      setState(() { _users = users; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
  }

  Future<void> _blockUser(String id, String name, bool isBlocked) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isBlocked ? 'Unblock User' : 'Block User'),
        content: Text('${isBlocked ? "Unblock" : "Block"} user "$name"?'),
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
      final ok = await adminApiService.blockUser(id, block: !isBlocked);
      if (!mounted) return;
      if (ok) { _showSuccess('User ${isBlocked ? "unblocked" : "blocked"} successfully'); _loadUsers(); }
    }
  }

  Future<void> _deleteUser(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Permanently delete "$name"? This action cannot be undone.'),
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
    if (confirm == true) {
      final ok = await adminApiService.deleteUser(id);
      if (!mounted) return;
      if (ok) { _showSuccess('User deleted successfully'); _loadUsers(); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: AppColors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${_users.length} Users', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadUsers),
            ]),
            const SizedBox(height: 16),
            // Search bar
            Container(
              decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _searchController,
                onChanged: (v) { _search = v; if (v.isEmpty || v.length > 2) _loadUsers(); },
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or phone...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _search = ''; _loadUsers(); }) : null,
                  border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Filter tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'active', 'blocked'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () { setState(() => _selectedFilter = filter); _loadUsers(); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppColors.primaryGradient : null,
                          color: isSelected ? null : AppColors.grey100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(filter.toUpperCase(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textSecondary)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.person_off_rounded, size: 60, color: AppColors.grey300),
                      const SizedBox(height: 16),
                      const Text('No users found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _users.length,
                      itemBuilder: (ctx, i) => _buildUserCard(_users[i], i),
                    ),
        ),
      ],
    );
  }

  /// Automatic engagement score from booking volume alone — distinct from
  /// `rating` (the average of reviews a provider left this customer). Purely
  /// computed from data already on screen, so it updates itself the moment
  /// a new booking lands; admin never sets or maintains it.
  double _engagementRating(int bookingCount) {
    if (bookingCount >= 15) return 5.0;
    if (bookingCount >= 8) return 4.5;
    if (bookingCount >= 3) return 3.5;
    return 2.5;
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    final isBlocked = user['is_blocked'] == true;
    final bookingCount = (user['_count']?['bookings_as_customer'] as int?) ?? 0;
    final joinDate = DateTime.tryParse(user['created_at'] ?? '') ?? DateTime.now();
    final totalSpent = (user['total_spent'] as num?)?.toDouble() ?? 0;
    final rating = (user['rating'] as num?)?.toDouble() ?? 0;
    final engagementRating = _engagementRating(bookingCount);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isBlocked ? AppColors.error.withValues(alpha: 0.3) : AppColors.grey100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          // Avatar
          Stack(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
              backgroundImage: user['profileImage'] != null && (user['profileImage'] as String).isNotEmpty
                  ? NetworkImage(user['profileImage'] as String) : null,
              child: user['profileImage'] == null ? Text(
                (user['name'] ?? 'U')[0].toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primaryBlue),
              ) : null,
            ),
            if (isBlocked)
              Positioned(right: 0, bottom: 0, child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                child: const Icon(Icons.block, size: 10, color: Colors.white),
              )),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(user['email'] ?? '', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (user['phone'] != null) Text(user['phone'] as String, style: TextStyle(fontSize: 12, color: AppColors.textHint)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip('$bookingCount bookings', Icons.event_note_outlined, AppColors.primaryBlue),
                _chip('Rs. ${totalSpent.toStringAsFixed(0)} spent', Icons.account_balance_wallet_outlined, AppColors.success),
                if (rating > 0)
                  _chip(rating.toStringAsFixed(1), Icons.star_rounded, AppColors.warning),
                _chip('Joined ${_formatDate(joinDate)}', Icons.calendar_today_outlined, AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 8),
            Text('RATING OF CUSTOMER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textHint, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                const SizedBox(width: 3),
                Text(engagementRating.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Text('($bookingCount bookings)', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ])),
          // Actions
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (action) {
              if (action == 'block') _blockUser(user['id'], user['name'] ?? '', isBlocked);
              if (action == 'delete') _deleteUser(user['id'], user['name'] ?? '');
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
      ),
    ).animate(delay: Duration(milliseconds: index * 40)).fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

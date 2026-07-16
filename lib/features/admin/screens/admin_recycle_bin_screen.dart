// Admin Recycle Bin (Users)
//
// Soft-deleted customer accounts, straight from the backend. This screen used to
// render an in-memory mock list, so it showed invented people and its Restore
// button changed nothing in the database.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminRecycleBinScreen extends StatefulWidget {
  final bool isEmbedded;
  const AdminRecycleBinScreen({super.key, this.isEmbedded = false});

  @override
  State<AdminRecycleBinScreen> createState() => _AdminRecycleBinScreenState();
}

class _AdminRecycleBinScreenState extends State<AdminRecycleBinScreen> {
  List<dynamic> _deleted = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await adminApiService.fetchUsers(status: 'deleted');
      if (!mounted) return;
      setState(() {
        _deleted = data;
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

  Future<void> _restore(Map<String, dynamic> user) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await adminApiService.restoreUser(user['id'] as String);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(ok
            ? '${user['name'] ?? 'User'} restored'
            : 'Restore failed'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
      if (ok) _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Restore failed: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _deleted.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _deleted.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _buildDeletedUserCard(_deleted[i] as Map<String, dynamic>),
                    ),
    );

    if (widget.isEmbedded) return body;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Recycle Bin (Users)',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: body,
    );
  }

  Widget _buildDeletedUserCard(Map<String, dynamic> user) {
    final deletedAt = user['deleted_at'] as String?;
    final when = deletedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(deletedAt).toLocal())
        : 'Unknown';
    final image = user['profileImage'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.grey100,
            backgroundImage: (image != null && image.isNotEmpty) ? NetworkImage(image) : null,
            child: (image == null || image.isEmpty)
                ? const Icon(Icons.person_rounded, color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'] ?? 'Unnamed',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(user['email'] ?? '',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text('Deleted $when',
                    style: const TextStyle(fontSize: 11, color: AppColors.error)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _restore(user),
            icon: const Icon(Icons.restore_rounded, size: 16),
            label: const Text('Restore'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.delete_outline_rounded, size: 64, color: AppColors.grey300),
          SizedBox(height: 16),
          Center(
            child: Text('Recycle bin is empty',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          SizedBox(height: 6),
          Center(
            child: Text('Deleted customer accounts show up here and can be restored.',
                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          ),
        ],
      );

  Widget _buildError() => ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
          const SizedBox(height: 12),
          Center(child: Text('Could not load: $_error',
              style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
}

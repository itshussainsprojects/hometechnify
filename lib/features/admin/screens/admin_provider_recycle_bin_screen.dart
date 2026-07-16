// Admin Recycle Bin (Providers)
//
// Soft-deleted provider accounts, straight from the backend. This screen used to
// render an in-memory mock list, so it showed invented providers and its Restore
// button changed nothing in the database.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminProviderRecycleBinScreen extends StatefulWidget {
  final bool isEmbedded;
  const AdminProviderRecycleBinScreen({super.key, this.isEmbedded = false});

  @override
  State<AdminProviderRecycleBinScreen> createState() => _AdminProviderRecycleBinScreenState();
}

class _AdminProviderRecycleBinScreenState extends State<AdminProviderRecycleBinScreen> {
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
      final data = await adminApiService.fetchProviders(status: 'deleted');
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

  Future<void> _restore(Map<String, dynamic> provider) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await adminApiService.restoreProvider(provider['id'] as String);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(ok ? '${provider['name'] ?? 'Provider'} restored' : 'Restore failed'),
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
                          _buildDeletedProviderCard(_deleted[i] as Map<String, dynamic>),
                    ),
    );

    if (widget.isEmbedded) return body;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Recycle Bin (Providers)',
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

  Widget _buildDeletedProviderCard(Map<String, dynamic> provider) {
    final profile = (provider['provider_profile'] as Map<String, dynamic>?) ?? {};
    final deletedAt = provider['deleted_at'] as String?;
    final when = deletedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(deletedAt).toLocal())
        : 'Unknown';
    final image = provider['profileImage'] as String?;
    final category = (profile['category'] as Map<String, dynamic>?)?['name'] as String?;

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
                ? const Icon(Icons.engineering_rounded, color: AppColors.textSecondary)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider['name'] ?? 'Unnamed',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (category != null) category,
                    provider['email'] ?? '',
                  ].where((s) => s.toString().isNotEmpty).join(' • '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text('Deleted $when',
                    style: const TextStyle(fontSize: 11, color: AppColors.error)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _restore(provider),
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
            child: Text('Deleted providers show up here and can be restored.',
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

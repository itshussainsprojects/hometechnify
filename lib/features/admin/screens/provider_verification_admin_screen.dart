// Provider Verification — review submitted documents and let a provider into
// the marketplace.
//
// This screen used to read a `provider_verifications` Supabase table that
// nothing ever writes to, so it was permanently empty while real providers who
// HAD uploaded their CNIC sat unverified and invisible to the admin. Onboarding
// stores the documents on the provider profile, so that is what we read here.
//
// Verification is the gate: an unverified provider receives no jobs at all.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';
import 'package:home_technify/core/utils/snackbar_helper.dart';

class ProviderVerificationAdminScreen extends StatefulWidget {
  final bool isEmbedded;
  const ProviderVerificationAdminScreen({super.key, this.isEmbedded = false});

  @override
  State<ProviderVerificationAdminScreen> createState() =>
      _ProviderVerificationAdminScreenState();
}

class _ProviderVerificationAdminScreenState
    extends State<ProviderVerificationAdminScreen> {
  List<dynamic> _pending = [];
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
      final all = await adminApiService.fetchProviders(status: 'unverified');
      if (!mounted) return;
      setState(() {
        // Only those who actually submitted something to review.
        _pending = all.where((p) {
          final profile = (p['provider_profile'] as Map<String, dynamic>?) ?? {};
          return _has(profile['cnic_front']) ||
              _has(profile['cnic_back']) ||
              _has(profile['selfie_url']);
        }).toList();
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

  bool _has(dynamic v) => v != null && v.toString().isNotEmpty;

  Future<void> _approve(Map<String, dynamic> p) async {
    try {
      final ok = await adminApiService.verifyProvider(p['id'] as String, verify: true);
      if (!mounted) return;
      if (ok) {
        SnackBarHelper.showSuccess(context,
            '${p['name'] ?? 'Provider'} verified — they can now receive jobs');
        _load();
      } else {
        SnackBarHelper.showError(context, 'Verification failed');
      }
    } catch (e) {
      if (mounted) SnackBarHelper.showError(context, 'Failed: $e');
    }
  }

  Future<void> _reject(Map<String, dynamic> p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject and block?'),
        content: Text(
            '${p['name'] ?? 'This provider'} stays unverified and is blocked from the app. They can be unblocked later from Provider Accounts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final ok = await adminApiService.blockProvider(p['id'] as String, block: true);
      if (!mounted) return;
      if (ok) {
        SnackBarHelper.showSuccess(context, 'Rejected and blocked');
        _load();
      } else {
        SnackBarHelper.showError(context, 'Reject failed');
      }
    } catch (e) {
      if (mounted) SnackBarHelper.showError(context, 'Failed: $e');
    }
  }

  void _openImage(String url, String title) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, e, s) => Container(
                  padding: const EdgeInsets.all(40),
                  color: AppColors.white,
                  child: const Text('Could not load this document'),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? _buildError()
            : _pending.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _pending.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 14),
                      itemBuilder: (context, i) =>
                          _buildCard(_pending[i] as Map<String, dynamic>, i),
                    ),
                  );

    if (widget.isEmbedded) return body;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Provider Verification',
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

  Widget _buildCard(Map<String, dynamic> p, int index) {
    final profile = (p['provider_profile'] as Map<String, dynamic>?) ?? {};
    final category = (profile['category'] as Map<String, dynamic>?)?['name'] as String?;
    final joined = p['created_at'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.grey100,
                backgroundImage: _has(p['profileImage'])
                    ? NetworkImage(p['profileImage'] as String)
                    : null,
                child: !_has(p['profileImage'])
                    ? const Icon(Icons.engineering_rounded, color: AppColors.textSecondary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name'] ?? 'Unnamed',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (category != null) category,
                        p['phone'] ?? p['email'] ?? '',
                      ].where((s) => s.toString().isNotEmpty).join(' • '),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (joined != null)
                      Text(
                        'Applied ${DateFormat('dd MMM yyyy').format(DateTime.parse(joined).toLocal())}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('PENDING',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.warning)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Submitted documents',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          // A fixed 3-wide Row squeezed on a narrow admin window; Wrap lets
          // the tiles drop to 2 (or 1) per line instead of compressing.
          LayoutBuilder(builder: (context, constraints) {
            const spacing = 10.0;
            final perRow = constraints.maxWidth < 360 ? 2 : 3;
            final tileWidth = (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(width: tileWidth, child: _doc('CNIC Front', profile['cnic_front'] as String?)),
                SizedBox(width: tileWidth, child: _doc('CNIC Back', profile['cnic_back'] as String?)),
                SizedBox(width: tileWidth, child: _doc('Live Selfie', profile['selfie_url'] as String?)),
              ],
            );
          }),
          const SizedBox(height: 8),
          const Text('Tap a document to open it full size. Check the selfie matches the CNIC photo.',
              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reject(p),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _approve(p),
                  icon: const Icon(Icons.verified_rounded, size: 16),
                  label: const Text('Approve & let them work'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 60)).fadeIn(duration: 300.ms);
  }

  Widget _doc(String label, String? url) {
    final has = _has(url);
    return GestureDetector(
        onTap: has ? () => _openImage(url!, label) : null,
        child: Column(
          children: [
            Container(
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: has ? AppColors.grey200 : AppColors.error.withValues(alpha: 0.4)),
                image: has
                    ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
                    : null,
              ),
              child: has
                  ? null
                  : const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: AppColors.error, size: 20),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              has ? label : '$label — missing',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: has ? AppColors.textSecondary : AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
  }

  Widget _buildEmpty() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.verified_user_outlined, size: 64, color: AppColors.grey300),
          SizedBox(height: 16),
          Center(
            child: Text('Nothing to verify',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          SizedBox(height: 6),
          Center(
            child: Text('Providers who upload their CNIC or selfie show up here.',
                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          ),
        ],
      );

  Widget _buildError() => ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
          const SizedBox(height: 12),
          Center(
              child: Text('Could not load: $_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary))),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
}

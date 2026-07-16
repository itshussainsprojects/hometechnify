import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() => _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _targetType = 'ALL';
  bool _isSending = false;
  int? _lastSentCount;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleCtrl.text.isEmpty || _bodyCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title and message'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _isSending = true);
    try {
      final count = await adminApiService.sendAdminNotification(
        title: _titleCtrl.text,
        body: _bodyCtrl.text,
        targetType: _targetType,
      );
      if (!mounted) return;
      setState(() { _lastSentCount = count; _isSending = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification saved for $count users'), backgroundColor: AppColors.success),
      );
      _titleCtrl.clear(); _bodyCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Send Admin Notification', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Send push notifications to users, providers, or everyone. Notifications are saved to the DB for in-app display.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 32),
            // Target Audience
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Target Audience', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 16),
                ...{
                  'ALL': ('Everyone', Icons.people_rounded, AppColors.primaryBlue),
                  'ALL_USERS': ('Customers Only', Icons.person_rounded, AppColors.success),
                  'ALL_PROVIDERS': ('Providers Only', Icons.engineering_rounded, AppColors.warning),
                }.entries.map((e) {
                  final isSelected = _targetType == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _targetType = e.key),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? (e.value.$3).withValues(alpha: 0.08) : AppColors.grey50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? e.value.$3 : AppColors.grey200, width: isSelected ? 2 : 1),
                      ),
                      child: Row(children: [
                        Icon(e.value.$2, color: isSelected ? e.value.$3 : AppColors.grey400, size: 20),
                        const SizedBox(width: 12),
                        Text(e.value.$1, style: TextStyle(fontWeight: FontWeight.w700, color: isSelected ? e.value.$3 : AppColors.textSecondary)),
                        if (isSelected) ...[const Spacer(), Icon(Icons.check_circle_rounded, color: e.value.$3, size: 20)],
                      ]),
                    ),
                  );
                }),
              ]),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 20),
            // Notification Content
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Notification Content', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bodyCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Message *',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.message_rounded)),
                  ),
                ),
              ]),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1),
            const SizedBox(height: 24),
            // Send Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _send,
                icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                label: Text(_isSending ? 'Sending...' : 'Send Notification', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
            if (_lastSentCount != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                  const SizedBox(width: 12),
                  Text('Last sent: notification delivered to $_lastSentCount user(s)',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

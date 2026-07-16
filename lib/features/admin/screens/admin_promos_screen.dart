import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminPromosScreen extends StatefulWidget {
  const AdminPromosScreen({super.key});

  @override
  State<AdminPromosScreen> createState() => _AdminPromosScreenState();
}

class _AdminPromosScreenState extends State<AdminPromosScreen> {
  List<dynamic> _promos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await adminApiService.fetchPromos();
      setState(() { _promos = data; _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading promos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load promos: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  void _showCreateDialog({Map<String, dynamic>? existing}) {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final subtitleCtrl = TextEditingController(text: existing?['subtitle'] ?? '');
    final codeCtrl = TextEditingController(text: existing?['code'] ?? '');
    final discountCtrl = TextEditingController(text: (existing?['discount'] ?? 0).toString());
    bool isActive = existing?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'Create Promo' : 'Edit Promo'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: subtitleCtrl, decoration: const InputDecoration(labelText: 'Subtitle', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Promo Code (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: discountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount %', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Active'),
            value: isActive,
            onChanged: (v) => setDialogState(() => isActive = v),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              Navigator.pop(context);
              if (existing == null) {
                await adminApiService.createPromo(
                  title: titleCtrl.text,
                  subtitle: subtitleCtrl.text.isEmpty ? null : subtitleCtrl.text,
                  code: codeCtrl.text.isEmpty ? null : codeCtrl.text,
                  discount: double.tryParse(discountCtrl.text) ?? 0,
                  isActive: isActive,
                );
              } else {
                await adminApiService.updatePromo(existing['id'], {
                  'title': titleCtrl.text, 'subtitle': subtitleCtrl.text,
                  'code': codeCtrl.text.isEmpty ? null : codeCtrl.text,
                  'discount': double.tryParse(discountCtrl.text) ?? 0,
                  'is_active': isActive,
                });
              }
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      )),
    );
  }

  Future<void> _delete(String id) async {
    final ok = await adminApiService.deletePromo(id);
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        color: AppColors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_promos.length} Promo Banners', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showCreateDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Promo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _promos.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.local_offer_rounded, size: 60, color: AppColors.grey300),
                    const SizedBox(height: 16),
                    const Text('No promos yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(onPressed: () => _showCreateDialog(), icon: const Icon(Icons.add), label: const Text('Create First Promo')),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _promos.length,
                    itemBuilder: (ctx, i) {
                      final p = _promos[i] as Map<String, dynamic>;
                      final isActive = p['is_active'] == true;
                      int colorVal = 0xFF1565C0;
                      if (p['color_value'] != null) {
                        colorVal = (p['color_value'] as num).toInt();
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isActive ? Color(colorVal).withValues(alpha: 0.3) : AppColors.grey200),
                        ),
                        child: Row(children: [
                          Container(
                            width: 8,
                            height: 80,
                            decoration: BoxDecoration(
                              color: isActive ? Color(colorVal) : AppColors.grey300,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                            ),
                          ),
                          Expanded(child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                                if (!isActive) Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(8)),
                                  child: const Text('INACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                                ),
                              ]),
                              if (p['subtitle'] != null) Text(p['subtitle'] as String, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Row(children: [
                                if (p['discount'] != null && (p['discount'] as num) > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text('${(p['discount'] as num).toStringAsFixed(0)}% OFF', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.error)),
                                  ),
                                if (p['code'] != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.grey300)),
                                    child: Text('CODE: ${p['code']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                                  ),
                                ],
                              ]),
                            ]),
                          )),
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            Switch(
                              value: isActive,
                              onChanged: (v) async { await adminApiService.togglePromo(p['id'], v); _load(); },
                            ),
                            Row(children: [
                              IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primaryBlue), onPressed: () => _showCreateDialog(existing: p)),
                              IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), onPressed: () => _delete(p['id'])),
                            ]),
                          ]),
                        ]),
                      ).animate(delay: Duration(milliseconds: i * 40)).fadeIn(duration: 300.ms);
                    },
                  ),
      ),
    ]);
  }
}

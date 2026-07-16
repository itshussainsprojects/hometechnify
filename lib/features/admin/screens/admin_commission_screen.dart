// Admin — Commission (%)
// Sets the platform commission charged to providers per completed job.
// Applies live (read at every job completion + shown on the provider bid
// screen) — set / edit / reset. 0% effectively turns commission off.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminCommissionScreen extends StatefulWidget {
  const AdminCommissionScreen({super.key});

  @override
  State<AdminCommissionScreen> createState() => _AdminCommissionScreenState();
}

class _AdminCommissionScreenState extends State<AdminCommissionScreen> {
  static const double _default = 12; // must match backend default
  final _controller = TextEditingController();

  double _commission = _default;
  double? _radius;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await adminApiService.fetchPlatformSettings();
      final c = (s['commission_percent'] as num?)?.toDouble() ?? _default;
      setState(() {
        _commission = c;
        _radius = (s['provider_radius_km'] as num?)?.toDouble();
        _controller.text = c.toStringAsFixed(0);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save(double value) async {
    if (value < 0 || value > 50) {
      _toast('Commission must be between 0% and 50%', AppColors.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final ok = await adminApiService.setPlatformSettings(commissionPercent: value);
      if (!mounted) return;
      setState(() { _saving = false; if (ok) _commission = value; _controller.text = value.toStringAsFixed(0); });
      _toast(ok ? 'Commission set to ${value.toStringAsFixed(0)}% — applies to all providers now' : 'Failed to update', ok ? AppColors.success : AppColors.error);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Error: $e', AppColors.error);
    }
  }

  void _toast(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reset commission?'),
        content: const Text('This resets the platform commission back to the default of 12%.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _save(_default); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.grey400),
          const SizedBox(height: 12),
          Text('Could not load settings', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    final isOff = _commission == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Platform Commission', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text('Charged to the provider on every completed job. Applies live — the provider sees it on their bid screen and it is deducted at completion.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
              const SizedBox(height: 22),

              // Current value hero
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))]),
                child: Row(children: [
                  const Icon(Icons.percent_rounded, color: Colors.white, size: 34),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Current commission', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text('${_commission.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  ]),
                  const Spacer(),
                  if (_radius != null)
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Search radius', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('${_radius!.toStringAsFixed(0)} km', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    ]),
                ]),
              ).animate().fadeIn(duration: 300.ms),

              if (isOff) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: const [
                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB7791F)),
                    SizedBox(width: 8),
                    Expanded(child: Text('Commission is OFF (0%). Providers keep the full amount.', style: TextStyle(fontSize: 12.5, color: Color(0xFFB7791F), fontWeight: FontWeight.w600))),
                  ]),
                ),
              ],

              const SizedBox(height: 24),

              // Live preview on a sample job
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
                child: Column(children: [
                  _previewRow('On a Rs. 1,000 job', ''),
                  const SizedBox(height: 6),
                  _previewRow('Platform earns', 'Rs. ${(1000 * _commission / 100).toStringAsFixed(0)}', color: AppColors.primaryDark, bold: true),
                  _previewRow('Provider keeps', 'Rs. ${(1000 - 1000 * _commission / 100).toStringAsFixed(0)}', color: AppColors.success, bold: true),
                ]),
              ),

              const SizedBox(height: 24),

              // Slider
              Text('Adjust', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Row(children: [
                Expanded(
                  child: Slider(
                    value: _commission.clamp(0, 50),
                    min: 0, max: 50, divisions: 50,
                    label: '${_commission.toStringAsFixed(0)}%',
                    activeColor: AppColors.primaryBlue,
                    onChanged: _saving ? null : (v) => setState(() { _commission = v; _controller.text = v.toStringAsFixed(0); }),
                    onChangeEnd: (v) => _save(v.roundToDouble()),
                  ),
                ),
                SizedBox(width: 48, child: Text('${_commission.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),

              const SizedBox(height: 8),

              // Exact input
              Text('Or enter exact value', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      suffixText: '%',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(double.tryParse(_controller.text) ?? _commission),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                ),
              ]),

              const SizedBox(height: 16),

              // Quick presets
              Wrap(spacing: 8, children: [0, 10, 12, 15, 20, 25].map((p) => ActionChip(
                label: Text(p == 0 ? 'Off' : '$p%'),
                backgroundColor: _commission.round() == p ? AppColors.primaryBlue.withValues(alpha: 0.15) : AppColors.grey100,
                labelStyle: TextStyle(color: _commission.round() == p ? AppColors.primaryBlue : AppColors.textSecondary, fontWeight: FontWeight.w700),
                onPressed: _saving ? null : () => _save(p.toDouble()),
              )).toList()),

              const SizedBox(height: 24),

              // Reset
              OutlinedButton.icon(
                onPressed: _saving ? null : _confirmReset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Reset to default (12%)'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewRow(String label, String value, {Color? color, bool bold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      Text(value, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? AppColors.textPrimary)),
    ]);
  }
}

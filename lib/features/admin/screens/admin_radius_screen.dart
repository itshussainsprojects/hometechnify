// Admin — Provider Radius Adjustment (km)
// Sets the search radius used to show nearby providers to customers.
// Applies live (backend reads it at every provider search) — set / edit / reset.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminRadiusScreen extends StatefulWidget {
  const AdminRadiusScreen({super.key});

  @override
  State<AdminRadiusScreen> createState() => _AdminRadiusScreenState();
}

class _AdminRadiusScreenState extends State<AdminRadiusScreen> {
  static const double _defaultRadius = 20; // must match backend default
  final _controller = TextEditingController();

  double _radius = _defaultRadius;
  double? _commission;
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
      final r = (s['provider_radius_km'] as num?)?.toDouble() ?? _defaultRadius;
      setState(() {
        _radius = r;
        _commission = (s['commission_percent'] as num?)?.toDouble();
        _controller.text = r.toStringAsFixed(0);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save(double value) async {
    if (value <= 0 || value > 500) {
      _toast('Enter a radius between 1 and 500 km', AppColors.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final ok = await adminApiService.setPlatformSettings(providerRadiusKm: value);
      if (!mounted) return;
      setState(() { _saving = false; if (ok) _radius = value; _controller.text = value.toStringAsFixed(0); });
      _toast(ok ? 'Radius updated to ${value.toStringAsFixed(0)} km — applies to all searches now' : 'Failed to update', ok ? AppColors.success : AppColors.error);
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
        title: const Text('Reset radius?'),
        content: const Text('This resets the provider search radius back to the default of 20 km.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _save(_defaultRadius); },
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Provider Radius Adjustment', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text('Customers only see providers within this distance. Applies live to every search.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
              const SizedBox(height: 22),

              // Current value hero
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))]),
                child: Row(children: [
                  const Icon(Icons.my_location_rounded, color: Colors.white, size: 34),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Current search radius', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text('${_radius.toStringAsFixed(0)} km', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  ]),
                  const Spacer(),
                  if (_commission != null)
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Commission', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('${_commission!.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    ]),
                ]),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 24),

              // Slider (quick set)
              Text('Adjust', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Row(children: [
                Expanded(
                  child: Slider(
                    value: _radius.clamp(1, 100),
                    min: 1, max: 100, divisions: 99,
                    label: '${_radius.toStringAsFixed(0)} km',
                    activeColor: AppColors.primaryBlue,
                    onChanged: _saving ? null : (v) => setState(() { _radius = v; _controller.text = v.toStringAsFixed(0); }),
                    onChangeEnd: (v) => _save(v.roundToDouble()),
                  ),
                ),
                SizedBox(width: 54, child: Text('${_radius.toStringAsFixed(0)} km', style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),

              const SizedBox(height: 8),

              // Exact input (edit)
              Text('Or enter exact value', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      suffixText: 'km',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(double.tryParse(_controller.text) ?? _radius),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                ),
              ]),

              const SizedBox(height: 16),

              // Quick presets
              Wrap(spacing: 8, children: [5, 10, 20, 30, 50].map((km) => ActionChip(
                label: Text('$km km'),
                backgroundColor: _radius.round() == km ? AppColors.primaryBlue.withValues(alpha: 0.15) : AppColors.grey100,
                labelStyle: TextStyle(color: _radius.round() == km ? AppColors.primaryBlue : AppColors.textSecondary, fontWeight: FontWeight.w700),
                onPressed: _saving ? null : () => _save(km.toDouble()),
              )).toList()),

              const SizedBox(height: 24),

              // Reset (delete/default)
              OutlinedButton.icon(
                onPressed: _saving ? null : _confirmReset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Reset to default (20 km)'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Provider Work-Flow Screen — the two-OTP security lock.
// Stage 1: "I've arrived" (GPS). Stage 2: Start OTP + before photo -> ONGOING.
// Stage 3: Completion OTP + after photo -> COMPLETED (unlocks customer payment/rating).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import '../../core/services/supabase_service.dart';
import 'data/models/booking_model.dart';
import 'providers/booking_provider.dart';

class ProviderWorkFlowScreen extends StatefulWidget {
  final BookingModel booking;
  const ProviderWorkFlowScreen({super.key, required this.booking});

  @override
  State<ProviderWorkFlowScreen> createState() => _ProviderWorkFlowScreenState();
}

class _ProviderWorkFlowScreenState extends State<ProviderWorkFlowScreen> {
  late BookingModel _booking;
  final _otpCtrl = TextEditingController();
  File? _photo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  bool get _arrived => _booking.arrivedAt != null;
  bool get _ongoing => _booking.status == 'ONGOING';
  bool get _completed => _booking.status == 'COMPLETED';

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _capturePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera, // camera-only — a real on-site photo
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _markArrived() async {
    final prov = context.read<BookingProvider>();
    setState(() => _busy = true);
    double lat = _booking.lat, lng = _booking.lng;
    try {
      final pos = await Geolocator.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {/* fall back to booking coords */}

    final res = await prov.markArrived(_booking.id, lat, lng);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.isSuccess) {
      setState(() => _booking = res.data!);
      _snack('Marked as arrived. Ask the customer for the Start OTP.');
    } else {
      _snack(res.error?.message ?? 'Failed', error: true);
    }
  }

  Future<void> _submitStage({required bool starting}) async {
    if (_otpCtrl.text.trim().length != 4) {
      _snack('Enter the 4-digit OTP from the customer', error: true);
      return;
    }
    if (_photo == null) {
      _snack('Capture a ${starting ? "before" : "after"} work photo', error: true);
      return;
    }
    final prov = context.read<BookingProvider>();
    setState(() => _busy = true);

    // 1) Upload photo
    final url = await SupabaseService.uploadWorkPhoto(
      image: _photo!,
      bookingId: _booking.id,
      stage: starting ? 'before' : 'after',
    );
    if (url == null) {
      if (mounted) { setState(() => _busy = false); _snack('Photo upload failed. Try again.', error: true); }
      return;
    }

    // 2) Verify OTP + advance
    final res = starting
        ? await prov.startWork(_booking.id, _otpCtrl.text.trim(), url)
        : await prov.completeWork(_booking.id, _otpCtrl.text.trim(), url);

    if (!mounted) return;
    setState(() => _busy = false);
    if (res.isSuccess) {
      setState(() { _booking = res.data!; _otpCtrl.clear(); _photo = null; });
      _snack(starting ? 'Work started!' : 'Work completed! 🎉');
      if (_completed) Future.delayed(const Duration(milliseconds: 900), () { if (mounted) Navigator.pop(context, true); });
    } else {
      _snack(res.error?.message ?? 'Invalid OTP', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Service Progress'), backgroundColor: AppColors.white),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stepper(),
              const SizedBox(height: 24),
              _bookingCard(),
              const SizedBox(height: 20),
              if (_completed)
                _doneCard()
              else if (!_arrived)
                _arrivedCard()
              else if (!_ongoing)
                _stageCard(starting: true)
              else
                _stageCard(starting: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepper() {
    final step = _completed ? 3 : _ongoing ? 2 : _arrived ? 1 : 0;
    final labels = ['Arrive', 'Start', 'Complete'];
    return Row(
      children: List.generate(3, (i) {
        final active = step > i;
        final current = step == i;
        return Expanded(
          child: Column(children: [
            Row(children: [
              Expanded(child: Container(height: 3, color: i == 0 ? Colors.transparent : (active || current ? AppColors.primaryBlue : AppColors.grey200))),
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryBlue : current ? AppColors.primaryBlue.withValues(alpha: 0.15) : AppColors.grey100,
                  shape: BoxShape.circle,
                  border: Border.all(color: active || current ? AppColors.primaryBlue : AppColors.grey300, width: 2),
                ),
                child: Icon(active ? Icons.check : Icons.circle, size: active ? 16 : 8, color: active ? Colors.white : AppColors.primaryBlue),
              ),
              Expanded(child: Container(height: 3, color: i == 2 ? Colors.transparent : (step > i + 1 ? AppColors.primaryBlue : AppColors.grey200))),
            ]),
            const SizedBox(height: 6),
            Text(labels[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active || current ? AppColors.primaryBlue : AppColors.textTertiary)),
          ]),
        );
      }),
    );
  }

  Widget _bookingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey200)),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.build_rounded, color: AppColors.primaryBlue)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_booking.serviceName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text('${_booking.customerName} • Rs. ${_booking.price.toStringAsFixed(0)}', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ])),
      ]),
    );
  }

  Widget _arrivedCard() {
    return _actionCard(
      icon: Icons.location_on_rounded,
      title: 'Reached the customer?',
      subtitle: 'Confirm your arrival to unlock the Start OTP step.',
      child: _primaryBtn('I\'ve Arrived', _busy ? null : _markArrived),
    );
  }

  Widget _stageCard({required bool starting}) {
    return _actionCard(
      icon: starting ? Icons.play_circle_fill_rounded : Icons.check_circle_rounded,
      title: starting ? 'Start the Work' : 'Complete the Work',
      subtitle: starting
          ? 'Ask the customer for the Start OTP, then capture a "before" photo.'
          : 'Ask the customer for the Completion OTP, then capture an "after" photo.',
      child: Column(children: [
        _otpField(),
        const SizedBox(height: 14),
        _photoPicker(starting: starting),
        const SizedBox(height: 16),
        _primaryBtn(starting ? 'Start Work' : 'Complete Work', _busy ? null : () => _submitStage(starting: starting)),
      ]),
    );
  }

  Widget _doneCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Icon(Icons.verified_rounded, color: AppColors.success, size: 54),
        const SizedBox(height: 12),
        const Text('Service Completed', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 6),
        Text('The customer can now pay and rate you.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _actionCard({required IconData icon, required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.grey200), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)]),
      child: Column(children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: AppColors.primaryBlue, size: 28)),
        const SizedBox(height: 14),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 18),
        child,
      ]),
    );
  }

  Widget _otpField() {
    return TextField(
      controller: _otpCtrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 12),
      decoration: InputDecoration(
        counterText: '',
        hintText: '––––',
        hintStyle: TextStyle(letterSpacing: 12, color: AppColors.grey300),
        filled: true,
        fillColor: AppColors.grey50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.grey200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.grey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2)),
      ),
    );
  }

  Widget _photoPicker({required bool starting}) {
    return GestureDetector(
      onTap: _busy ? null : _capturePhoto,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _photo != null ? AppColors.primaryBlue : AppColors.grey300, width: 1.5, style: BorderStyle.solid),
          image: _photo != null ? DecorationImage(image: FileImage(_photo!), fit: BoxFit.cover) : null,
        ),
        child: _photo != null
            ? Align(alignment: Alignment.topRight, child: Padding(padding: const EdgeInsets.all(8), child: CircleAvatar(radius: 14, backgroundColor: Colors.black54, child: const Icon(Icons.refresh, size: 16, color: Colors.white))))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.camera_alt_rounded, color: AppColors.primaryBlue, size: 30),
                const SizedBox(height: 8),
                Text('Capture ${starting ? "before" : "after"} photo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ]),
      ),
    );
  }

  Widget _primaryBtn(String label, VoidCallback? onTap) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
    );
  }
}

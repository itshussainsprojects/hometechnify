import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/provider_controller.dart';

class CnicVerificationScreen extends StatefulWidget {
  const CnicVerificationScreen({super.key});

  @override
  State<CnicVerificationScreen> createState() => _CnicVerificationScreenState();
}

class _CnicVerificationScreenState extends State<CnicVerificationScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  final List<bool> _uploadedSteps = [false, false, false];
  final List<String?> _imagePaths = [null, null, null];

  final List<Map<String, dynamic>> _steps = [
    {'title': 'CNIC Front', 'subtitle': 'Upload clear photo of front side', 'icon': Icons.credit_card_rounded},
    {'title': 'CNIC Back', 'subtitle': 'Upload clear photo of back side', 'icon': Icons.credit_card_rounded},
    {'title': 'Live Selfie', 'subtitle': 'Take a live front-camera selfie holding your CNIC (gallery not allowed)', 'icon': Icons.face_retouching_natural_rounded},
  ];

  // Live selfie — front camera only, no gallery/file, so it can't be faked.
  Future<void> _takeLiveSelfie() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 75,
        maxWidth: 1080,
      );
      if (image != null) _setImage(image.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  void _showPickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Select Image Source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () { Navigator.pop(context); _pickFromCamera(); },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3))),
                      child: Column(children: [Icon(Icons.camera_alt_rounded, size: 40, color: AppColors.primaryBlue), const SizedBox(height: 12), const Text('Camera', style: TextStyle(fontWeight: FontWeight.w600))]),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () { Navigator.pop(context); _pickFromGallery(); },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
                      child: Column(children: [Icon(Icons.photo_library_rounded, size: 40, color: AppColors.success), const SizedBox(height: 12), const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600))]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () { Navigator.pop(context); _pickFromFile(); },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.folder_rounded, color: AppColors.grey600), const SizedBox(width: 10), Text('Choose from Files', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.grey600))]),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await ImagePicker().pickImage(source: ImageSource.camera);
      if (image != null) _setImage(image.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) _setImage(image.path);
    } catch (e) { debugPrint('Gallery error: $e'); }
  }

  Future<void> _pickFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) _setImage(result.files.single.path!);
    } catch (e) { debugPrint('File picker error: $e'); }
  }

  void _setImage(String path) {
    setState(() {
      _imagePaths[_currentStep] = path;
      _uploadedSteps[_currentStep] = true;
      if (_currentStep < 2) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _currentStep < 2) setState(() => _currentStep++);
        });
      }
    });
  }

  Future<void> _submitVerification() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (mounted) SnackBarHelper.showError(context, 'Please login again.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (mounted) SnackBarHelper.showInfo(context, 'Uploading documents...');

      // Uploaded concurrently, not one at a time — see uploadDocument's own
      // fix note for why the "unique" filename now also carries a base name.
      final uploads = await Future.wait([
        SupabaseService.uploadCnicFront(image: File(_imagePaths[0]!), userId: user.id),
        SupabaseService.uploadCnicBack(image: File(_imagePaths[1]!), userId: user.id),
        SupabaseService.uploadSelfieWithCnic(image: File(_imagePaths[2]!), userId: user.id),
      ]);
      final cnicFrontUrl = uploads[0];
      final cnicBackUrl = uploads[1];
      final selfieUrl = uploads[2];

      if (cnicFrontUrl == null || cnicBackUrl == null || selfieUrl == null) {
        if (mounted) SnackBarHelper.showError(context, 'Upload failed. Check internet connection.');
        setState(() => _isSubmitting = false);
        return;
      }

      // This used to only try SupabaseService.submitVerificationRequest — an
      // insert into a Supabase table whose anon role has no grant on the
      // public schema at all, so it silently failed on every submission and
      // the documents these providers uploaded never reached the backend's
      // provider_profile row admin actually reviews from. Saving through the
      // real backend endpoint is what makes them show up for verification.
      if (!mounted) return;
      final providerController = context.read<ProviderController>();
      final success = await providerController.updateProfile({
        'cnic_front': cnicFrontUrl,
        'cnic_back': cnicBackUrl,
        'selfie_url': selfieUrl,
      });

      if (!mounted) return;
      if (success) {
        SnackBarHelper.showSuccess(context, 'Submitted! Admin will review within 24-48 hours.');
        Navigator.pop(context, true);
      } else {
        SnackBarHelper.showError(context, 'Submission failed. Please try again.');
      }
    } catch (e) {
      if (mounted) SnackBarHelper.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final allUploaded = _uploadedSteps.every((e) => e);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary)),
        title: const Text('CNIC Verification', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildProgress(),
          const SizedBox(height: 32),
          _buildCurrentStep(),
          const SizedBox(height: 24),
          _buildStepsList(),
          const SizedBox(height: 24),
          _buildInfoCard(),
        ]),
      ),
      bottomNavigationBar: _buildBottomButton(horizontalPadding, allUploaded),
    );
  }

  Widget _buildProgress() {
    final progress = _uploadedSteps.where((e) => e).length / 3;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${_uploadedSteps.where((e) => e).length}/3 Completed', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
      ]),
      const SizedBox(height: 12),
      Container(
        height: 8,
        decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(4)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: Container(decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(4))),
        ),
      ),
    ]).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildCurrentStep() {
    final step = _steps[_currentStep];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)), child: Icon(step['icon'], size: 40, color: Colors.white)),
        const SizedBox(height: 20),
        Text(step['title'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(step['subtitle'], style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
          // Selfie step is live front-camera only; other steps allow upload.
          onTap: _currentStep == 2 ? _takeLiveSelfie : _showPickerDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_currentStep == 2 ? Icons.camera_front_rounded : Icons.upload_rounded, color: AppColors.primaryBlue),
              const SizedBox(width: 10),
              Text(_currentStep == 2 ? 'Take Live Selfie' : 'Upload Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
            ]),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildStepsList() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Verification Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      ...List.generate(3, (i) {
        final step = _steps[i];
        final isUploaded = _uploadedSteps[i];
        final isCurrent = _currentStep == i;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isCurrent ? AppColors.primaryBlue : (isUploaded ? AppColors.success : AppColors.grey200), width: isCurrent ? 2 : 1),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: isUploaded ? AppColors.success.withValues(alpha: 0.15) : AppColors.grey100, borderRadius: BorderRadius.circular(12)),
              child: Icon(isUploaded ? Icons.check_rounded : step['icon'], color: isUploaded ? AppColors.success : AppColors.grey500),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step['title'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(isUploaded ? 'Uploaded ✓' : 'Pending', style: TextStyle(fontSize: 12, color: isUploaded ? AppColors.success : AppColors.textSecondary)),
            ])),
            if (isUploaded)
              Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 18, color: Colors.white)),
          ]),
        );
      }),
    ]).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: AppColors.info),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Verification Time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text('Documents are usually verified within 24-48 hours.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildBottomButton(double horizontalPadding, bool allUploaded) {
    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(color: AppColors.white, boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -5))]),
      child: SafeArea(
        child: GestureDetector(
          onTap: (allUploaded && !_isSubmitting) ? _submitVerification : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            decoration: BoxDecoration(
              gradient: allUploaded ? AppColors.primaryGradient : null,
              color: allUploaded ? null : AppColors.grey200,
              borderRadius: BorderRadius.circular(14),
              boxShadow: allUploaded ? [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))] : null,
            ),
            child: Center(
              child: _isSubmitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(allUploaded ? 'Submit for Verification' : 'Complete All Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: allUploaded ? Colors.white : AppColors.grey400)),
            ),
          ),
        ),
      ),
    );
  }
}

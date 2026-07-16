import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../providers/provider_controller.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class AdvertiseServiceScreen extends StatefulWidget {
  const AdvertiseServiceScreen({super.key});

  @override
  State<AdvertiseServiceScreen> createState() => _AdvertiseServiceScreenState();
}

class _AdvertiseServiceScreenState extends State<AdvertiseServiceScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  String _selectedMethod = 'Easypaisa';
  File? _bannerImageFile;
  String? _voicePath; 
  bool _isRecording = false;
  bool _isPlaying = false;
  final double _bannerPrice = 500.0;
  final ImagePicker _picker = ImagePicker();
  
  // Audio
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _accountController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _submitForVerification() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final providerController = context.read<ProviderController>();

    if (_contentController.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please enter banner content')));
      return;
    }
    if (_accountController.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please enter your account number')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String? imageUrl;

      if (_bannerImageFile != null) {
        imageUrl = await providerController.uploadFile(_bannerImageFile!);
        if (imageUrl == null) {
           navigator.pop();
           messenger.showSnackBar(SnackBar(content: Text(providerController.errorMessage ?? 'Image upload failed')));
           return;
        }
      }

      String? voiceUrl;
      if (_voicePath != null) {
        voiceUrl = await providerController.uploadFile(File(_voicePath!));
        if (voiceUrl == null) {
           navigator.pop();
           messenger.showSnackBar(SnackBar(content: Text(providerController.errorMessage ?? 'Voice upload failed')));
           return;
        }
      }

      final success = await providerController.submitBannerRequest({
        'content': _contentController.text.trim(),
        'account_number': _accountController.text.trim(),
        'payment_method': _selectedMethod,
        'amount': _bannerPrice,
        'banner_image': imageUrl,
        'voice_note': voiceUrl,
      });

      if (!mounted) return;
      navigator.pop();

      if (success) {
        _showSuccessDialog();
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text(providerController.errorMessage ?? 'Submission failed'),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 28),
            const SizedBox(width: 10),
            const Text('Submitted!', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text('Your banner request has been submitted for approval.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close Dialog
              Navigator.pop(context); // Back to Screen
            },
            child: const Text('OK', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBannerImage(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() {
          _bannerImageFile = File(image.path);
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  void _pickBannerImageModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Image Source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickBannerImage(ImageSource.camera);
                  },
                ),
                _buildImageSourceOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickBannerImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _bannerImageFile = null;
    });
  }

  void _removeVoice() {
    setState(() {
      _voicePath = null;
      _isRecording = false;
      _isPlaying = false;
    });
    _audioPlayer.stop(); // Stop playback
    // _audioRecorder.stop(); // logic handled in toggle
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice description removed')),
    );
  }

  Future<void> _togglePlayback() async {
    if (_voicePath == null) return;
    
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(_voicePath!));
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        // Stop
        final path = await _audioRecorder.stop();
        setState(() {
          _isRecording = false;
          _voicePath = path;
        });
        if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Voice description recorded!'), backgroundColor: AppColors.primaryBlue),
             );
        }
      } else {
        // Start
        if (await _audioRecorder.hasPermission()) {
            final directory = await getApplicationDocumentsDirectory();
            final path = '${directory.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
            
            await _audioRecorder.start(const RecordConfig(), path: path);
            setState(() => _isRecording = true);
        } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission required')));
            }
        }
      }
    } catch (e) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recording failed: $e')));
      }
      setState(() => _isRecording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: Text(
          'Advertise Your Service',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w800,
            fontSize: isSmall ? 18 : 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Boost Your Reach',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Create a banner that will be visible to all potential customers in your area.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ).animate().fade().slideY(begin: 0.1),

            const SizedBox(height: 32),

            // Form Title
            const Text(
              'Banner Content',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),



            // Content Input
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _contentController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Describe your offer (e.g., 20% off on first AC Repair!)',
                  hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                  contentPadding: const EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
              ),
            ).animate().fade(delay: 100.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Multimedia Row
            Row(
              children: [
                // Image Picker
                Expanded(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickBannerImageModal,
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _bannerImageFile != null ? AppColors.primaryBlue : AppColors.grey200,
                              width: _bannerImageFile != null ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _bannerImageFile != null ? Icons.image_rounded : Icons.add_photo_alternate_rounded,
                                color: _bannerImageFile != null ? AppColors.primaryBlue : AppColors.textTertiary,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _bannerImageFile != null ? 'Image Added' : 'Add Image',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _bannerImageFile != null ? AppColors.primaryBlue : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_bannerImageFile != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _removeImage,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Voice Recorder
                Expanded(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_isRecording) {
                            _toggleRecording();
                          } else if (_voicePath != null) {
                            _togglePlayback();
                          } else {
                            _toggleRecording();
                          }
                        },
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: (_isRecording || _isPlaying) ? AppColors.primaryBlue.withValues(alpha: 0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (_voicePath != null || _isRecording || _isPlaying) ? AppColors.primaryBlue : AppColors.grey200,
                              width: (_voicePath != null || _isRecording || _isPlaying) ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isRecording)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(3, (i) => 
                                    Container(
                                      width: 4,
                                      height: 15,
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(2)),
                                    ).animate(onPlay: (controller) => controller.repeat())
                                     .scaleY(begin: 0.5, end: 1.5, duration: 400.ms, delay: (i * 100).ms, curve: Curves.easeInOut)
                                  ),
                                )
                              else if (_isPlaying)
                                const Icon(Icons.pause_circle_filled_rounded, color: AppColors.primaryBlue, size: 32)
                                  .animate(onPlay: (controller) => controller.repeat())
                                  .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.1, 1.1), duration: 500.ms, curve: Curves.easeInOut)
                              else
                                Icon(
                                  _voicePath != null ? Icons.play_circle_fill_rounded : Icons.mic_none_rounded,
                                  color: _voicePath != null ? AppColors.primaryBlue : AppColors.textTertiary,
                                  size: 32,
                                ),
                              const SizedBox(height: 8),
                              Text(
                                _isRecording ? 'Recording...' : (_isPlaying ? 'Playing...' : (_voicePath != null ? 'Listen Voice' : 'Add Voice')),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: (_voicePath != null || _isRecording || _isPlaying) ? AppColors.primaryBlue : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_voicePath != null && !_isRecording && !_isPlaying)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _removeVoice,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ).animate().fade(delay: 150.ms).slideY(begin: 0.1),

            const SizedBox(height: 32),

            // Price Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Advertising Fee',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Price set by Company',
                        style: TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Text(
                    'Rs. ${_bannerPrice.toInt()}',
                    style: TextStyle(fontSize: 22, color: AppColors.primaryBlue, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ).animate().fade(delay: 200.ms).slideY(begin: 0.1),

            const SizedBox(height: 32),

            // Payment Method Selection
            const Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  _buildPaymentMethodOption('Easypaisa', Icons.account_balance_wallet_rounded),
                  const Divider(height: 1, color: AppColors.grey100, indent: 56),
                  _buildPaymentMethodOption('JazzCash', Icons.account_balance_wallet_rounded),
                ],
              ),
            ).animate().fade(delay: 250.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Account Number Input
            const Text(
              'Account Number',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _accountController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Enter your 11 digit account number',
                  hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                  prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.primaryBlue, size: 20),
                  contentPadding: const EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
              ),
            ).animate().fade(delay: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 48),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitForVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                ),
                child: const Text(
                  'Submit for Verification',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ).animate().fade(delay: 300.ms).scale(curve: Curves.elasticOut),

            const SizedBox(height: 24),
            
            Center(
              child: Text(
                'Approval process typically takes 20 mins',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildPaymentMethodOption(String method, IconData icon) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.1) : AppColors.grey50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? AppColors.primaryBlue : AppColors.grey400, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              method,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primaryBlue : AppColors.grey300,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

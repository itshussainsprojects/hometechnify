// Provider Onboarding Screen - 3-Step Registration

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/constants.dart';
import 'package:provider/provider.dart';
import '../providers/provider_controller.dart';
import 'package:home_technify/core/utils/snackbar_helper.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/session_cache.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  State<ProviderOnboardingScreen> createState() => _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedExperience;

  /// The trade the provider actually signed up to do, as a REAL category id.
  ///
  /// This step used to offer a hardcoded list of six words — Plumber,
  /// Electrician, Cleaner, AC Repair, Carpenter, Painter — none of which were
  /// the platform's real categories, and none of which were ever sent to the
  /// backend. The provider's choice was thrown away and the server filed every
  /// single one of them under whatever category happened to be first in the
  /// table. Fourteen providers ended up as plumbers whether they were plumbers
  /// or not, and any new category an admin created stayed permanently empty.
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  // Upload states for CNIC verification (Indices: 0=Front, 1=Back, 2=Selfie, 3=Profile)
  final List<bool> _uploadedDocs = [false, false, false, false];
  final List<String?> _uploadedPaths = [null, null, null, null];

  /// Fetched from the backend, so a category the admin adds today is on the
  /// signup form today.
  List<dynamic> _categories = [];
  bool _loadingCategories = true;
  String? _categoryError;

  final List<String> _experiences = ['Less than 1 year', '1-3 years', '3-5 years', '5+ years'];

  /// Registration uploads real photos over a mobile connection — a slow
  /// network can genuinely take the better part of a minute even after
  /// parallelizing every upload. A single static spinner over that long
  /// looks identical to a frozen app, so this cycles through what's
  /// actually happening to make the wait read as progress, not a hang.
  int _submitStageIndex = 0;
  Timer? _submitStageTimer;
  static const _submitStages = [
    'Creating your account…',
    'Uploading your documents…',
    'Almost there…',
  ];

  void _startSubmitStageCycle() {
    _submitStageIndex = 0;
    _submitStageTimer?.cancel();
    _submitStageTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() {
        _submitStageIndex = (_submitStageIndex + 1) % _submitStages.length;
      });
    });
  }

  void _stopSubmitStageCycle() {
    _submitStageTimer?.cancel();
    _submitStageTimer = null;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });
    try {
      final res = await ApiService().dio.get('/categories');
      if (!mounted) return;
      setState(() {
        _categories = (res.data['data'] as List?) ?? [];
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoryError = 'Could not load the trade list';
        _loadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _submitStageTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showPickerDialog(int index) {
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromCamera(index);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.camera_alt_rounded, size: 40, color: AppColors.primaryBlue),
                          const SizedBox(height: 12),
                          const Text('Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromGallery(index);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.photo_library_rounded, size: 40, color: AppColors.success),
                          const SizedBox(height: 12),
                          const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera(int index) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      
      if (image != null) {
        setState(() {
          _uploadedDocs[index] = true;
          _uploadedPaths[index] = image.path;
        });
      }
    } catch (e) {
      debugPrint('Camera error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open camera: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery(int index) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        setState(() {
          _uploadedDocs[index] = true;
          _uploadedPaths[index] = result.files.single.path;
        });
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  void _showFullScreenImage(String path, String label) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextStep() async {
    if (_currentStep < 2) {
      // Validate steps
      if (_currentStep == 0) {
        if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _emailController.text.isEmpty || (!_isGoogleAuth && _passwordController.text.isEmpty)) {
          SnackBarHelper.showError(context, "Please fill all fields");
          return;
        }
        // Google sign-in skips password entirely (there is no password to
        // confirm) — this check only applies to the manual email/password path.
        // It used to run only at final submit, after Service Details AND CNIC
        // upload were already filled in — a mismatched password meant redoing
        // two more steps just to find out.
        if (!_isGoogleAuth && _passwordController.text != _confirmPasswordController.text) {
          SnackBarHelper.showError(context, "Passwords do not match");
          return;
        }
      } else if (_currentStep == 1) {
        if (_selectedCategoryId == null || _selectedExperience == null) {
          SnackBarHelper.showError(context, "Please select your trade and experience");
          return;
        }
      }
      setState(() => _currentStep++);
    } else {
      // Complete Registration
      _handleRegistration();
    }
  }

  bool _isGoogleAuth = false;

  void _handleRegistration() async {
    // Validate password match if NOT Google Auth
    if (!_isGoogleAuth) {
      if (_passwordController.text != _confirmPasswordController.text) {
        if (mounted) SnackBarHelper.showError(context, "Passwords do not match");
        return;
      }
    }

    // Check standard verification docs (0, 1, 2)
    bool docsUploaded = _uploadedDocs[0] && _uploadedDocs[1] && _uploadedDocs[2];
    
    if (!docsUploaded) {
       if (mounted) {
         final skipResult = await showDialog<bool>(
           context: context,
           builder: (context) => AlertDialog(
             title: const Text('Documents Not Uploaded'),
             content: const Text('You haven\'t uploaded all verification documents. Do you want to skip for now? (You can upload later in profile)'),
             actions: [
               TextButton(
                 onPressed: () => Navigator.pop(context, false),
                 child: const Text('Upload Now'),
               ),
               TextButton(
                 onPressed: () => Navigator.pop(context, true),
                 child: const Text('Skip'),
               ),
             ],
           ),
         );
         
         if (skipResult == false) {
           if (mounted) setState(() => _isLoading = false);
           return;
         }
       }
    }

    try {
      if (mounted) setState(() => _isLoading = true);
      _startSubmitStageCycle();
      
      User? user;
      
      if (_isGoogleAuth) {
        // Use existing Google User
        user = FirebaseAuthService.currentUser;
        if (user == null) throw Exception("Google User not found");
      } else {
        // 1. Create Firebase Auth Account with Email/Password
        final userCredential = await FirebaseAuthService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          onError: (error) {
            if (mounted) {
              setState(() => _isLoading = false);
              _stopSubmitStageCycle();
              SnackBarHelper.showError(context, error);
            }
          },
        );
        user = userCredential?.user;
      }

      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        _stopSubmitStageCycle();
        return;
      }

      // 2. Upload every selected image (profile pic + CNIC front/back/selfie)
      // in one batch. These four uploads have no dependency on each other —
      // they used to go one at a time (profile pic, THEN front, THEN back,
      // THEN selfie), four sequential network round-trips stacked up before
      // the "Verification Pending" dialog could ever appear. Concurrently,
      // the whole batch costs as long as the single slowest upload.
      final userId = user.uid;
      final uploads = await Future.wait([
        (_uploadedDocs[3] && _uploadedPaths[3] != null)
            ? SupabaseService.uploadDocument(file: File(_uploadedPaths[3]!), fileName: 'profile.jpg', folder: 'avatars', userId: userId)
            : Future.value(null),
        (_uploadedDocs[0] && _uploadedPaths[0] != null)
            ? SupabaseService.uploadCnicFront(image: File(_uploadedPaths[0]!), userId: userId)
            : Future.value(null),
        (_uploadedDocs[1] && _uploadedPaths[1] != null)
            ? SupabaseService.uploadCnicBack(image: File(_uploadedPaths[1]!), userId: userId)
            : Future.value(null),
        (_uploadedDocs[2] && _uploadedPaths[2] != null)
            ? SupabaseService.uploadSelfieWithCnic(image: File(_uploadedPaths[2]!), userId: userId)
            : Future.value(null),
      ]);
      final profileUrl = uploads[0];
      final cnicFrontUrl = uploads[1];
      final cnicBackUrl = uploads[2];
      final selfieUrl = uploads[3];

      // 3-5. Every remaining write only depends on the uploaded URLs above,
      // not on each other — Firebase Auth's own profile, the Firestore
      // fallback doc, and the backend sync were firing off one after another
      // for no reason, each one a separate network round-trip stacked onto
      // the wait before the "Verification Pending" dialog could appear.
      // Running them together costs as long as the slowest one instead of
      // the sum of all three.
      //
      // The Supabase `provider_verifications` insert that used to run here
      // has been removed: that table's anon role has no grant on the public
      // schema at all (every insert returned "permission denied for schema
      // public"), so it silently failed on every single registration and
      // never reached anyone. The admin panel was already fixed to read
      // verification documents straight off provider_profile (cnic_front /
      // cnic_back / selfie_url, written by the updateProfile call below) —
      // this call was dead weight that only added a guaranteed-to-fail
      // network round-trip to the wait.
      final currentUser = user;
      await Future.wait([
        () async {
          await currentUser.updateDisplayName(_nameController.text.trim());
          if (profileUrl != null) {
            await currentUser.updatePhotoURL(profileUrl);
          }
        }(),
        FirebaseFirestore.instance.collection('users').doc(userId).set({
            'uid': userId,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': "+92${_phoneController.text.trim()}",
            'role': 'PROVIDER',
            'service': _selectedCategoryName,
            'experience': _selectedExperience,
            'profileImage': profileUrl ?? user.photoURL,
            'status': 'pending_verification', // STRICTLY Pending
            'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)), // Merge to avoid overwriting existing fields if any
        ApiService().syncUser(role: 'PROVIDER').catchError((e) {
          debugPrint('Backend sync error: $e');
        }),
      ]);

      // 7. Update Provider Profile — including the TRADE they just picked.
      //
      // service_category_id was commented out here to dodge a foreign-key error,
      // and it was never put back. It is not an optional stat: job matching is by
      // category, so without it the backend fell back to "whatever category is
      // first in the table" and every provider became a plumber. A real category
      // id from the API cannot trip the foreign key.
      try {
        if (!mounted) return;
        final providerController = context.read<ProviderController>();
        await providerController.updateProfile({
          'bio': "Experienced ${_selectedCategoryName ?? 'Professional'}",
          'hourly_rate': 1000,
          'service_category_id': _selectedCategoryId,
          'experience': _selectedExperience,
          'city': _cityController.text.trim(),
          'cnic_front': cnicFrontUrl ?? "",
          'cnic_back': cnicBackUrl ?? "",
          'selfie_url': selfieUrl ?? "",
        });
      } catch(e) {
         debugPrint('Provider profile update error: $e');
      }

      // SessionCache is what the splash screen's fast-path uses to decide
      // "dashboard or pending" on the NEXT cold start, without waiting on a
      // network round-trip. It is keyed to the device, not the account — if
      // it's left holding whatever an earlier session on this device cached
      // (e.g. an already-verified provider, or no provider at all), a brand
      // new unverified registration would inherit that stale flag and the
      // fast-path would send them straight to the live dashboard, skipping
      // the verification gate entirely. Seed it correctly the moment the
      // account is actually created.
      await SessionCache.save('PROVIDER', providerPending: true);

      if (mounted) {
        setState(() => _isLoading = false);
        _stopSubmitStageCycle();
        _showVerificationPendingDialog();
      }

    } catch (e) {
      _stopSubmitStageCycle();
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.showError(context, "Registration Error: $e");
      }
      debugPrint('Registration error: $e');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuthService.signInWithGoogle(
        onError: (error) {
          setState(() => _isLoading = false);
          if (mounted) SnackBarHelper.showError(context, error);
        },
      );

      if (userCredential == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userId = userCredential.user?.uid;
      if (userId != null) {
        // Check if already exists as CUSTOMER
        final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (doc.exists) {
           final data = doc.data();
           if (data != null && data['role'] == 'CUSTOMER') {
             await FirebaseAuthService.signOut();
             if (mounted) {
               setState(() => _isLoading = false);
               SnackBarHelper.showError(context, "Account exists as Customer. Use a different account.");
             }
             return;
           }
        }
        
        // Populate fields from Google Data
        _nameController.text = userCredential.user?.displayName ?? '';
        _emailController.text = userCredential.user?.email ?? '';
        // Note: Google doesn't usually provide phone number, so user must enter it.
      }
      
      setState(() {
        _isLoading = false;
        _isGoogleAuth = true; // Flag to skip email auth step
        _currentStep = 1; // Move to Service Info
      });
      
      if (mounted) SnackBarHelper.showSuccess(context, 'Signed in with Google! Please complete your profile.');

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) SnackBarHelper.showError(context, "Google Sign-In Error: $e");
    }
  }

  void _showVerificationPendingDialog() {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmall ? 20 : 24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isSmall ? 20 : 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: isSmall ? 70 : 90,
                  height: isSmall ? 70 : 90,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.hourglass_top_rounded, size: isSmall ? 38 : 50, color: AppColors.warning),
                ),
                SizedBox(height: isSmall ? 16 : 24),
                
                // Title
                Text(
                  'Verification Pending',
                  style: TextStyle(fontSize: isSmall ? 18 : 22, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isSmall ? 8 : 12),
                
                // Description
                Text(
                  'Your information is being verified by HomeTechnify team. You will receive an email notification once approved.',
                  style: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.textSecondary, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isSmall ? 14 : 20),
                
                // Time info
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: isSmall ? 10 : 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time_rounded, size: isSmall ? 16 : 18, color: AppColors.primaryBlue),
                      SizedBox(width: isSmall ? 6 : 8),
                      Expanded(
                        child: Text(
                          'Verified within 1 hour',
                          style: TextStyle(
                            fontSize: isSmall ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmall ? 14 : 20),
                
                // Email info
                Row(
                  children: [
                    Icon(Icons.email_outlined, size: isSmall ? 16 : 18, color: AppColors.textSecondary),
                    SizedBox(width: isSmall ? 6 : 8),
                    Expanded(
                      child: Text(
                        'Check your email for approval notification',
                        style: TextStyle(fontSize: isSmall ? 11 : 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmall ? 20 : 28),
                
                // OK Button
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pushReplacementNamed(context, '/provider/login');
                  },
                  child: Container(
                    width: double.infinity,
                    height: isSmall ? 46 : 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(isSmall ? 12 : 14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Got It',
                        style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => _currentStep > 0 ? setState(() => _currentStep--) : Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: const Text('Provider Registration', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildProgressBar(horizontalPadding),
              // Google Sign-In Option (only on first step)
              if (_currentStep == 0) _buildGoogleSignInOption(horizontalPadding),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(horizontalPadding),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentStep == 0
                        ? _buildPersonalInfo()
                        : _currentStep == 1
                            ? _buildServiceInfo()
                            : _buildVerification(),
                  ),
                ),
              ),
              _buildBottomButton(horizontalPadding),
            ],
          ),
          // Real photo uploads over mobile data can genuinely take the
          // better part of a minute — a plain spinner over that long looks
          // identical to a frozen app. This blocks input and cycles through
          // what's actually happening so the wait reads as progress.
          if (_isLoading && _currentStep == 2) _buildSubmittingOverlay(),
        ],
      ),
    );
  }

  Widget _buildSubmittingOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _submitStages[_submitStageIndex],
                      key: ValueKey(_submitStageIndex),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This can take a minute on a slow connection — please don\'t close the app.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInOption(double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
      child: Column(
        children: [
          // Divider with "OR"
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('OR', style: TextStyle(color: AppColors.grey400, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          // Google Sign-In Button
          GestureDetector(
            onTap: _isLoading ? null : _handleGoogleSignIn,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.grey200),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://www.google.com/favicon.ico',
                    height: 24,
                    width: 24,
                    errorBuilder: (context, error, stack) => const Icon(Icons.g_mobiledata, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Skip manual registration - use your Google account',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.primaryGradient : null,
                color: isActive ? null : AppColors.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('personal'),
      children: [
        const Text('Personal Information', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Tell us about yourself', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        
        // Profile Picture Picker
        Center(
          child: GestureDetector(
            onTap: () => _showPickerDialog(3), // Index 3 for Profile Pic
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.grey200,
                    shape: BoxShape.circle,
                    image: _uploadedPaths[3] != null
                        ? DecorationImage(image: FileImage(File(_uploadedPaths[3]!)), fit: BoxFit.cover)
                        : null,
                    border: Border.all(color: AppColors.grey300, width: 2),
                  ),
                  child: _uploadedPaths[3] == null
                      ? const Icon(Icons.person_rounded, size: 50, color: AppColors.grey400)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        _buildTextField('Full Name', 'Enter your full name', Icons.person_outline_rounded, _nameController),
        const SizedBox(height: 20),
        _buildPhoneField(),
        const SizedBox(height: 20),
        _buildTextField('Email Address', 'Enter your email', Icons.email_outlined, _emailController, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 20),
        _buildTextField('City / Area', 'e.g. Gulberg, Lahore', Icons.location_city_rounded, _cityController),
        const SizedBox(height: 20),
        _buildPasswordField('Password', 'Enter your password', _passwordController, _obscurePassword, () => setState(() => _obscurePassword = !_obscurePassword)),
        const SizedBox(height: 20),
        _buildPasswordField('Confirm Password', 'Confirm your password', _confirmPasswordController, _obscureConfirmPassword, () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildServiceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('service'),
      children: [
        const Text('Service Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('What service do you provide?', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 32),
        const Text('Select your trade', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'You will only be shown jobs in this trade.',
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
        const SizedBox(height: 12),
        _buildTradePicker(),
        const SizedBox(height: 28),
        const Text('Experience', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...(_experiences.map((exp) => _buildRadioOption(exp, _selectedExperience == exp, () => setState(() => _selectedExperience = exp)))),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('verification'),
      children: [
        const Text('Verification', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Upload documents for verification', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 32),
        _buildUploadCard('CNIC Front', Icons.credit_card_rounded, 0),
        const SizedBox(height: 16),
        _buildUploadCard('CNIC Back', Icons.credit_card_rounded, 1),
        const SizedBox(height: 16),
        _buildUploadCard('Selfie with CNIC', Icons.camera_alt_rounded, 2),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.info),
              const SizedBox(width: 12),
              Expanded(child: Text('Documents will be verified within 24 hours', style: TextStyle(fontSize: 13, color: AppColors.info))),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildTextField(String label, String hint, IconData icon, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textHint),
              prefixIcon: Icon(icon, color: AppColors.grey400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, String hint, TextEditingController controller, bool obscure, VoidCallback onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textHint),
              prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.grey400),
              suffixIcon: GestureDetector(
                onTap: onToggle,
                child: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.grey400,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(border: Border(right: BorderSide(color: AppColors.grey200))),
                child: const Text('+92', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  decoration: InputDecoration(
                    hintText: '300 1234567',
                    hintStyle: TextStyle(color: AppColors.textHint),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The real trades, from the backend.
  ///
  /// This was a hardcoded list — Plumber, Electrician, Cleaner, AC Repair,
  /// Carpenter, Painter — that matched none of the platform's actual categories
  /// and was thrown away on submit. A provider could pick "Electrician" and be
  /// filed as a plumber. Reading the list from the API also means a category the
  /// admin adds today appears on this form today.
  Widget _buildTradePicker() {
    if (_loadingCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_categoryError != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_categoryError!,
                style: const TextStyle(fontSize: 13, color: AppColors.error)),
          ),
          TextButton(onPressed: _loadCategories, child: const Text('Retry')),
        ],
      );
    }

    // The admin has not set up any trades yet. Say so plainly rather than
    // showing an empty box the provider cannot get past.
    if (_categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'No trades are available yet. Please contact support — an admin has to '
          'add them before providers can sign up.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((c) {
        final id = c['id'] as String;
        final name = (c['name'] ?? '') as String;
        return _buildChip(
          name,
          _selectedCategoryId == id,
          () => setState(() {
            _selectedCategoryId = id;
            _selectedCategoryName = name;
          }),
        );
      }).toList(),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? null : Border.all(color: AppColors.grey200),
        ),
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textPrimary)),
      ),
    );
  }

  Widget _buildRadioOption(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? AppColors.primaryBlue : AppColors.grey200)),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? AppColors.primaryBlue : AppColors.grey300, width: 2)),
              child: isSelected ? Center(child: Container(width: 12, height: 12, decoration: BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle))) : null,
            ),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(String label, IconData icon, int index) {
    final isUploaded = _uploadedDocs[index];
    final path = _uploadedPaths[index];
    final fileExists = path != null && File(path).existsSync();

    return GestureDetector(
      onTap: isUploaded && fileExists 
          ? () => _showFullScreenImage(path, label)
          : () => _showPickerDialog(index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUploaded ? AppColors.success.withValues(alpha: 0.5) : AppColors.grey200, 
            width: isUploaded ? 1.5 : 1,
            style: BorderStyle.solid
          ),
          boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            if (isUploaded && fileExists)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Image.file(File(path), width: 50, height: 50, fit: BoxFit.cover),
                    Container(
                      width: 50,
                      height: 50,
                      color: Colors.black.withValues(alpha: 0.2),
                      child: const Center(child: Icon(Icons.zoom_in_rounded, size: 20, color: Colors.white)),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: (isUploaded ? AppColors.success : AppColors.primaryBlue).withValues(alpha: 0.1), 
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Icon(isUploaded ? Icons.check_rounded : icon, color: isUploaded ? AppColors.success : AppColors.primaryBlue),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  if (isUploaded)
                    Text('Click to preview document', style: TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w500))
                  else
                    Text('Upload for verification', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (isUploaded)
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient, 
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Upload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(double horizontalPadding) {
    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(color: AppColors.white, boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -5))]),
      child: SafeArea(
        child: GestureDetector(
          onTap: _isLoading ? null : _nextStep,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: _isLoading ? null : AppColors.primaryGradient,
              color: _isLoading ? AppColors.grey200 : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _isLoading ? [] : [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _currentStep == 2 ? 'Complete Registration' : 'Continue',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

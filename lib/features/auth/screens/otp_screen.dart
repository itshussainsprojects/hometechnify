// OTP Verification Screen - Firebase Phone Authentication

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pinput/pinput.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/api_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  int _resendTimer = 60;
  Timer? _timer;
  String? _phoneNumber;
  String? _name;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
    _phoneNumber = args['phone'] as String?;
    _name = args['name'] as String?;
      }
  }

  void _startTimer() {
    _resendTimer = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() => _errorMessage = 'Please enter complete 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await FirebaseAuthService.verifyOtp(
      otp: _otpController.text,
      onError: (error) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      },
    );


    if (result != null && mounted) {
      // Update display name if provided (New Registration)
      if (_name != null && _name!.isNotEmpty) {
        await FirebaseAuthService.updateDisplayName(_name!);
      }

      // Sync with Backend
      try {
        await ApiService().syncUser();
      } catch (e) {
        debugPrint('Sync failed: $e');
        // Continue anyway, maybe show warning?
      }
      
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushNamedAndRemoveUntil(context, '/location-permission', (route) => false);
    }
  }

  Future<void> _resendCode() async {
    if (_resendTimer > 0 || _phoneNumber == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await FirebaseAuthService.sendOtp(
      phoneNumber: _phoneNumber!,
      onCodeSent: (_) {
        setState(() => _isLoading = false);
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New code sent!'), backgroundColor: Colors.green),
        );
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      },
      onAutoVerify: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.08),
              Colors.white,
              AppColors.primaryBlue.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms),

                SizedBox(height: isSmall ? 40 : 60),

                // Header
                _buildHeader(isSmall),

                SizedBox(height: isSmall ? 40 : 60),

                // OTP Input
                _buildOtpInput(isSmall),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
                  ).animate().fadeIn().shake(),
                ],

                SizedBox(height: isSmall ? 32 : 48),

                // Verify Button
                _buildVerifyButton(isSmall),

                const SizedBox(height: 24),

                // Resend Code
                _buildResendSection(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmall) {
    return Column(
      children: [
        Container(
          width: isSmall ? 80 : 100,
          height: isSmall ? 80 : 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryBlue, AppColors.primaryBlue.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.sms_outlined, color: Colors.white, size: isSmall ? 40 : 48),
        ),
        const SizedBox(height: 24),
        Text(
          'Verification Code',
          style: TextStyle(
            fontSize: isSmall ? 28 : 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enter the 6-digit code sent to',
          style: TextStyle(fontSize: 15, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          _phoneNumber ?? 'your phone',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2);
  }

  Widget _buildOtpInput(bool isSmall) {
    final defaultPinTheme = PinTheme(
      width: isSmall ? 48 : 56,
      height: isSmall ? 56 : 64,
      textStyle: TextStyle(
        fontSize: isSmall ? 22 : 26,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1A1A2E),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );

    return Pinput(
      controller: _otpController,
      length: 6,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: defaultPinTheme.copyWith(
        decoration: defaultPinTheme.decoration!.copyWith(
          border: Border.all(color: AppColors.primaryBlue, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      submittedPinTheme: defaultPinTheme.copyWith(
        decoration: defaultPinTheme.decoration!.copyWith(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.1),
              AppColors.primaryBlue.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: AppColors.primaryBlue, width: 2),
        ),
      ),
      errorPinTheme: defaultPinTheme.copyWith(
        decoration: defaultPinTheme.decoration!.copyWith(
          border: Border.all(color: AppColors.error, width: 2),
        ),
      ),
      onCompleted: (_) => _verifyOtp(),
    ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildVerifyButton(bool isSmall) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verifyOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Verify & Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(width: 10),
                  Icon(Icons.verified_user_outlined, size: 22),
                ],
              ),
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3);
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        Text(
          "Didn't receive the code?",
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        _resendTimer > 0
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    'Resend in ${_resendTimer}s',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              )
            : TextButton(
                onPressed: _resendCode,
                child: const Text(
                  'Resend Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
      ],
    ).animate().fadeIn(delay: 600.ms);
  }
}

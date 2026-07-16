import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../data/repositories/remote_auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _repo = RemoteAuthRepository();

  int _currentStep = 0; // 0: email, 1: OTP, 2: new password
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email address');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _repo.sendPasswordResetOtp(_emailController.text.trim());
      if (!mounted) return;
      setState(() { _isLoading = false; _currentStep = 1; });
      _showInfo('OTP Sent!', 'A verification code has been sent to ${_emailController.text.trim()}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 4) {
      _showError('Please enter the verification code');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _repo.verifyPasswordResetOtp(
        _emailController.text.trim(),
        _otpController.text.trim(),
      );
      if (!mounted) return;
      setState(() { _isLoading = false; _currentStep = 2; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      _showError('Please fill all fields');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }
    if (_newPasswordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _repo.resetPassword(
        _emailController.text.trim(),
        _otpController.text.trim(),
        _newPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.error_outline_rounded, size: 35, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity, height: 44,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('OK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfo(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_read_rounded, size: 32, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message, style: TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity, height: 44,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('OK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.check_rounded, size: 45, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('Password Reset!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Your password has been updated. Please login with your new password.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Back to Login', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final isSmall = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: Text(
          'Forgot Password',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: isSmall ? 17 : 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressIndicator(),
            SizedBox(height: isSmall ? 28 : 36),
            if (_currentStep == 0) _buildEmailStep(isSmall),
            if (_currentStep == 1) _buildOtpStep(isSmall),
            if (_currentStep == 2) _buildNewPasswordStep(isSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
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
    );
  }

  Widget _buildEmailStep(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter Your Email', style: TextStyle(fontSize: isSmall ? 22 : 26, fontWeight: FontWeight.w800)).animate().fadeIn(duration: 400.ms),
        SizedBox(height: isSmall ? 6 : 8),
        Text('We will send a verification code to reset your password', style: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.textSecondary)).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        SizedBox(height: isSmall ? 28 : 36),
        Text('Email Address', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600)),
        SizedBox(height: isSmall ? 6 : 8),
        Container(
          decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: TextStyle(color: AppColors.textHint),
              prefixIcon: Icon(Icons.email_outlined, color: AppColors.grey400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        SizedBox(height: isSmall ? 32 : 40),
        _buildButton('Send OTP', _sendOtp, isSmall),
      ],
    );
  }

  Widget _buildOtpStep(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter OTP', style: TextStyle(fontSize: isSmall ? 22 : 26, fontWeight: FontWeight.w800)).animate().fadeIn(duration: 400.ms),
        SizedBox(height: isSmall ? 6 : 8),
        Text('Enter the code sent to ${_emailController.text.trim()}', style: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.textSecondary)).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        SizedBox(height: isSmall ? 28 : 36),
        Text('Verification Code', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600)),
        SizedBox(height: isSmall ? 6 : 8),
        Container(
          decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
          child: TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 12),
            decoration: InputDecoration(
              hintText: '• • • • • •',
              hintStyle: TextStyle(color: AppColors.textHint, letterSpacing: 12),
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _sendOtp,
            child: Text('Resend OTP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
          ),
        ),
        SizedBox(height: isSmall ? 24 : 32),
        _buildButton('Verify OTP', _verifyOtp, isSmall),
      ],
    );
  }

  Widget _buildNewPasswordStep(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create New Password', style: TextStyle(fontSize: isSmall ? 22 : 26, fontWeight: FontWeight.w800)).animate().fadeIn(duration: 400.ms),
        SizedBox(height: isSmall ? 6 : 8),
        Text('Your new password must be at least 6 characters', style: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.textSecondary)).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        SizedBox(height: isSmall ? 28 : 36),
        Text('New Password', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600)),
        SizedBox(height: isSmall ? 6 : 8),
        _buildPasswordField(_newPasswordController, 'Enter new password', _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
        SizedBox(height: isSmall ? 16 : 20),
        Text('Confirm Password', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600)),
        SizedBox(height: isSmall ? 6 : 8),
        _buildPasswordField(_confirmPasswordController, 'Confirm new password', _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
        SizedBox(height: isSmall ? 32 : 40),
        _buildButton('Reset Password', _resetPassword, isSmall),
      ],
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String hint, bool obscure, VoidCallback onToggle) {
    return Container(
      decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textHint),
          prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.grey400),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.grey400),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onTap, bool isSmall) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: isSmall ? 52 : 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }
}

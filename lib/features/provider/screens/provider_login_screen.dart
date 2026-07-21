// Provider Login Screen - Firebase Phone OTP, Email, Google Authentication

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import 'package:home_technify/core/utils/snackbar_helper.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers/auth_provider.dart';

class ProviderLoginScreen extends StatefulWidget {
  const ProviderLoginScreen({super.key});

  @override
  State<ProviderLoginScreen> createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }




  Future<void> _loginWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      if (mounted) SnackBarHelper.showError(context, "Please fill all fields");
      return;
    }

    setState(() => _isLoading = true);

    // Go through AuthProvider so the backend can enforce role separation: a
    // CUSTOMER account must not be able to sign in on the provider app.
    final authProvider = context.read<AuthProvider>();
    await authProvider.loginWithEmail(email, password, role: 'PROVIDER');

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (authProvider.status == AuthStatus.success) {
      _routeAfterLogin(authProvider);
    } else {
      SnackBarHelper.showError(
          context, authProvider.errorMessage ?? 'Login failed');
    }
  }

  // A provider whose documents are still under admin review must land on the
  // pending screen, not the dashboard. Cold app start already gates this
  // (splash_screen checks user.status), but logging in is a separate path
  // that skipped the same check — so logging out and back in was a way to
  // walk straight past verification into the live dashboard.
  void _routeAfterLogin(AuthProvider authProvider) {
    final route = authProvider.user?.status == 'pending_verification'
        ? '/provider/pending'
        : '/provider/dashboard';
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();

    final result = await FirebaseAuthService.signInWithGoogle(
      onError: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          SnackBarHelper.showError(context, error);
        }
      },
    );

    if (!mounted) return;

    if (result == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Block customers from using the provider login
    try {
      final userId = FirebaseAuthService.getUserId();
      if (userId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['role'] == 'CUSTOMER') {
            await FirebaseAuthService.signOut();
            if (mounted) {
              setState(() => _isLoading = false);
              SnackBarHelper.showError(context,
                  'This account is registered as a Customer. Please use a different Google account.');
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Role check error: $e');
    }

    // Sync backend in background — don't block navigation
    ApiService().syncUser(role: 'PROVIDER').catchError((e) {
      debugPrint('Provider Google sync skipped: $e');
    });

    // Populate AuthProvider so provider dashboard has user data
    await authProvider.checkAuthStatus();

    if (!mounted) return;
    setState(() => _isLoading = false);
    _routeAfterLogin(authProvider);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final isVerySmall = size.height < 600;
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isSmall ? 30 : 50),
              
              // Logo / Header
              Center(
                child: Container(
                  width: isSmall ? 70 : 80,
                  height: isSmall ? 70 : 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.home_repair_service_rounded, color: Colors.white, size: 40),
                ),
              ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
              
              SizedBox(height: isSmall ? 20 : 30),
              
              Center(
                child: Text(
                  'Provider Login',
                  style: TextStyle(
                    fontSize: isSmall ? 24 : 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              
              const SizedBox(height: 8),
              
              Center(
                child: Text(
                  'Sign in with your email',
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
              
              SizedBox(height: isSmall ? 30 : 40),
              
              // Email + password only, plus Google below. This screen used to
              // DEFAULT to a phone + "Send OTP" flow, with email hidden behind a
              // toggle — and that OTP path called syncUser() with no role, so it
              // walked straight past the check that stops a customer signing in
              // on the provider app.
              _buildEmailForm(isSmall, isVerySmall),
              
              SizedBox(height: isSmall ? 16 : 20),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(color: AppColors.grey400)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ).animate().fadeIn(delay: 500.ms),

              SizedBox(height: isSmall ? 16 : 20),

              // Google Sign In Button
              GestureDetector(
                onTap: _isLoading ? null : _loginWithGoogle,
                child: Container(
                  width: double.infinity,
                  height: isVerySmall ? 48 : isSmall ? 52 : 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.grey200),
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
                        'Sign in with Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
              
              SizedBox(height: isSmall ? 20 : 24),

              SizedBox(height: isSmall ? 24 : 32),
              
              // Register Link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/provider/onboarding');
                      },
                      child: Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildEmailForm(bool isSmall, bool isVerySmall) {
    return Column(
      children: [
        // Email Field
        _buildTextField(
          controller: _emailController,
          hint: 'Enter your email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          isSmall: isSmall,
        ),
        
        SizedBox(height: isSmall ? 14 : 18),
        
        // Password Field
        _buildPasswordField(isSmall),
        
        SizedBox(height: isSmall ? 24 : 32),
        
        // Login Button
        GestureDetector(
          onTap: _isLoading ? null : _loginWithEmail,
          child: Container(
            width: double.infinity,
            height: isVerySmall ? 48 : isSmall ? 52 : 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
      ],
    );
  }



  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool isSmall = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(isSmall ? 12 : 14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: isSmall ? 14 : 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: isSmall ? 14 : 15),
          prefixIcon: Icon(icon, color: AppColors.grey400, size: isSmall ? 20 : 22),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(isSmall ? 14 : 16),
        ),
      ),
    );
  }

  Widget _buildPasswordField(bool isSmall) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(isSmall ? 12 : 14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: TextStyle(fontSize: isSmall ? 14 : 15),
        decoration: InputDecoration(
          hintText: 'Enter your password',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: isSmall ? 14 : 15),
          prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.grey400, size: isSmall ? 20 : 22),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.grey400,
              size: isSmall ? 20 : 22,
            ),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(isSmall ? 14 : 16),
        ),
      ),
    );
  }
}

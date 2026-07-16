// Premium Login Screen - Firebase Phone, Email, Google Authentication

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/widgets/techy_animation.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/services/api_service.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    // Use AuthProvider instead of direct service call
    final authProvider = context.read<AuthProvider>();
    
    // AuthProvider handles loading state internally, but we might want local loading too
    setState(() => _isLoading = true);
    
    await authProvider.loginWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
      role: 'CUSTOMER',
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (authProvider.status == AuthStatus.success) {
      if (authProvider.user?.role == 'PROVIDER') {
         // Force fetch provider dashboard stats too if needed?
         // ProviderController handles that on dashboard init.
      }
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      _showError(authProvider.errorMessage ?? 'Login failed');
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();

    final result = await FirebaseAuthService.signInWithGoogle(
      onError: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError(error);
        }
      },
    );

    if (!mounted) return;

    // null = user cancelled (onError already showed error if it failed)
    if (result == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Sync backend in background — do NOT block navigation on backend failure
      ApiService().syncUser().catchError((e) {
        debugPrint('Google login: backend sync skipped: $e');
      });

      // Load user data from Firebase/Firestore (falls back gracefully when backend is down)
      await authProvider.checkAuthStatus();

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      debugPrint('Google login post-auth error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        // Still navigate — Firebase auth succeeded even if data load had issues
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    }
  }

  void _showError(String message) {
    SnackBarHelper.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    // After logout the login screen is the ONLY route on the stack - a
    // system back would pop it and leave a black screen. Go back normally
    // when there's history, otherwise return to the splash screen.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          nav.pushReplacementNamed('/');
        }
      },
      child: Scaffold(
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
                ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2),

                SizedBox(height: isSmall ? 24 : 40),

                // Header
                _buildHeader(isSmall),

                SizedBox(height: isSmall ? 32 : 48),

                // Email + password is the only way in, plus Google below.
                // The screen used to DEFAULT to a phone number + "Send OTP"
                // flow, with email hidden behind a toggle — so the OTP step was
                // the first thing every returning customer hit.
                _buildEmailForm(isSmall),

                SizedBox(height: isSmall ? 16 : 24),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: Colors.grey[600])),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ).animate().fadeIn(delay: 500.ms),

                SizedBox(height: isSmall ? 16 : 24),

                // Social Login Buttons
                _buildSocialButtons(isSmall),

                SizedBox(height: isSmall ? 16 : 24),

                // Sign Up Link
                _buildSignUpLink(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(bool isSmall) {
    return Column(
      children: [
        // Techy mascot welcomes the user
        TechyStill(height: isSmall ? 110 : 130),
        const SizedBox(height: 12),
        Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: isSmall ? 28 : 32,
            fontWeight: FontWeight.w800,
            color: AppColors.brandNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in with your email',
          style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2);
  }


  Widget _buildEmailForm(bool isSmall) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ).animate().fadeIn(delay: 350.ms),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
              child: Text(
                'Forgot Password?',
                style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
              ),
            ),
          ).animate().fadeIn(delay: 370.ms),

          const SizedBox(height: 8),

          // Sign In Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _loginWithEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.login_rounded, size: 20),
                      ],
                    ),
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildSocialButtons(bool isSmall) {
    return Column(
      children: [
        // Google Sign In
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _loginWithGoogle,
            icon: Image.network(
              'https://www.google.com/favicon.ico',
              width: 24,
              height: 24,
              errorBuilder: (context, error, stack) => const Icon(Icons.g_mobiledata, size: 28),
            ),
            label: const Text(
              'Continue with Google',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ).animate().fadeIn(delay: 550.ms),
      ],
    );
  }


  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/signup'),
          child: const Text(
            'Sign Up',
            style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 650.ms);
  }

}

// Premium Signup Screen - Firebase Phone Authentication

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../providers/auth_provider.dart';
import '../data/models/user_model.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _agreeToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _focusedField = -1;
  int _selectedCountryIndex = 0;

  // Country list with flags and codes
  final List<Map<String, dynamic>> _countries = [
    {
      'name': 'Pakistan',
      'code': '+92',
      'colors': [const Color(0xFF01411C), Colors.white],
    },
    {
      'name': 'United States',
      'code': '+1',
      'colors': [const Color(0xFFB31942), Colors.white, const Color(0xFF0A3161)],
    },
    {
      'name': 'United Kingdom',
      'code': '+44',
      'colors': [const Color(0xFF012169), Colors.white, const Color(0xFFC8102E)],
    },
    {
      'name': 'UAE',
      'code': '+971',
      'colors': [const Color(0xFF00732F), Colors.white, Colors.black, const Color(0xFFFF0000)],
    },
    {
      'name': 'Saudi Arabia',
      'code': '+966',
      'colors': [const Color(0xFF006C35), Colors.white],
    },
    {
      'name': 'Bangladesh',
      'code': '+880',
      'colors': [const Color(0xFF006A4E), const Color(0xFFF42A41)],
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber {
    return '${_countries[_selectedCountryIndex]['code']}${_phoneController.text.trim()}';
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      SnackBarHelper.showWarning(context, 'Please agree to Terms of Service');
      return;
    }

    setState(() => _isLoading = true);

    // Straight email + password registration — no phone OTP step.
    // register() creates the Firebase account, saves name/email/phone to the
    // backend under the CUSTOMER role, and returns signed in. Once it succeeds
    // the account is verified and we go straight into the app.
    final authProvider = context.read<AuthProvider>();
    final newUser = UserModel(
      id: '',
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _fullPhoneNumber,
      joinDate: DateTime.now(),
      role: 'CUSTOMER',
    );

    await authProvider.register(
      newUser,
      _passwordController.text,
      role: 'CUSTOMER',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (authProvider.status == AuthStatus.success) {
      // Straight in — new customers pick their location next.
      Navigator.pushNamedAndRemoveUntil(context, '/location-permission', (route) => false);
    } else {
      SnackBarHelper.showError(
          context, authProvider.errorMessage ?? 'Registration failed');
    }
  }

  Future<void> _signupWithGoogle() async {
    setState(() => _isLoading = true);

    // Go through AuthProvider so the backend enforces role separation: a Google
    // account already registered as a Provider cannot sign up here as a Customer.
    final authProvider = context.read<AuthProvider>();
    await authProvider.signInWithGoogle(role: 'CUSTOMER');

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (authProvider.status == AuthStatus.success) {
      Navigator.pushNamedAndRemoveUntil(context, '/location-permission', (route) => false);
    } else if (authProvider.errorMessage != null) {
      SnackBarHelper.showError(context, authProvider.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
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
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isSmall ? 16 : 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBackButton(isSmall),
                      SizedBox(height: isSmall ? 20 : 32),
                      _buildHeader(isSmall),
                      SizedBox(height: isSmall ? 24 : 36),
                      _buildForm(isSmall),
                      SizedBox(height: isSmall ? 16 : 24),
                      _buildTermsCheckbox(isSmall),
                      SizedBox(height: isSmall ? 20 : 32),
                      _buildSignupButton(isSmall),
                      SizedBox(height: isSmall ? 16 : 24),
                      _buildOrDivider(isSmall),
                      SizedBox(height: isSmall ? 16 : 20),
                      _buildGoogleSignupButton(isSmall),
                      SizedBox(height: isSmall ? 16 : 24),
                      _buildLoginLink(isSmall),
                      SizedBox(height: isSmall ? 12 : 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(bool isSmall) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: isSmall ? 44 : 50,
        height: isSmall ? 44 : 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.arrow_back_rounded, color: AppColors.primaryBlue, size: isSmall ? 20 : 22),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }

  Widget _buildHeader(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Account',
          style: TextStyle(
            fontSize: isSmall ? 28 : 34,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.8,
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.15, end: 0),
        SizedBox(height: isSmall ? 6 : 8),
        Text(
          'Join Home Technify and get access to trusted professionals.',
          style: TextStyle(
            fontSize: isSmall ? 14 : 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 150.ms),
      ],
    );
  }

  Widget _buildForm(bool isSmall) {
    return Column(
      children: [
        _buildTextField(
          index: 0,
          controller: _nameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          icon: Icons.person_rounded,
          delay: 200,
          isSmall: isSmall,
        ),
        SizedBox(height: isSmall ? 14 : 18),
        _buildTextField(
          index: 1,
          controller: _emailController,
          label: 'Email Address',
          hint: 'Enter your email',
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          delay: 275,
          isSmall: isSmall,
        ),
        SizedBox(height: isSmall ? 14 : 18),
        _buildPhoneField(delay: 350, isSmall: isSmall),
        SizedBox(height: isSmall ? 14 : 18),
        _buildPasswordField(delay: 425, isSmall: isSmall),
        SizedBox(height: isSmall ? 14 : 18),
        _buildConfirmPasswordField(delay: 500, isSmall: isSmall),
      ],
    );
  }

  Widget _buildTextField({
    required int index,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    required int delay,
    required bool isSmall,
  }) {
    final isFocused = _focusedField == index;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 13 : 14,
            fontWeight: FontWeight.w700,
            color: isFocused ? AppColors.primaryBlue : AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: isSmall ? 6 : 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFocused ? AppColors.primaryBlue : AppColors.grey200,
              width: isFocused ? 2 : 1.5,
            ),
            boxShadow: isFocused
                ? [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            onTap: () => setState(() => _focusedField = index),
            style: TextStyle(
              fontSize: isSmall ? 15 : 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: isSmall ? 15 : 16,
                color: AppColors.textHint,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 14, right: 10),
                child: Container(
                  width: isSmall ? 38 : 42,
                  height: isSmall ? 38 : 42,
                  decoration: BoxDecoration(
                    gradient: isFocused ? AppColors.primaryGradient : null,
                    color: isFocused ? null : AppColors.grey100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isFocused ? Colors.white : AppColors.grey500,
                    size: isSmall ? 18 : 20,
                  ),
                ),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: isSmall ? 62 : 68),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 14 : 16),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay)).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPhoneField({required int delay, required bool isSmall}) {
    final isFocused = _focusedField == 2;
    final selectedCountry = _countries[_selectedCountryIndex];
    final colors = selectedCountry['colors'] as List<Color>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: isSmall ? 13 : 14,
            fontWeight: FontWeight.w700,
            color: isFocused ? AppColors.primaryBlue : AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: isSmall ? 6 : 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFocused ? AppColors.primaryBlue : AppColors.grey200,
              width: isFocused ? 2 : 1.5,
            ),
            boxShadow: isFocused
                ? [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              // Country code with flag - tappable
              GestureDetector(
                onTap: () => _showCountryPicker(isSmall),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 14, vertical: isSmall ? 12 : 14),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: AppColors.grey200, width: 1.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFlag(colors, isSmall),
                      SizedBox(width: isSmall ? 6 : 8),
                      Text(
                        selectedCountry['code'],
                        style: TextStyle(
                          fontSize: isSmall ? 15 : 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: isSmall ? 4 : 6),
                      Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.grey500, size: isSmall ? 18 : 20),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  onTap: () => setState(() => _focusedField = 2),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  style: TextStyle(
                    fontSize: isSmall ? 15 : 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '300 123 4567',
                    hintStyle: TextStyle(
                      fontSize: isSmall ? 15 : 16,
                      color: AppColors.textHint,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: isSmall ? 14 : 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay)).slideY(begin: 0.1, end: 0);
  }

  Widget _buildFlag(List<Color> colors, bool isSmall) {
    return Container(
      width: isSmall ? 26 : 30,
      height: isSmall ? 18 : 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Row(
          children: colors.map((color) => Expanded(child: Container(color: color))).toList(),
        ),
      ),
    );
  }

  void _showCountryPicker(bool isSmall) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Select Country',
                style: TextStyle(
                  fontSize: isSmall ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(height: 1),
            // Country list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _countries.length,
                itemBuilder: (context, index) {
                  final country = _countries[index];
                  final isSelected = index == _selectedCountryIndex;
                  final colors = country['colors'] as List<Color>;
                  
                  return ListTile(
                    onTap: () {
                      setState(() => _selectedCountryIndex = index);
                      Navigator.pop(context);
                    },
                    leading: _buildFlag(colors, isSmall),
                    title: Text(
                      country['name'],
                      style: TextStyle(
                        fontSize: isSmall ? 15 : 16,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          country['code'],
                          style: TextStyle(
                            fontSize: isSmall ? 14 : 15,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: isSmall ? 20 : 22),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox(bool isSmall) {
    return GestureDetector(
      onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
      child: Container(
        padding: EdgeInsets.all(isSmall ? 12 : 14),
        decoration: BoxDecoration(
          color: _agreeToTerms ? AppColors.primaryBlue.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _agreeToTerms ? AppColors.primaryBlue.withValues(alpha: 0.3) : AppColors.grey200,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSmall ? 22 : 24,
              height: isSmall ? 22 : 24,
              decoration: BoxDecoration(
                gradient: _agreeToTerms ? AppColors.primaryGradient : null,
                color: _agreeToTerms ? null : AppColors.grey100,
                borderRadius: BorderRadius.circular(6),
                border: _agreeToTerms ? null : Border.all(color: AppColors.grey300, width: 2),
                boxShadow: _agreeToTerms ? [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 8)] : null,
              ),
              child: _agreeToTerms
                  ? Icon(Icons.check_rounded, size: isSmall ? 14 : 16, color: Colors.white)
                  : null,
            ),
            SizedBox(width: isSmall ? 10 : 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: isSmall ? 12 : 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 425.ms);
  }

  Widget _buildOrDivider(bool isSmall) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.grey200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.grey200)),
      ],
    ).animate().fadeIn(delay: 550.ms);
  }

  Widget _buildGoogleSignupButton(bool isSmall) {
    return SizedBox(
      width: double.infinity,
      height: isSmall ? 54 : 60,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _signupWithGoogle,
        icon: Image.network(
          'https://www.google.com/favicon.ico',
          width: 24,
          height: 24,
          errorBuilder: (context, error, stack) => const Icon(Icons.g_mobiledata, size: 28),
        ),
        label: const Text(
          'Sign up with Google',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: BorderSide(color: AppColors.grey300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1);
  }

  Widget _buildSignupButton(bool isSmall) {
    final isEnabled = _agreeToTerms;

    return GestureDetector(
      onTap: isEnabled && !_isLoading ? _signup : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: isSmall ? 54 : 60,
        decoration: BoxDecoration(
          gradient: isEnabled ? AppColors.primaryGradient : null,
          color: isEnabled ? null : AppColors.grey200,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(
                  width: isSmall ? 22 : 24,
                  height: isSmall ? 22 : 24,
                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: isSmall ? 16 : 17,
                        fontWeight: FontWeight.w700,
                        color: isEnabled ? Colors.white : AppColors.grey400,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isEnabled) ...[
                      SizedBox(width: isSmall ? 6 : 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: isSmall ? 18 : 20),
                    ],
                  ],
                ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 500.ms).slideY(begin: 0.15, end: 0);
  }

  Widget _buildLoginLink(bool isSmall) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 16 : 20, vertical: isSmall ? 10 : 12),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(
                fontSize: isSmall ? 13 : 14,
                color: AppColors.textSecondary,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'Login',
                style: TextStyle(
                  fontSize: isSmall ? 13 : 14,
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 575.ms);
  }

  Widget _buildPasswordField({required int delay, required bool isSmall}) {
    final isFocused = _focusedField == 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontSize: isSmall ? 13 : 14,
            fontWeight: FontWeight.w700,
            color: isFocused ? AppColors.primaryBlue : AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isSmall ? 14 : 16),
            border: Border.all(
              color: isFocused ? AppColors.primaryBlue : AppColors.grey200,
              width: isFocused ? 2 : 1.5,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onTap: () => setState(() => _focusedField = 3),
            style: TextStyle(
              fontSize: isSmall ? 15 : 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Password is required';
              if (value.length < 8) return 'Password must be at least 8 characters';
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Create a password',
              hintStyle: TextStyle(
                fontSize: isSmall ? 15 : 16,
                color: AppColors.textHint,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 14, right: 10),
                child: Container(
                  width: isSmall ? 38 : 42,
                  height: isSmall ? 38 : 42,
                  decoration: BoxDecoration(
                    gradient: isFocused ? AppColors.primaryGradient : null,
                    color: isFocused ? null : AppColors.grey100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: isFocused ? Colors.white : AppColors.grey500,
                    size: isSmall ? 18 : 20,
                  ),
                ),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: isSmall ? 62 : 68),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.grey400,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 14 : 16),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay)).slideY(begin: 0.1, end: 0);
  }

  Widget _buildConfirmPasswordField({required int delay, required bool isSmall}) {
    final isFocused = _focusedField == 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirm Password',
          style: TextStyle(
            fontSize: isSmall ? 13 : 14,
            fontWeight: FontWeight.w700,
            color: isFocused ? AppColors.primaryBlue : AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isSmall ? 14 : 16),
            border: Border.all(
              color: isFocused ? AppColors.primaryBlue : AppColors.grey200,
              width: isFocused ? 2 : 1.5,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            onTap: () => setState(() => _focusedField = 4),
            style: TextStyle(
              fontSize: isSmall ? 15 : 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please confirm your password';
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Confirm your password',
              hintStyle: TextStyle(
                fontSize: isSmall ? 15 : 16,
                color: AppColors.textHint,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 14, right: 10),
                child: Container(
                  width: isSmall ? 38 : 42,
                  height: isSmall ? 38 : 42,
                  decoration: BoxDecoration(
                    gradient: isFocused ? AppColors.primaryGradient : null,
                    color: isFocused ? null : AppColors.grey100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: isFocused ? Colors.white : AppColors.grey500,
                    size: isSmall ? 18 : 20,
                  ),
                ),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: isSmall ? 62 : 68),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.grey400,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 14 : 16),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay)).slideY(begin: 0.1, end: 0);
  }
}

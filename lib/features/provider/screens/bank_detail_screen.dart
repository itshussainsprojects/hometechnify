// Bank Detail Screen - Provider payment details
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../providers/provider_controller.dart';

class BankDetailScreen extends StatefulWidget {
  const BankDetailScreen({super.key});

  @override
  State<BankDetailScreen> createState() => _BankDetailScreenState();
}

class _BankDetailScreenState extends State<BankDetailScreen> {
  final _accountController = TextEditingController();
  final _titleController = TextEditingController(); // Added Account Title
  String _selectedMethod = 'Easypaisa';
  bool _isEditing = false;
  bool _hasSavedData = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'name': 'Easypaisa',
      'icon': Icons.phone_android_rounded,
      'color': AppColors.primaryBlue,
      'label': 'EP',
    },
    {
      'name': 'JazzCash',
      'icon': Icons.phone_iphone_rounded,
      'color': AppColors.primaryBlue,
      'label': 'JC',
    },
    {
      'name': 'Bank Transfer',
      'icon': Icons.account_balance_rounded,
      'color': AppColors.primaryBlue,
      'label': 'BK',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Load current provider data
    final provider = context.read<ProviderController>().selectedProvider;
    if (provider != null) {
      _accountController.text = provider.accountNumber ?? '';
      _titleController.text = provider.accountTitle ?? '';
      _selectedMethod = provider.bankName ?? 'Easypaisa';
      _hasSavedData = (provider.accountNumber != null && provider.accountNumber!.isNotEmpty);
    }
  }

  @override
  void dispose() {
    _accountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    if (_accountController.text.isEmpty || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all details'),
          backgroundColor: AppColors.primaryBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final success = await context.read<ProviderController>().updateProfile({
      'bank_name': _selectedMethod,
      'account_title': _titleController.text,
      'account_number': _accountController.text,
    });

    if (success && mounted) {
      setState(() {
        _isEditing = false;
        _hasSavedData = true;
      });
      
      // Refresh details
      final userId = context.read<ProviderController>().selectedProvider?.id;
      if (userId != null) {
        context.read<ProviderController>().fetchProviderDetails(userId);
      }

      _showSuccessDialog();
    } else if (mounted) {
       final errorMsg = context.read<ProviderController>().errorMessage ?? 'Failed to save';
       debugPrint("Save Bank Details Failed: $errorMsg");
       
       // Force refresh in case it was just a timeout but data saved
       final userIdRefresh = context.read<ProviderController>().selectedProvider?.id;
       if (userIdRefresh != null) {
          context.read<ProviderController>().fetchProviderDetails(userIdRefresh);
       }

       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$errorMsg. Refreshing data...'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.primaryBlue.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.white, size: 60),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Saved Successfully!',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your payment details have been updated and verified.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 8,
                          shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                        ),
                        child: const Text('Great!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final providerController = context.watch<ProviderController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
        ),
        title: const Text('Bank Detail', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: true,
        actions: [
          if (_hasSavedData && !_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primaryBlue),
                label: const Text('Edit', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background Decorative Elements
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.02),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (providerController.isLoading)
                   const LinearProgressIndicator(color: AppColors.primaryBlue),
                
                // Premium Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.primaryBlue.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.security_rounded, color: AppColors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Secure Payments',
                              style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Earnings will be safely transferred to your selected wallet.',
                              style: TextStyle(color: AppColors.white.withValues(alpha: 0.9), fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().slideY(begin: 0.2, duration: 400.ms).fadeIn(),

                const SizedBox(height: 32),

                // Section Headers
                _buildSectionHeader('Select Method', Icons.payments_rounded),
                const SizedBox(height: 16),

                // Payment Method Grid
                Row(
                  children: _paymentMethods.map((method) {
                    final isSelected = _selectedMethod == method['name'];
                    // Limit rows if needed or use wrap
                    return Expanded(
                      child: GestureDetector(
                        onTap: (_isEditing || !_hasSavedData) ? () => setState(() => _selectedMethod = method['name']) : null,
                        child: AnimatedContainer(
                          duration: 300.ms,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.white : AppColors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    )
                                  ]
                                : [],
                          ),
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.1) : AppColors.grey100,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Icon(
                                    method['icon'] as IconData,
                                    color: isSelected ? AppColors.primaryBlue : AppColors.grey400,
                                    size: 24,
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primaryBlue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, color: AppColors.white, size: 12),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  method['name'] as String,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().scale(delay: Duration(milliseconds: _paymentMethods.indexOf(method) * 100));
                  }).toList(),
                ),

                const SizedBox(height: 32),

                // Account Title Field
                _buildSectionHeader('Account Title', Icons.person_rounded),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _titleController,
                    enabled: _isEditing || !_hasSavedData,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Hassaan Ali',
                      hintStyle: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.normal),
                      prefixIcon: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.badge_rounded, color: AppColors.primaryBlue, size: 20),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 24),

                // Account Number Field
                _buildSectionHeader('Account Number', Icons.account_balance_wallet_rounded),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _accountController,
                    enabled: _isEditing || !_hasSavedData,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                    decoration: InputDecoration(
                      hintText: 'e.g. 0300 0000000',
                      hintStyle: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.normal, letterSpacing: 0),
                      prefixIcon: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.phone_rounded, color: AppColors.primaryBlue, size: 20),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 48),

                // Save / Status Button
                if (_isEditing || !_hasSavedData)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 10,
                        shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Save Payment Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ).animate().scale(delay: 300.ms)
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: AppColors.white, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verified Account',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Account details are active and verified.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textPrimary),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

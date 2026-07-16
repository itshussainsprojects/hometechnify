// Payment Methods Screen - Card Style Design

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';
import 'package:provider/provider.dart';
import 'package:home_technify/features/profile/providers/profile_provider.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  late String _selectedMethod;
  String _selectedWallet = 'jazzcash';

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProfileProvider>();
    _selectedMethod = provider.selectedPaymentMethod;
    _selectedWallet = provider.selectedWallet;
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey200),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          ),
        ),
        title: const Text(
          'Payment Methods',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(horizontalPadding),
              children: [
                const SizedBox(height: 16),
                // Section header
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 16),
                  child: Text(
                    'Select Payment Method',
                    style: TextStyle(
                      fontSize: isSmall ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                
                // Payment Method Cards - Row style like Book Service
                Row(
                  children: [
                    _buildPaymentCard(
                      id: 'cash',
                      title: 'Cash',
                      icon: Icons.payments_rounded,
                      isSmall: isSmall,
                    ),
                    SizedBox(width: isSmall ? 10 : 14),
                    _buildPaymentCard(
                      id: 'wallet',
                      title: 'Wallet',
                      icon: Icons.account_balance_wallet_rounded,
                      isSmall: isSmall,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Wallet options (shown when wallet selected)
                if (_selectedMethod == 'wallet') ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'Select Wallet',
                      style: TextStyle(
                        fontSize: isSmall ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  _buildWalletOption('jazzcash', 'JazzCash', 'Pay via JazzCash', Icons.phone_android_rounded, isSmall),
                  const SizedBox(height: 10),
                  _buildWalletOption('easypaisa', 'EasyPaisa', 'Pay via EasyPaisa', Icons.account_balance_wallet_rounded, isSmall),
                  const SizedBox(height: 24),
                ],
                
                // Info card
                _buildInfoCard(isSmall),
              ],
            ),
          ),
          
          // Save button at bottom
          _buildSaveButton(isSmall, horizontalPadding),
        ],
      ),
    );
  }

  Widget _buildPaymentCard({
    required String id,
    required String title,
    required IconData icon,
    required bool isSmall,
  }) {
    final isSelected = _selectedMethod == id;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: isSmall ? 100 : 110,
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected ? null : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.transparent : AppColors.grey200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected 
                    ? AppColors.primaryBlue.withValues(alpha: 0.3)
                    : AppColors.black.withValues(alpha: 0.05),
                blurRadius: isSelected ? 12 : 8,
                offset: Offset(0, isSelected ? 4 : 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isSmall ? 28 : 32,
                color: isSelected ? Colors.white : AppColors.primaryBlue,
              ),
              SizedBox(height: isSmall ? 8 : 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmall ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildWalletOption(String id, String title, String subtitle, IconData icon, bool isSmall) {
    final isSelected = _selectedWallet == id;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedWallet = id),
      child: Container(
        padding: EdgeInsets.all(isSmall ? 14 : 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.grey200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? AppColors.primaryBlue.withValues(alpha: 0.1)
                  : AppColors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: isSmall ? 44 : 48,
              height: isSmall ? 44 : 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.1) : AppColors.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon, 
                size: isSmall ? 22 : 24, 
                color: isSelected ? AppColors.primaryBlue : AppColors.grey500,
              ),
            ),
            SizedBox(width: isSmall ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmall ? 14 : 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isSmall ? 11 : 12,
                      color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.8) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Sub-option selection indicator
            _buildSelectionIndicator(isSelected, isSmall),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildSelectionIndicator(bool isSelected, bool isSmall) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isSmall ? 20 : 22,
      height: isSmall ? 20 : 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primaryBlue : AppColors.grey300,
          width: 2,
        ),
        color: isSelected ? AppColors.primaryBlue : Colors.transparent,
      ),
      child: isSelected
          ? Icon(Icons.check_rounded, size: isSmall ? 12 : 14, color: Colors.white)
          : null,
    );
  }

  Widget _buildInfoCard(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: isSmall ? 20 : 22),
          SizedBox(width: isSmall ? 10 : 12),
          Expanded(
            child: Text(
              'All transactions are secure and encrypted',
              style: TextStyle(
                fontSize: isSmall ? 12 : 13,
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildSaveButton(bool isSmall, double padding) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () {
            final provider = context.read<ProfileProvider>();
            provider.updatePaymentMethod(_selectedMethod);
            if (_selectedMethod == 'wallet') {
               provider.updateWallet(_selectedWallet);
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment method saved: ${_selectedMethod == 'cash' ? 'Cash' : 'Wallet'}'),
                backgroundColor: AppColors.primaryBlue,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            Navigator.pop(context);
          },
          child: Container(
            width: double.infinity,
            height: isSmall ? 50 : 54,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_rounded, color: Colors.white, size: isSmall ? 20 : 22),
                const SizedBox(width: 10),
                Text(
                  'Save Payment Method',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmall ? 15 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

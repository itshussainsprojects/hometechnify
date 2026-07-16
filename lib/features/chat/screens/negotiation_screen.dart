// Negotiation Screen - Price Negotiation UI

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';

class NegotiationScreen extends StatefulWidget {
  final String? providerName;
  final String? serviceName;
  final String? initialPrice;
  final String? userOffer;

  const NegotiationScreen({
    super.key,
    this.providerName,
    this.serviceName,
    this.initialPrice,
    this.userOffer,
  });

  @override
  State<NegotiationScreen> createState() => _NegotiationScreenState();
}

class _NegotiationScreenState extends State<NegotiationScreen> {
  final _priceController = TextEditingController();
  late List<Map<String, dynamic>> _offers;

  @override
  void initState() {
    super.initState();
    // Initialize offers with provider's price and user's initial offer from popup
    _offers = [
      {
        'amount': widget.initialPrice ?? 'Rs. 500',
        'by': 'provider',
        'message': 'My rate for ${widget.serviceName ?? "this service"}',
        'time': 'Just now',
      },
    ];
    // Add user's offer if passed from popup
    if (widget.userOffer != null && widget.userOffer!.isNotEmpty) {
      _offers.add({
        'amount': widget.userOffer!,
        'by': 'user',
        'message': 'My offer for your service',
        'time': 'Just now',
      });
      // Simulate provider response
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _offers.add({
              'amount': widget.userOffer!,
              'by': 'provider',
              'message': 'I can accept this offer!',
              'time': 'Just now',
            });
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final isTiny = size.height < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildCompactHeader(isSmall, isTiny),
            Expanded(child: _buildOffersList(isSmall, isTiny)),
            _buildSmartQuickOffers(isTiny),
            _buildCompactInputArea(isSmall, isTiny),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader(bool isSmall, bool isTiny) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isTiny ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row with back button and title
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: isTiny ? 32 : 36,
                  height: isTiny ? 32 : 36,
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: isTiny ? 14 : 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Negotiate Price',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: isTiny ? 15 : 17,
                      ),
                    ),
                    Text(
                      '${widget.serviceName ?? "Service"} • ${widget.providerName ?? "Provider"}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: isTiny ? 10 : 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Live badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTiny ? 6 : 8,
                  vertical: isTiny ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: isTiny ? 9 : 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 8 : 12),
          // Price summary row
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTiny ? 10 : 14,
              vertical: isTiny ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompactStat('Initial', widget.initialPrice ?? 'Rs. 0', isTiny),
                Container(width: 1, height: isTiny ? 20 : 24, color: AppColors.grey200),
                _buildCompactStat('Your Offer', _offers.where((o) => o['by'] == 'user').isEmpty ? '-' : _offers.where((o) => o['by'] == 'user').last['amount'], isTiny),
                Container(width: 1, height: isTiny ? 20 : 24, color: AppColors.grey200),
                _buildCompactStat('Status', 'Active', isTiny, isActive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, bool isTiny, {bool isActive = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: isTiny ? 9 : 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isActive ? AppColors.success : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: isTiny ? 12 : 13,
          ),
        ),
      ],
    );
  }

  Widget _buildOffersList(bool isSmall, bool isTiny) {
    if (_offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handshake_outlined, size: isTiny ? 48 : 56, color: AppColors.grey300),
            SizedBox(height: isTiny ? 10 : 14),
            Text(
              'Start negotiating!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: isTiny ? 13 : 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isTiny ? 8 : 12),
      itemCount: _offers.length,
      itemBuilder: (context, index) {
        final offer = _offers[index];
        final isMe = offer['by'] == 'user';
        return _buildCompactOfferCard(offer, isMe, isTiny, index);
      },
    );
  }

  Widget _buildCompactOfferCard(Map<String, dynamic> offer, bool isMe, bool isTiny, int index) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: isTiny ? 8 : 10,
          left: isMe ? 40 : 0,
          right: isMe ? 0 : 40,
        ),
        padding: EdgeInsets.all(isTiny ? 10 : 12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: (isMe ? AppColors.primaryBlue : Colors.black).withValues(alpha: isMe ? 0.15 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              offer['amount'],
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: isTiny ? 16 : 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              offer['message'],
              style: TextStyle(
                color: isMe ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondary,
                fontSize: isTiny ? 11 : 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              offer["time"],
              style: TextStyle(
                color: isMe ? Colors.white.withValues(alpha: 0.5) : AppColors.textHint,
                fontSize: isTiny ? 9 : 10,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildSmartQuickOffers(bool isTiny) {
    final quickOffers = [50, 100, 200, 500];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isTiny ? 4 : 6),
      height: isTiny ? 36 : 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: quickOffers.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final amount = quickOffers[index];
          return GestureDetector(
            onTap: () {
              final basePrice = int.parse(widget.initialPrice?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0');
              final newPrice = basePrice - amount;
              if (newPrice > 0) {
                _priceController.text = newPrice.toString();
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isTiny ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
              ),
              child: Center(
                child: Text(
                  '- Rs. $amount',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: isTiny ? 11 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactInputArea(bool isSmall, bool isTiny) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, isTiny ? 8 : 10, 12, isTiny ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Input row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: isTiny ? 42 : 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.grey50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Rs.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: isTiny ? 14 : 15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isTiny ? 14 : 15,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter price',
                            hintStyle: TextStyle(
                              color: AppColors.textHint,
                              fontWeight: FontWeight.normal,
                              fontSize: isTiny ? 13 : 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendOffer,
                child: Container(
                  width: isTiny ? 42 : 48,
                  height: isTiny ? 42 : 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: isTiny ? 18 : 20,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isTiny ? 8 : 10),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _acceptOffer,
                  child: Container(
                    height: isTiny ? 38 : 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Accept & Book',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: isTiny ? 12 : 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _declineOffer,
                  child: Container(
                    height: isTiny ? 38 : 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        'Decline',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: isTiny ? 12 : 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendOffer() {
    if (_priceController.text.isNotEmpty) {
      setState(() {
        _offers.add({
          'amount': 'Rs. ${_priceController.text}',
          'by': 'user',
          'message': 'My counter offer',
          'time': 'Just now',
        });
        _priceController.clear();
      });
      
      // Simulate provider response after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _offers.add({
              'amount': _offers.last['amount'],
              'by': 'provider',
              'message': 'I accept your offer!',
              'time': 'Just now',
            });
          });
        }
      });
    }
  }

  void _acceptOffer() {
    // Get the last offer amount
    final lastOffer = _offers.isNotEmpty ? _offers.last['amount'] : widget.initialPrice ?? 'Rs. 0';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Price agreed at $lastOffer! Opening booking...'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    
    // Navigate to booking with the negotiated price
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/booking',
          arguments: {
            'provider': widget.providerName ?? 'Provider',
            'service': widget.serviceName ?? 'Service',
            'price': lastOffer.toString().replaceAll(RegExp(r'[^0-9]'), ''),
            'negotiated': true,
          },
        );
      }
    });
  }

  void _declineOffer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Negotiation?'),
        content: const Text('Are you sure you want to end this negotiation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to map
            },
            child: Text('Yes', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

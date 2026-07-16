// Service In Progress Screen - User App
// Premium design with improved step tracking

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';

class ServiceInProgressScreen extends StatefulWidget {
  final String? providerId;
  final String? providerName;
  final String? serviceName;

  const ServiceInProgressScreen({
    super.key,
    this.providerId,
    this.providerName,
    this.serviceName,
  });

  @override
  State<ServiceInProgressScreen> createState() => _ServiceInProgressScreenState();
}

class _ServiceInProgressScreenState extends State<ServiceInProgressScreen> {
  final int _currentStep = 1;
  
  final List<Map<String, dynamic>> _serviceSteps = [
    {'title': 'Provider Arrived', 'time': '2:00 PM', 'completed': true, 'icon': Icons.login_rounded},
    {'title': 'Diagnosing Issue', 'time': '2:05 PM', 'completed': true, 'icon': Icons.search_rounded},
    {'title': 'Working on Service', 'time': '--', 'completed': false, 'icon': Icons.build_rounded},
    {'title': 'Service Complete', 'time': '--', 'completed': false, 'icon': Icons.check_circle_rounded},
  ];

  final Map<String, dynamic> _providerData = {
    'name': 'Ahmad Hassan',
    'service': 'AC Repair',
    'phone': '+92 300 1234567',
    'rating': 4.8,
  };

  Future<void> _callProvider() async {
    final phone = (_providerData['phone'] as String?)?.replaceAll(' ', '') ?? '';
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isVerySmall = size.height < 600;
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: SafeArea(
        child: Column(
          children: [
            // Premium Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isVerySmall ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.grey50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Service In Progress',
                      style: TextStyle(
                        fontSize: isVerySmall ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // Live indicator
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isVerySmall ? 8 : 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ).animate(onPlay: (c) => c.repeat()).fadeIn().then().fadeOut(duration: 800.ms),
                        const SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  children: [
                    SizedBox(height: isVerySmall ? 4 : 10),
                    
                    // Status Badge
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: isVerySmall ? 10 : 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withValues(alpha: 0.1),
                            const Color(0xFF34D399).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.engineering_rounded, size: isVerySmall ? 28 : 36, color: const Color(0xFF059669)),
                          SizedBox(height: isVerySmall ? 4 : 8),
                          Text(
                            'Service in Progress',
                            style: TextStyle(
                              fontSize: isVerySmall ? 15 : 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_providerData['name']} is working',
                            style: TextStyle(
                              fontSize: isVerySmall ? 11 : 12,
                              color: const Color(0xFF059669).withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
                    
                    SizedBox(height: isVerySmall ? 10 : 16),
                    
                    // Premium Steps Card
                    Container(
                      padding: EdgeInsets.all(isVerySmall ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: List.generate(_serviceSteps.length, (index) {
                          final step = _serviceSteps[index];
                          final isActive = index == _currentStep;
                          final isCompleted = step['completed'] as bool;
                          
                          return Column(
                            children: [
                              Row(
                                children: [
                                  // Step indicator with icon
                                  Container(
                                    width: isVerySmall ? 38 : 44,
                                    height: isVerySmall ? 38 : 44,
                                    decoration: BoxDecoration(
                                      gradient: isCompleted 
                                          ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])
                                          : isActive 
                                              ? AppColors.primaryGradient
                                              : null,
                                      color: !isCompleted && !isActive ? AppColors.grey100 : null,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: isCompleted || isActive ? [
                                        BoxShadow(
                                          color: (isCompleted ? const Color(0xFF10B981) : AppColors.primaryBlue).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ] : null,
                                    ),
                                    child: Center(
                                      child: isCompleted
                                          ? Icon(Icons.check_rounded, size: isVerySmall ? 20 : 24, color: Colors.white)
                                          : Icon(
                                              (step['icon'] ?? Icons.circle_rounded) as IconData,
                                              size: isVerySmall ? 18 : 22,
                                              color: isActive ? Colors.white : AppColors.textSecondary,
                                            ),
                                    ),
                                  ),
                                  SizedBox(width: isVerySmall ? 12 : 16),
                                  // Step info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step['title'],
                                          style: TextStyle(
                                            fontSize: isVerySmall ? 13 : 15,
                                            fontWeight: isActive || isCompleted ? FontWeight.w600 : FontWeight.w500,
                                            color: isActive || isCompleted 
                                                ? AppColors.textPrimary 
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                        if (isCompleted) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            step['time'],
                                            style: TextStyle(
                                              fontSize: isVerySmall ? 10 : 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Status badge
                                  if (isActive)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: isVerySmall ? 8 : 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'In Progress',
                                        style: TextStyle(
                                          fontSize: isVerySmall ? 9 : 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  else if (isCompleted)
                                    Icon(Icons.verified_rounded, size: 18, color: const Color(0xFF10B981)),
                                ],
                              ),
                              if (index < _serviceSteps.length - 1)
                                Container(
                                  margin: EdgeInsets.only(left: isVerySmall ? 17 : 20),
                                  width: 2,
                                  height: isVerySmall ? 20 : 28,
                                  decoration: BoxDecoration(
                                    gradient: isCompleted 
                                        ? const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Color(0xFF10B981), Color(0xFF34D399)],
                                          )
                                        : null,
                                    color: !isCompleted ? AppColors.grey200 : null,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                            ],
                          );
                        }),
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                    
                    SizedBox(height: isVerySmall ? 10 : 16),
                    
                    // Provider Mini Card
                    Container(
                      padding: EdgeInsets.all(isVerySmall ? 12 : 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: isVerySmall ? 40 : 46,
                            height: isVerySmall ? 40 : 46,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'AH',
                                style: TextStyle(
                                  fontSize: isVerySmall ? 14 : 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isVerySmall ? 10 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _providerData['name'],
                                  style: TextStyle(
                                    fontSize: isVerySmall ? 13 : 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      _providerData['service'],
                                      style: TextStyle(
                                        fontSize: isVerySmall ? 10 : 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.star_rounded, size: 12, color: const Color(0xFFFBBF24)),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${_providerData['rating']}',
                                      style: TextStyle(
                                        fontSize: isVerySmall ? 10 : 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Call button
                          GestureDetector(
                            onTap: _callProvider,
                            child: Container(
                              width: isVerySmall ? 34 : 38,
                              height: isVerySmall ? 34 : 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.call_rounded, size: isVerySmall ? 16 : 18, color: const Color(0xFF10B981)),
                            ),
                          ),
                          SizedBox(width: isVerySmall ? 6 : 8),
                          // Chat button
                          GestureDetector(
                            onTap: () {
                              if (widget.providerId != null) {
                                Navigator.pushNamed(context, '/chat', arguments: {
                                  'recipientId': widget.providerId,
                                  'name': widget.providerName ?? _providerData['name'],
                                  'service': widget.serviceName ?? _providerData['service'],
                                });
                              } else {
                                Navigator.pushNamed(context, '/chats');
                              }
                            },
                            child: Container(
                              width: isVerySmall ? 34 : 38,
                              height: isVerySmall ? 34 : 38,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chat_rounded, size: isVerySmall ? 16 : 18, color: AppColors.primaryBlue),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                    
                    SizedBox(height: isVerySmall ? 14 : 20),
                    
                    // Premium Complete Button
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/rate-provider'),
                      child: Container(
                        width: double.infinity,
                        height: isVerySmall ? 48 : 54,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: isVerySmall ? 18 : 20),
                            const SizedBox(width: 8),
                            Text(
                              'Service Completed',
                              style: TextStyle(
                                fontSize: isVerySmall ? 14 : 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: isVerySmall ? 16 : 18),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.95, 0.95)),
                    
                    SizedBox(height: isVerySmall ? 12 : 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

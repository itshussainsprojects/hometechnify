// Voice Call Screen - Provider calling customer
// Premium blue theme design

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';

class VoiceCallScreen extends StatefulWidget {
  final String? customerName;
  final String? phoneNumber;

  const VoiceCallScreen({
    super.key,
    this.customerName,
    this.phoneNumber,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  int _callDuration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    // Demo mode — show notice once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo mode: Real calling requires Agora/ZEGOCLOUD SDK integration'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _callDuration++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getInitials(String name) {
    return name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final customerName = widget.customerName ?? 'Customer';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0B72D8),
              const Color(0xFF1495FF),
              AppColors.primaryBlue,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with timer and menu
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.horizontalPadding(context),
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    // Timer badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_callDuration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Menu button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Avatar
              Container(
                width: isSmall ? 110 : 130,
                height: isSmall ? 110 : 130,
                decoration: BoxDecoration(
                  color: const Color(0xFF4AA8E5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInitials(customerName),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmall ? 36 : 44,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              SizedBox(height: isSmall ? 24 : 32),

              // Name
              Text(
                customerName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmall ? 26 : 30,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              // Call status
              Text(
                'Voice Call',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: isSmall ? 15 : 16,
                ),
              ),

              const Spacer(),

              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mute button
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: 'Mute',
                    isActive: _isMuted,
                    onTap: () => setState(() => _isMuted = !_isMuted),
                    isSmall: isSmall,
                  ),
                  SizedBox(width: isSmall ? 40 : 50),
                  // Speaker button
                  _buildControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_up_rounded,
                    label: 'Speaker',
                    isActive: _isSpeakerOn,
                    onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                    isSmall: isSmall,
                  ),
                ],
              ),

              SizedBox(height: isSmall ? 50 : 70),

              // End call button
              GestureDetector(
                onTap: () {
                  _timer?.cancel();
                  Navigator.pop(context);
                },
                child: Container(
                  width: isSmall ? 64 : 72,
                  height: isSmall ? 64 : 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: isSmall ? 28 : 32,
                  ),
                ),
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isSmall,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: isSmall ? 54 : 60,
            height: isSmall ? 54 : 60,
            decoration: BoxDecoration(
              color: isActive 
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isSmall ? 24 : 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: isSmall ? 12 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Call Screen - Voice/Video Call UI

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';

class CallScreen extends StatefulWidget {
  final bool isVideo;
  final String? callerName;
  
  const CallScreen({super.key, this.isVideo = false, this.callerName});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoOn = true;
  bool _isConnecting = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Demo mode — no real calling SDK integrated
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo mode: Real calling requires Agora/ZEGOCLOUD SDK integration'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isConnecting = false);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          widget.isVideo && !_isConnecting
              ? _buildVideoBackground()
              : _buildVoiceBackground(),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isSmall),
                const Spacer(),
                _buildCallerInfo(isSmall),
                const Spacer(),
                _buildControls(isSmall),
                SizedBox(height: isSmall ? 40 : 60),
              ],
            ),
          ),

          // Small self video (for video call)
          if (widget.isVideo && !_isConnecting && _isVideoOn)
            Positioned(
              right: 20,
              top: MediaQuery.of(context).padding.top + 70,
              child: _buildSelfVideo(isSmall),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF1A237E)],
        ),
      ),
    );
  }

  Widget _buildVideoBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Icon(Icons.person, size: 200, color: Colors.grey.shade800),
      ),
    );
  }

  Widget _buildHeader(bool isSmall) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isSmall ? 12 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(isSmall ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: isSmall ? 18 : 20),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 14 : 18, vertical: isSmall ? 8 : 10),
            decoration: BoxDecoration(
              color: _isConnecting ? Colors.orange.withValues(alpha: 0.2) : AppColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnecting ? Colors.orange : AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnecting ? 'Connecting...' : '00:32',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: isSmall ? 12 : 13),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(isSmall ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.more_vert_rounded, color: Colors.white, size: isSmall ? 18 : 20),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildCallerInfo(bool isSmall) {
    return Column(
      children: [
        // Avatar with pulse
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: (isSmall ? 120 : 150) + (_isConnecting ? 20 * _pulseController.value : 0),
              height: (isSmall ? 120 : 150) + (_isConnecting ? 20 * _pulseController.value : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.4 + (_pulseController.value * 0.2)),
                    blurRadius: 30 + (_pulseController.value * 20),
                    spreadRadius: _isConnecting ? 5 + (_pulseController.value * 10) : 0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'AK',
                  style: TextStyle(color: Colors.white, fontSize: isSmall ? 40 : 50, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        ),
        SizedBox(height: isSmall ? 24 : 32),
        Text(
          widget.callerName ?? 'Unknown',
          style: TextStyle(color: Colors.white, fontSize: isSmall ? 26 : 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _isConnecting ? 'Connecting...' : widget.isVideo ? 'Video Call' : 'Voice Call',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: isSmall ? 15 : 17),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  Widget _buildControls(bool isSmall) {
    return Column(
      children: [
        // Secondary controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _isMuted ? 'Unmute' : 'Mute',
              isActive: _isMuted,
              onTap: () => setState(() => _isMuted = !_isMuted),
              isSmall: isSmall,
            ),
            SizedBox(width: isSmall ? 24 : 32),
            _buildControlButton(
              icon: _isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
              label: 'Speaker',
              isActive: _isSpeaker,
              onTap: () => setState(() => _isSpeaker = !_isSpeaker),
              isSmall: isSmall,
            ),
            if (widget.isVideo) ...[
              SizedBox(width: isSmall ? 24 : 32),
              _buildControlButton(
                icon: _isVideoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                label: _isVideoOn ? 'Video On' : 'Video Off',
                isActive: !_isVideoOn,
                onTap: () => setState(() => _isVideoOn = !_isVideoOn),
                isSmall: isSmall,
              ),
            ],
          ],
        ),
        SizedBox(height: isSmall ? 32 : 48),
        // End call button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: isSmall ? 70 : 80,
            height: isSmall ? 70 : 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFFFF5252).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Icon(Icons.call_end_rounded, color: Colors.white, size: isSmall ? 32 : 38),
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 400.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms);
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSmall ? 54 : 64,
            height: isSmall ? 54 : 64,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? AppColors.textPrimary : Colors.white, size: isSmall ? 24 : 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: isSmall ? 11 : 12)),
        ],
      ),
    );
  }

  Widget _buildSelfVideo(bool isSmall) {
    return Container(
      width: isSmall ? 100 : 120,
      height: isSmall ? 140 : 170,
      decoration: BoxDecoration(
        color: AppColors.grey800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Center(child: Icon(Icons.person, color: Colors.grey.shade600, size: isSmall ? 40 : 50)),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 600.ms).slideX(begin: 0.3, end: 0);
  }
}

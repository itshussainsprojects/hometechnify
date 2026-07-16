import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/socket_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'service_in_progress_screen.dart';

class TrackProviderScreen extends StatefulWidget {
  final String? bookingId;
  final String? providerId;
  final double? initialLat;
  final double? initialLng;
  
  const TrackProviderScreen({
    super.key,
    this.bookingId,
    this.providerId,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<TrackProviderScreen> createState() => _TrackProviderScreenState();
}

class _TrackProviderScreenState extends State<TrackProviderScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final SocketService _socketService = SocketService();
  final MapController _mapController = MapController();
  
  // Real-time provider location
  LatLng _providerLocation = const LatLng(31.5204, 74.3587); // Default Lahore
  // Simulated provider data
  final Map<String, dynamic> _providerData = {
    'name': 'Ahmad Hassan',
    'service': 'AC Repair',
    'phone': '+92 300 1234567',
    'rating': 4.8,
    'eta': '15 min',
    'distance': '2.5 km',
    'status': 'On the way',
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Set initial location if provided
    if (widget.initialLat != null && widget.initialLng != null) {
      _providerLocation = LatLng(widget.initialLat!, widget.initialLng!);
    }
    
    // Join booking room to receive real-time location updates
    if (widget.bookingId != null) {
      _socketService.joinBookingRoom(widget.bookingId!);
      
      // Listen for provider location updates
      _socketService.onProviderLocation = (data) {
        final lat = data['lat'] as double;
        final lng = data['lng'] as double;
        
        setState(() {
          _providerLocation = LatLng(lat, lng);
        });
        
        // Move map to new location
        _mapController.move(_providerLocation, 15.0);
        
        debugPrint('📍 Provider location updated: $lat, $lng');
      };
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isVerySmall = size.height < 600;
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Stack(
        children: [
          // Gradient Map Placeholder with animated elements
          Container(
            height: size.height * 0.52,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F4FD),
                  Color(0xFFD4ECFB),
                  Color(0xFFC0E4F9),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Grid pattern
                CustomPaint(
                  size: Size(size.width, size.height * 0.52),
                  painter: _GridPainter(),
                ),
                
                // Animated route line
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Provider location marker with pulse
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 60 + (_pulseController.value * 20),
                            height: 60 + (_pulseController.value * 20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryBlue.withValues(alpha: 0.1 + (_pulseController.value * 0.1)),
                            ),
                            child: Center(
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryBlue.withValues(alpha: 0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 24),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Dotted line
                      Container(
                        width: 3,
                        height: 60,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) => Container(
                            width: 3,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          )),
                        ),
                      ),
                      
                      // User location marker
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B4D8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00B4D8).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 600.ms),
              ],
            ),
          ),
          
          // Back button with glassmorphism
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.primaryBlue),
              ),
            ).animate().fadeIn().slideX(begin: -0.3),
          ),
          
          // Premium ETA Badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isVerySmall ? 12 : 16, vertical: isVerySmall ? 8 : 10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.schedule_rounded, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _providerData['eta'],
                    style: TextStyle(
                      fontSize: isVerySmall ? 15 : 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn().slideX(begin: 0.3),
          
          // Premium Bottom Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 45,
                    height: 5,
                    margin: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(
                      color: AppColors.grey200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  
                  Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      children: [
                        // Animated Status badge
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: isVerySmall ? 10 : 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF10B981).withValues(alpha: 0.1),
                                const Color(0xFF34D399).withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ).animate(onPlay: (c) => c.repeat()).fadeIn().then().fadeOut(duration: 800.ms),
                              const SizedBox(width: 10),
                              Text(
                                _providerData['status'],
                                style: TextStyle(
                                  fontSize: isVerySmall ? 13 : 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.person_rounded, size: 18, color: Color(0xFF059669)),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                        
                        SizedBox(height: isVerySmall ? 14 : 18),
                        
                        // Premium Provider Card
                        Container(
                          padding: EdgeInsets.all(isVerySmall ? 12 : 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FBFF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // Gradient Avatar
                                  Container(
                                    width: isVerySmall ? 46 : 52,
                                    height: isVerySmall ? 46 : 52,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        _providerData['name'].toString().substring(0, 2).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: isVerySmall ? 15 : 18,
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
                                            fontSize: isVerySmall ? 14 : 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: isVerySmall ? 6 : 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                _providerData['service'],
                                                style: TextStyle(
                                                  fontSize: isVerySmall ? 9 : 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primaryBlue,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(Icons.star_rounded, size: isVerySmall ? 13 : 15, color: const Color(0xFFFBBF24)),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${_providerData['rating']}',
                                              style: TextStyle(
                                                fontSize: isVerySmall ? 11 : 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Action buttons
                                  _buildActionButton(Icons.call_rounded, const Color(0xFF10B981), () {}, isVerySmall),
                                  SizedBox(width: isVerySmall ? 6 : 8),
                                  _buildActionButton(Icons.chat_rounded, AppColors.primaryBlue, () {
                                    if (widget.providerId != null) {
                                      Navigator.pushNamed(context, '/chat', arguments: {
                                        'recipientId': widget.providerId,
                                        'name': _providerData['name'],
                                        'service': _providerData['service'],
                                      });
                                    } else {
                                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Provider information missing")));
                                    }
                                  }, isVerySmall),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                        
                        SizedBox(height: isVerySmall ? 12 : 16),
                        
                        // Distance Progress Bar
                        Container(
                          padding: EdgeInsets.all(isVerySmall ? 12 : 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryBlue.withValues(alpha: 0.05),
                                const Color(0xFF00B4D8).withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.navigation_rounded, size: 20, color: AppColors.primaryBlue),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Distance remaining',
                                      style: TextStyle(fontSize: isVerySmall ? 12 : 13, color: AppColors.textSecondary),
                                    ),
                                  ),
                                  Text(
                                    _providerData['distance'],
                                    style: TextStyle(
                                      fontSize: isVerySmall ? 15 : 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: 0.6,
                                  minHeight: 6,
                                  backgroundColor: AppColors.grey200,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: isVerySmall ? 14 : 18),
                        
                        // Premium Button
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceInProgressScreen(
                                  providerId: widget.providerId,
                                  providerName: _providerData['name'],
                                  serviceName: _providerData['service'],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            height: isVerySmall ? 50 : 56,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'Provider Arrived',
                                  style: TextStyle(
                                    fontSize: isVerySmall ? 15 : 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.95, 0.95)),
                        
                        SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().slideY(begin: 0.2).fadeIn(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap, bool isVerySmall) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isVerySmall ? 36 : 40,
        height: isVerySmall ? 36 : 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: isVerySmall ? 17 : 19, color: color),
      ),
    );
  }
}

// Grid painter for map effect
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1495FF).withValues(alpha: 0.08)
      ..strokeWidth = 1;

    const spacing = 30.0;
    
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

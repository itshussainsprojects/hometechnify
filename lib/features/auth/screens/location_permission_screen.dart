import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/constants.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  void _allowLocation() {
    // Home requests the OS permission itself on load; this screen only
    // decides where to go next.
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  void _denyLocation() {
    // Declining location must NOT end the session. This used to throw the
    // freshly-registered user out to the login screen — account created,
    // still signed in, but staring at "Welcome Back" as if registration
    // had failed. Location is optional; home works fine without it.
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      body: Stack(
        children: [
          // Background Map
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(31.5204, 74.3587), // Lahore, Pakistan
              initialZoom: 12.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none, // Disable interaction
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hometechnify.app',
              ),
            ],
          ),
          
          // Gradient overlay for better card visibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.85),
                  Colors.white.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),

          // Centered Content
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 20 : 32),
              child: Container(
                constraints: BoxConstraints(maxWidth: isSmall ? 380 : 420),
                padding: EdgeInsets.all(isSmall ? 28 : 36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.05),
                      blurRadius: 60,
                      offset: const Offset(0, 30),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Location icon with pulse animation
                    Container(
                      width: isSmall ? 100 : 120,
                      height: isSmall ? 100 : 120,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: isSmall ? 50 : 60,
                        color: Colors.white,
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .scale(duration: 2000.ms, begin: const Offset(1.0, 1.0), end: const Offset(1.08, 1.08))
                        .then()
                        .scale(duration: 2000.ms, begin: const Offset(1.08, 1.08), end: const Offset(1.0, 1.0)),
                    
                    SizedBox(height: isSmall ? 28 : 32),
                    
                    // Title
                    Text(
                      'Enable your location',
                      style: TextStyle(
                        fontSize: isSmall ? 24 : 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: isSmall ? 10 : 12),
                    
                    // Description
                    Text(
                      'Choose your location to start find the\nrequest around you',
                      style: TextStyle(
                        fontSize: isSmall ? 14 : 15,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: isSmall ? 32 : 40),
                    
                    // Allow button
                    GestureDetector(
                      onTap: _allowLocation,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: isSmall ? 16 : 18),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Text(
                          'Allow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmall ? 15 : 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
                    
                    SizedBox(height: isSmall ? 14 : 16),
                    
                    // Deny button
                    GestureDetector(
                      onTap: _denyLocation,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: isSmall ? 16 : 18),
                        decoration: BoxDecoration(
                          color: AppColors.grey50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.grey200, width: 1.5),
                        ),
                        child: Text(
                          'Don\'t Allow',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: isSmall ? 15 : 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2, end: 0),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), curve: Curves.easeOutBack),
            ),
          ),
        ],
      ),
    );
  }
}

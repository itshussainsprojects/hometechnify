// Nearby Providers Screen - Shows providers on map with their rates
// User can see nearby providers who can do their job with quoted rates

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';

class NearbyProvidersScreen extends StatefulWidget {
  final String serviceName;
  final IconData serviceIcon;
  final String? description;
  final String? mediaType;
  final String? mediaPath;

  const NearbyProvidersScreen({
    super.key,
    required this.serviceName,
    required this.serviceIcon,
    this.description,
    this.mediaType,
    this.mediaPath,
  });

  @override
  State<NearbyProvidersScreen> createState() => _NearbyProvidersScreenState();
}

class _NearbyProvidersScreenState extends State<NearbyProvidersScreen> {
  int _selectedProviderIndex = -1;
  bool _isLoading = true;

  // Sample providers with rates
  final List<ProviderData> _providers = [
    ProviderData(
      id: '1',
      name: 'Ahmad Khan',
      rating: 4.8,
      reviews: 124,
      rate: 1500,
      distance: 0.8,
      lat: 31.4820,
      lng: 74.3222,
      image: null,
      isOnline: true,
    ),
    ProviderData(
      id: '2',
      name: 'Ali Hassan',
      rating: 4.6,
      reviews: 89,
      rate: 1200,
      distance: 1.2,
      lat: 31.4780,
      lng: 74.3180,
      image: null,
      isOnline: true,
    ),
    ProviderData(
      id: '3',
      name: 'Usman Tariq',
      rating: 4.9,
      reviews: 203,
      rate: 1800,
      distance: 1.5,
      lat: 31.4850,
      lng: 74.3280,
      image: null,
      isOnline: false,
    ),
    ProviderData(
      id: '4',
      name: 'Bilal Ahmed',
      rating: 4.5,
      reviews: 67,
      rate: 1000,
      distance: 2.0,
      lat: 31.4760,
      lng: 74.3250,
      image: null,
      isOnline: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Simulate loading providers
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _onProviderTap(int index) {
    setState(() => _selectedProviderIndex = index);
  }

  void _acceptProvider(ProviderData provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Booking', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Accept ${provider.name}\'s quote of'),
            const SizedBox(height: 8),
            Text(
              'Rs. ${provider.rate}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/booking-success');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(31.4800, 74.3200),
              initialZoom: 14.0,
              onTap: (tapPosition, point) => setState(() => _selectedProviderIndex = -1),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hometechnify.app',
              ),
              // Provider markers
              MarkerLayer(
                markers: _providers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final provider = entry.value;
                  final isSelected = _selectedProviderIndex == index;
                  
                  return Marker(
                    point: LatLng(provider.lat, provider.lng),
                    width: isSelected ? 100 : 80,
                    height: isSelected ? 50 : 40,
                    child: GestureDetector(
                      onTap: () => _onProviderTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppColors.primaryGradient : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? AppColors.primaryBlue.withValues(alpha: 0.4)
                                  : Colors.black.withValues(alpha: 0.2),
                              blurRadius: isSelected ? 12 : 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: isSelected ? AppColors.primaryBlue : AppColors.grey200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rs.${provider.rate}',
                              style: TextStyle(
                                fontSize: isSelected ? 14 : 12,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // User location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: const LatLng(31.4800, 74.3200),
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // App bar
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(widget.serviceIcon, color: AppColors.primaryBlue, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.serviceName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${_providers.length} providers nearby',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primaryBlue),
                      const SizedBox(height: 16),
                      const Text(
                        'Finding providers...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom providers list
          if (!_isLoading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: isSmall ? 200 : 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.grey300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text(
                            'Available Providers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_providers.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _providers.length,
                        itemBuilder: (context, index) {
                          final provider = _providers[index];
                          final isSelected = _selectedProviderIndex == index;
                          
                          return GestureDetector(
                            onTap: () => _onProviderTap(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isSmall ? 160 : 180,
                              margin: const EdgeInsets.only(right: 12, bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.05) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryBlue : AppColors.grey200,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.2), blurRadius: 12)]
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.primaryBlue,
                                        child: Text(
                                          provider.name[0],
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              provider.name,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              children: [
                                                Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                                Text(
                                                  ' ${provider.rating}',
                                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Rs.${provider.rate}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _acceptProvider(provider),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: AppColors.primaryGradient,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Accept',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: index * 100));
                        },
                      ),
                    ),
                  ],
                ),
              ).animate().slideY(begin: 0.3, end: 0, duration: 500.ms),
            ),
        ],
      ),
    );
  }
}

class ProviderData {
  final String id;
  final String name;
  final double rating;
  final int reviews;
  final int rate;
  final double distance;
  final double lat;
  final double lng;
  final String? image;
  final bool isOnline;

  ProviderData({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviews,
    required this.rate,
    required this.distance,
    required this.lat,
    required this.lng,
    this.image,
    required this.isOnline,
  });
}

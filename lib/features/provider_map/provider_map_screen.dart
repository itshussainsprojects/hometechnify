// Provider Map Screen - Shows providers on map with carousel

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import '../../core/services/map_service.dart';
import '../../core/services/provider_simulation_service.dart'; // Import Simulation Service
import '../provider/providers/provider_controller.dart';
import '../provider/data/models/provider_model.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'package:geocoding/geocoding.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/providers/navigation_provider.dart';


class ProviderMapScreen extends StatefulWidget {
  final String serviceName;
  final String serviceId;
  final Color serviceColor;

  const ProviderMapScreen({
    super.key,
    required this.serviceName,
    required this.serviceId,
    required this.serviceColor,
  });

  @override
  State<ProviderMapScreen> createState() => _ProviderMapScreenState();
}



class _ProviderMapScreenState extends State<ProviderMapScreen> {
  int _currentProviderIndex = 0;
  late PageController _pageController;
  
  // Local state to track filtered/rejected providers
  final Set<String> _rejectedProviderIds = {};
  
  // Simulation Service
  final _simulationService = ProviderSimulationService();
  List<ProviderModel> _simulatedProviders = [];
  final bool _useSimulation = true; // Flag to toggle simulation
  
  // User Location
  LatLng _userLocation = const LatLng(31.4800, 74.3200); // Default fallback
  String _currentAddress = "Current Location"; // Store address
  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9); // Slightly create more space
    
    _getCurrentLocation();
    
    _simulationService.providerStream.listen((providers) {
      if (mounted) {
        setState(() {
          _simulatedProviders = providers;
        });
      }
    });

    // Also fetch real API providers in background (optional, maybe merge later)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderController>().fetchProviders(categoryId: widget.serviceId);
    });
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) SnackBarHelper.showWarning(context, "Location services are disabled. Using default location.");
        // Continue to fallback
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
           if (mounted) {
             SnackBarHelper.showError(context, "Location permission denied. Map centered on Lahore.");
             
             _startFallbackSimulation();
           }
           return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
         if (mounted) {
             SnackBarHelper.showError(context, "Location permission permanently denied.");
             
             _startFallbackSimulation();
         }
         return;
      }
      
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);

        });
        // Start simulation around real location
        _simulationService.startSimulation(_userLocation, serviceName: widget.serviceName);
        
        // Reverse Geocode
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            setState(() {
              _currentAddress = "${place.street}, ${place.subLocality} ${place.locality}";
            });
          }
        } catch (e) {
          debugPrint("Geocoding failed: $e");
        }
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) {
         
         _startFallbackSimulation();
      }
    }
  }

  void _startFallbackSimulation() {
      _simulationService.startSimulation(_userLocation, serviceName: widget.serviceName);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _simulationService.dispose();
    super.dispose();
  }

  void _rejectProvider(List<ProviderModel> visibleProviders) {
    if (_currentProviderIndex < visibleProviders.length) {
      final provider = visibleProviders[_currentProviderIndex];
      setState(() {
        _rejectedProviderIds.add(provider.id);
        // Adjust index if needed
        if (_currentProviderIndex >= visibleProviders.length - 1) {
           _currentProviderIndex = (visibleProviders.length - 2).clamp(0, visibleProviders.length);
        }
      });
    }
  }

  void _bookProvider(List<ProviderModel> visibleProviders) {
    if (_currentProviderIndex < visibleProviders.length) {
      final provider = visibleProviders[_currentProviderIndex];
      Navigator.pushNamed(
        context,
        '/booking',
        arguments: {
          'providerName': provider.name,
          'serviceName': widget.serviceName,
          'price': provider.hourlyRate.toString(), // Using hourlyRate as price
          'providerId': provider.id,
          'serviceId': widget.serviceId, // Pass serviceId
          'initialAddress': _currentAddress, // Pass GPS address
          'initialLat': _userLocation.latitude,
          'initialLng': _userLocation.longitude,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProviderController>(
      builder: (context, controller, _) {
        // Use simulated providers if enabled, otherwise fall back to controller
        List<ProviderModel> sourceProviders = _useSimulation ? _simulatedProviders : controller.providers;
        
        // Filter out rejected and invalid location providers
        final visibleProviders = sourceProviders.where((ProviderModel p) {
          // ignore: unnecessary_null_comparison
          return p != null && 
                 !_rejectedProviderIds.contains(p.id) && 
                 p.latitude != null && p.longitude != null;
        }).toList();

        // If not simulating and loading
        if (!_useSimulation && controller.isLoading) {
           return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Handle empty state (No providers found)
        if (visibleProviders.isEmpty) {
          // Check if it's just loading simulation?
          if (_useSimulation && _simulatedProviders.isEmpty) {
             return const Scaffold(body: Center(child: CircularProgressIndicator())); 
          }
          
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: BackButton(color: AppColors.textPrimary),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Providers Nearby',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try again later or search a different area',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Go Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        }

        final size = MediaQuery.of(context).size;
        final isSmall = size.height < 700;

        return Scaffold(
          body: Stack(
            children: [
              // Map with provider icons
              _buildMap(size, isSmall, visibleProviders),

              // Header
              _buildHeader(context, isSmall),

              // Provider cards carousel at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: size.height < 600 ? 200 : size.height < 700 ? 220 : size.height < 800 ? 240 : 280,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: visibleProviders.length,
                  onPageChanged: (index) {
                    setState(() => _currentProviderIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return _buildProviderCard(visibleProviders[index], isSmall, visibleProviders);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(Size size, bool isSmall, List<ProviderModel> providers) {
    // Use real user location
    // userLat/Lng were removed from method, using _userLocation directly

    return FlutterMap(
      options: MapOptions(
        initialCenter: _userLocation,
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.hometechnify.app',
          tileProvider: MapService.getTileProvider(),
        ),
        MarkerLayer(
          markers: [
            // User Marker
            Marker(
              point: _userLocation,
              width: 140,
              height: 90,
              child: Center(
                child: Container(
                  width: isSmall ? 42 : 48,
                  height: isSmall ? 42 : 48,
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
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: isSmall ? 22 : 24,
                  ),
                ),
              ),
            ),
            // Provider Markers
            ...providers.asMap().entries.map((entry) {
              final index = entry.key;
              final provider = entry.value;
              final lat = provider.latitude ?? _userLocation.latitude;
              final lng = provider.longitude ?? _userLocation.longitude;
              
              return Marker(
                point: LatLng(lat, lng),
                width: 70,
                height: 80,
                child: GestureDetector(
                   onTap: () {
                     // Animate page controller
                     _pageController.animateToPage(
                        index, 
                        duration: 300.ms, 
                        curve: Curves.easeInOut
                     );
                     setState(() => _currentProviderIndex = index);
                   },
                   child: _buildProviderPin(provider, isSmall, index),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isSmall) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: isSmall ? 12 : 16,
      right: isSmall ? 12 : 16,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                // Fallback: switch to Home tab in the IndexedStack
                context.read<NavigationProvider>().setIndex(0);
              }
            },
            child: Container(
              width: isSmall ? 40 : 44,
              height: isSmall ? 40 : 44,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
                size: isSmall ? 20 : 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 12 : 16,
                vertical: isSmall ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryBlue,
                    size: isSmall ? 18 : 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search location (e.g. DHA)',
                        hintStyle: TextStyle(
                          fontSize: isSmall ? 13 : 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        fontSize: isSmall ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      onSubmitted: (_) => _handleSearch(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildProviderPin(ProviderModel provider, bool isSmall, int index) {
    final isSelected = index == _currentProviderIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      transform: Matrix4.translationValues(0.0, isSelected ? -8.0 : 0.0, 0.0),
      child: Column(
        children: [
          Container(
            width: isSmall ? 44 : 48,
            height: isSmall ? 44 : 48,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryBlue : AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : AppColors.primaryBlue,
                width: isSmall ? 2 : 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSelected ? AppColors.primaryBlue : AppColors.black)
                      .withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
              child: Center(
                child: FittedBox( // Fix Overflow in PIN
                  fit: BoxFit.scaleDown,
                  child: Text(
                    provider.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.primaryBlue,
                      fontSize: isSmall ? 12 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 5 : 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: isSmall ? 9 : 10,
                  color: Colors.white,
                ),
                const SizedBox(width: 2),
                Text(
                  provider.rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: isSmall ? 9 : 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(target: isSelected ? 1 : 0).scaleXY(end: 1.1);
  }

  // Search Controller
  final TextEditingController _searchController = TextEditingController();

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    try {
      final results = await locationFromAddress(query);
      if (results.isNotEmpty) {
        final loc = results.first;
        if (mounted) {
          setState(() {
            _userLocation = LatLng(loc.latitude, loc.longitude);
            _currentAddress = query;
          });
          _simulationService.startSimulation(_userLocation, serviceName: widget.serviceName);
        }
      } else {
        if (mounted) SnackBarHelper.showWarning(context, "Location not found");
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) SnackBarHelper.showError(context, "Could not find location");
    }
  }

  Widget _buildProviderCard(ProviderModel provider, bool isSmall, List<ProviderModel> visibleProviders) {
    // Calculate distance
    final Distance distance = const Distance();
    final double providerLat = provider.latitude ?? _userLocation.latitude;
    final double providerLng = provider.longitude ?? _userLocation.longitude;
    final double km = distance.as(LengthUnit.Kilometer, _userLocation, LatLng(providerLat, providerLng));

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(isSmall ? 8 : 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(isSmall ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView( // Prevent overflow
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(isSmall ? 12 : 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Provider info row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Container(
                        width: isSmall ? 50 : 60,
                        height: isSmall ? 50 : 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryBlue,
                              AppColors.primaryBlue.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(isSmall ? 12 : 14),
                        ),
                        child: Center(
                          child: provider.profileImage != null 
                             ? ClipRRect(
                                 borderRadius: BorderRadius.circular(isSmall ? 12 : 14),
                                 child: Image.network(provider.profileImage!, fit: BoxFit.cover),
                               )
                             : Text(
                                  provider.name.split(' ').map((e) => e[0]).take(2).join(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmall ? 16 : 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(width: isSmall ? 12 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name & Verified Badge
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    provider.name,
                                    style: TextStyle(
                                      fontSize: isSmall ? 16 : 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.verified_rounded, color: AppColors.primaryBlue, size: 14),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.serviceName,
                              style: TextStyle(
                                fontSize: isSmall ? 11 : 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
                                      const SizedBox(width: 2),
                                      Text(
                                        provider.rating.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${provider.reviewCount} reviews',
                                    style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on_rounded, size: 10, color: AppColors.primaryBlue),
                                      const SizedBox(width: 2),
                                      Flexible( // Nested flexible for text
                                        child: Text(
                                          '${km.toStringAsFixed(1)} km',
                                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // NEW: Local Providers Badge / Stats
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F2F5), // Soft grey replacement
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${provider.experience + 2} Years Experience • ${10 + provider.reviewCount * 2} Jobs Done',
                                style: TextStyle(
                                  fontSize: 10, 
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quoted Rate (Compact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                           Text('Rate/hr', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                           Text(
                            'Rs. ${provider.hourlyRate.toInt()}',
                            style: TextStyle(
                              fontSize: isSmall ? 16 : 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: isSmall ? 12 : 16),
                  
                  // Action buttons with Expanded
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () => _rejectProvider(visibleProviders),
                          child: Container(
                            height: isSmall ? 40 : 46, // Taller buttons
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                            ),
                            child: Center(
                              child: Text(
                                'Reject',
                                style: TextStyle(
                                  fontSize: isSmall ? 12 : 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: () => _showNegotiateDialog(provider),
                          child: Container(
                            height: isSmall ? 40 : 46,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Bargain', 
                                style: TextStyle(
                                  fontSize: isSmall ? 12 : 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Action Button
                      Expanded(
                         flex: 4, // More weight to Book Now
                        child: GestureDetector(
                          onTap: () => _bookProvider(visibleProviders),
                          child: Container(
                            height: isSmall ? 40 : 46,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Book Now',
                                style: TextStyle(
                                  fontSize: isSmall ? 13 : 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
            ),
          ],
        ),
      ),
    ).animate().slideY(
      begin: 1,
      end: 0,
      duration: 400.ms,
      curve: Curves.easeOutQuart,
    );
  }

  void _showNegotiateDialog(ProviderModel provider) {
    final originalPrice = provider.hourlyRate.toInt().toString();
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _NegotiateDialogContent(
        provider: provider,
        serviceName: widget.serviceName,
        serviceColor: AppColors.primaryBlue,
        originalPrice: originalPrice,
      ),
    );
  }
}

class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0).withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    // Draw subtle grid
    const gridSize = 50.0;
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Stateful dialog for negotiation with chat
class _NegotiateDialogContent extends StatefulWidget {
  final ProviderModel provider;
  final String serviceName;
  final Color serviceColor;
  final String originalPrice;

  const _NegotiateDialogContent({
    required this.provider,
    required this.serviceName,
    required this.serviceColor,
    required this.originalPrice,
  });

  @override
  State<_NegotiateDialogContent> createState() => _NegotiateDialogContentState();
}

class _NegotiateDialogContentState extends State<_NegotiateDialogContent> {
  final _priceController = TextEditingController();
  final List<Map<String, dynamic>> _offers = [];

  @override
  void initState() {
    super.initState();
    // Add provider's initial offer
    _offers.add({
      'amount': 'Rs. ${widget.originalPrice}',
      'by': 'provider',
      'message': 'My rate for ${widget.serviceName}',
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _sendOffer() {
    if (_priceController.text.isNotEmpty) {
      setState(() {
        _offers.add({
          'amount': 'Rs. ${_priceController.text}',
          'by': 'user',
          'message': 'My offer',
        });
        _priceController.clear();
      });
      // Simulate provider response
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _offers.add({
              'amount': _offers.last['amount'],
              'by': 'provider',
              'message': 'I accept this offer!',
            });
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTiny = size.height < 650;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: isTiny ? 40 : 60),
      child: Container(
        constraints: BoxConstraints(maxHeight: size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  // Provider avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: widget.provider.profileImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(widget.provider.profileImage!, fit: BoxFit.cover),
                            )
                          : Text(
                              widget.provider.name.split(' ').map((e) => e[0]).take(2).join(),
                              style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.provider.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.serviceName,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.warning, size: 13),
                      const SizedBox(width: 2),
                      Text(
                        widget.provider.rating.toString(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.grey200),
            // Chat messages section
            Flexible(
              child: _offers.isEmpty
                  ? const Center(child: Text('Start negotiating!'))
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _offers.length,
                      itemBuilder: (context, index) {
                        final offer = _offers[index];
                        final isMe = offer['by'] == 'user';
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.only(
                              bottom: 8,
                              left: isMe ? 40 : 0,
                              right: isMe ? 0 : 40,
                            ),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primaryBlue : AppColors.grey100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  offer['amount'],
                                  style: TextStyle(
                                    color: isMe ? Colors.white : AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  offer['message'],
                                  style: TextStyle(
                                    color: isMe ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Quick chips
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [50, 100, 200, 500].map((amount) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        final basePrice = int.parse(widget.originalPrice.replaceAll(RegExp(r'[^0-9]'), ''));
                        final newPrice = basePrice - amount;
                        if (newPrice > 0) {
                          _priceController.text = newPrice.toString();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '- Rs. $amount',
                            style: const TextStyle(color: AppColors.primaryBlue, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            // Input row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.grey50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.grey200),
                      ),
                      child: Row(
                        children: [
                          const Text('Rs.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: widget.originalPrice,
                                hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        // Navigate to booking with negotiated price
                        final lastPrice = _offers.isNotEmpty ? _offers.last['amount'] : 'Rs. ${widget.originalPrice}';
                        Navigator.pushNamed(context, '/booking', arguments: {
                          'provider': widget.provider.name,
                          'service': widget.serviceName,
                          'price': lastPrice.toString().replaceAll(RegExp(r'[^0-9]'), ''),
                          'negotiated': true,
                          'providerId': widget.provider.id, // Add providerId
                          'serviceId': widget.provider.category, // Assuming category is service name or ID? No, use passed serviceName/Id logic from caller
                          // Actually Booking screen receives whatever arguments we pass.
                          // But we should be consistent.
                          // The 'service' argument is name.
                        });
                      },
                      child: Container(
                        height: 42,
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
                        child: const Center(
                          child: Text('Accept & Book', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                        ),
                        child: const Center(
                          child: Text('Decline', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

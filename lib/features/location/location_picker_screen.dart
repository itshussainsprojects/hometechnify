// Location Picker Screen

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:home_technify/features/auth/providers/auth_provider.dart';
import 'package:home_technify/features/address/providers/address_provider.dart';
import 'package:home_technify/features/address/data/models/address_model.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _searchController = TextEditingController();
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    // Fetch addresses on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final user = context.read<AuthProvider>().user;
       if (user != null) {
          context.read<AddressProvider>().fetchAddresses(user.id);
       }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    
    setState(() => _selectedAddress = "Searching...");
    
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        List<Placemark> placemarks = await placemarkFromCoordinates(locations.first.latitude, locations.first.longitude);
        if (placemarks.isNotEmpty) {
           Placemark place = placemarks[0];
           List<String> parts = [];
           if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
           if (place.subLocality != null && place.subLocality!.isNotEmpty) parts.add(place.subLocality!);
           if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
           if (place.country != null && place.country!.isNotEmpty) parts.add(place.country!);
           
           setState(() {
             _selectedAddress = parts.join(", ");
           });
        }
      } else {
        setState(() => _selectedAddress = null);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location not found")));
      }
    } catch (e) {
       setState(() => _selectedAddress = null);
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Search failed")));
    }
  }
  
  Future<void> _getCurrentLocation() async {
      setState(() => _selectedAddress = "Locating...");
      
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location services are disabled.")));
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) return;
        }
        
        if (permission == LocationPermission.deniedForever) return;

        final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        
        if (placemarks.isNotEmpty) {
           Placemark place = placemarks[0];
           List<String> parts = [];
           if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
           if (place.subLocality != null && place.subLocality!.isNotEmpty) parts.add(place.subLocality!);
           if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
           
           setState(() {
             _selectedAddress = parts.join(", ");
           });
        }
      } catch (e) {
         setState(() => _selectedAddress = null);
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to get location")));
      }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        title: const Text(
          'Select Location',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(horizontalPadding),
          _buildCurrentLocation(horizontalPadding),
          Expanded(child: _buildSavedAddresses(horizontalPadding)),
        ],
      ),
      bottomNavigationBar: _buildConfirmButton(horizontalPadding),
    );
  }

  Widget _buildSearchBar(double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search location...',
            hintStyle: TextStyle(color: AppColors.textHint),
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.grey400),
            suffixIcon: IconButton(
              icon: Icon(Icons.arrow_forward_rounded, color: AppColors.primaryBlue),
              onPressed: () => _performSearch(_searchController.text),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
          onSubmitted: (val) => _performSearch(val),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildCurrentLocation(double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: GestureDetector(
        onTap: _getCurrentLocation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use Current Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Auto-detect via GPS',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildSavedAddresses(double horizontalPadding) {
    return Consumer<AddressProvider>(
      builder: (context, provider, _) {
          final addresses = provider.addresses;
          
          if (addresses.isEmpty) {
             return Center(child: Text("No saved addresses", style: TextStyle(color: AppColors.grey500)));
          }

          return ListView(
            padding: EdgeInsets.all(horizontalPadding),
            children: [
              const SizedBox(height: 8),
              const Text(
                'Saved Addresses',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ...addresses.map((address) => _buildAddressCard(address)),
            ],
          );
      }
    );
  }

  Widget _buildAddressCard(AddressModel address) {
    final isSelected = _selectedAddress == address.address;

    return GestureDetector(
      onTap: () => setState(() => _selectedAddress = address.address),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.grey200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isSelected ? AppColors.primaryBlue : AppColors.grey300)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                address.label.toLowerCase().contains('home')
                    ? Icons.home_rounded
                    : address.label.toLowerCase().contains('work') ? Icons.work_rounded : Icons.location_on_rounded,
                color: isSelected ? AppColors.primaryBlue : AppColors.grey500,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.address,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildConfirmButton(double horizontalPadding) {
    final isEnabled = _selectedAddress != null;

    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: isEnabled
              ? () => Navigator.pop(context, _selectedAddress)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            decoration: BoxDecoration(
              gradient: isEnabled ? AppColors.primaryGradient : null,
              color: isEnabled ? null : AppColors.grey200,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                'Confirm Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isEnabled ? Colors.white : AppColors.grey400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

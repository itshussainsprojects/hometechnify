// My Addresses Screen - Fully Functional with Backend Integration

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/responsive.dart';
import 'package:home_technify/features/auth/providers/auth_provider.dart';
import 'package:home_technify/features/address/providers/address_provider.dart';
import 'package:home_technify/features/address/data/models/address_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/neu_theme.dart';

class MyAddressesScreen extends StatefulWidget {
  const MyAddressesScreen({super.key});

  @override
  State<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends State<MyAddressesScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<AddressProvider>().fetchAddresses(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: NeuTheme.bg,
      appBar: AppBar(
        backgroundColor: NeuTheme.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: NeuTheme.sm(radius: 12),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          ),
        ),
        title: const Text(
          'My Addresses',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<AddressProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.addresses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (provider.error != null && provider.addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading addresses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(provider.error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                         final user = context.read<AuthProvider>().user;
                         if (user != null) context.read<AddressProvider>().fetchAddresses(user.id);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.addresses.isEmpty) {
            return _buildEmptyState(isSmall);
          }

          return ListView(
            padding: EdgeInsets.all(horizontalPadding),
            children: [
              const SizedBox(height: 8),
              ...provider.addresses.map((addr) => _buildAddressCard(addr, isSmall)),
              const SizedBox(height: 8),
              _buildAddNewButton(isSmall),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isSmall) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: NeuTheme.circle(),
            child: Icon(Icons.location_off_rounded, size: 50, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 24),
          Text(
            'No Addresses Yet',
            style: TextStyle(fontSize: isSmall ? 18 : 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first address to get started',
            style: TextStyle(fontSize: isSmall ? 14 : 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildAddNewButton(isSmall),
        ],
      ),
    );
  }

  Widget _buildAddressCard(AddressModel address, bool isSmall) {
    // Determine icon based on label
    IconData icon = Icons.location_on_rounded;
    if (address.label.toLowerCase().contains('home')) icon = Icons.home_rounded;
    if (address.label.toLowerCase().contains('work')) icon = Icons.work_rounded;

    return GestureDetector(
      onTap: () {
        context.read<AddressProvider>().selectAddress(address);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address selected as current location')),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all(isSmall ? 16 : 18),
        decoration: NeuTheme.sm(radius: 20),
        child: Row(
          children: [
            Container(
              width: isSmall ? 48 : 52,
              height: isSmall ? 48 : 52,
              decoration: NeuTheme.sm(radius: 14),
              child: Icon(icon, color: AppColors.primaryBlue, size: isSmall ? 22 : 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.label,
                    style: TextStyle(fontSize: isSmall ? 16 : 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.address,
                    style: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.textSecondary, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              onPressed: () => _confirmDelete(address),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildAddNewButton(bool isSmall) {
    return GestureDetector(
      onTap: () => _showAddAddressDialog(),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 16 : 18, horizontal: 32),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              'Add New Address',
              style: TextStyle(fontSize: isSmall ? 15 : 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  void _confirmDelete(AddressModel address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address?'),
        content: Text('Are you sure you want to remove "${address.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AddressProvider>().deleteAddress(address.id, context);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showAddAddressDialog() {
    final titleController = TextEditingController();
    final addressController = TextEditingController();
    String selectedType = 'Home';
    double? gpsLat;
    double? gpsLng;
    bool locatingGps = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, color: AppColors.grey300)),
                const SizedBox(height: 20),
                const Text('Add New Address', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                
                // Type Selector
                Row(
                  children: ['Home', 'Work', 'Other'].map((type) {
                    final isSelected = selectedType == type;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedType = type),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryBlue : AppColors.grey100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Fields
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Label (Optional)', hintText: 'e.g. Dream House'),
                ),
                const SizedBox(height: 16),

                // GPS Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: locatingGps
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setModalState(() => locatingGps = true);
                            try {
                              LocationPermission permission = await Geolocator.checkPermission();
                              if (permission == LocationPermission.denied) {
                                permission = await Geolocator.requestPermission();
                              }
                              if (permission == LocationPermission.denied ||
                                  permission == LocationPermission.deniedForever) {
                                messenger.showSnackBar(const SnackBar(
                                    content: Text('Location permission is required to use your current location.')));
                                return;
                              }

                              final position = await Geolocator.getCurrentPosition(
                                locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                              );
                              final placemarks =
                                  await placemarkFromCoordinates(position.latitude, position.longitude);

                              if (placemarks.isNotEmpty) {
                                final place = placemarks[0];
                                final parts = <String>[];
                                if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
                                if (place.subLocality != null && place.subLocality!.isNotEmpty) parts.add(place.subLocality!);
                                if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
                                if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
                                  parts.add(place.administrativeArea!);
                                }
                                setModalState(() {
                                  addressController.text = parts.join(', ');
                                  gpsLat = position.latitude;
                                  gpsLng = position.longitude;
                                });
                              }
                            } catch (e) {
                              messenger.showSnackBar(const SnackBar(content: Text('Could not get current location.')));
                            } finally {
                              setModalState(() => locatingGps = false);
                            }
                          },
                    icon: locatingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(locatingGps ? 'Locating...' : 'Use Current Location'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Search / Address Field
                TextField(
                  controller: addressController,
                  maxLines: null,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Full Address', 
                    hintText: 'Search or type address...',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                      onPressed: () async {
                         final query = addressController.text;
                         if (query.isNotEmpty) {
                           final messenger = ScaffoldMessenger.of(context);
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
                                  if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) parts.add(place.administrativeArea!);

                                  if (mounted) setState(() { addressController.text = parts.join(", "); });
                                  messenger.showSnackBar(SnackBar(content: Text("Found: ${parts.join(", ")}")));
                               }
                             } else {
                               messenger.showSnackBar(const SnackBar(content: Text("Address not found")));
                             }
                           } catch (e) {
                             messenger.showSnackBar(const SnackBar(content: Text("Search failed")));
                           }
                         }
                      },
                    ),
                  ),
                  onSubmitted: (val) async {
                       // Trigger search on submit
                       // Duplicate logic for simplicity or extract method
                         final query = val;
                         if (query.isNotEmpty) {
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
                                  
                                  setState(() {
                                    addressController.text = parts.join(", ");
                                  });
                               }
                             }
                           } catch (_) {}
                         }
                  },
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (addressController.text.isEmpty) return;
                      
                      final user = context.read<AuthProvider>().user;
                      if (user != null) {
                        context.read<AddressProvider>().addAddress(
                          user.id,
                          addressController.text,
                          label: titleController.text.isNotEmpty ? titleController.text : selectedType,
                          lat: gpsLat,
                          lng: gpsLng,
                          context: context
                        );
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

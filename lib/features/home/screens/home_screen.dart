// Premium Home Screen with Enhanced Services

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/techy_animation.dart';
import '../../../core/widgets/techy_buddy.dart';
import '../../../core/utils/service_visuals.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../widgets/service_card.dart';
import 'package:provider/provider.dart';
import '../providers/service_provider.dart';
import '../widgets/home_shimmer.dart';
import 'package:home_technify/features/notifications/providers/notification_provider.dart';
import 'package:home_technify/core/providers/navigation_provider.dart';
import 'package:home_technify/features/auth/providers/auth_provider.dart';
import 'package:geolocator/geolocator.dart' hide ServiceStatus;
import 'package:geocoding/geocoding.dart';
import '../../profile/providers/profile_provider.dart';
import '../../address/providers/address_provider.dart';
import '../../booking/my_bookings_screen.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../profile/profile_screen.dart'; // Ensure this path is correct
import '../../../core/theme/neu_theme.dart';

// ... existing imports ...

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentBannerIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final PageController _bannerPageController = PageController();
  String _searchQuery = '';
  String _currentLocation = 'Select Location';
  bool _gettingLocation = false;

  // Living mascot in the hero card - reacts when good things happen.
  final GlobalKey<TechyBuddyState> _techyKey = GlobalKey<TechyBuddyState>();
  NotificationProvider? _notifProvider;
  int _lastUnreadCount = 0;

  // Settings > Location Services can be flipped while the user is sitting
  // on the Profile tab, not this one. HomeScreen lives inside an
  // IndexedStack (never disposed, so didChangeAppLifecycleState only fires
  // on true app backgrounding) — without this listener the toggle silently
  // did nothing until the next cold resume, which looked broken.
  ProfileProvider? _profileProvider;
  bool? _lastLocationEnabled;

  // Softly fades/raises the page content in whenever the tab changes.
  late final AnimationController _tabSwitchController;

  // Pulses the "Book a Service" button in sync with Techy pointing at it.
  late final AnimationController _ctaPulseController;
  
  final List<NavItem> _navItems = [
    NavItem(icon: Icons.home_rounded, label: 'Home'),
    NavItem(icon: Icons.calendar_month_rounded, label: 'Bookings'),
    NavItem(icon: Icons.chat_bubble_rounded, label: 'Chat'),
    NavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _tabSwitchController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340), value: 1);
    _ctaPulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));

    // Initialize Notification Provider with Firebase UID (not Postgres UUID)
    WidgetsBinding.instance.addObserver(this); // Add Observer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final firebaseUid = FirebaseAuthService.getUserId();
      // Fetch Notifications
      if (firebaseUid != null) {
        context.read<NotificationProvider>().init(firebaseUid);
      }

      // Techy celebrates when a new notification arrives (booking updates,
      // offers, provider messages) - a tiny hop, never a popup.
      _notifProvider = context.read<NotificationProvider>();
      _lastUnreadCount = _notifProvider!.unreadCount;
      _notifProvider!.addListener(_onNotificationsChanged);
      
      // Fetch Addresses for Dropdown
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        if (mounted) {
          context.read<AddressProvider>().fetchAddresses(user.id);
          context.read<ProfileProvider>().fetchProfile(user.id);
          favoritesService.init(user.id);
        }
      }

      // React immediately when Location Services is toggled from Settings,
      // instead of waiting for the next app resume.
      _profileProvider = context.read<ProfileProvider>();
      _lastLocationEnabled = _profileProvider!.appLocationEnabled;
      _profileProvider!.addListener(_onProfileChanged);

      // Admin promo change — this used to only ever appear on a fresh
      // HomeScreen widget instance (the fetch was memoized in _promosCache
      // for the widget's whole lifetime, and nothing invalidated it), so a
      // promo created/edited/deleted was invisible until the app restarted.
      SocketService().onPromosUpdated = _onPromosUpdated;
      if(mounted) {
          context.read<ServiceProvider>().loadServices();
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    
    // Auto-detect location on startup
    _getCurrentLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-refresh location when user comes back to app (e.g. from Settings)
    if (state == AppLifecycleState.resumed) {
      _getCurrentLocation();
    }
  }

  // Automatic call site (startup, app resume) — silently respects the
  // Settings > Location Services preference instead of prompting.
  Future<void> _getCurrentLocation() async {
    final profile = context.read<ProfileProvider>();
    if (!profile.appLocationEnabled) {
       setState(() {
         _currentLocation = 'Location Off';
         _gettingLocation = false;
       });
       return;
    }
    await _fetchLocation();
  }

  // Explicit call site — the user tapped "Use My Current Location" in the
  // picker. That tap is unambiguous consent, so it must always attempt a
  // fetch (and flip the preference back on) instead of silently doing
  // nothing when Location Services happened to be toggled off — which
  // looked exactly like the button was broken.
  Future<void> _fetchLocation() async {
    final profile = context.read<ProfileProvider>();
    if (!profile.appLocationEnabled) {
      profile.setAppLocation(true);
    }

    setState(() {
      _gettingLocation = true;
      if (_currentLocation == 'Select Location') _currentLocation = 'Locating...';
    });
    
    if (mounted) context.read<AddressProvider>().selectAddress(null);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showEnableLocationDialog();
          setState(() {
            _currentLocation = 'Location Disabled';
            _gettingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showError("Location permission denied.");
            setState(() {
              _currentLocation = 'Permission Denied';
              _gettingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showError("Location permissions are permanently denied. Please enable them in settings.");
          setState(() {
            _currentLocation = 'Permission Denied';
            _gettingLocation = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      );

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];

          debugPrint("DEBUG LOCATION: Lat: ${position.latitude}, Lng: ${position.longitude}");
          debugPrint("DEBUG PLACEMARK: $place");

          Set<String> addressParts = {};

          bool shouldExclude(String s) => s.toLowerCase().contains("waqar");

          if (place.street?.isNotEmpty == true && !shouldExclude(place.street!)) addressParts.add(place.street!);
          if (place.subLocality?.isNotEmpty == true && !shouldExclude(place.subLocality!)) addressParts.add(place.subLocality!);
          if (place.locality?.isNotEmpty == true && !shouldExclude(place.locality!)) addressParts.add(place.locality!);
          if (place.subAdministrativeArea?.isNotEmpty == true && !shouldExclude(place.subAdministrativeArea!)) addressParts.add(place.subAdministrativeArea!);
          if (place.administrativeArea?.isNotEmpty == true && !shouldExclude(place.administrativeArea!)) addressParts.add(place.administrativeArea!);
          if (place.country?.isNotEmpty == true) addressParts.add(place.country!);

          final hasRawalpindiOrTaxila = addressParts.any((s) => s.contains("Taxila") || s.contains("Rawalpindi"));
          if (hasRawalpindiOrTaxila) addressParts.removeWhere((s) => s.contains("Lahore"));

          String address = addressParts.join(", ");
          debugPrint("DEBUG FINAL ADDRESS: $address");
          if (address.isEmpty) address = "Unknown Location";

          if (mounted) {
            setState(() { _currentLocation = address; _gettingLocation = false; });
          }
        } else {
          if (mounted) {
            setState(() {
              _currentLocation = "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
              _gettingLocation = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _currentLocation = "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
            _gettingLocation = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) {
        setState(() { _currentLocation = 'Location Error'; _gettingLocation = false; });
      }
    }
  }

  void _showEnableLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_off_rounded, size: 48, color: AppColors.primaryBlue),
              ),
              const SizedBox(height: 24),
              const Text(
                "Enable Location",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              const Text(
                "To show you the best home services near you, please enable location services.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Cancel", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Geolocator.openLocationSettings();
                      },
                      child: const Text("Enable", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
  
  void _showError(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  void _onNotificationsChanged() {
    if (!mounted || _notifProvider == null) return;
    final count = _notifProvider!.unreadCount;
    if (count > _lastUnreadCount) {
      _techyKey.currentState?.react();
    }
    _lastUnreadCount = count;
  }

  void _onProfileChanged() {
    if (!mounted || _profileProvider == null) return;
    final enabled = _profileProvider!.appLocationEnabled;
    if (enabled == _lastLocationEnabled) return;
    _lastLocationEnabled = enabled;
    if (enabled) {
      _fetchLocation();
    } else {
      setState(() => _currentLocation = 'Location Off');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifProvider?.removeListener(_onNotificationsChanged);
    _profileProvider?.removeListener(_onProfileChanged);
    SocketService().onPromosUpdated = null;
    _searchController.dispose();
    _bannerPageController.dispose();
    _tabSwitchController.dispose();
    _ctaPulseController.dispose();
    super.dispose();
  }

  void _onPromosUpdated() {
    if (!mounted) return;
    setState(() => _promosCache = null);
  }

  void _onNavTap(int index) {
    final nav = context.read<NavigationProvider>();
    if (nav.currentIndex == index) return;
    nav.setIndex(index);
    // Screens keep their state (IndexedStack) - this just plays a soft
    // fade-and-rise on the incoming tab.
    _tabSwitchController.forward(from: 0);
  }

  void _showCategoriesFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final provider = context.watch<ServiceProvider>();
        final services = provider.services;

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('All Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Expanded(
                child: provider.isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9,
                        ),
                        itemCount: services.length,
                        itemBuilder: (context, index) {
                          final service = services[index];
                          final visual = ServiceVisuals.of(service.name);
                          final serviceColor = visual.color;
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _searchController.text = service.name;
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.grey200),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(color: serviceColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                                    child: Icon(visual.icon, size: 24, color: serviceColor),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(service.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                   children: [
                       Row(children: [
                        Icon(Icons.location_on_rounded, color: AppColors.primaryBlue, size: 24),
                        const SizedBox(width: 10),
                        const Text('Select Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ]),
                      const SizedBox(height: 16),
                      // Location Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.grey100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search city, area or street...',
                            border: InputBorder.none,
                            icon: Icon(Icons.search, color: AppColors.grey500),
                          ),
                          onSubmitted: (value) async {
                            if (value.isNotEmpty) {
                               Navigator.pop(context); // Close sheet
                               setState(() {
                                 _currentLocation = 'Searching "$value"...';
                                 _gettingLocation = true;
                               });
                               try {
                                 List<Location> locations = await locationFromAddress(value);
                                 if (locations.isNotEmpty) {
                                    // Get address from coordinates to be consistent
                                    List<Placemark> placemarks = await placemarkFromCoordinates(locations.first.latitude, locations.first.longitude);
                                    if (placemarks.isNotEmpty) {
                                       // Reuse formatting logic? 
                                       // For now just simpler format or call _getCurrentLocation with override?
                                       // Let's manually set it to formatted address
                                       Placemark place = placemarks[0];
                                       List<String> parts = [];
                                       if (place.subLocality != null && place.subLocality!.isNotEmpty) parts.add(place.subLocality!);
                                       if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
                                       if (place.country != null && place.country!.isNotEmpty) parts.add(place.country!);
                                       
                                       setState(() {
                                         _currentLocation = parts.join(", ");
                                         _gettingLocation = false;
                                       });
                                    }
                                 } else {
                                    setState(() {
                                       _currentLocation = 'Location not found';
                                       _gettingLocation = false;
                                    });
                                 }
                               } catch (e) {
                                  setState(() {
                                     _currentLocation = 'Search failed';
                                     _gettingLocation = false;
                                  });
                               }
                            }
                          },
                        ),
                      ),
                   ]
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _fetchLocation();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                        child: _gettingLocation 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Use My Current Location', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('Auto-detect via GPS', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: Consumer<AddressProvider>(
                builder: (context, provider, child) {
                  final addresses = provider.addresses;
                  if (addresses.isEmpty) {
                    return Center(
                      child: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Icon(Icons.location_off_rounded, color: AppColors.grey400, size: 40),
                           const SizedBox(height: 8),
                           Text("No saved addresses", style: TextStyle(color: AppColors.grey500)),
                           TextButton(
                             onPressed: () => Navigator.pushNamed(context, '/my-addresses'),
                             child: const Text("Add New Address"),
                           )
                         ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final addr = addresses[index];
                      final isSelected = provider.selectedAddress?.id == addr.id;
                      
                      return ListTile(
                        onTap: () {
                          provider.selectAddress(addr);
                          Navigator.pop(context);
                        },
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.1) : AppColors.grey100, borderRadius: BorderRadius.circular(12)),
                          child: Icon(
                            addr.label == 'Home' ? Icons.home_rounded : addr.label == 'Work' ? Icons.work_rounded : Icons.location_on_rounded, 
                            color: isSelected ? AppColors.primaryBlue : AppColors.grey500, size: 20
                          ),
                        ),
                        title: Text(addr.label, style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary)),
                        subtitle: Text(addr.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 22) : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeBody(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final isTiny = size.height < 550;
    
    // Show Full Screen Shimmer on Initial Load
    final serviceProvider = context.watch<ServiceProvider>();
    if (serviceProvider.isLoading) {
      return const HomeShimmer();
    }

    return Container(
      // Neumorphism needs a flat, uniform base — the raised/inset illusion
      // comes entirely from the light/dark shadow pair, and a gradient here
      // would make the shadows look wrong depending on scroll position.
      color: NeuTheme.bg,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Order follows the Uber/Careem pattern: get the user to a
          // booking in one glance - services first, promos after.
          SliverToBoxAdapter(child: _buildHeader(horizontalPadding, isSmall, isTiny)),
          SliverToBoxAdapter(child: _buildSearchBar(horizontalPadding, isSmall)),
          SliverToBoxAdapter(child: _buildHeroCard(horizontalPadding, isSmall, isTiny)),
          SliverToBoxAdapter(child: SizedBox(height: isSmall ? 14 : 18)),
          SliverToBoxAdapter(child: _buildServicesSection(horizontalPadding, size, isSmall)),
          SliverToBoxAdapter(child: SizedBox(height: isSmall ? 14 : 18)),
          SliverToBoxAdapter(child: _buildTrustStrip(horizontalPadding, isSmall)),
          SliverToBoxAdapter(child: _buildPromoBanner(horizontalPadding, isSmall)),
          SliverToBoxAdapter(child: SizedBox(height: isSmall ? 16 : 24)),
          SliverToBoxAdapter(child: _buildFavoritesSection(horizontalPadding, isSmall)),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final currentNavIndex = navProvider.currentIndex;

    return Scaffold(
      // The glass nav bar needs page content to run underneath it — without
      // extendBody the Scaffold reserves an opaque strip (the "white band")
      // behind the floating bar and the translucency shows nothing.
      extendBody: true,
      body: AnimatedBuilder(
        animation: _tabSwitchController,
        builder: (context, child) {
          final v = Curves.easeOutCubic.transform(_tabSwitchController.value);
          return Opacity(
            opacity: 0.35 + 0.65 * v,
            child: Transform.translate(
              offset: Offset(0, (1 - v) * 16),
              child: child,
            ),
          );
        },
        child: IndexedStack(
          index: currentNavIndex,
          children: [
            _buildHomeBody(context),
            const MyBookingsScreen(),
            const ChatListScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _buildAnimatedBottomNav(),
    );
  }

  Widget _buildHeader(double horizontalPadding, bool isSmall, bool isTiny) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;

    // Clean single-purpose header (Careem/Uber style): where are we
    // serving you + notifications. The greeting lives in the hero card.
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isTiny ? 8 : isSmall ? 10 : isDesktop ? 16 : 12),
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: isTiny ? 4 : isSmall ? 6 : isDesktop ? 12 : 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _showLocationPicker,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SERVICE LOCATION',
                    style: TextStyle(
                      fontSize: isTiny ? 8.5 : isSmall ? 9 : isDesktop ? 12 : 9.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: isTiny ? 2 : 3),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: isTiny ? 13 : isSmall ? 14 : isDesktop ? 20 : 16,
                          color: AppColors.primaryBlue),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Consumer<AddressProvider>(
                          builder: (context, provider, child) {
                            final displayLocation = provider.selectedAddress?.address ?? _currentLocation;
                            return Text(
                              displayLocation,
                              style: TextStyle(
                                fontSize: isTiny ? 12.5 : isSmall ? 13.5 : isDesktop ? 18 : 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded, size: isSmall ? 16 : isDesktop ? 22 : 18, color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Notification button
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/notifications'),
            child: Container(
              width: isTiny ? 42 : isSmall ? 46 : isDesktop ? 56 : 50,
              height: isTiny ? 42 : isSmall ? 46 : isDesktop ? 56 : 50,
              decoration: NeuTheme.sm(radius: 14),
              child: Stack(
                children: [
                  Center(child: Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: isSmall ? 22 : isDesktop ? 28 : 24)),
                  Consumer<NotificationProvider>(
                    builder: (context, provider, child) {
                      if (provider.unreadCount == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: isSmall ? 8 : isDesktop ? 12 : 10,
                          height: isSmall ? 8 : isDesktop ? 12 : 10,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  // Premium Hero Card with Techy mascot
  Widget _buildHeroCard(double horizontalPadding, bool isSmall, bool isTiny) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final user = context.watch<AuthProvider>().user;
    final rawName = user?.name.trim();
    final firstName = (rawName != null && rawName.isNotEmpty) ? rawName.split(' ').first : 'Dost';
    final mascotSize = isTiny ? 88.0 : isSmall ? 100.0 : isDesktop ? 140.0 : 116.0;

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        top: isTiny ? 6 : isSmall ? 8 : 10,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // Deep navy -> brand blue: the same premium "night" language as
          // the splash, so the app feels like one designed product.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0E2138),
              Color(0xFF0D3A66),
              Color(0xFF0B72D8),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(isDesktop ? 28 : 24),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Soft light spot behind Techy - lifts the mascot off the card
            Positioned(
              top: -30,
              right: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryLight.withValues(alpha: 0.30),
                      AppColors.primaryLight.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // A whisper of texture, bottom-left
            Positioned(
              bottom: -50,
              left: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06), width: 24),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isSmall ? 16 : 20,
                isSmall ? 14 : 18,
                isSmall ? 8 : 10,
                isSmall ? 14 : 18,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Assalam-o-Alaikum,',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: isTiny ? 11 : isSmall ? 12 : isDesktop ? 16 : 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(height: isTiny ? 2 : 3),
                        Text(
                          '$firstName!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTiny ? 18 : isSmall ? 20 : isDesktop ? 28 : 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isTiny ? 4 : 6),
                        Text(
                          'Ghar ki har zaroorat,\nek tap par hal!',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: isTiny ? 10.5 : isSmall ? 11.5 : isDesktop ? 15 : 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: isTiny ? 8 : isSmall ? 10 : 12),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/all-services'),
                          child: AnimatedBuilder(
                            animation: _ctaPulseController,
                            builder: (context, child) {
                              // Two decaying heartbeats while Techy points.
                              final v = _ctaPulseController.value;
                              final pulse =
                                  math.sin(v * math.pi * 3) * (1 - v) * 0.08;
                              return Transform.scale(
                                scale: 1 + pulse,
                                child: child,
                              );
                            },
                            child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmall ? 14 : 16,
                              vertical: isTiny ? 7 : isSmall ? 8 : 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Book a Service',
                                  style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: isTiny ? 11 : isSmall ? 12 : isDesktop ? 15 : 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(Icons.arrow_forward_rounded,
                                    color: AppColors.primaryDark,
                                    size: isSmall ? 14 : 16),
                              ],
                            ),
                          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Techy — the living HomeTechnify mascot: rockets in from
                  // the edge of the screen, floats, plays with his wrench,
                  // laughs when poked, hops on good news, and every so often
                  // turns to POINT at the Book-a-Service button (which
                  // pulses at the same beat, guiding the user's eye).
                  TechyBuddy(
                    key: _techyKey,
                    height: mascotSize,
                    entrance: true,
                    enablePointing: true,
                    onPoint: () {
                      if (mounted) _ctaPulseController.forward(from: 0);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 80.ms).slideY(begin: 0.08, end: 0);
  }

  // Trust bar - one slim, always-fully-visible line of confidence.
  // FittedBox guarantees it can never truncate or overflow on any screen.
  Widget _buildTrustStrip(double horizontalPadding, bool isSmall) {
    Widget item(IconData icon, String label, Color color) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.1,
            ),
          ),
        ],
      );
    }

    Widget dot() => Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 3.5,
          height: 3.5,
          decoration: BoxDecoration(
            color: AppColors.grey300,
            shape: BoxShape.circle,
          ),
        );

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: isSmall ? 12 : 16,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isSmall ? 9 : 11, horizontal: 12),
        decoration: NeuTheme.sm(radius: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(Icons.verified_user_rounded, 'Verified Pros', AppColors.success),
              dot(),
              item(Icons.lock_rounded, 'Secure Payments', AppColors.primaryBlue),
              dot(),
              item(Icons.star_rounded, 'Top Rated', AppColors.warning),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 450.ms, delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSearchBar(double horizontalPadding, bool isSmall) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isSmall ? 10 : isDesktop ? 18 : 14),
      child: Row(
        children: [
          // Search bar with TextField
          Expanded(
            child: Container(
              height: isSmall ? 50 : isDesktop ? 58 : 54,
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10),
              decoration: NeuTheme.inset(radius: isDesktop ? 18 : 16),
              child: Row(
                children: [
                  Container(
                    width: isSmall ? 34 : 38,
                    height: isSmall ? 34 : 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.search_rounded,
                        color: AppColors.primaryBlue,
                        size: isSmall ? 19 : isDesktop ? 24 : 21),
                  ),
                  SizedBox(width: isSmall ? 10 : 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: isSmall ? 14 : isDesktop ? 16 : 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Try "AC repair" or "Plumber"...',
                        hintStyle: TextStyle(
                          fontSize: isSmall ? 14 : isDesktop ? 16 : 15,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.grey100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, color: AppColors.grey500, size: isSmall ? 16 : isDesktop ? 20 : 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: isSmall ? 10 : isDesktop ? 14 : 12),
          // Filter button - shows all categories
          GestureDetector(
            onTap: () => _showCategoriesFilter(),
            child: Container(
              width: isSmall ? 50 : isDesktop ? 58 : 54,
              height: isSmall ? 50 : isDesktop ? 58 : 54,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.tune_rounded, color: Colors.white, size: isSmall ? 20 : isDesktop ? 24 : 22),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  // Favorites Section - Shows user's favorite providers
  Widget _buildFavoritesSection(double horizontalPadding, bool isSmall) {
    final favorites = favoritesService.favoritesWithDetails;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Favorites',
                style: TextStyle(
                  fontSize: isSmall ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (favorites.isNotEmpty)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/favorite-providers'),
                  child: Text(
                    'See All',
                    style: TextStyle(
                      fontSize: isSmall ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: isSmall ? 12 : 16),
        
        // Favorites Content
        if (favorites.isEmpty)
          // Empty State
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Container(
              padding: EdgeInsets.all(isSmall ? 16 : 20),
              decoration: NeuTheme.sm(radius: 16),
              child: Row(
                children: [
                  const TechyStill(height: 56, borderRadius: 12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No favorites yet',
                          style: TextStyle(
                            fontSize: isSmall ? 14 : 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Add providers from messages',
                          style: TextStyle(
                            fontSize: isSmall ? 12 : 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms)
        else
          // Favorites List (Horizontal)
          SizedBox(
            height: isSmall ? 80 : 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final fav = favorites[index];
                final name = fav['name'] as String? ?? 'Provider';
                final initials = fav['initials'] as String? ?? name.substring(0, 2).toUpperCase();
                final color = fav['color'] as Color? ?? AppColors.primaryBlue;
                
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {'name': name, 'service': 'Service Provider'},
                  ),
                  child: Container(
                    width: isSmall ? 68 : 76,
                    margin: EdgeInsets.only(right: isSmall ? 10 : 12),
                    child: Column(
                      children: [
                        Container(
                          width: isSmall ? 50 : 56,
                          height: isSmall ? 50 : 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [color, color.withValues(alpha: 0.8)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmall ? 16 : 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      favoritesService.removeFavorite(name);
                                    });
                                  },
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: Icon(Icons.favorite_rounded, size: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name.split(' ').first,
                          style: TextStyle(
                            fontSize: isSmall ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ).animate(delay: Duration(milliseconds: index * 80)).fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
              },
            ),
          ),
      ],
    );
  }

  // Enhanced Services Section with Bigger Cards
  Widget _buildServicesSection(double horizontalPadding, Size size, bool isSmall) {
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;
    
    // Responsive column count
    final columns = isDesktop ? 4 : 3;
    final spacing = isDesktop ? 16.0 : isTablet ? 12.0 : 8.0;
    final gridWidth = size.width - (horizontalPadding * 2);
    final cardWidth = (gridWidth - (spacing * (columns - 1))) / columns;

    return Consumer<ServiceProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Padding(
             padding: EdgeInsets.all(32.0),
             child: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.status == ServiceStatus.error) {
           // provider.errorMessage is a raw DioException.toString() (stack
           // trace, timeout duration, the works) — never show that to a
           // customer. A short, human message plus a retry button that
           // re-runs the same load is what they can actually act on.
           return Padding(
             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
             child: Container(
               width: double.infinity,
               padding: const EdgeInsets.all(24),
               decoration: NeuTheme.sm(radius: 20),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.cloud_off_rounded, color: AppColors.grey400, size: 36),
                   const SizedBox(height: 12),
                   Text(
                     "Couldn't load services. Check your connection.",
                     textAlign: TextAlign.center,
                     style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                   ),
                   const SizedBox(height: 16),
                   GestureDetector(
                     onTap: () => provider.loadServices(),
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                       decoration: NeuTheme.raised(radius: 14),
                       child: Text(
                         'Retry',
                         style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700, fontSize: 14),
                       ),
                     ),
                   ),
                 ],
               ),
             ),
           );
        }

        final services = provider.services;

        // Filter services
        final filteredServices = _searchQuery.isEmpty
            ? services
            : services.where((service) => service.name.toLowerCase().contains(_searchQuery)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _searchQuery.isEmpty ? 'Our Services' : 'Search Results (${filteredServices.length})',
                    style: TextStyle(fontSize: isSmall ? 18 : isDesktop ? 24 : 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
                  ),
                  if (_searchQuery.isEmpty)
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/all-services'),
                      child: Text('See All', style: TextStyle(fontSize: isSmall ? 13 : isDesktop ? 16 : 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                    ),
                ],
              ),
            ),
            SizedBox(height: isDesktop ? 20 : 16),
            if (filteredServices.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isDesktop ? 60 : 40),
                child: Center(
                  child: Column(
                    children: [
                      TechyStill(height: isDesktop ? 140 : 110),
                      SizedBox(height: isDesktop ? 16 : 12),
                      Text('No services found', style: TextStyle(fontSize: isDesktop ? 20 : 16, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      SizedBox(height: isDesktop ? 10 : 8),
                      Text('Try searching for something else', style: TextStyle(fontSize: isDesktop ? 16 : 14, color: AppColors.grey400)),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Wrap(
                  spacing: spacing,
                  runSpacing: isDesktop ? 16 : 12,
                  children: List.generate(
                    filteredServices.length > 6 ? 6 : filteredServices.length, 
                    (index) => SizedBox(
                      width: cardWidth,
                      child: ServiceCard(data: filteredServices[index], index: index),
                    ),
                  ),
                ),
              ),
          ],
        ).animate().fadeIn(duration: 500.ms, delay: 300.ms);
      },
    );
  }

  // Promo Banner Carousel
  Widget _buildPromoBanner(double horizontalPadding, bool isSmall) {
    final size = MediaQuery.of(context).size;
    final isTiny = size.height < 600;
    final isDesktop = size.width >= 1024;
    
    // Responsive banner height
    final bannerHeight = isTiny ? 120.0 : isSmall ? 135.0 : isDesktop ? 160.0 : 150.0;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchPromos(),
        builder: (context, snapshot) {
          final banners = snapshot.data ?? [];
          
          if (banners.isEmpty) {
            return const SizedBox.shrink(); // Hide section if no promos
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Offers for you',
                  style: TextStyle(
                    fontSize: isSmall ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(
                height: bannerHeight,
                child: PageView.builder(
                  controller: _bannerPageController,
                  itemCount: banners.length,
                  onPageChanged: (index) {
                    setState(() => _currentBannerIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final banner = banners[index];
                    return _buildBannerCard(banner, isTiny, isSmall, isDesktop);
                  },
                ),
              ),
              // Page indicators
              SizedBox(height: isTiny ? 8 : 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentBannerIndex == index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentBannerIndex == index 
                        ? AppColors.primaryBlue 
                        : AppColors.grey300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 400.ms);
  }
  
  Future<List<Map<String, dynamic>>>? _promosCache;
  
  Future<List<Map<String, dynamic>>> _fetchPromos() {
    _promosCache ??= _doFetchPromos();
    return _promosCache!;
  }
  
  Future<List<Map<String, dynamic>>> _doFetchPromos() async {
    try {
      final dio = ApiService().dio;
      final res = await dio.get('/promos');
      if (res.data['success'] == true) {
        return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
      }
    } catch (e) {
      debugPrint('Promo fetch error: $e');
    }
    return [];
  }
  
  Widget _buildBannerCard(Map<String, dynamic> banner, bool isTiny, bool isSmall, bool isDesktop) {
    final borderRadius = isTiny ? 16.0 : isSmall ? 18.0 : isDesktop ? 24.0 : 20.0;

    // DB color becomes an accent only - the card itself always uses the
    // premium navy language of the brand, so every promo looks designed.
    final colorValue = banner['color_value'] as int? ?? 0xFF1495FF;
    final accent = Color(colorValue);
    final discount = (banner['discount'] as num?)?.toDouble() ?? 0;
    final title = banner['title'] as String? ?? 'Special Offer';
    final subtitle = banner['subtitle'] as String? ?? '';
    final code = banner['code'] as String? ?? '';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTiny ? 2 : 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2138), Color(0xFF0D3A66)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Accent glow behind the discount block
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.35),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Diagonal sheen for a subtle premium finish
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTiny ? 16 : isSmall ? 18 : 22,
              vertical: isTiny ? 12 : isSmall ? 14 : 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'LIMITED OFFER',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: isTiny ? 8.5 : isSmall ? 9 : 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: isTiny ? 4 : 6),
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTiny ? 15 : isSmall ? 17 : isDesktop ? 22 : 19,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        SizedBox(height: isTiny ? 3 : 5),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: isTiny ? 10 : isSmall ? 11 : 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (code.isNotEmpty) ...[
                        SizedBox(height: isTiny ? 7 : 9),
                        // Ticket-style code chip
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: isTiny ? 9 : 11,
                              vertical: isTiny ? 4 : 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primaryLight
                                    .withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.confirmation_number_outlined,
                                  color: AppColors.primaryLight,
                                  size: isTiny ? 11 : 13),
                              const SizedBox(width: 5),
                              Text(
                                code,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTiny ? 9.5 : isSmall ? 10.5 : 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Techy with his wrench - "ready to fix", brand image
                if (!isTiny) ...[
                  const SizedBox(width: 6),
                  Image.asset(
                    'assets/anim/techy_alpha/f025.webp',
                    height: isSmall ? 88 : isDesktop ? 120 : 104,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ],
                // Discount - big, confident display type (no bubble)
                if (discount > 0) ...[
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${discount.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTiny ? 30 : isSmall ? 34 : isDesktop ? 44 : 38,
                          fontWeight: FontWeight.w900,
                          height: 0.95,
                          letterSpacing: -1.5,
                        ),
                      ),
                      Text(
                        'OFF',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: isTiny ? 11 : isSmall ? 12 : 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // "Water-drop" bottom navigation: the bar has a liquid notch that glides
  // to the active tab, and the active icon floats in a gradient droplet
  // above it - a wave motion that fits a home-services brand.
  Widget _buildAnimatedBottomNav() {
    final navProvider = context.watch<NavigationProvider>();
    final currentNavIndex = navProvider.currentIndex;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final navHeight = isSmall ? 60.0 : 66.0;
    final horizontalMargin = isSmall ? 12.0 : 16.0;
    final dropSize = isSmall ? 46.0 : 52.0;
    final overhang = dropSize * 0.42; // how far the droplet rises above the bar
    final barWidth = size.width - horizontalMargin * 2;
    final slot = barWidth / _navItems.length;

    return Container(
      margin: EdgeInsets.only(
          left: horizontalMargin,
          right: horizontalMargin,
          bottom: bottomPadding + (isSmall ? 8 : 12)),
      height: navHeight + overhang,
      // The droplet glides between tabs; TweenAnimationBuilder re-animates
      // automatically every time the selected index changes.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: currentNavIndex.toDouble()),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        builder: (context, pos, _) {
          final cx = (pos + 0.5) * slot;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // The bar with its moving liquid notch — frosted glass:
              // page content blurs through the bar shape, and the painter on
              // top adds only the neumorphic shadow pair + edge highlight
              // (no opaque fill, so the bar stays translucent).
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: navHeight,
                child: ClipPath(
                  clipper: _WaveNavClipper(
                    notchCenterX: cx,
                    notchRadius: dropSize / 2 + 7,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.62),
                            NeuTheme.bg.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: navHeight,
                child: CustomPaint(
                  painter: _WaveNavBarPainter(
                    notchCenterX: cx,
                    notchRadius: dropSize / 2 + 7,
                  ),
                ),
              ),
              // Tab hit areas + labels/icons
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: navHeight,
                child: Row(
                  children: List.generate(_navItems.length, (index) {
                    final item = _navItems[index];
                    final isSelected = currentNavIndex == index;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onNavTap(index),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: isSelected ? 1 : 0.75,
                          child: Column(
                            mainAxisAlignment: isSelected
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.center,
                            children: [
                              // Icon hides under the droplet when selected.
                              // Ink tones, not white — the bar is light glass
                              // now and white simply vanished on it.
                              if (!isSelected)
                                Icon(item.icon,
                                    size: isSmall ? 21 : 23,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.9)),
                              SizedBox(height: isSelected ? 0 : 3),
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : AppColors.textSecondary
                                          .withValues(alpha: 0.85),
                                  fontSize: isSmall ? 9.5 : 10.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              if (isSelected) SizedBox(height: isSmall ? 7 : 9),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // The floating droplet with the active icon
              Positioned(
                left: cx - dropSize / 2,
                top: 0,
                child: Container(
                  width: dropSize,
                  height: dropSize,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryLight, AppColors.primaryBlue],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                      // Neumorphic top-left light kiss so the droplet sits in
                      // the same soft-light world as the glass bar under it.
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.85),
                        blurRadius: 8,
                        offset: const Offset(-2, -2),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutBack,
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      _navItems[currentNavIndex].icon,
                      key: ValueKey(currentNavIndex),
                      color: Colors.white,
                      size: isSmall ? 22 : 25,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Shared geometry for the nav pill with its liquid notch — the clipper cuts
// the frosted-glass blur to this shape and the painter decorates the same
// outline, so the two must never drift apart.
Path _waveNavPath(Size size, double notchCenterX, double notchRadius) {
  final rect = Offset.zero & size;
  final bar = Path()
    ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(26)));
  // Slightly widened oval reads as a wave dip rather than a hard bite.
  final notch = Path()
    ..addOval(Rect.fromCenter(
      center: Offset(notchCenterX, 0),
      width: notchRadius * 2.6,
      height: notchRadius * 2,
    ));
  return Path.combine(PathOperation.difference, bar, notch);
}

// Clips the BackdropFilter blur to the bar shape — this is what makes the
// bar itself translucent glass instead of a solid slab.
class _WaveNavClipper extends CustomClipper<Path> {
  final double notchCenterX;
  final double notchRadius;
  _WaveNavClipper({required this.notchCenterX, required this.notchRadius});

  @override
  Path getClip(Size size) => _waveNavPath(size, notchCenterX, notchRadius);

  @override
  bool shouldReclip(covariant _WaveNavClipper old) =>
      old.notchCenterX != notchCenterX || old.notchRadius != notchRadius;
}

// Decorates the glass bar with the neumorphic shadow pair (dark below-right,
// light above-left) and a bright top edge. Deliberately NO fill — the
// translucent blur layer underneath provides the surface.
class _WaveNavBarPainter extends CustomPainter {
  final double notchCenterX;
  final double notchRadius;
  _WaveNavBarPainter({required this.notchCenterX, required this.notchRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _waveNavPath(size, notchCenterX, notchRadius);

    // Neumorphic dark shadow — soft, low, blue-grey like the rest of the app
    final darkShadow = Paint()
      ..color = const Color(0xFF9FB1C8).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.save();
    canvas.translate(4, 7);
    canvas.drawPath(path, darkShadow);
    canvas.restore();

    // Neumorphic light glow — lifts the bar off the content behind it
    final lightGlow = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.save();
    canvas.translate(-3, -4);
    canvas.drawPath(path, lightGlow);
    canvas.restore();

    // Crisp glass edge — a hairline highlight along the outline
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawPath(path, edge);
  }

  @override
  bool shouldRepaint(covariant _WaveNavBarPainter old) =>
      old.notchCenterX != notchCenterX || old.notchRadius != notchRadius;
}


// Map grid painter
class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.grey200
      ..strokeWidth = 1;

    // Draw grid lines
    for (var i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i.toDouble(), 0), Offset(i.toDouble(), size.height), paint);
    }
    for (var i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i.toDouble()), Offset(size.width, i.toDouble()), paint);
    }

    // Draw some "roads"
    final roadPaint = Paint()
      ..color = AppColors.grey300
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.7, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NavItem {
  final IconData icon;
  final String label;
  NavItem({required this.icon, required this.label});
}



class ProviderData {
  final String name;
  final String service;
  final double rating;
  final String distance;
  final String price;
  
  ProviderData({
    required this.name,
    required this.service,
    required this.rating,
    required this.distance,
    required this.price,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../features/booking/providers/booking_provider.dart';
import '../../../features/job/providers/job_post_provider.dart';
import 'package:home_technify/features/booking/data/models/booking_model.dart';
import '../../../features/job/data/models/job_post_model.dart';
import '../../provider/providers/provider_controller.dart';
import '../../../core/services/socket_service.dart';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme/neu_theme.dart';
import '../data/dismissed_cards.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  int _currentNavIndex = 0;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _currentNavIndex = 0;
    // Removing a card in the requests screen must also remove it here.
    DismissedCards.instance.addListener(_onDismissedChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _fetchCurrentLocation();
    });
  }

  @override
  void dispose() {
    DismissedCards.instance.removeListener(_onDismissedChanged);
    super.dispose();
  }

  void _onDismissedChanged() {
    if (mounted) setState(() {});
  }

  /// Hides a card from this provider's dashboard with an undo. The job stays
  /// OPEN for every other provider — nothing is deleted on the server.
  void _dismissCard(String id, String label) {
    DismissedCards.instance.dismiss(id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label removed'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () => DismissedCards.instance.restore(id),
          ),
        ),
      );
  }

  /// Red swipe-to-remove background behind a dismissible card.
  Widget _removeBackground() => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white),
            SizedBox(height: 2),
            Text('Remove',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  /// Escape hatch: bring back everything the provider has swiped away.
  Widget _buildRestoreRemoved(double horizontalPadding, DismissedCards dismissed) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: dismissed.restoreAll,
          icon: const Icon(Icons.undo_rounded, size: 16),
          label: Text('Restore ${dismissed.count} removed'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ),
    );
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _showLocationServiceDialog();
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
           return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) _showPermissionDialog();
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
           Placemark place = placemarks.first;
           if (mounted) {
             setState(() {
                // Construct a more complete address
                // Default: "G-10/3, Islamabad" 
                // Enhanced: "House 123, Street 4, G-10/3, Islamabad" context dependent
                // We will try to get the most relevant parts
                final components = [
                   place.name, // e.g. "House 12"
                   place.subLocality, // e.g. "G-10/3"
                   place.locality, // e.g. "Islamabad"
                ].where((e) => e != null && e.isNotEmpty && e != place.street).toSet().toList(); 
                // Set used to remove duplicates if name == subLocality
                
                if (components.isEmpty) {
                    components.add(place.street ?? '');
                    components.add(place.locality ?? '');
                }

                _currentAddress = components.join(', ');
             });
           }
        }
      } catch (e) {
         debugPrint("Geocoding error: $e");
         if (mounted) setState(() => _currentAddress = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}");
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }



  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Location Services Disabled"),
        content: const Text("Please enable location services to see nearby jobs."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
               Navigator.pop(ctx);
               Geolocator.openLocationSettings();
            },
            child: const Text("Settings"),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Location Permission Required"),
        content: const Text("We need your location to show relevant jobs nearby. Please enable it in settings."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
               Navigator.pop(ctx);
               Geolocator.openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

// ... inside _buildJobPostCard ...




  void _loadData() async {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      context.read<BookingProvider>().fetchMyBookings(user.id);
      
      // Fetch Provider Details first to get Category
      final providerController = context.read<ProviderController>();
      await providerController.fetchProviderDetails(user.id);
      final category = providerController.selectedProvider?.category;

      if (!mounted) return;
      if (category != null) {
        context.read<JobPostProvider>().fetchNearbyJobs(category: category);
      } else {
        debugPrint("⚠️ Skipping nearby jobs fetch: Category is null");
      }
      context.read<ProviderController>().fetchDashboardStats();
      context.read<ProviderController>().fetchNotifications();
      
      // Connect Socket
      SocketService().connect(user.id);
      _setupSocketListeners();
    }
  }

  void _setupSocketListeners() {
    // 1. Refresh Bookings & Stats when booking status changes (e.g., job completed -> revenue up)
    SocketService().onBookingStatusChanged = (data) {
       if (mounted) {
          final user = context.read<AuthProvider>().user;
          if (user != null) {
             context.read<BookingProvider>().fetchMyBookings(user.id);
             context.read<ProviderController>().fetchDashboardStats(); // Refresh Revenue Graph
          }
       }
    };

    // 2. Refresh Notifications
    SocketService().onNotification = (data) {
       if (mounted) {
          // Ideally fetch notification count, but here we can just refresh stats
          // if notifications are tied to bookings.
          // For now, let's just refresh bookings as a broad catch-all
          final user = context.read<AuthProvider>().user;
          if (user != null) {
             context.read<BookingProvider>().fetchMyBookings(user.id);
          }

          // A pending provider only ever sees this screen embedded (blurred,
          // non-interactive) underneath ProviderPendingScreen — so THIS
          // handler, not AuthProvider's, is the one actually listening when
          // admin approval lands. Refresh status and step out of the pending
          // route the instant it comes through; no logout/login needed.
          if (data['type'] == 'verification' &&
              data['data']?['verified']?.toString() == 'true') {
            final authProvider = context.read<AuthProvider>();
            final navigator = Navigator.of(context);
            authProvider.checkAuthStatus().then((_) {
              if (mounted &&
                  authProvider.user?.role == 'PROVIDER' &&
                  authProvider.user?.status != 'pending_verification') {
                navigator.pushReplacementNamed('/provider/dashboard');
              }
            });
          }
       }
    };
  }

  @override
  Widget build(BuildContext context) {
    // Watch AuthProvider to check if we have valid user data
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    // DATA INTEGRITY CHECK:
    // If user is null OR name is 'Provider' (placeholder), we are not ready.
    // Show loading instead of "Sample/Mock" data.
    if (user == null || user.name == 'Provider' || user.name.isEmpty) {
        // Trigger fetch if we are stuck in this state (and not already loading).
        // Only while actually signed in — this screen is embedded (blurred,
        // behind AbsorbPointer) inside ProviderPendingScreen, and logging out
        // from there sets user to null on THIS still-mounted widget. Calling
        // checkAuthStatus() with no Firebase session just re-confirms "no
        // user" forever; skipping it here avoids a pointless request during
        // the moment logout is tearing this widget down.
        if (authProvider.status != AuthStatus.loading &&
            FirebaseAuthService.isAuthenticated()) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.read<AuthProvider>().checkAuthStatus();
           });
        }
        
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Finalizing Setup..."),
              ],
            ),
          ),
        );
    }
    
    // Once we have valid data, show the real dashboard
    final horizontalPadding = Responsive.horizontalPadding(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: NeuTheme.bg,
      body: Consumer3<BookingProvider, JobPostProvider, ProviderController>(
        builder: (context, bookingProvider, jobProvider, providerController, child) {
          // Cards the provider swiped away stay hidden (locally — the job is
          // still open to everyone else, and they can undo).
          final dismissed = DismissedCards.instance;
          final bookings = bookingProvider.bookings
              .where((b) => b.status == 'PENDING' && !dismissed.contains(b.id))
              .toList();
          final jobs = jobProvider.nearbyJobs
              .where((j) => !dismissed.contains(j.id))
              .toList();
          final stats = providerController.dashboardStats;
          final unreadNotifications = providerController.notifications.where((n) => n['is_read'] == false).length;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(horizontalPadding, isSmall, unreadNotifications)),
              // Stats come straight from the backend. They used to be recomputed
              // here from the bookings list, which showed 0 for everything until
              // that list happened to load.
              SliverToBoxAdapter(child: _buildStatsGrid(horizontalPadding, isSmall, stats)),
              SliverToBoxAdapter(child: _buildRevenueChart(horizontalPadding, isSmall, stats['monthlyRevenue'] ?? [])),
              if (bookings.isNotEmpty)
                SliverToBoxAdapter(child: _buildBookingRequests(horizontalPadding, isSmall, bookings)),
              SliverToBoxAdapter(child: _buildJobPostsList(horizontalPadding, isSmall, jobs)),
              if (dismissed.count > 0)
                SliverToBoxAdapter(child: _buildRestoreRemoved(horizontalPadding, dismissed)),
              SliverToBoxAdapter(child: const SizedBox(height: 100)),
            ],
          );
        }
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader(double horizontalPadding, bool isSmall, int notificationCount) {
    final user = context.watch<AuthProvider>().user;
    final providerController = context.watch<ProviderController>(); // Access ProviderController
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Location + Chat + Notifications
          Row(
            children: [
              Icon(Icons.location_on, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Builder(
                  builder: (context) {
                    String address = _currentAddress ?? (user != null && user.addresses.isNotEmpty ? user.addresses.first : "Finding location...");
                    // Custom fix for Gulshan Colony
                    if (address.contains("Gulshan Colony")) {
                      address = address.replaceAll("Lahore", "Taxila, Rawalpindi")
                                       .replaceAll("Waqar", "")
                                       .replaceAll("  ", " ").trim();
                    }
                    return Text(
                      address,
                      style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2, 
                    );
                  }
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textSecondary),
              
              const SizedBox(width: 12),
               // Chat
               GestureDetector(
                 onTap: () => Navigator.pushNamed(context, '/chats'),
                 child: Container(
                   width: 38,
                   height: 38,
                   decoration: NeuTheme.circle(),
                   child: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.primaryBlue),
                 ),
               ),
               const SizedBox(width: 8),

               // Notifications
               GestureDetector(
                 onTap: () => Navigator.pushNamed(context, '/provider/notifications'),
                 child: Stack(
                   children: [
                     Container(
                       width: 38,
                       height: 38,
                       decoration: NeuTheme.circle(),
                       child: const Icon(Icons.notifications_outlined, size: 18, color: AppColors.primaryBlue),
                     ),
                     if (notificationCount > 0)
                       Positioned(
                         right: 0,
                         top: 0,
                         child: Container(
                           width: 16,
                           height: 16,
                           decoration: BoxDecoration(
                           color: AppColors.primaryBlue,
                           shape: BoxShape.circle,
                           border: Border.all(color: Colors.white, width: 2),
                         ),
                           child: Center(
                             child: Text(
                               '$notificationCount',
                               style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                             ),
                           ),
                         ),
                       ),
                   ],
                 ),
               ),
            ],
          ),
          
          const SizedBox(height: 20),

          // Row 2: Profile & Wallet
          Row(
            children: [
              // Profile avatar
              Container(
                width: isSmall ? 50 : 56,
                height: isSmall ? 50 : 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  image: user?.profileImage != null 
                     ? DecorationImage(image: NetworkImage(user!.profileImage!), fit: BoxFit.cover)
                     : null,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: user?.profileImage == null ? Center(
                  child: Text(
                    user?.name.split(' ').first[0] ?? 'P',
                    style: TextStyle(
                      fontSize: isSmall ? 18 : 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ) : null,
              ),
              const SizedBox(width: 12),
              
              // Welcome & Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: isSmall ? 13 : 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      providerController.selectedProvider?.name ?? user?.name ?? 'Provider',
                      style: TextStyle(
                        fontSize: isSmall ? 18 : 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

               // Commission wallet. This pill used to show totalEarnings and take
               // its "low" colour from mock data for a fake provider, so it was
               // never the number that actually gates quoting.
               Builder(builder: (context) {
                 final wallet = context.watch<ProviderController>().walletBalance;
                 // At zero the backend refuses new quotes — that is the only
                 // threshold the business model defines.
                 final isEmpty = wallet <= 0;
                 final color = isEmpty ? AppColors.error : AppColors.warning;

                 return GestureDetector(
                   onTap: () => Navigator.pushNamed(context, '/provider/wallet'),
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                     decoration: BoxDecoration(
                       color: color.withValues(alpha: 0.1),
                       borderRadius: BorderRadius.circular(20),
                       border: Border.all(color: color),
                     ),
                     child: Row(
                       children: [
                         Icon(Icons.account_balance_wallet_rounded, size: 16, color: color),
                         const SizedBox(width: 4),
                         Text(
                           'Rs. ${wallet.toStringAsFixed(0)}',
                           style: TextStyle(
                             fontSize: 12,
                             fontWeight: FontWeight.w700,
                             color: color,
                           ),
                         ),
                       ],
                     ),
                   ),
                 );
               }),
            ],
          ),
          const SizedBox(height: 14),
          _buildAvailabilityToggle(isSmall),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // Available / Not Available switch — controls whether this provider is shown
  // to customers and surfaced for new jobs.
  Widget _buildAvailabilityToggle(bool isSmall) {
    return Consumer<ProviderController>(
      builder: (context, controller, _) {
        final available = controller.isAvailable;
        // Matching is by distance — Available with no location = no jobs at all.
        final locationBlocked = available && controller.locationBlocked;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (locationBlocked) _buildLocationWarning(),
            _buildToggleBody(isSmall),
          ],
        );
      },
    );
  }

  /// Shown when the provider is Available but we couldn't get their location.
  /// Without a location they are dropped from both the customer's nearby list
  /// and job notifications, so this explains the silence.
  Widget _buildLocationWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Location is off. You will NOT receive any jobs until you turn it '
              'on — jobs are matched by how close you are.',
              style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Geolocator.openLocationSettings(),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBody(bool isSmall) {
    return Consumer<ProviderController>(
      builder: (context, controller, _) {
        final available = controller.isAvailable;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: available
              ? BoxDecoration(
                  color: NeuTheme.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFFBDCADB),
                        offset: Offset(4, 4),
                        blurRadius: 8),
                    BoxShadow(
                        color: Colors.white,
                        offset: Offset(-4, -4),
                        blurRadius: 8),
                  ],
                )
              : NeuTheme.sm(radius: 14),
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: available ? AppColors.success : AppColors.grey400, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      available ? 'Available for jobs' : 'Not available',
                      style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w800, color: available ? AppColors.success : AppColors.textSecondary),
                    ),
                    Text(
                      available ? 'Customers can see you & send requests' : 'You are hidden from new jobs',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              controller.togglingAvailability
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Switch(
                      value: available,
                      activeThumbColor: AppColors.success,
                      onChanged: (v) async {
                        final result = await controller.setAvailability(v);
                        if (!context.mounted) return;
                        if (result != v) {
                          // Server rejected the change - show the real reason.
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(controller.errorMessage ??
                                  'Could not update availability. Please try again.'),
                              backgroundColor: AppColors.error,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result ? 'You are now Available' : 'You are now Not Available'),
                            backgroundColor: result ? AppColors.success : AppColors.textSecondary,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(double horizontalPadding, bool isSmall, Map<String, dynamic> stats) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          // Row 1: Deal Done & Deal Not Done
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/my-jobs', arguments: {'initialTab': 0}), // Active/Completed
                  child: _buildStatCard(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppColors.success,
                    iconBgColor: AppColors.success.withValues(alpha: 0.1),
                    label: 'Deal Done',
                    value: '${stats['dealDone'] ?? 0}',
                    isSmall: isSmall,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/provider/jobs'), // Requests/Pending
                  child: _buildStatCard(
                    icon: Icons.pending_actions_rounded,
                    iconColor: AppColors.warning,
                    iconBgColor: AppColors.warning.withValues(alpha: 0.1),
                    label: 'Deal Not Done',
                    value: '${stats['dealNotDone'] ?? 0}',
                    isSmall: isSmall,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Earnings & Rating
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.primaryDark,
                  iconBgColor: AppColors.primaryDark.withValues(alpha: 0.1),
                  label: 'Total Earnings',
                  value: 'Rs. ${stats['totalEarnings'] ?? 0}',
                  isSmall: isSmall,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.star_rounded,
                  iconColor: AppColors.warning,
                  iconBgColor: AppColors.warning.withValues(alpha: 0.1),
                  label: 'Rating',
                  value: '${stats['rating'] ?? 0.0}',
                  isSmall: isSmall,
                ),
              ),
            ],
          ),

        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
    required bool isSmall,
  }) {
    final size = MediaQuery.of(context).size;
    final isVerySmall = size.height < 600;
    
    return Container(
      padding: EdgeInsets.all(isVerySmall ? 10 : isSmall ? 12 : 16),
      decoration: NeuTheme.raised(radius: isVerySmall ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isVerySmall ? 36 : isSmall ? 40 : 48,
            height: isVerySmall ? 36 : isSmall ? 40 : 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(isVerySmall ? 8 : 10),
            ),
            child: Icon(icon, size: isVerySmall ? 18 : isSmall ? 20 : 24, color: iconColor),
          ),
          SizedBox(height: isVerySmall ? 8 : 12),
          Text(
            label,
            style: TextStyle(fontSize: isVerySmall ? 10 : isSmall ? 11 : 13, color: AppColors.textSecondary),
          ),
          SizedBox(height: isVerySmall ? 2 : 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: isVerySmall ? 15 : isSmall ? 17 : 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(double horizontalPadding, bool isSmall, List<dynamic> monthlyRevenue) {
    final size = MediaQuery.of(context).size;
    final isVerySmall = size.height < 600;
    
    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Revenue', style: TextStyle(fontSize: isVerySmall ? 14 : isSmall ? 15 : 18, fontWeight: FontWeight.w700)),
          SizedBox(height: isVerySmall ? 10 : 16),
          Container(
            height: isVerySmall ? 100 : isSmall ? 120 : 140,
            decoration: NeuTheme.inset(radius: isVerySmall ? 10 : 12),
            padding: EdgeInsets.all(isVerySmall ? 10 : isSmall ? 12 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: ['25k', '20k', '15k', '10k', '5k', '0']
                      .map((label) => Text(label, style: TextStyle(fontSize: isVerySmall ? 7 : 9, color: AppColors.textSecondary)))
                      .toList(),
                ),
                SizedBox(width: isVerySmall ? 6 : 10),
                Expanded(
                  child: CustomPaint(
                    size: Size(double.infinity, isVerySmall ? 70 : isSmall ? 85 : 100),
                    painter: _RevenueChartPainter(monthlyRevenue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildBookingRequests(double horizontalPadding, bool isSmall, List<BookingModel> bookings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: [
              Text('Booking Requests', style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${bookings.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return Dismissible(
              key: ValueKey('booking_${booking.id}'),
              direction: DismissDirection.endToStart,
              background: _removeBackground(),
              onDismissed: (_) => _dismissCard(booking.id, 'Request'),
              child: _buildBookingRequestCard(booking, isSmall),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 250.ms);
  }

  Widget _buildBookingRequestCard(BookingModel booking, bool isSmall) {
    final customerName = booking.customerName;
    final dateStr = DateFormatter.formatDate(booking.scheduledAt);
    final timeStr = DateFormatter.formatTime(booking.scheduledAt);

     return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/provider/booking-request', arguments: booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isSmall ? 14 : 16),
        decoration: NeuTheme.raised(radius: 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: NeuTheme.circle(),
                  child: Center(
                    child: Text(
                      customerName.split(' ').map((e) => e[0]).take(2).join(),
                      style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: TextStyle(fontSize: isSmall ? 16 : 17, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                       Text(
                        booking.serviceId, 
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Rs. ${booking.totalAmount}',
                    style: TextStyle(fontSize: isSmall ? 15 : 17, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(dateStr, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                Icon(Icons.access_time_rounded, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(timeStr, style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                Text('View', style: TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primaryBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobPostsList(double horizontalPadding, bool isSmall, List<JobPostModel> jobs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('New Job Posts', style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w700)),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/provider/jobs'),
                child: Text('View all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primaryBlue)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (jobs.isEmpty)
           Padding(
             padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
             child: Text("No jobs nearby", style: TextStyle(color: AppColors.textSecondary)),
           )
        else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          itemCount: jobs.take(5).length, // Show top 5
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final job = jobs[index];
            return Dismissible(
              key: ValueKey('job_${job.id}'),
              direction: DismissDirection.endToStart,
              background: _removeBackground(),
              onDismissed: (_) => _dismissCard(job.id, 'Job'),
              child: _buildJobPostCard(job, isSmall),
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildJobPostCard(JobPostModel job, bool isSmall) {
    final mediaIcon = (job.mediaUrls.isNotEmpty)
        ? Icons.attachment_rounded 
        : Icons.textsms_outlined;
        
    // Use Helper to get best address - prioritize customer address if available
    final displayAddress = (job.customerAddress != null && job.customerAddress!.isNotEmpty) 
        ? job.customerAddress! 
        : job.location;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/provider/job-detail', arguments: job),
      child: Container(
        padding: EdgeInsets.all(isSmall ? 14 : 16),
        decoration: NeuTheme.raised(radius: 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: NeuTheme.circle(),
                  child: ClipOval(
                    child: job.customerProfileImage != null
                        ? Image.network(
                            job.customerProfileImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                (job.customerName ?? 'C').substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              (job.customerName ?? 'C').substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title, style: TextStyle(fontSize: isSmall ? 16 : 17, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                      Text(job.customerName ?? 'Customer', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (job.mediaUrls.isNotEmpty)
                Container(
                  width: 40,
                  height: 40,
                  decoration: NeuTheme.sm(radius: 10),
                  child: Icon(mediaIcon, color: AppColors.primaryBlue, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(DateFormatter.timeAgo(job.createdAt), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                
                // Location Section - Expanded to take remaining space
                Icon(Icons.location_on, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (displayAddress.isNotEmpty) ? displayAddress : "Location not specified",
                    style: TextStyle(
                       fontSize: 13, 
                       color: AppColors.textPrimary, 
                       fontWeight: FontWeight.w700,
                    ), 
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                
                const SizedBox(width: 8),
                // Button - Fixed size
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Set Price', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'iconOutlined': Icons.home_outlined, 'label': 'Home'},
      {'icon': Icons.calendar_today_rounded, 'iconOutlined': Icons.calendar_today_outlined, 'label': 'Bookings'},
      {'icon': Icons.person_rounded, 'iconOutlined': Icons.person_outline_rounded, 'label': 'Profile'},
    ];

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: NeuTheme.bg,
        boxShadow: [
          BoxShadow(color: Color(0xFFBDCADB), offset: Offset(0, -4), blurRadius: 12),
          BoxShadow(color: Colors.white, offset: Offset(0, 4), blurRadius: 12),
        ],
      ),
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final isSelected = _currentNavIndex == index;
            return GestureDetector(
              onTap: () {
                if (index == 0) {
                  // Already on Home
                } else if (index == 1) {
                  Navigator.pushReplacementNamed(context, '/provider/jobs');
                } else if (index == 2) {
                  Navigator.pushReplacementNamed(context, '/provider/profile');
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 14 : 6, vertical: 5),
                    decoration: isSelected
                        ? BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3)),
                            ],
                          )
                        : null,
                    child: Icon(
                      isSelected
                          ? items[index]['icon'] as IconData
                          : items[index]['iconOutlined'] as IconData,
                      size: 22,
                      color: isSelected ? Colors.white : AppColors.grey400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[index]['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.grey400,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  final List<dynamic> data; // [{month: 'Jan', amount: 5000}, ...]

  _RevenueChartPainter([this.data = const []]);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.grey200
      ..strokeWidth = 1;

    // Draw Grid Lines
    for (int i = 0; i <= 4; i++) {
        final y = (size.height / 4) * i;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (data.isEmpty) return;

    final linePaint = Paint()
      ..color = AppColors.primaryBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Determine Max Amount for scaling
    double maxAmount = 50000; // Default max
    for (var item in data) {
        double val = (item['amount'] as num).toDouble();
        if (val > maxAmount) maxAmount = val;
    }
    if (maxAmount == 0) maxAmount = 10000; // Avoid division by zero

    // Calculate points
    // We expect 6 data points
    final widthPerPoint = size.width / (data.length - 1 > 0 ? data.length - 1 : 1);

    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
        double val = (data[i]['amount'] as num).toDouble();
        double x = i * widthPerPoint;
        double y = size.height - ((val / maxAmount) * size.height); // Invert Y
        points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
        path.moveTo(points[0].dx, points[0].dy);
        for (var i = 1; i < points.length; i++) {
             // Use quadratic bezier for smooth curve if desired, or straight line
             path.lineTo(points[i].dx, points[i].dy);
        }
        canvas.drawPath(path, linePaint);

        // Draw Dots and Labels
        final dotPaint = Paint()..color = AppColors.primaryBlue..style = PaintingStyle.fill;
        final textPainter = TextPainter(textDirection: TextDirection.ltr);

        for (int i = 0; i < points.length; i++) {
            canvas.drawCircle(points[i], 3, dotPaint);
            
            // Draw Month Label below
            textPainter.text = TextSpan(
                text: data[i]['month'], 
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10)
            );
            textPainter.layout();
            textPainter.paint(canvas, Offset(points[i].dx - (textPainter.width / 2), size.height + 5));
        }
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) => oldDelegate.data != data;
}

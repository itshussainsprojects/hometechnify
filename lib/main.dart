// Home Technify - Main Entry Point with Complete Routing
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert'; // Added for jsonEncode
import 'package:home_technify/core/theme/theme.dart';
import 'package:home_technify/core/constants/constants.dart';
// Corrected
import 'package:home_technify/core/services/notification_service.dart';
import 'package:home_technify/core/services/favorites_service.dart';
import 'package:home_technify/core/services/socket_service.dart';
import 'features/booking/screens/negotiation_map_screen.dart';
import 'package:provider/provider.dart';
import 'package:home_technify/features/chat/providers/chat_provider.dart'; // Added Import
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:home_technify/features/auth/providers/auth_provider.dart';
import 'package:home_technify/features/auth/data/repositories/remote_auth_repository.dart';
import 'package:home_technify/features/booking/providers/booking_provider.dart';
import 'package:home_technify/features/booking/data/repositories/remote_booking_repository.dart';
import 'package:home_technify/features/job/providers/job_post_provider.dart';
import 'package:home_technify/features/job/data/repositories/remote_job_repository.dart';
import 'package:home_technify/features/job/data/models/job_post_model.dart';
import 'package:home_technify/features/booking/data/models/booking_model.dart';
import 'package:home_technify/features/home/providers/service_provider.dart';
import 'package:home_technify/features/home/data/repositories/remote_service_repository.dart';
import 'package:home_technify/features/address/providers/address_provider.dart';
import 'package:home_technify/features/address/data/repositories/remote_address_repository.dart';
import 'package:home_technify/features/notifications/providers/notification_provider.dart';
import 'package:home_technify/features/notifications/data/repositories/remote_notification_repository.dart';
import 'package:home_technify/features/profile/providers/profile_provider.dart';
import 'package:home_technify/core/providers/navigation_provider.dart';
import 'package:home_technify/core/widgets/root_back_guard.dart';
import 'package:home_technify/features/profile/data/repositories/remote_profile_repository.dart';
import 'package:home_technify/features/provider/providers/provider_controller.dart';
import 'package:home_technify/features/provider/data/repositories/remote_provider_repository.dart';

// Auth Screens
import 'features/auth/screens/role_selection_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/splash/splash_screen.dart'; // Correct Path
import 'features/onboarding/onboarding_screen.dart'; // Correct Path
import 'features/auth/screens/account_blocked_screen.dart';
import 'features/auth/screens/change_password_screen.dart';
import 'features/auth/screens/location_permission_screen.dart';

// Admin Screens
import 'features/admin/screens/provider_verification_admin_screen.dart';

// User Screens
import 'features/home/screens/home_screen.dart';
import 'features/home/screens/all_services_screen.dart';
import 'features/home/screens/category_screen.dart';
// BottomNavScreen seems missing, defaulting to HomeScreen or assuming it handles nav
import 'features/services/service_detail_screen.dart'; // Correct Path
// CategoryScreen missing, using placeholder or finding it
import 'features/booking/booking_screen.dart'; // Correct Path
import 'features/booking/booking_detail_screen.dart';
import 'features/booking/payment_success_screen.dart';
import 'features/booking/live_track_map_screen.dart';
import 'features/booking/rate_provider_screen.dart';
import 'features/profile/profile_screen.dart'; // User Profile
import 'features/profile/edit_profile_screen.dart'; // Edit Profile
import 'features/payment/payment_methods_screen.dart';
import 'features/address/my_addresses_screen.dart';
import 'features/job/screens/my_jobs_screen.dart';
import 'features/booking/my_bookings_screen.dart';
import 'features/profile/favorite_providers_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/help/help_center_screen.dart';
import 'features/profile/language_screen.dart';
import 'features/settings/terms_screen.dart'; // Correct Path
import 'features/settings/privacy_policy_screen.dart';
import 'features/notifications/notifications_screen.dart'; // Correct Path

// Provider Screens
import 'features/provider/screens/provider_login_screen.dart';
import 'features/provider/screens/provider_forgot_password_screen.dart';
import 'features/provider/screens/provider_onboarding_screen.dart';
import 'features/provider/screens/provider_pending_screen.dart';
import 'features/provider/screens/provider_dashboard_screen.dart';
import 'features/provider/screens/job_requests_screen.dart';
import 'features/provider/screens/cnic_verification_screen.dart';
import 'features/provider/screens/earnings_screen.dart';
import 'features/provider/screens/provider_profile_screen.dart'; // Provider Profile
import 'features/provider/screens/reviews_screen.dart';
import 'features/provider/screens/wallet_screen.dart'; // Correct Path
import 'features/provider/screens/job_post_detail_screen.dart';
import 'features/provider/screens/set_price_screen.dart';
import 'features/provider/screens/booking_request_screen.dart';
import 'features/provider/screens/ongoing_service_screen.dart';
import 'features/provider/screens/service_complete_screen.dart';
import 'features/provider/screens/provider_notifications_screen.dart';
// Keeping for reference or removal
import 'features/provider/screens/provider_services_screen.dart'; // New Service Screen
import 'features/provider/screens/bank_detail_screen.dart';
import 'features/provider/screens/wallet_history_screen.dart'; // New Wallet History Screen
import 'features/provider/screens/advertise_service_screen.dart';
import 'features/provider/screens/profile_actions_screen.dart';
import 'features/location/location_picker_screen.dart';
import 'features/job/screens/finding_providers_screen.dart';
import 'features/job/screens/post_job_screen.dart';

// Chat & Calls
import 'features/chat/screens/chat_list_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/screens/call_screen.dart'; // Correct Path
import 'features/call/voice_call_screen.dart'; // Correct Path
// Assuming exists
import 'features/chat/data/repositories/remote_chat_repository.dart'; // Added Import

// Admin Screens
import 'features/admin/screens/admin_login_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/admin/screens/admin_recycle_bin_screen.dart';
import 'features/admin/screens/admin_provider_recycle_bin_screen.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Supabase — initialize ONCE (calling it twice throws and crashes on launch).
  // Overridable at build time so a different project can be targeted without a
  // code edit. The anon key is the publishable one (row-level security is what
  // protects the data), so baking it into the binary is expected — the service
  // key must never appear here.
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://wuwnkcnuphnwmuxdpcqn.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1d25rY251cGhud211eGRwY3FuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzNDA0ODcsImV4cCI6MjA4NDkxNjQ4N30.ns5ufUrUAY81up2yjFF7x1hKudMeRkUyY-_QVGRnROU',
    ),
  );

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Initialize Notification Service
  await NotificationService().init();
  
  // Initialize Socket.IO (will connect when user logs in)
  // Socket connection happens in AuthProvider after successful login
  
  // Hook Socket Notifications
  SocketService().onNotification = (data) {
     if (data['title'] != null && data['body'] != null) {
        NotificationService().showNotification(data['title'], data['body']);
     }
  };
   
  // Also hook new messages if not in chat screen? 
  // Ideally, logic should check current route, but for now, let's just show notification.
  SocketService().onNewMessage = (data) {
      // data: {senderId, message, ...}
      final payload = {
        'route': '/chat',
        'arguments': {
           'recipientId': data['senderId'],
           'name': 'New Message', // Backend should ideally send name
           'service': 'Chat'
        }
      };
      
      NotificationService().showNotification(
          "New Message", 
          data['text'] ?? data['message'] ?? 'You have a new message',
          payload: jsonEncode(payload) // Requires dart:convert
      );
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(RemoteAuthRepository())),
        ChangeNotifierProvider(create: (_) => BookingProvider(RemoteBookingRepository())), 
        ChangeNotifierProvider(create: (_) => JobPostProvider(RemoteJobRepository())), // Corrected
        ChangeNotifierProvider(create: (_) => FavoritesService()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => ServiceProvider(RemoteServiceRepository())),
        ChangeNotifierProvider(create: (_) => AddressProvider(RemoteAddressRepository())),
        ChangeNotifierProvider(create: (_) => NotificationProvider(RemoteNotificationRepository())),
        ChangeNotifierProvider(create: (_) => ProfileProvider(RemoteProfileRepository())),
        ChangeNotifierProvider(create: (_) => ProviderController(RemoteProviderRepository())),
        ChangeNotifierProvider(create: (_) => ChatProvider(RemoteChatRepository(FirebaseFirestore.instance))), // Added ChatProvider with Repository and Firestore instance
      ],
      child: const HomeTechnifyApp(),
    ),
  );
}

class HomeTechnifyApp extends StatelessWidget {
  const HomeTechnifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Home Technify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final page = buildPage(settings);

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: animation, curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // Pure cross-fade route - used by the splash screen so the mascot's last
  // frame dissolves straight into the app with no slide/wipe motion.
  static Route<dynamic> fadeRoute(RouteSettings settings) {
    final page = buildPage(settings);

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 550),
    );
  }

  static Widget buildPage(RouteSettings settings) {
    Widget page;
    final args = settings.arguments; 
    final Map<String, dynamic>? argumentsMap = args is Map<String, dynamic> ? args : null;

    switch (settings.name) {
      case '/':
        page = const SplashScreen();
        break;
      case '/onboarding':
        page = const OnboardingScreen();
        break;
      case '/role-selection':
        page = const RoleSelectionScreen();
        break;
      
      // Auth Routes
      case '/login':
        page = const LoginScreen();
        break;
      case '/signup':
        page = const SignupScreen();
        break;
      // '/otp' route removed. Sign-in and registration are email + password (or
      // Google) — the phone OTP step is gone from both the customer and provider
      // apps, so nothing routes here any more.
      case '/location-permission':
        page = const LocationPermissionScreen();
        break;
      case '/forgot-password':
        page = const ForgotPasswordScreen();
        break;
      
      // Main App Routes
      case '/home':
        page = const HomeScreen(); // BottomNav seems merged or missing
        break;
      case '/service-detail':
        final map = args is Map<String, dynamic> ? args : <String, dynamic>{};
        page = ServiceDetailScreen(
          serviceName: map['serviceName'] ?? 'Service',
          serviceId: map['serviceId'] ?? '', // Should be provided
          serviceIcon: map['serviceIcon'] ?? Icons.design_services,
          serviceColor: map['serviceColor'] ?? AppColors.primaryBlue,
        );
        break;
      case '/category':
        final map = args is Map<String, dynamic> ? args : <String, dynamic>{};
        page = CategoryScreen(categoryName: map['name'] ?? 'Services');
        break;
      case '/booking':
        final map = args is Map<String, dynamic> ? args : <String, dynamic>{};
        page = BookingScreen(
          providerId: map['providerId'],
          serviceId: map['serviceId'],
          providerName: map['providerName'],
          serviceName: map['serviceName'],
          price: map['price']?.toString(),
          negotiated: map['negotiated'] ?? false,
          initialAddress: map['initialAddress'],
        );
        break;
      case '/booking-detail':
        page = const BookingDetailScreen();
        break;
      case '/booking-confirmation':
      case '/booking-success':
        page = const PaymentSuccessScreen();
        break;
      // Real live map. This route used to open a screen whose "map" was a
      // gradient with a grid painted on it — no tiles, no route, no real
      // position — while the live GPS socket feed went to that same screen.
      case '/track-provider':
        page = LiveTrackMapScreen(
          bookingId: argumentsMap?['bookingId'] ?? '',
          providerId: argumentsMap?['providerId'] ?? '',
          view: TrackView.customerWatchingProvider,
          customerLat: (argumentsMap?['customerLat'] as num?)?.toDouble() ?? 0,
          customerLng: (argumentsMap?['customerLng'] as num?)?.toDouble() ?? 0,
          providerLat: (argumentsMap?['lat'] as num?)?.toDouble(),
          providerLng: (argumentsMap?['lng'] as num?)?.toDouble(),
          providerName: argumentsMap?['providerName'] ?? 'Provider',
        );
        break;
      case '/rate-provider':
        page = const RateProviderScreen();
        break;
      case '/notifications':
        page = const NotificationsScreen();
        break;
      
      // Profile Routes
      case '/profile':
        page = const ProfileScreen(); 
        break;
      case '/edit-profile':
        page = const EditProfileScreen();
        break;
      case '/payment-methods':
        page = const PaymentMethodsScreen();
        break;
      case '/my-addresses':
        page = const MyAddressesScreen();
        break;
      case '/location-picker':
        page = const LocationPickerScreen();
        break;
      case '/my-jobs':
        page = const MyJobsScreen();
        break;
      case '/my-bookings':
        page = const MyBookingsScreen();
        break;
      case '/favorite-providers':
        page = const FavoriteProvidersScreen();
        break;
      case '/settings':
        page = const SettingsScreen();
        break;
      case '/help-center':
        page = const HelpCenterScreen();
        break;
      // '/provider-map' route removed. That screen was fed by
      // ProviderSimulationService, which INVENTS providers — random names, random
      // ratings between 3.5 and 5.0, random hourly rates — and drops them on the
      // map as if they were real people a customer could book. Nothing navigated
      // to it, and a marketplace that shows fabricated providers is not one you
      // ship. The real nearby-provider list is service_detail_screen, backed by
      // GET /providers with the live radius fence.
      case '/all-services':
        page = const AllServicesScreen();
        break;
      case '/language':
        page = LanguageScreen(currentLanguage: argumentsMap?['currentLanguage'] ?? 'English');
        break;
      case '/terms':
        page = const TermsOfServiceScreen();
        break;
      case '/privacy':
        page = const PrivacyPolicyScreen();
        break;
      
      // Provider Flow
      case '/provider/login':
        page = const ProviderLoginScreen();
        break;
      case '/provider/forgot-password':
        page = const ProviderForgotPasswordScreen();
        break;
      case '/provider/onboarding':
        page = const ProviderOnboardingScreen();
        break;
      case '/provider/dashboard':
        page = const ProviderDashboardScreen();
        break;
      case '/provider/pending':
        page = const ProviderPendingScreen();
        break;
      case '/provider/jobs':
        page = const JobRequestsScreen();
        break;
      case '/provider/cnic':
        page = const CnicVerificationScreen();
        break;
      case '/provider/earnings':
        page = const EarningsScreen();
        break;
      case '/provider/profile':
        page = const ProviderProfileScreen();
        break;
      case '/provider/reviews':
        page = const ReviewsScreen();
        break;
      case '/provider/wallet':
        page = const ProviderWalletScreen();
        break;
      case '/provider/wallet-history':
        page = const WalletHistoryScreen();
        break;
      // '/provider/workers' route removed. There is no Worker in the data model
      // and no endpoint behind it — the screen listed invented staff. Nothing
      // navigated to it, and shipping a fake feature is worse than not shipping
      // one. Reinstate it when sub-contractors actually exist in the backend.
      case '/provider/job-detail':
        page = JobPostDetailScreen(job: args as JobPostModel);
        break;
      case '/provider/set-price':
        page = SetPriceScreen(job: args as JobPostModel);
        break;
      case '/provider/booking-request':
        page = BookingRequestScreen(booking: args as BookingModel);
        break;
      case '/provider/ongoing':
        page = OngoingServiceScreen(bookingData: argumentsMap); 
        break;
      case '/provider/complete':
        final completeArgs = args as Map<String, dynamic>;
        page = ServiceCompleteScreen(
          booking: completeArgs['booking'] as BookingModel,
          elapsedSeconds: completeArgs['duration'] as int? ?? 0,
        );
        break;
      case '/provider/notifications':
        page = const ProviderNotificationsScreen();
        break;
      // The real, Firestore-backed conversation list. This used to open a screen
      // with a hardcoded list of invented chats ("Fatima Khan").
      case '/provider/messages':
        page = const ChatListScreen();
        break;
      case '/provider/services':
        page = const ProviderServicesScreen();
        break;
      case '/provider/bank-detail':
        page = const BankDetailScreen();
        break;
      case '/provider/advertise':
        page = const AdvertiseServiceScreen();
        break;
      case '/provider/theme':
        page = const ProfileActionsScreen(type: 'theme');
        break;
      case '/provider/password':
        page = const ChangePasswordScreen();
        break;
      case '/provider/about':
        page = const ProfileActionsScreen(type: 'about');
        break;
      
      // Chat & Calls
      case '/chats':
        page = const ChatListScreen();
        break;
      case '/chat':
        page = ChatScreen(
          recipientId: argumentsMap?['id'] ?? argumentsMap?['recipientId'],
          recipientName: argumentsMap?['name'],
          recipientService: argumentsMap?['service'],
        );
        break;
      case '/call':
        page = CallScreen(
          isVideo: argumentsMap?['isVideo'] ?? false,
          callerName: argumentsMap?['name'],
        );
        break;
      case '/voice-call':
        page = VoiceCallScreen(
          customerName: argumentsMap?['name'],
          phoneNumber: argumentsMap?['phone'],
        );
        break;
      // '/negotiation' route removed — the old NegotiationScreen used FAKE
      // simulated replies. Real negotiation happens via the Negotiate popup
      // (finding_providers_screen) + booking detail panels, socket-driven.

      // Admin Routes
      case '/admin/login':
        page = const AdminLoginScreen();
        break;
      case '/admin/dashboard':
        page = const AdminDashboardScreen();
        break;
      case '/admin/providers/verification':
        page = const ProviderVerificationAdminScreen();
        break;
      case '/admin-recycle-bin':
        page = const AdminRecycleBinScreen();
        break;
      case '/admin-provider-recycle-bin':
        page = const AdminProviderRecycleBinScreen();
        break;
      case '/account-blocked':
        page = const AccountBlockedScreen();
        break;
              case '/negotiation-map':
            final args = settings.arguments as Map<String, dynamic>;
            page = NegotiationMapScreen(
              providerId: args['providerId'],
              providerName: args['providerName'] ?? 'Provider',
              serviceName: args['serviceName'] ?? 'Service',
              jobId: args['jobId'],
              bookingId: args['bookingId'],
            );
            break;
      case '/post-job':
        final map = args as Map<String, dynamic>;
        page = PostJobScreen(
          serviceName: map['serviceName'],
          serviceId: map['serviceId'] ?? '', // Fallback or required?
          serviceIcon: map['serviceIcon'],
          serviceColor: map['serviceColor'],
        );
        break;
      case '/finding-providers':
        final map = settings.arguments as Map<String, dynamic>;
        page = FindingProvidersScreen(
          jobId: map['jobId'],
          serviceName: map['serviceName'],
          serviceId: map['serviceId'] ?? '',
          jobData: map['jobData'],
        );
        break;
          default:
        page = const SplashScreen();
    }

    // Entry screens are reached with pushReplacementNamed, so they sit at the
    // bottom of the stack with nothing to pop. A system back there emptied the
    // navigator and showed a black screen; send the user to splash instead.
    const rootRoutes = {
      '/role-selection',
      '/login',
      '/signup',
      '/provider/login',
      '/provider/register',
      '/admin/login',
    };
    if (rootRoutes.contains(settings.name)) {
      page = RootBackGuard(child: page);
    }

    return page;
  }
}

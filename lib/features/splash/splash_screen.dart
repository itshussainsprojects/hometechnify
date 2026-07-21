// Premium Splash Screen
// The official 3D Techy mascot floats freely on a studio-light canvas -
// no frame, no circle, no visible box. The keyframe edges are feathered
// into the background so only the avatar reads. As Techy flies off, the
// next screen fades in UNDER the exit - the user never sees a blank frame.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/session_cache.dart';
import '../../core/widgets/techy_animation.dart';
import '../auth/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _splashDuration = Duration(milliseconds: 5800);

  bool _navigated = false;
  bool _animReady = false;
  String? _fastPathRoute;

  /// A user with a persisted Firebase session is coming back, not arriving.
  /// Firebase keeps that session on disk, so this is a local, instant check —
  /// no network. Returning users must not be made to sit through the full brand
  /// animation; they leave the moment their session resolves.
  final bool _isReturningUser = FirebaseAuthService.isAuthenticated();

  late final AnimationController _progressController;
  Future<void>? _authFuture;

  @override
  void initState() {
    super.initState();
    _progressController =
        AnimationController(vsync: this, duration: _splashDuration);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // The session check still runs — it is the source of truth — but for a
      // returning user we don't WAIT for it. Kick it off, then jump straight to
      // the dashboard using the role cached on disk. No splash animation, no
      // login page, no round-trip to a database on the other side of the world.
      // If that background check later finds the account blocked or deleted, the
      // API's 403 interceptor signs them out.
      _authFuture = context.read<AuthProvider>().checkAuthStatus();

      if (_isReturningUser) {
        _fastPathToDashboard();
        // If there was no cached role, _tryNavigate still opens the right
        // screen once the check resolves. If the fast path DID fire, this
        // instead verifies it: SessionCache is device-wide, not per-account,
        // so a fresh registration on a device that last cached a different
        // role/status inherits that stale flag — the fast path would then
        // send them to the wrong screen before the real check ever ran.
        _authFuture!.whenComplete(_verifyFastPathOrNavigate);
      }
    });

    // Safety net: never keep the user waiting past 10s even if assets fail.
    Future.delayed(const Duration(seconds: 10), _tryNavigate);
  }

  /// Open the right dashboard immediately from the cached role, before any
  /// network call returns. Does nothing if there is no cached role (falls back
  /// to the normal resolve-then-navigate path).
  Future<void> _fastPathToDashboard() async {
    final role = await SessionCache.role();
    if (role == null || _navigated || !mounted) return;

    final route = switch (role) {
      'ADMIN' => '/admin/dashboard',
      'PROVIDER' =>
        await SessionCache.providerPending() ? '/provider/pending' : '/provider/dashboard',
      'CUSTOMER' => '/home',
      _ => null,
    };
    if (route == null || _navigated || !mounted) return;

    _navigated = true;
    _fastPathRoute = route;
    Navigator.pushReplacementNamed(context, route);
  }

  void _tryNavigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _navigateBasedOnSession();
  }

  /// Runs once the real /auth/me check resolves. If the fast path already
  /// navigated on cached data, this compares that route against what the live
  /// data actually says and corrects course if they disagree — the one case
  /// that matters is a provider whose device-wide cache said "not pending"
  /// (or nothing) while the live status says otherwise.
  void _verifyFastPathOrNavigate() {
    if (!_navigated) {
      _tryNavigate();
      return;
    }
    if (_fastPathRoute == null || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.status != AuthStatus.success || authProvider.user == null) return;
    final user = authProvider.user!;

    final correctRoute = switch (user.role) {
      'PROVIDER' => user.status == 'pending_verification' ? '/provider/pending' : '/provider/dashboard',
      'ADMIN' => '/admin/dashboard',
      'CUSTOMER' => '/home',
      _ => null,
    };

    if (correctRoute != null && correctRoute != _fastPathRoute) {
      debugPrint('⚠️ Fast-path route ($_fastPathRoute) disagreed with live status — correcting to $correctRoute');
      Navigator.pushReplacementNamed(context, correctRoute);
    }
  }

  void _navigateBasedOnSession() async {
    final authProvider = context.read<AuthProvider>();
    // Usually already resolved (started at splash launch) - instant open.
    // Hard timeout: if the network is dead/slow (e.g. Firebase can't
    // resolve), NEVER hang on the splash - proceed with whatever auth
    // state we have (falls through to onboarding when unknown).
    try {
      await (_authFuture ?? authProvider.checkAuthStatus())
          .timeout(const Duration(seconds: 8));
    } catch (_) {/* offline / slow network - continue with current state */}
    if (!mounted) return;

    if (authProvider.status == AuthStatus.success && authProvider.user != null) {
      final user = authProvider.user!;
      debugPrint("🚀 Splash Navigation - Role: ${user.role}, Status: ${user.status}");

      if (user.role == 'PROVIDER') {
        if (user.status == 'pending_verification') {
           if (mounted) Navigator.pushReplacementNamed(context, '/provider/pending');
        } else {
           if (mounted) Navigator.pushReplacementNamed(context, '/provider/dashboard');
        }
      } else if (user.role == 'ADMIN') {
        if (mounted) Navigator.pushReplacementNamed(context, '/admin/dashboard');
      } else if (user.role == 'CUSTOMER') {
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        debugPrint("⚠️ Unknown role: ${user.role}");
        if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
      }
    } else {
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final isVerySmall = size.height < 600;

    // Avatar sizing: as large as the screen allows, full body visible,
    // capped on tablets/desktop. Frames are 720x1060 (aspect 1.472).
    const frameAspect = 1060 / 720;
    final avatarW = math.min(
      math.min(size.width * 1.0, (size.height * 0.66) / frameAspect),
      480.0,
    );
    final avatarH = avatarW * frameAspect;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFD3DAE0),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFEAEEF2),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Studio-light canvas matched to the animation's backdrop
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF1F4F7),
                    Color(0xFFE7EBEF),
                    Color(0xFFD3DAE0),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 4),

                  // ---- The avatar, free-floating (edges feathered away) ----
                  SizedBox(
                    width: avatarW,
                    height: avatarH,
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.09, 0.88, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.10, 0.90, 1.0],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: TechyFrameAnimation(
                          duration: _splashDuration,
                          fit: BoxFit.cover,
                          onReady: () {
                            if (!mounted) return;
                            setState(() => _animReady = true);
                            _progressController.forward();
                          },
                          // Start opening the app WHILE Techy is flying off -
                          // the fade completes before the animation ends, so
                          // there is never a stuck or blank moment.
                          onTrigger: _tryNavigate,
                          triggerFraction: 0.88,
                          onCompleted: _tryNavigate,
                        ),
                      ),
                    ),
                  ).animate(target: _animReady ? 1 : 0).fadeIn(duration: 450.ms),

                  const Spacer(flex: 1),

                  // ---- Wordmark ----
                  AnimatedOpacity(
                    opacity: _animReady ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: isVerySmall ? 24 : isSmall ? 27 : 31,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                            children: const [
                              TextSpan(
                                text: 'HOME ',
                                style: TextStyle(color: AppColors.brandNavy),
                              ),
                              TextSpan(
                                text: 'TECHNIFY',
                                style: TextStyle(color: AppColors.primaryBlue),
                              ),
                            ],
                          ),
                        )
                            .animate(target: _animReady ? 1 : 0)
                            .fadeIn(duration: 600.ms, delay: 250.ms)
                            .slideY(
                                begin: 0.4, end: 0, curve: Curves.easeOutCubic)
                            .shimmer(
                                duration: 1800.ms,
                                delay: 1200.ms,
                                color: AppColors.primaryLight
                                    .withValues(alpha: 0.5)),
                        SizedBox(height: isVerySmall ? 6 : 10),
                        Text(
                          "Pakistan's #1 Premium Home Services",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: isVerySmall ? 11.5 : isSmall ? 12.5 : 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.4,
                          ),
                        )
                            .animate(target: _animReady ? 1 : 0)
                            .fadeIn(duration: 600.ms, delay: 500.ms)
                            .slideY(begin: 0.5, end: 0),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ---- Progress line ----
                  AnimatedOpacity(
                    opacity: _animReady ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: isVerySmall ? 20 : isSmall ? 26 : 36),
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, _) => SizedBox(
                          width: size.width * 0.3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progressController.value,
                              minHeight: 3.5,
                              backgroundColor:
                                  AppColors.brandNavy.withValues(alpha: 0.08),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryBlue),
                            ),
                          ),
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

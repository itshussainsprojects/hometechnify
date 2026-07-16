import 'package:flutter/material.dart';

/// Wraps a screen that can be the bottom of the navigation stack.
///
/// Entry screens (role selection, the login screens) are reached with
/// `pushReplacementNamed`, so there is nothing left to pop. A system back there
/// empties the stack and Flutter renders a black screen. This sends the user
/// back to [fallbackRoute] instead.
class RootBackGuard extends StatelessWidget {
  const RootBackGuard({
    super.key,
    required this.child,
    this.fallbackRoute = '/',
  });

  final Widget child;

  /// Where to go when there is no history to pop. Defaults to the splash route,
  /// which re-runs the auth check and lands the user on the right screen.
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          nav.pushReplacementNamed(fallbackRoute);
        }
      },
      child: child,
    );
  }
}

// TechyBuddy - the living mascot companion for the user dashboard.
//
// Techy quietly floats in the hero card with a breathing bob, and every
// once in a while does a tiny bit of personality on his own: pulls out his
// wrench, has a little laugh, or does a happy wiggle. Poke him and he
// laughs and hops. When something good happens (new notification, booking
// confirmed) call `react()` and he does an excited double-hop.
//
// Design rules: everything is small, silent and short (~1.5s max), never
// blocks a tap, never interrupts scrolling - pure delight, zero friction.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TechyBuddy extends StatefulWidget {
  final double height;

  /// Seconds range between self-started antics (min..max).
  final int anticsMinGap;
  final int anticsMaxGap;

  /// Do an excited hop-and-laugh shortly after appearing - for success /
  /// celebration screens.
  final bool celebrateOnStart;

  /// Fly in from beyond the right edge (rocket entrance) instead of just
  /// appearing - for the hero banner.
  final bool entrance;

  /// Occasionally turn and point (left, toward the card's CTA), nudging
  /// the user to book. [onPoint] fires at the same moment so the host can
  /// pulse its button in sync.
  final bool enablePointing;
  final VoidCallback? onPoint;

  const TechyBuddy({
    super.key,
    this.height = 120,
    this.anticsMinGap = 9,
    this.anticsMaxGap = 18,
    this.celebrateOnStart = false,
    this.entrance = false,
    this.enablePointing = false,
    this.onPoint,
  });

  @override
  State<TechyBuddy> createState() => TechyBuddyState();
}

class TechyBuddyState extends State<TechyBuddy>
    with TickerProviderStateMixin {
  // Poses reuse assets that already ship with the app - zero extra weight.
  static const _posing = 'assets/images/techy_wave_nobg.webp'; // wave + toolbox
  static const _laughing = 'assets/anim/techy_alpha/f034.webp'; // big laugh
  static const _working = 'assets/anim/techy_alpha/f025.webp'; // wrench out
  // Arm extended - rendered mirrored so he points LEFT, toward the CTA.
  static const _pointing = 'assets/anim/techy_alpha/f033.webp';

  late final AnimationController _floatCtrl;
  late final AnimationController _hopCtrl;
  late final AnimationController _wiggleCtrl;
  late final AnimationController _entryCtrl;

  String _pose = _posing;
  Timer? _anticsTimer;
  Timer? _poseTimer;
  final _rng = math.Random();
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    // Gentle breathing float - always on, barely-there.
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    // A springy little hop (used for taps and reactions).
    _hopCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    // A quick left-right happy wiggle.
    _wiggleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    // Rocket fly-in from the right edge.
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950));
    if (widget.entrance) {
      Timer(const Duration(milliseconds: 250), () {
        if (mounted) _entryCtrl.forward();
      });
    } else {
      _entryCtrl.value = 1;
    }
    _scheduleAntics();
    if (widget.celebrateOnStart) {
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) react();
      });
    }
    // First guided nudge: shortly after landing, point at the CTA once.
    if (widget.enablePointing) {
      Timer(const Duration(milliseconds: 2800), () {
        if (mounted) _pointAtCta();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Warm the alternate poses so swaps never flash.
    precacheImage(const AssetImage(_laughing), context);
    precacheImage(const AssetImage(_working), context);
    precacheImage(const AssetImage(_pointing), context);
  }

  @override
  void dispose() {
    _anticsTimer?.cancel();
    _poseTimer?.cancel();
    _floatCtrl.dispose();
    _hopCtrl.dispose();
    _wiggleCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ---- Public API ----

  /// Excited double-hop + laugh. Call when something good happens
  /// (new notification, booking confirmed, payment success...).
  void react() {
    if (!mounted) return;
    _setPose(_laughing, holdMs: 1600);
    _hop(times: 2);
    _wiggleCtrl.forward(from: 0);
  }

  // ---- Internals ----

  void _scheduleAntics() {
    final gap = widget.anticsMinGap +
        _rng.nextInt(math.max(1, widget.anticsMaxGap - widget.anticsMinGap));
    _anticsTimer = Timer(Duration(seconds: gap), () {
      if (!mounted) return;
      _doRandomAntic();
      _scheduleAntics();
    });
  }

  void _doRandomAntic() {
    switch (_rng.nextInt(widget.enablePointing ? 4 : 3)) {
      case 0: // pulls out the wrench for a moment - "ready to fix!"
        _setPose(_working, holdMs: 1500);
        _wiggleCtrl.forward(from: 0);
        break;
      case 1: // a private little laugh
        _setPose(_laughing, holdMs: 1300);
        _hop();
        break;
      case 2: // happy wiggle, no pose change
        _wiggleCtrl.forward(from: 0);
        break;
      case 3: // turn and point at the Book-a-Service button
        _pointAtCta();
        break;
    }
  }

  // Turn toward the CTA and point at it; the host pulses its button
  // at the same beat via [onPoint].
  void _pointAtCta() {
    if (!mounted) return;
    _setPose(_pointing, holdMs: 2100);
    widget.onPoint?.call();
  }

  void _onPoked() {
    HapticFeedback.lightImpact();
    _setPose(_laughing, holdMs: 1400);
    _hop();
  }

  void _setPose(String pose, {required int holdMs}) {
    _poseTimer?.cancel();
    setState(() => _pose = pose);
    _poseTimer = Timer(Duration(milliseconds: holdMs), () {
      if (mounted) setState(() => _pose = _posing);
    });
  }

  void _hop({int times = 1}) async {
    for (var i = 0; i < times; i++) {
      if (!mounted) return;
      await _hopCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onPoked,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation:
            Listenable.merge([_floatCtrl, _hopCtrl, _wiggleCtrl, _entryCtrl]),
        builder: (context, child) {
          // Breathing bob: +-3.5px drift with a hint of tilt.
          final f = Curves.easeInOut.transform(_floatCtrl.value);
          final bobY = (f - 0.5) * 7;
          final bobTilt = (f - 0.5) * 0.05;

          // Hop: a single sine arc, up to 12% of the mascot height,
          // with a touch of squash-and-stretch at the top.
          final h = math.sin(math.pi * _hopCtrl.value);
          final hopY = -h * widget.height * 0.12;
          final stretch = 1 + h * 0.05;

          // Wiggle: three decaying swings.
          final w = _wiggleCtrl.value;
          final wiggle =
              math.sin(w * math.pi * 3) * (1 - w) * 0.09;

          // Rocket entrance: swoop in from beyond the right edge, leaning
          // into the motion, overshoot a touch, then settle.
          final e = Curves.easeOutBack.transform(_entryCtrl.value);
          final entryX = (1 - e) * widget.height * 1.6;
          final entryTilt = (1 - e) * -0.30;

          // Lean toward the CTA while pointing.
          final pointLean = _pose == TechyBuddyState._pointing ? -0.06 : 0.0;

          return Opacity(
            opacity: _entryCtrl.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(entryX, bobY + hopY),
              child: Transform.rotate(
                angle: bobTilt + wiggle + entryTilt + pointLean,
                child: Transform.scale(
                  scaleY: stretch,
                  scaleX: 2 - stretch, // conserve volume: squash as it stretches
                  child: child,
                ),
              ),
            ),
          );
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Transform.flip(
            key: ValueKey(_pose),
            // The pointing frame has his arm out to the right; mirrored it
            // aims left - straight at the Book-a-Service button.
            flipX: _pose == TechyBuddyState._pointing,
            child: Image.asset(
              _pose,
              height: widget.height,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

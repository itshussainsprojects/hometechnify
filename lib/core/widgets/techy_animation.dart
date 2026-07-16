// Techy frame animation - the official 3D mascot rendered as a keyframe
// sequence (extracted from the brand animation, watermark and studio
// background removed - every frame is a transparent cut-out, so the mascot
// composites onto any screen design).
// Played as a flipbook: all frames are precached first so playback is
// perfectly smooth, then an AnimationController drives the frame index.

import 'package:flutter/material.dart';

class TechyFrameAnimation extends StatefulWidget {
  /// Total playback time for the full sequence.
  final Duration duration;

  /// Called once when the last frame has been shown.
  final VoidCallback? onCompleted;

  /// Called when every frame is precached and playback starts.
  final VoidCallback? onReady;

  /// Called once when playback crosses [triggerFraction] (0..1).
  final VoidCallback? onTrigger;
  final double triggerFraction;

  /// Called once when playback crosses [exitFraction] (0..1) - lets the
  /// host start its exit choreography (fly the mascot off screen, fade the
  /// next screen in) WHILE the final frames still play, so there is never
  /// a held pose or a wait at the end.
  final VoidCallback? onExitStart;
  final double exitFraction;

  final BoxFit fit;

  const TechyFrameAnimation({
    super.key,
    this.duration = const Duration(milliseconds: 6200),
    this.onCompleted,
    this.onReady,
    this.onTrigger,
    this.triggerFraction = 0.5,
    this.onExitStart,
    this.exitFraction = 0.9,
    this.fit = BoxFit.contain,
  });

  static const int frameCount = 59;

  // The source clip had a middle segment where the mascot drifts left to
  // point at UI cards baked into (and cut off by) the footage - that
  // segment is removed. The seam between the two kept segments sits at
  // this frame (0-based); playback cross-dissolves over it so the cut
  // reads as intentional.
  static const int _seamFrame = 32;
  static const double _seamDissolveFrames = 3.0;

  static String framePath(int index) =>
      'assets/anim/techy_alpha/f${(index + 1).toString().padLeft(3, '0')}.webp';

  @override
  State<TechyFrameAnimation> createState() => _TechyFrameAnimationState();
}

class _TechyFrameAnimationState extends State<TechyFrameAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _ready = false;
  bool _precacheStarted = false;
  bool _triggered = false;
  bool _exitTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted?.call();
      }
    });
    _controller.addListener(() {
      if (!_triggered &&
          widget.onTrigger != null &&
          _controller.value >= widget.triggerFraction) {
        _triggered = true;
        widget.onTrigger!();
      }
      if (!_exitTriggered &&
          widget.onExitStart != null &&
          _controller.value >= widget.exitFraction) {
        _exitTriggered = true;
        widget.onExitStart!();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precacheStarted) return;
    _precacheStarted = true;
    _precacheAll();
  }

  Future<void> _precacheAll() async {
    // Warm every frame into the image cache so the flipbook never stutters.
    final futures = <Future<void>>[];
    for (var i = 0; i < TechyFrameAnimation.frameCount; i++) {
      futures.add(
        precacheImage(AssetImage(TechyFrameAnimation.framePath(i)), context),
      );
    }
    await Future.wait(futures);
    if (!mounted) return;
    setState(() => _ready = true);
    widget.onReady?.call();
    if (MediaQuery.of(context).disableAnimations) {
      // Reduced motion: hold the wave pose, then finish on schedule.
      _controller.value = 0.04;
      Future.delayed(widget.duration, () {
        if (mounted) widget.onCompleted?.call();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _frame(int index) {
    return Image.asset(
      TechyFrameAnimation.framePath(
          index.clamp(0, TechyFrameAnimation.frameCount - 1)),
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final p = _controller.value * (TechyFrameAnimation.frameCount - 1);
        const seam = TechyFrameAnimation._seamFrame;
        const window = TechyFrameAnimation._seamDissolveFrames;

        // Cross-dissolve across the edit seam.
        if (p > seam && p < seam + window) {
          final t = Curves.easeInOut.transform((p - seam) / window);
          return Stack(
            fit: StackFit.passthrough,
            children: [
              _frame(seam),
              Opacity(opacity: t, child: _frame(p.floor() + 1)),
            ],
          );
        }

        final index =
            p.floor().clamp(0, TechyFrameAnimation.frameCount - 1);
        return _frame(index);
      },
    );
  }
}

/// Static still of the official mascot (waving pose) for headers,
/// hero cards and empty states. Transparent cut-out - no card, no
/// background, no shape: just the avatar.
class TechyStill extends StatelessWidget {
  final double height;

  // Kept so existing call sites compile; the cut-out has no background
  // to round anymore.
  final double borderRadius;

  const TechyStill({super.key, this.height = 120, this.borderRadius = 0});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/techy_wave_nobg.webp',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

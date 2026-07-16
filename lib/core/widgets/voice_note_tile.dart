import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../constants/constants.dart';

/// Plays a voice note attached to a job post.
///
/// Customers record their job description as `.m4a`, so a voice attachment must
/// never be rendered as an image thumbnail — it just fails to load.
class VoiceNoteTile extends StatefulWidget {
  const VoiceNoteTile({super.key, required this.url, this.width = 160});

  final String url;
  final double width;

  @override
  State<VoiceNoteTile> createState() => _VoiceNoteTileState();
}

class _VoiceNoteTileState extends State<VoiceNoteTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds;
    final progress =
        total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: widget.width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voice note',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor:
                          AppColors.primaryBlue.withValues(alpha: 0.2),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _duration == Duration.zero
                        ? 'Tap to play'
                        : '${_fmt(_position)} / ${_fmt(_duration)}',
                    style: TextStyle(fontSize: 10, color: AppColors.grey600),
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

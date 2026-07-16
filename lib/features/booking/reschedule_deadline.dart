import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import 'data/models/booking_model.dart';

/// How long is left before the backend auto-declines an unanswered reschedule.
///
/// The backend sweeps proposals and, past this window, quietly puts the booking
/// back on its ORIGINAL time (silence is not consent). Without showing the
/// deadline, that would look to the user like the app "changed its mind" on its
/// own — so both sides are told how long they have.
///
/// Must match RESCHEDULE_EXPIRY_HOURS on the server.
const rescheduleExpiryHours = 24;

/// A one-line deadline notice for the reschedule panel. Renders nothing when
/// there is no pending proposal or the request time is unknown.
class RescheduleDeadline extends StatelessWidget {
  const RescheduleDeadline({super.key, required this.booking, required this.actionRequired});

  final BookingModel booking;

  /// True on the side that still has to accept or decline.
  final bool actionRequired;

  @override
  Widget build(BuildContext context) {
    final requestedAt = booking.rescheduleRequestedAt;
    if (booking.rescheduleProposedAt == null || requestedAt == null) {
      return const SizedBox.shrink();
    }

    final deadline = requestedAt.add(const Duration(hours: rescheduleExpiryHours));
    final left = deadline.difference(DateTime.now());

    late final String text;
    if (left.isNegative) {
      text = 'This request has expired — the original time stands.';
    } else if (left.inHours >= 1) {
      final h = left.inHours;
      text = actionRequired
          ? 'Respond within $h ${h == 1 ? 'hour' : 'hours'}, or the original time stands.'
          : 'Expires in $h ${h == 1 ? 'hour' : 'hours'} if they do not respond.';
    } else {
      final m = left.inMinutes.clamp(1, 59);
      text = actionRequired
          ? 'Respond within $m min, or the original time stands.'
          : 'Expires in $m min if they do not respond.';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: AppColors.textHint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

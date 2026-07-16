import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDate(DateTime date) {
    // e.g. 28 Jan 2026
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    // e.g. 10:30 AM
    return DateFormat('hh:mm a').format(date);
  }

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hr ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min ago';
    } else {
      return 'Just now';
    }
  }
}

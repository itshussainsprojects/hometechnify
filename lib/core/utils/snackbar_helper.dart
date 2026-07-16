
import 'package:flutter/material.dart';

class SnackBarHelper {
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.green, Icons.check_circle_outline);
  }

  static void showError(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.red, Icons.error_outline);
  }

  static void showWarning(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.orange, Icons.warning_amber_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.blue, Icons.info_outline);
  }

  static void _showSnackBar(BuildContext context, String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: color.withValues(alpha: 0.9), // Modern transparency
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

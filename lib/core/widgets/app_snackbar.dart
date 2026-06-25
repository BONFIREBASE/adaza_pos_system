import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum _SnackKind { success, error, info }

/// Minimalist, floating snackbars with a consistent look across the app.
///
/// Usage: `AppSnack.success(context, 'Saved.')`
abstract final class AppSnack {
  static void success(BuildContext context, String message) =>
      _show(context, message, _SnackKind.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _SnackKind.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, _SnackKind.info);

  static void _show(BuildContext context, String message, _SnackKind kind) {
    final (icon, accent) = switch (kind) {
      _SnackKind.success => (Icons.check_circle_rounded, AppColors.success),
      _SnackKind.error => (Icons.error_rounded, AppColors.error),
      _SnackKind.info => (Icons.info_rounded, AppColors.teal),
    };

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final wide = MediaQuery.sizeOf(context).width > 480;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        elevation: 6,
        duration: const Duration(seconds: 3),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        width: wide ? 360 : null,
        margin: wide ? null : const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

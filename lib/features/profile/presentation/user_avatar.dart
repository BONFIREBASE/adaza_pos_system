import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/domain/app_user.dart';

/// Circular avatar showing the user's photo (base64) or their initial.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 18});

  final AppUser user;
  final double radius;

  Color get _roleColor => switch (user.role) {
        UserRole.owner => AppColors.gold,
        UserRole.admin => AppColors.teal,
        UserRole.cashier => AppColors.copper,
      };

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(user.photo);
    final initial =
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: _roleColor.withValues(alpha: 0.18),
      backgroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null
          ? Text(initial,
              style: TextStyle(
                  color: _roleColor,
                  fontWeight: FontWeight.w700,
                  fontSize: radius * 0.8))
          : null,
    );
  }

  static Uint8List? _decode(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}

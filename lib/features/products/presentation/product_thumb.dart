import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Shows a product's photo from a base64 string, with a graceful icon fallback.
class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, required this.image, this.size = 44});

  final String? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(image);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder())
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.creamSurface,
        alignment: Alignment.center,
        child: Icon(Icons.inventory_2_outlined,
            color: AppColors.bronze, size: size * 0.5),
      );

  static Uint8List? _decode(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}

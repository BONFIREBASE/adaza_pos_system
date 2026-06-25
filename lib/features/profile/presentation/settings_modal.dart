import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Lightweight settings dialog. Business-level options live here; more will be
/// added as the system grows.
Future<void> showSettingsModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Settings'),
      content: const SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Info(label: 'Business', value: 'Adaza School & Office Supplies'),
            _Info(label: 'Currency', value: 'Philippine Peso (₱)'),
            _Info(label: 'Backend', value: 'Firebase / Firestore'),
            _Info(label: 'Version', value: '0.1.0'),
            SizedBox(height: 12),
            Text(
              'More settings (tax, receipt options, low-stock defaults) are '
              'coming soon.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

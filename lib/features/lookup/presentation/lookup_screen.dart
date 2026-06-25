import 'package:flutter/material.dart';

import '../../../core/widgets/app_nav_scaffold.dart';
import '../../../core/widgets/under_construction.dart';

/// Barcode lookup (Req 3). Temporarily under construction: camera scanning is
/// mobile-only and the desktop barcode/receipt machine integration is pending.
class LookupScreen extends StatelessWidget {
  const LookupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppNavScaffold(
      title: 'Lookup',
      currentRoute: '/lookup',
      body: UnderConstructionView(
        title: 'Barcode Lookup',
        message:
            'Mobile camera scanning and the connected barcode/receipt machine '
            'integration are still being built. Check back soon.',
      ),
    );
  }
}

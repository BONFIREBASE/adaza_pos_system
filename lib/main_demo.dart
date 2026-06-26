import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/config/env_config.dart';
import 'core/providers.dart';
import 'core/services/sync/in_memory_sync_service.dart';
import 'core/services/sync/sync_service.dart';
import 'features/auth/data/local_auth_repository.dart';

/// Demo entry point: runs entirely in memory with seeded data so the system
/// can be explored without any Firebase configuration. Auth uses the env-backed
/// local login (sign in with the password from `.env`).
///
/// Launch with:  flutter run -t lib/main_demo.dart -d edge
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await EnvConfig.load();

  final sync = InMemorySyncService();
  _seed(sync);

  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(LocalAuthRepository()),
        syncServiceProvider.overrideWithValue(sync),
      ],
      child: const AdazaApp(),
    ),
  );
}

void _seed(SyncService sync) {
  sync.setDocument('products', 'p1', {
    'name': 'Adaza House Blend Coffee',
    'barcode': '1000001',
    'price': 12.50,
    'cost': 6.00,
    'stockQuantity': 24,
    'lowStockThreshold': 5,
  });
  sync.setDocument('products', 'p2', {
    'name': 'Ceramic Mug',
    'barcode': '1000002',
    'price': 8.00,
    'cost': 3.50,
    'stockQuantity': 3,
    'lowStockThreshold': 5,
  });
  sync.setDocument('products', 'p3', {
    'name': 'Gift Box Set',
    'barcode': '1000003',
    'price': 25.00,
    'cost': 12.00,
    'stockQuantity': 10,
    'lowStockThreshold': 4,
  });
  sync.setDocument('finance', 'f1', {
    'type': 'expense',
    'amount': 40.0,
    'category': 'Supplies',
    'date': DateTime.now().toIso8601String(),
    'note': '',
    'saleId': null,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'data/database/local_database.dart';
import 'data/database/seed_data.dart';
import 'router/app_router.dart';
import 'state/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Hive and seed demo data on first run.
  final db = LocalDatabase();
  await db.init();
  await SeedData.seedIfNeeded(db);

  runApp(
    ProviderScope(
      overrides: [
        // Provide the already-initialised database instance to all providers.
        databaseProvider.overrideWithValue(db),
      ],
      child: const PharmaSoftApp(),
    ),
  );
}

class PharmaSoftApp extends StatelessWidget {
  const PharmaSoftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PharmaSoft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}

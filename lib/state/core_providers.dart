import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/local_database.dart';
import '../data/models/app_settings.dart';

/// Provides the initialised [LocalDatabase]. Overridden in `main()` with the
/// instance that has already run `init()` + seed, so every provider can read
/// it synchronously.
final databaseProvider = Provider<LocalDatabase>((ref) {
  throw StateError('databaseProvider must be overridden in main()');
});

/// Holds and persists app settings (pharmacy identity, currency, thresholds,
/// next invoice/purchase numbers).
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(databaseProvider).getSettings();

  Future<void> update(AppSettings settings) async {
    await ref.read(databaseProvider).saveSettings(settings);
    state = settings;
  }

  void reload() {
    state = ref.read(databaseProvider).getSettings();
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

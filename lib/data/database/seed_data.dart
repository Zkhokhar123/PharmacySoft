import '../models/category.dart';
import '../models/customer.dart';
import 'local_database.dart';

/// Seeds the database with essential initial setup only:
/// standard categories and a default Walk-in Customer for POS.
/// No dummy/fake medicines, batches, or sales are inserted.
class SeedData {
  SeedData._();

  static Future<void> seedIfNeeded(LocalDatabase db) async {
    if (db.isSeeded) return;

    // Categories ---------------------------------------------------------
    final categories = <Category>[
      Category(id: 'cat_tablets', name: 'Tablets', colorValue: 0xFF0D9488),
      Category(id: 'cat_capsules', name: 'Capsules', colorValue: 0xFF6366F1),
      Category(id: 'cat_syrups', name: 'Syrups', colorValue: 0xFFF59E0B),
      Category(id: 'cat_injections', name: 'Injections', colorValue: 0xFFEF4444),
      Category(id: 'cat_drops', name: 'Drops', colorValue: 0xFFEC4899),
      Category(id: 'cat_ointments', name: 'Ointments', colorValue: 0xFF10B981),
      Category(id: 'cat_suspensions', name: 'Suspensions', colorValue: 0xFF3B82F6),
      Category(id: 'cat_devices', name: 'Medical Devices', colorValue: 0xFF64748B),
    ];
    for (final c in categories) {
      await db.saveCategory(c);
    }

    // Default Walk-in customer for POS sales -----------------------------
    await db.saveCustomer(const Customer(
      id: Customer.walkInId,
      name: 'Walk-in Customer',
    ));

    await db.markSeeded();
  }
}

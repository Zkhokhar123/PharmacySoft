import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/batch.dart';
import '../data/models/medicine.dart';
import 'core_providers.dart';

enum StockStatus { inStock, lowStock, outOfStock }

/// A medicine combined with its batches and derived stock/expiry info.
class MedicineStockInfo {
  final Medicine medicine;
  final List<Batch> batches;
  final int totalStock;
  final double stockValue; // sum(qty * purchasePrice)
  final Batch? nearestExpiryBatch;
  final StockStatus status;

  const MedicineStockInfo({
    required this.medicine,
    required this.batches,
    required this.totalStock,
    required this.stockValue,
    required this.nearestExpiryBatch,
    required this.status,
  });

  bool get hasStock => totalStock > 0;
}

class MedicinesNotifier extends Notifier<List<Medicine>> {
  @override
  List<Medicine> build() => ref.read(databaseProvider).getMedicines();

  Future<void> add(Medicine medicine) async {
    await ref.read(databaseProvider).saveMedicine(medicine);
    state = [...state, medicine];
  }

  Future<void> update(Medicine medicine) async {
    await ref.read(databaseProvider).saveMedicine(medicine);
    state = state.map((e) => e.id == medicine.id ? medicine : e).toList();
  }

  Future<void> remove(String id) async {
    // also delete its batches
    final db = ref.read(databaseProvider);
    for (final b in db.batchesForMedicine(id)) {
      await db.deleteBatch(b.id);
    }
    await db.deleteMedicine(id);
    state = state.where((e) => e.id != id).toList();
    ref.read(batchesProvider.notifier).reload();
  }

  void reload() {
    state = ref.read(databaseProvider).getMedicines();
  }
}

final medicinesProvider =
    NotifierProvider<MedicinesNotifier, List<Medicine>>(MedicinesNotifier.new);

class BatchesNotifier extends Notifier<List<Batch>> {
  @override
  List<Batch> build() => ref.read(databaseProvider).getBatches();

  Future<void> add(Batch batch) async {
    await ref.read(databaseProvider).saveBatch(batch);
    state = [...state, batch];
  }

  Future<void> update(Batch batch) async {
    await ref.read(databaseProvider).saveBatch(batch);
    state = state.map((e) => e.id == batch.id ? batch : e).toList();
  }

  Future<void> remove(String id) async {
    await ref.read(databaseProvider).deleteBatch(id);
    state = state.where((e) => e.id != id).toList();
  }

  /// Decrements the given batch by [qty] (used at checkout / stock-in).
  Future<void> adjustQuantity(String batchId, int delta) async {
    final batch = state.firstWhere((b) => b.id == batchId);
    final updated = batch.copyWith(quantity: batch.quantity + delta);
    await ref.read(databaseProvider).saveBatch(updated);
    state = state.map((b) => b.id == batchId ? updated : b).toList();
  }

  /// Sets absolute quantity (used for stock audit / wastage adjustment).
  Future<void> setQuantity(String batchId, int newQuantity) async {
    final batch = state.firstWhere((b) => b.id == batchId);
    final updated = batch.copyWith(quantity: newQuantity < 0 ? 0 : newQuantity);
    await ref.read(databaseProvider).saveBatch(updated);
    state = state.map((b) => b.id == batchId ? updated : b).toList();
  }

  void reload() {
    state = ref.read(databaseProvider).getBatches();
  }
}

final batchesProvider =
    NotifierProvider<BatchesNotifier, List<Batch>>(BatchesNotifier.new);

/// Batches belonging to a specific medicine, sorted by expiry ascending.
final batchesForMedicineProvider =
    Provider.family<List<Batch>, String>((ref, medicineId) {
  final batches = ref.watch(batchesProvider)
      .where((b) => b.medicineId == medicineId)
      .toList()
    ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  return batches;
});

/// Computes [MedicineStockInfo] for every medicine. This drives the inventory
/// list, dashboard stat cards and low-stock / expiry alerts.
final medicineStockProvider = Provider<List<MedicineStockInfo>>((ref) {
  final medicines = ref.watch(medicinesProvider);
  final batches = ref.watch(batchesProvider);

  final result = <MedicineStockInfo>[];
  for (final med in medicines) {
    final medBatches = batches.where((b) => b.medicineId == med.id).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    final totalStock = medBatches.fold<int>(0, (s, b) => s + b.quantity);
    final stockValue = medBatches.fold<double>(
        0, (s, b) => s + b.quantity * b.purchasePrice);

    Batch? nearestExpiry;
    for (final b in medBatches) {
      if (b.quantity > 0) {
        nearestExpiry = b;
        break;
      }
    }
    // fall back to first batch if all are empty
    nearestExpiry ??= medBatches.isEmpty ? null : medBatches.first;

    final status = totalStock <= 0
        ? StockStatus.outOfStock
        : totalStock <= med.reorderLevel
            ? StockStatus.lowStock
            : StockStatus.inStock;

    result.add(MedicineStockInfo(
      medicine: med,
      batches: medBatches,
      totalStock: totalStock,
      stockValue: stockValue,
      nearestExpiryBatch: nearestExpiry,
      status: status,
    ));
  }
  // newest first
  result.sort((a, b) => b.medicine.createdAt.compareTo(a.medicine.createdAt));
  return result;
});

/// Medicines whose stock is at or below their reorder level.
final lowStockProvider = Provider<List<MedicineStockInfo>>((ref) {
  return ref
      .watch(medicineStockProvider)
      .where((s) => s.status != StockStatus.inStock)
      .toList();
});

/// Batches that are not yet expired but expire within the near-expiry window
/// (from settings). Sorted by expiry ascending.
final nearExpiryBatchesProvider = Provider<List<Batch>>((ref) {
  final days = ref.watch(settingsProvider).nearExpiryDays;
  final all = ref.watch(batchesProvider);
  final now = DateTime.now().millisecondsSinceEpoch;
  final cutoff = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
  return all
      .where((b) =>
          b.quantity > 0 &&
          b.expiryDate >= now &&
          b.expiryDate <= cutoff)
      .toList()
    ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
});

/// Already-expired batches still holding stock.
final expiredBatchesProvider = Provider<List<Batch>>((ref) {
  final all = ref.watch(batchesProvider);
  final now = DateTime.now().millisecondsSinceEpoch;
  return all
      .where((b) => b.quantity > 0 && b.expiryDate < now)
      .toList()
    ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
});

/// Total value of current stock (sum of qty * purchasePrice across batches).
final totalStockValueProvider = Provider<double>((ref) {
  return ref
      .watch(batchesProvider)
      .fold(0.0, (s, b) => s + b.quantity * b.purchasePrice);
});

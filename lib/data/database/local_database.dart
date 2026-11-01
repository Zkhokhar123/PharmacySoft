import 'dart:convert';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/app_constants.dart';
import '../models/app_settings.dart';
import '../models/batch.dart';
import '../models/category.dart';
import '../models/credit_payment.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/medicine.dart';
import '../models/purchase.dart';
import '../models/sale.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';

/// Local persistence layer backed by Hive CE. Stores each entity as a JSON
/// [Map] keyed by its id. A deep cast is applied on read because Hive returns
/// nested maps as `Map<dynamic, dynamic>`.
class LocalDatabase {
  late final Box _categories;
  late final Box _suppliers;
  late final Box _medicines;
  late final Box _batches;
  late final Box _customers;
  late final Box _sales;
  late final Box _purchases;
  late final Box _settings;
  late final Box _meta;
  late final Box _creditPayments;
  late final Box _supplierPayments;
  late final Box _expenses;

  /// Opens all boxes. Call once before the app starts.
  Future<void> init() async {
    await Hive.initFlutter();
    _categories = await Hive.openBox(AppConstants.categoriesBox);
    _suppliers = await Hive.openBox(AppConstants.suppliersBox);
    _medicines = await Hive.openBox(AppConstants.medicinesBox);
    _batches = await Hive.openBox(AppConstants.batchesBox);
    _customers = await Hive.openBox(AppConstants.customersBox);
    _sales = await Hive.openBox(AppConstants.salesBox);
    _purchases = await Hive.openBox(AppConstants.purchasesBox);
    _settings = await Hive.openBox(AppConstants.settingsBox);
    _meta = await Hive.openBox(AppConstants.metaBox);
    _creditPayments = await Hive.openBox(AppConstants.creditPaymentsBox);
    _supplierPayments = await Hive.openBox(AppConstants.supplierPaymentsBox);
    _expenses = await Hive.openBox(AppConstants.expensesBox);
  }

  // ---- meta / seed flag -------------------------------------------------

  bool get isSeeded => _meta.get('seeded', defaultValue: false) as bool;

  Future<void> markSeeded() => _meta.put('seeded', true);

  bool get isCleanProductionReady =>
      _meta.get('clean_v1', defaultValue: false) as bool;

  Future<void> markCleanProductionReady() => _meta.put('clean_v1', true);

  // ---- settings ---------------------------------------------------------

  AppSettings getSettings() {
    final raw = _settings.get('app');
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(_cast(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) =>
      _settings.put('app', settings.toJson());

  // ---- categories -------------------------------------------------------

  List<Category> getCategories() => _readAll(_categories, Category.fromJson);

  Future<void> saveCategory(Category c) => _categories.put(c.id, c.toJson());

  Future<void> deleteCategory(String id) => _categories.delete(id);

  // ---- suppliers --------------------------------------------------------

  List<Supplier> getSuppliers() => _readAll(_suppliers, Supplier.fromJson);

  Future<void> saveSupplier(Supplier s) => _suppliers.put(s.id, s.toJson());

  Future<void> deleteSupplier(String id) => _suppliers.delete(id);

  // ---- customers -------------------------------------------------------

  List<Customer> getCustomers() => _readAll(_customers, Customer.fromJson);

  Future<void> saveCustomer(Customer c) => _customers.put(c.id, c.toJson());

  Future<void> deleteCustomer(String id) => _customers.delete(id);

  // ---- medicines --------------------------------------------------------

  List<Medicine> getMedicines() => _readAll(_medicines, Medicine.fromJson);

  Medicine? getMedicine(String id) {
    final raw = _medicines.get(id);
    if (raw == null) return null;
    return Medicine.fromJson(_cast(raw) as Map<String, dynamic>);
  }

  Future<void> saveMedicine(Medicine m) => _medicines.put(m.id, m.toJson());

  Future<void> deleteMedicine(String id) => _medicines.delete(id);

  Medicine? findByBarcode(String barcode) {
    if (barcode.trim().isEmpty) return null;
    for (final raw in _medicines.values) {
      final m = Medicine.fromJson(_cast(raw) as Map<String, dynamic>);
      if (m.barcode == barcode.trim()) return m;
    }
    return null;
  }

  // ---- batches ---------------------------------------------------------

  List<Batch> getBatches() => _readAll(_batches, Batch.fromJson);

  List<Batch> batchesForMedicine(String medicineId) =>
      getBatches().where((b) => b.medicineId == medicineId).toList();

  Batch? getBatch(String id) {
    final raw = _batches.get(id);
    if (raw == null) return null;
    return Batch.fromJson(_cast(raw) as Map<String, dynamic>);
  }

  Future<void> saveBatch(Batch b) => _batches.put(b.id, b.toJson());

  Future<void> deleteBatch(String id) => _batches.delete(id);

  // ---- sales -----------------------------------------------------------

  List<Sale> getSales() {
    final sales = _readAll(_sales, Sale.fromJson);
    sales.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return sales;
  }

  Sale? getSale(String id) {
    final raw = _sales.get(id);
    if (raw == null) return null;
    return Sale.fromJson(_cast(raw) as Map<String, dynamic>);
  }

  Future<void> saveSale(Sale s) => _sales.put(s.id, s.toJson());

  Future<void> deleteSale(String id) => _sales.delete(id);

  // ---- purchases --------------------------------------------------------

  List<Purchase> getPurchases() {
    final purchases = _readAll(_purchases, Purchase.fromJson);
    purchases.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return purchases;
  }

  Future<void> savePurchase(Purchase p) => _purchases.put(p.id, p.toJson());

  Future<void> deletePurchase(String id) => _purchases.delete(id);

  // ---- credit payments -------------------------------------------------

  List<CreditPayment> getCreditPayments() {
    final list = _readAll(_creditPayments, CreditPayment.fromJson);
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  List<CreditPayment> creditPaymentsForCustomer(String customerId) =>
      getCreditPayments()
          .where((p) => p.customerId == customerId)
          .toList();

  Future<void> saveCreditPayment(CreditPayment p) =>
      _creditPayments.put(p.id, p.toJson());

  Future<void> deleteCreditPayment(String id) =>
      _creditPayments.delete(id);

  // ---- expenses --------------------------------------------------------

  List<Expense> getExpenses() {
    final list = _readAll(_expenses, Expense.fromJson);
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  Future<void> saveExpense(Expense e) => _expenses.put(e.id, e.toJson());

  Future<void> deleteExpense(String id) => _expenses.delete(id);

  // ---- supplier payments ------------------------------------------------

  List<SupplierPayment> getSupplierPayments() {
    final list = _readAll(_supplierPayments, SupplierPayment.fromJson);
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  List<SupplierPayment> supplierPaymentsForSupplier(String supplierId) =>
      getSupplierPayments()
          .where((p) => p.supplierId == supplierId)
          .toList();

  Future<void> saveSupplierPayment(SupplierPayment p) =>
      _supplierPayments.put(p.id, p.toJson());

  Future<void> deleteSupplierPayment(String id) =>
      _supplierPayments.delete(id);

  // ---- backup & restore ------------------------------------------------

  String exportBackupJson() {
    final data = {
      'version': AppConstants.appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': _settings.toMap(),
      'categories': _categories.toMap(),
      'suppliers': _suppliers.toMap(),
      'customers': _customers.toMap(),
      'medicines': _medicines.toMap(),
      'batches': _batches.toMap(),
      'sales': _sales.toMap(),
      'purchases': _purchases.toMap(),
      'creditPayments': _creditPayments.toMap(),
      'supplierPayments': _supplierPayments.toMap(),
      'expenses': _expenses.toMap(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> restoreBackupJson(String jsonStr) async {
    final Map<String, dynamic> data =
        jsonDecode(jsonStr) as Map<String, dynamic>;

    Future<void> restoreBox(Box box, dynamic boxData) async {
      if (boxData is Map) {
        await box.clear();
        for (final entry in boxData.entries) {
          await box.put(entry.key, entry.value);
        }
      }
    }

    if (data.containsKey('settings')) {
      await restoreBox(_settings, data['settings']);
    }
    if (data.containsKey('categories')) {
      await restoreBox(_categories, data['categories']);
    }
    if (data.containsKey('suppliers')) {
      await restoreBox(_suppliers, data['suppliers']);
    }
    if (data.containsKey('customers')) {
      await restoreBox(_customers, data['customers']);
    }
    if (data.containsKey('medicines')) {
      await restoreBox(_medicines, data['medicines']);
    }
    if (data.containsKey('batches')) {
      await restoreBox(_batches, data['batches']);
    }
    if (data.containsKey('sales')) {
      await restoreBox(_sales, data['sales']);
    }
    if (data.containsKey('purchases')) {
      await restoreBox(_purchases, data['purchases']);
    }
    if (data.containsKey('creditPayments')) {
      await restoreBox(_creditPayments, data['creditPayments']);
    }
    if (data.containsKey('supplierPayments')) {
      await restoreBox(_supplierPayments, data['supplierPayments']);
    }
    if (data.containsKey('expenses')) {
      await restoreBox(_expenses, data['expenses']);
    }
  }

  /// Clears all demo / transactional data: medicines, batches, sales, purchases,
  /// credit payments, expenses, suppliers, customers (except Walk-in).
  /// Resets invoice / purchase sequence counters to 1.
  Future<void> clearAllData({bool keepCategories = true}) async {
    await _medicines.clear();
    await _batches.clear();
    await _sales.clear();
    await _purchases.clear();
    await _creditPayments.clear();
    await _supplierPayments.clear();
    await _expenses.clear();
    await _suppliers.clear();
    await _customers.clear();

    if (!keepCategories) {
      await _categories.clear();
    }

    // Always preserve Walk-in Customer (needed for POS)
    await saveCustomer(const Customer(
      id: Customer.walkInId,
      name: 'Walk-in Customer',
    ));

    // Reset sequence numbers in settings
    final current = getSettings();
    await saveSettings(current.copyWith(
      nextInvoiceNumber: 1,
      nextPurchaseNumber: 1,
    ));

    await markSeeded();
  }

  // ---- helpers ---------------------------------------------------------

  List<T> _readAll<T>(Box box, T Function(Map<String, dynamic>) fromJson) {
    return box.values
        .map((raw) => fromJson(_cast(raw) as Map<String, dynamic>))
        .toList();
  }

  /// Recursively converts Hive's `Map<dynamic, dynamic>` / `List<dynamic>`
  /// into strongly typed `Map<String, dynamic>` / `List` so the model
  /// `fromJson` casts never throw.
  static dynamic _cast(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _cast(val)));
    }
    if (v is List) {
      return v.map(_cast).toList();
    }
    return v;
  }
}

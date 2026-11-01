import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/category.dart';
import '../data/models/customer.dart';
import '../data/models/supplier.dart';
import 'core_providers.dart';

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

class CategoriesNotifier extends Notifier<List<Category>> {
  @override
  List<Category> build() => ref.read(databaseProvider).getCategories();

  Future<void> add(Category category) async {
    await ref.read(databaseProvider).saveCategory(category);
    state = [...state, category];
  }

  Future<void> update(Category category) async {
    await ref.read(databaseProvider).saveCategory(category);
    state = state.map((e) => e.id == category.id ? category : e).toList();
  }

  Future<void> remove(String id) async {
    await ref.read(databaseProvider).deleteCategory(id);
    state = state.where((e) => e.id != id).toList();
  }

  void reload() {
    state = ref.read(databaseProvider).getCategories();
  }
}

final categoriesProvider =
    NotifierProvider<CategoriesNotifier, List<Category>>(CategoriesNotifier.new);

/// Quick lookup of category id -> [Category].
final categoryMapProvider = Provider<Map<String, Category>>((ref) {
  final list = ref.watch(categoriesProvider);
  return {for (final c in list) c.id: c};
});

// ---------------------------------------------------------------------------
// Suppliers
// ---------------------------------------------------------------------------

class SuppliersNotifier extends Notifier<List<Supplier>> {
  @override
  List<Supplier> build() => ref.read(databaseProvider).getSuppliers();

  Future<void> add(Supplier supplier) async {
    await ref.read(databaseProvider).saveSupplier(supplier);
    state = [...state, supplier];
  }

  Future<void> update(Supplier supplier) async {
    await ref.read(databaseProvider).saveSupplier(supplier);
    state = state.map((e) => e.id == supplier.id ? supplier : e).toList();
  }

  Future<void> remove(String id) async {
    await ref.read(databaseProvider).deleteSupplier(id);
    state = state.where((e) => e.id != id).toList();
  }

  void reload() {
    state = ref.read(databaseProvider).getSuppliers();
  }
}

final suppliersProvider =
    NotifierProvider<SuppliersNotifier, List<Supplier>>(SuppliersNotifier.new);

final supplierMapProvider = Provider<Map<String, Supplier>>((ref) {
  final list = ref.watch(suppliersProvider);
  return {for (final s in list) s.id: s};
});

// ---------------------------------------------------------------------------
// Customers
// ---------------------------------------------------------------------------

class CustomersNotifier extends Notifier<List<Customer>> {
  @override
  List<Customer> build() => ref.read(databaseProvider).getCustomers();

  Future<void> add(Customer customer) async {
    await ref.read(databaseProvider).saveCustomer(customer);
    state = [...state, customer];
  }

  Future<void> update(Customer customer) async {
    await ref.read(databaseProvider).saveCustomer(customer);
    state = state.map((e) => e.id == customer.id ? customer : e).toList();
  }

  Future<void> remove(String id) async {
    await ref.read(databaseProvider).deleteCustomer(id);
    state = state.where((e) => e.id != id).toList();
  }

  void reload() {
    state = ref.read(databaseProvider).getCustomers();
  }
}

final customersProvider =
    NotifierProvider<CustomersNotifier, List<Customer>>(CustomersNotifier.new);

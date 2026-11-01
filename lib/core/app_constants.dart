/// Application-wide constants: Hive box names, defaults and thresholds.
class AppConstants {
  AppConstants._();

  // Hive box names
  static const metaBox = 'meta';
  static const settingsBox = 'settings';
  static const categoriesBox = 'categories';
  static const suppliersBox = 'suppliers';
  static const medicinesBox = 'medicines';
  static const batchesBox = 'batches';
  static const customersBox = 'customers';
  static const salesBox = 'sales';
  static const purchasesBox = 'purchases';
  static const creditPaymentsBox = 'credit_payments';
  static const supplierPaymentsBox = 'supplier_payments';
  static const expensesBox = 'expenses';

  // Defaults
  static const defaultCurrencySymbol = 'Rs';
  static const defaultLowStockThreshold = 10;
  static const defaultNearExpiryDays = 90;

  // Default pharmacy identity (used on invoices)
  static const defaultPharmacyName = 'PharmaSoft';
  static const defaultPharmacyAddress = '';
  static const defaultPharmacyPhone = '';

  static const appVersion = '1.0.0';
}

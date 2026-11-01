import '../../core/app_constants.dart';

/// App-wide settings: pharmacy identity (printed on invoices), currency and
/// stock/expiry thresholds. Stored in a single-record box keyed by 'app'.
class AppSettings {
  final String pharmacyName;
  final String address;
  final String phone;
  final String currencySymbol;
  final int lowStockThreshold;
  final int nearExpiryDays;
  final int nextInvoiceNumber;
  final int nextPurchaseNumber;

  const AppSettings({
    this.pharmacyName = AppConstants.defaultPharmacyName,
    this.address = AppConstants.defaultPharmacyAddress,
    this.phone = AppConstants.defaultPharmacyPhone,
    this.currencySymbol = AppConstants.defaultCurrencySymbol,
    this.lowStockThreshold = AppConstants.defaultLowStockThreshold,
    this.nearExpiryDays = AppConstants.defaultNearExpiryDays,
    this.nextInvoiceNumber = 1,
    this.nextPurchaseNumber = 1,
  });

  AppSettings copyWith({
    String? pharmacyName,
    String? address,
    String? phone,
    String? currencySymbol,
    int? lowStockThreshold,
    int? nearExpiryDays,
    int? nextInvoiceNumber,
    int? nextPurchaseNumber,
  }) =>
      AppSettings(
        pharmacyName: pharmacyName ?? this.pharmacyName,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        nearExpiryDays: nearExpiryDays ?? this.nearExpiryDays,
        nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
        nextPurchaseNumber: nextPurchaseNumber ?? this.nextPurchaseNumber,
      );

  Map<String, dynamic> toJson() => {
        'pharmacyName': pharmacyName,
        'address': address,
        'phone': phone,
        'currencySymbol': currencySymbol,
        'lowStockThreshold': lowStockThreshold,
        'nearExpiryDays': nearExpiryDays,
        'nextInvoiceNumber': nextInvoiceNumber,
        'nextPurchaseNumber': nextPurchaseNumber,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        pharmacyName: (json['pharmacyName'] as String?) ??
            AppConstants.defaultPharmacyName,
        address: (json['address'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        currencySymbol: (json['currencySymbol'] as String?) ??
            AppConstants.defaultCurrencySymbol,
        lowStockThreshold:
            (json['lowStockThreshold'] as int?) ?? AppConstants.defaultLowStockThreshold,
        nearExpiryDays:
            (json['nearExpiryDays'] as int?) ?? AppConstants.defaultNearExpiryDays,
        nextInvoiceNumber: (json['nextInvoiceNumber'] as int?) ?? 1,
        nextPurchaseNumber: (json['nextPurchaseNumber'] as int?) ?? 1,
      );
}

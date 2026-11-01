import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../data/models/app_settings.dart';
import '../../shared/widgets/app_card.dart';
import '../../state/core_providers.dart';
import '../../state/dashboard_providers.dart';
import '../../state/expenses_providers.dart';
import '../../state/inventory_providers.dart';
import '../../state/sales_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(settingsProvider).currencySymbol;
    final stats = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Available Reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ReportCard(
                  title: 'Sales Summary',
                  subtitle: 'All invoices with totals',
                  icon: Icons.receipt_long,
                  color: AppColors.accent,
                  onGenerate: () => _generateSalesReport(ref, settings, symbol),
                ),
                _ReportCard(
                  title: 'Stock Report',
                  subtitle: 'Current inventory with batch details',
                  icon: Icons.inventory_2,
                  color: AppColors.primary,
                  onGenerate: () => _generateStockReport(ref, settings, symbol),
                ),
                _ReportCard(
                  title: 'Expiry Report',
                  subtitle: 'Near-expiry and expired batches',
                  icon: Icons.event_busy,
                  color: AppColors.nearExpiry,
                  onGenerate: () => _generateExpiryReport(ref, settings, symbol),
                ),
                _ReportCard(
                  title: 'Low Stock Report',
                  subtitle: 'Items at or below reorder level',
                  icon: Icons.warning_amber,
                  color: AppColors.lowStock,
                  onGenerate: () => _generateLowStockReport(ref, settings, symbol),
                ),
                _ReportCard(
                  title: 'Profit & Loss (P&L)',
                  subtitle: 'Revenue, COGS, Gross & Net Profit',
                  icon: Icons.analytics_outlined,
                  color: Colors.purple,
                  onGenerate: () => _generateProfitLossReport(ref, settings, symbol),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Quick stats summary
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Summary',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const Divider(height: 18),
                  Wrap(
                    spacing: 32,
                    runSpacing: 12,
                    children: [
                      _StatLine('Total Products', '${stats.totalMedicines}'),
                      _StatLine('Stock Value',
                          Formatters.currency(stats.stockValue, symbol: symbol)),
                      _StatLine('Total Sales', '${stats.totalSales} invoices'),
                      _StatLine('Total Revenue',
                          Formatters.currency(stats.totalRevenue, symbol: symbol)),
                      _StatLine('Low/Out of Stock', '${stats.lowStockCount}'),
                      _StatLine('Expiring Soon', '${stats.nearExpiryCount}'),
                      _StatLine('Already Expired', '${stats.expiredCount}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateSalesReport(WidgetRef ref, AppSettings settings, String symbol) async {
    final sales = ref.read(salesProvider);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
            level: 0,
            child: pw.Text('${settings.pharmacyName} — Sales Report',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Text('Generated: ${Formatters.dateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Invoice', 'Date', 'Customer', 'Items', 'Total', 'Payment'],
          data: sales
              .map((s) => [
                    s.invoiceNumber,
                    Formatters.date(s.dateTimeValue),
                    s.customerName,
                    '${s.itemCount}',
                    Formatters.currency(s.total, symbol: symbol),
                    s.paymentMethod,
                  ])
              .toList(),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.teal100),
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Grand Total: ${Formatters.currency(sales.fold(0.0, (s, sale) => s + sale.total), symbol: symbol)}',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _generateStockReport(WidgetRef ref, AppSettings settings, String symbol) async {
    final stock = ref.read(medicineStockProvider);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
            level: 0,
            child: pw.Text('${settings.pharmacyName} — Stock Report',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Text('Generated: ${Formatters.dateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: [
            'Medicine', 'Unit', 'Stock', 'Status', 'Sale Price', 'Value'
          ],
          data: stock
              .map((s) => [
                    s.medicine.name,
                    s.medicine.unit,
                    '${s.totalStock}',
                    s.status.name,
                    Formatters.currency(s.medicine.salePrice, symbol: symbol),
                    Formatters.currency(s.stockValue, symbol: symbol),
                  ])
              .toList(),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.teal100),
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Total Stock Value: ${Formatters.currency(stock.fold(0.0, (s, i) => s + i.stockValue), symbol: symbol)}',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _generateExpiryReport(WidgetRef ref, AppSettings settings, String symbol) async {
    final nearExpiry = ref.read(nearExpiryBatchesProvider);
    final expired = ref.read(expiredBatchesProvider);
    final medicines = ref.read(medicinesProvider);
    final medMap = {for (final m in medicines) m.id: m.name};
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
            level: 0,
            child: pw.Text('${settings.pharmacyName} — Expiry Report',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Text('Generated: ${Formatters.dateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 10),
        pw.Header(level: 1, child: pw.Text('Expired Batches (${expired.length})')),
        if (expired.isEmpty)
          pw.Text('No expired batches with stock.')
        else
          pw.TableHelper.fromTextArray(
            headers: ['Medicine', 'Batch', 'Qty', 'Expiry Date'],
            data: expired
                .map((b) => [
                      medMap[b.medicineId] ?? '-',
                      b.batchNumber,
                      '${b.quantity}',
                      Formatters.date(b.expiryDateTime),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.red100),
          ),
        pw.SizedBox(height: 10),
        pw.Header(
            level: 1,
            child: pw.Text('Near-Expiry Batches (${nearExpiry.length})')),
        if (nearExpiry.isEmpty)
          pw.Text('No near-expiry batches.')
        else
          pw.TableHelper.fromTextArray(
            headers: ['Medicine', 'Batch', 'Qty', 'Expiry Date', 'Days Left'],
            data: nearExpiry
                .map((b) => [
                      medMap[b.medicineId] ?? '-',
                      b.batchNumber,
                      '${b.quantity}',
                      Formatters.date(b.expiryDateTime),
                      '${Formatters.daysUntil(b.expiryDateTime)}',
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.orange100),
          ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _generateLowStockReport(WidgetRef ref, AppSettings settings, String symbol) async {
    final lowStock = ref.read(lowStockProvider);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
            level: 0,
            child: pw.Text('${settings.pharmacyName} — Low Stock Report',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Text('Generated: ${Formatters.dateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 10),
        if (lowStock.isEmpty)
          pw.Text('All products are sufficiently stocked.')
        else
          pw.TableHelper.fromTextArray(
            headers: [
              'Medicine', 'Unit', 'Stock', 'Reorder Level', 'Status'
            ],
            data: lowStock
                .map((s) => [
                      s.medicine.name,
                      s.medicine.unit,
                      '${s.totalStock}',
                      '${s.medicine.reorderLevel}',
                      s.status.name,
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.amber100),
          ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _generateProfitLossReport(
      WidgetRef ref, AppSettings settings, String symbol) async {
    final sales = ref.read(salesProvider).where((s) => !s.isReturned).toList();
    final expenses = ref.read(expensesProvider);

    final totalRevenue = sales.fold(0.0, (sum, s) => sum + s.total);
    final totalCost = sales.fold(0.0, (sum, s) => sum + s.totalCost);
    final grossProfit = totalRevenue - totalCost;
    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final netProfit = grossProfit - totalExpenses;

    final expByCategory = <String, double>{};
    for (final e in expenses) {
      expByCategory[e.category] = (expByCategory[e.category] ?? 0.0) + e.amount;
    }

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text('${settings.pharmacyName} — Profit & Loss Statement',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Text('Generated: ${Formatters.dateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 16),

        pw.Text('1. Revenue & Cost of Goods Sold',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Metric', 'Amount'],
          data: [
            ['Total Sales Revenue (${sales.length} invoices)', Formatters.currency(totalRevenue, symbol: symbol)],
            ['Cost of Goods Sold (COGS)', Formatters.currency(totalCost, symbol: symbol)],
            ['Gross Profit', Formatters.currency(grossProfit, symbol: symbol)],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
        ),
        pw.SizedBox(height: 16),

        pw.Text('2. Operating Expenses Breakdown',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Category', 'Total Spent'],
          data: expByCategory.isEmpty
              ? [
                  ['No operating expenses recorded', Formatters.currency(0, symbol: symbol)]
                ]
              : expByCategory.entries
                  .map((entry) => [entry.key, Formatters.currency(entry.value, symbol: symbol)])
                  .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange100),
        ),
        pw.SizedBox(height: 16),

        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            color: netProfit >= 0 ? PdfColors.green50 : PdfColors.red50,
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('NET PROFIT / (LOSS):',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                      color: netProfit >= 0 ? PdfColors.green900 : PdfColors.red900)),
              pw.Text(Formatters.currency(netProfit, symbol: symbol),
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                      color: netProfit >= 0 ? PdfColors.green900 : PdfColors.red900)),
            ],
          ),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onGenerate;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: AppCard(
        onTap: onGenerate,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            Row(children: [
              Text('Generate PDF',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward, size: 14, color: color),
            ]),
          ],
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }
}

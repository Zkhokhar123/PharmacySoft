import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/sale.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../state/core_providers.dart';
import '../../state/credit_providers.dart';
import '../../state/sales_providers.dart';
import 'thermal_receipt.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  final String saleId;
  final bool autoPrint;
  const InvoiceScreen({super.key, required this.saleId, this.autoPrint = false});

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  bool _autoPrinted = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoPrint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoPrinted) return;
        _autoPrinted = true;
        final sales = ref.read(salesProvider);
        final sale =
            sales.where((s) => s.id == widget.saleId).firstOrNull;
        final settings = ref.read(settingsProvider);
        if (sale != null) {
          ThermalReceipt.printReceipt(sale, settings);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sales = ref.watch(salesProvider);
    final sale = sales.where((s) => s.id == widget.saleId).firstOrNull;
    final settings = ref.watch(settingsProvider);
    final symbol = settings.currencySymbol;

    // Dynamic credit info
    final outstandingMap = ref.watch(outstandingMapProvider);
    final customerBalance = sale != null
        ? (outstandingMap[sale.customerId] ?? 0.0)
        : 0.0;
    final hasOutstanding   = customerBalance > 0.005;
    final isWalkIn         = sale?.customerId == 'walk_in';

    if (sale == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const Center(child: Text('Invoice not found')),
      );
    }

    final creditOnThisSale = sale.total - sale.paid;
    final hasCreditOnSale  = creditOnThisSale > 0.005;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Invoice ${sale.invoiceNumber}'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        leading: BackButton(onPressed: () => context.go('/sales')),
        actions: [
          // ── Receive Payment button (only for credit sales with named customer)
          if (hasCreditOnSale && !isWalkIn)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                icon: const Icon(Icons.payments_outlined,
                    color: AppColors.nearExpiry),
                label: Text(
                  'Receive Payment (${Formatters.currency(customerBalance, symbol: symbol)} due)',
                  style: const TextStyle(color: AppColors.nearExpiry),
                ),
                onPressed: () => _showReceivePayment(
                    context, ref, sale, customerBalance, symbol),
              ),
            ),
          if (!sale.isReturned)
            TextButton.icon(
              icon: const Icon(Icons.assignment_return_outlined,
                  color: AppColors.outOfStock),
              label: const Text('Return / Refund',
                  style: TextStyle(color: AppColors.outOfStock)),
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Return Invoice',
                  message:
                      'Return invoice ${sale.invoiceNumber}? All sold items will be returned and stock will be restored back to inventory.',
                  confirmText: 'Return & Restock',
                  isDestructive: true,
                );
                if (ok) {
                  await ref.read(salesProvider.notifier).returnSale(sale.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Invoice marked returned and stock restored.')),
                    );
                  }
                }
              },
            ),
          ElevatedButton.icon(
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('Print Thermal Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => ThermalReceipt.printReceipt(sale, settings),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: 'More Print Options',
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (val) {
              if (val == '58mm') {
                ThermalReceipt.printReceipt(sale, settings, is58mm: true);
              } else if (val == 'a4') {
                _print(sale, settings);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: '58mm',
                child: Row(
                  children: [
                    Icon(Icons.receipt, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Thermal Print (58mm / 2-inch)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'a4',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf,
                        size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('A4 Full Page Print'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // ── Returned banner ──────────────────────────────────────
                if (sale.isReturned)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.outOfStock.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.outOfStock.withValues(alpha: 0.5)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.assignment_return,
                          color: AppColors.outOfStock, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'THIS INVOICE HAS BEEN RETURNED & REFUNDED (Stock Restored)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.outOfStock,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ]),
                  ),
                // ── Credit alert banner ──────────────────────────────────
                if (hasCreditOnSale)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.nearExpiry.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.nearExpiry.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          color: AppColors.nearExpiry, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Credit Sale — ${Formatters.currency(creditOnThisSale, symbol: symbol)} unpaid',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.nearExpiry),
                            ),
                            if (!isWalkIn)
                              Text(
                                '${sale.customerName} owes a total of '
                                '${Formatters.currency(customerBalance, symbol: symbol)}',
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.textMuted),
                              ),
                            if (!isWalkIn)
                              TextButton.icon(
                                icon: const Icon(Icons.open_in_new, size: 14),
                                label: const Text('View Customer Ledger'),
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    foregroundColor: AppColors.nearExpiry),
                                onPressed: () => context.go(
                                    '/customers/ledger/${sale.customerId}'),
                              ),
                          ],
                        ),
                      ),
                    ]),
                  ),

                // ── Invoice card ─────────────────────────────────────────
                AppCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── header ─────────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.local_pharmacy,
                              color: AppColors.primary, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(settings.pharmacyName,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary)),
                                if (settings.address.isNotEmpty)
                                  Text(settings.address,
                                      style: const TextStyle(
                                          color: AppColors.textMuted)),
                                if (settings.phone.isNotEmpty)
                                  Text('Tel: ${settings.phone}',
                                      style: const TextStyle(
                                          color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(sale.invoiceNumber,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                              Text(Formatters.dateTime(sale.dateTimeValue),
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                              if (hasCreditOnSale)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.nearExpiry
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('CREDIT',
                                      style: TextStyle(
                                          color: AppColors.nearExpiry,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11)),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 28),

                      // ── customer ────────────────────────────────────────
                      Row(children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        const Text('Bill To:',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(sale.customerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        if (hasOutstanding && !isWalkIn) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.nearExpiry
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Total due: ${Formatters.currency(customerBalance, symbol: symbol)}',
                              style: const TextStyle(
                                  color: AppColors.nearExpiry,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 18),

                      // ── items table header ──────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(children: [
                          Expanded(flex: 5, child: _TH('Medicine')),
                          Expanded(flex: 2, child: _TH('Batch')),
                          SizedBox(width: 56, child: _TH('Qty', right: true)),
                          SizedBox(width: 90, child: _TH('Price', right: true)),
                          SizedBox(width: 100, child: _TH('Total', right: true)),
                        ]),
                      ),

                      // ── items rows ──────────────────────────────────────
                      ...sale.items.asMap().entries.map((e) {
                        final i    = e.key;
                        final item = e.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          color: i.isEven
                              ? AppColors.background
                              : AppColors.surface,
                          child: Row(children: [
                            Expanded(
                                flex: 5,
                                child: Text(item.medicineName)),
                            Expanded(
                                flex: 2,
                                child: Text(item.batchNumber,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted))),
                            SizedBox(
                              width: 120,
                              child: Text(
                                '${item.quantity} ${item.unit}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                Formatters.currency(item.unitPrice,
                                    symbol: symbol),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(
                                Formatters.currency(item.lineTotal,
                                    symbol: symbol),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                        );
                      }),

                      const Divider(height: 20),

                      // ── totals ──────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 300,
                            child: Column(children: [
                              _TotalRow('Subtotal',
                                  Formatters.currency(sale.subtotal,
                                      symbol: symbol)),
                              if (sale.discount > 0)
                                _TotalRow(
                                    'Discount',
                                    '- ${Formatters.currency(sale.discount, symbol: symbol)}'),
                              if (sale.taxAmount > 0)
                                _TotalRow(
                                    'Tax (${sale.taxRate.toStringAsFixed(0)}%)',
                                    Formatters.currency(sale.taxAmount,
                                        symbol: symbol)),
                              const Divider(height: 10),
                              _TotalRow(
                                'TOTAL',
                                Formatters.currency(sale.total, symbol: symbol),
                                bold: true,
                              ),
                              _TotalRow('Paid (${sale.paymentMethod})',
                                  Formatters.currency(sale.paid, symbol: symbol),
                                  color: AppColors.inStock),
                              if (sale.balance > 0.005)
                                _TotalRow(
                                  'Balance Due',
                                  Formatters.currency(sale.balance,
                                      symbol: symbol),
                                  bold: true,
                                  color: AppColors.outOfStock,
                                )
                              else if (sale.balance < -0.005)
                                _TotalRow(
                                  'Change',
                                  Formatters.currency(sale.balance.abs(),
                                      symbol: symbol),
                                  color: AppColors.inStock,
                                ),
                            ]),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── footer ──────────────────────────────────────────
                      if (sale.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            const Icon(Icons.notes,
                                size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Flexible(
                                child: Text(sale.notes,
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 13))),
                          ]),
                        ),
                      const Center(
                        child: Text('Thank you for your business!',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Receive payment from invoice screen ─────────────────────────────────────

  void _showReceivePayment(BuildContext context, WidgetRef ref, Sale sale,
      double customerBalance, String symbol) {
    showDialog(
      context: context,
      builder: (ctx) => _QuickPaymentDialog(
        customerId: sale.customerId,
        customerName: sale.customerName,
        invoiceNumber: sale.invoiceNumber,
        saleBalance: sale.balance,
        customerBalance: customerBalance,
        symbol: symbol,
      ),
    );
  }

  // ── PDF print ────────────────────────────────────────────────────────────────

  Future<void> _print(Sale sale, AppSettings settings) async {
    final sym = settings.currencySymbol;
    final doc = pw.Document();
    final creditOnSale = sale.total - sale.paid;
    final hasCreditOnSale = creditOnSale > 0.005;

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            // ── Header ───────────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(settings.pharmacyName,
                        style: pw.TextStyle(
                            fontSize: 22, fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF0D9488))),
                    if (settings.address.isNotEmpty)
                      pw.Text(settings.address,
                          style: const pw.TextStyle(fontSize: 10)),
                    if (settings.phone.isNotEmpty)
                      pw.Text('Tel: ${settings.phone}',
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(sale.invoiceNumber,
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text(Formatters.dateTime(sale.dateTimeValue),
                        style: const pw.TextStyle(fontSize: 10,
                            color: PdfColors.grey600)),
                    if (hasCreditOnSale)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFFFF0E0)),
                        child: pw.Text('CREDIT SALE',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFFF97316))),
                      ),
                  ],
                ),
              ],
            ),
            pw.Divider(color: const PdfColor.fromInt(0xFF0D9488)),
            pw.SizedBox(height: 6),

            // ── Bill To ──────────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.RichText(text: pw.TextSpan(children: [
                  const pw.TextSpan(
                      text: 'Bill To: ',
                      style: pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey600)),
                  pw.TextSpan(
                      text: sale.customerName,
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  const pw.TextSpan(
                      text: 'Payment: ',
                      style: pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey600)),
                  pw.TextSpan(
                      text: sale.paymentMethod,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ])),
              ],
            ),
            pw.SizedBox(height: 12),

            // ── Items table ──────────────────────────────────────────────
            pw.TableHelper.fromTextArray(
              headers: ['Medicine', 'Batch', 'Qty', 'Unit Price', 'Total'],
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0D9488)),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF5F5F5)),
              data: sale.items.map((item) => [
                item.medicineName,
                item.batchNumber,
                '${item.quantity} ${item.unit}',
                Formatters.currency(item.unitPrice, symbol: sym),
                Formatters.currency(item.lineTotal, symbol: sym),
              ]).toList(),
            ),
            pw.SizedBox(height: 10),

            // ── Totals ───────────────────────────────────────────────────
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 230,
                child: pw.Column(
                  children: [
                    _pdfRow('Subtotal',
                        Formatters.currency(sale.subtotal, symbol: sym)),
                    if (sale.discount > 0)
                      _pdfRow('Discount',
                          '- ${Formatters.currency(sale.discount, symbol: sym)}'),
                    if (sale.taxAmount > 0)
                      _pdfRow(
                          'Tax (${sale.taxRate.toStringAsFixed(0)}%)',
                          Formatters.currency(sale.taxAmount, symbol: sym)),
                    pw.Divider(),
                    _pdfRow(
                      'TOTAL',
                      Formatters.currency(sale.total, symbol: sym),
                      bold: true,
                      fontSize: 12,
                    ),
                    _pdfRow(
                      'Paid (${sale.paymentMethod})',
                      Formatters.currency(sale.paid, symbol: sym),
                      labelColor: PdfColors.green700,
                    ),
                    if (sale.balance > 0.005)
                      _pdfRow(
                        'Balance Due',
                        Formatters.currency(sale.balance, symbol: sym),
                        bold: true,
                        fontSize: 11,
                        labelColor: PdfColors.orange700,
                        valueColor: PdfColors.orange700,
                      )
                    else if (sale.balance < -0.005)
                      _pdfRow(
                        'Change',
                        Formatters.currency(sale.balance.abs(), symbol: sym),
                        labelColor: PdfColors.green700,
                      ),
                  ],
                ),
              ),
            ),

            // ── Notes ────────────────────────────────────────────────────
            if (sale.notes.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Note: ${sale.notes}',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
            ],

            // ── Credit warning in PDF ─────────────────────────────────────
            if (hasCreditOnSale) ...[
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFFF0E0),
                  border: pw.Border.fromBorderSide(
                      pw.BorderSide(
                          color: PdfColor.fromInt(0xFFF97316))),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CREDIT BALANCE: ${Formatters.currency(creditOnSale, symbol: sym)} OUTSTANDING',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFFF97316)),
                    ),
                    pw.Text(
                      'Kindly clear the above amount at your earliest convenience.',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            ],

            pw.Spacer(),

            // ── Footer ───────────────────────────────────────────────────
            pw.Divider(color: PdfColors.grey400),
            pw.Center(
              child: pw.Text(
                'Thank you for your business! — ${settings.pharmacyName}',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey500),
              ),
            ),
          ],
        );
      },
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  /// Helper: one row in the PDF totals section.
  pw.Widget _pdfRow(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 10,
    PdfColor? labelColor,
    PdfColor? valueColor,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : null,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: style.copyWith(color: labelColor ?? PdfColors.grey700)),
          pw.Text(value, style: style.copyWith(color: valueColor)),
        ],
      ),
    );
  }

}

// ── Quick "Receive Payment" dialog from invoice screen ───────────────────────

class _QuickPaymentDialog extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final String invoiceNumber;
  final double saleBalance;
  final double customerBalance;
  final String symbol;

  const _QuickPaymentDialog({
    required this.customerId,
    required this.customerName,
    required this.invoiceNumber,
    required this.saleBalance,
    required this.customerBalance,
    required this.symbol,
  });

  @override
  ConsumerState<_QuickPaymentDialog> createState() =>
      _QuickPaymentDialogState();
}

class _QuickPaymentDialogState extends ConsumerState<_QuickPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final _notesCtrl = TextEditingController();
  String _method = 'Cash';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default to this sale's balance (not the full customer balance)
    _amount = TextEditingController(
        text: widget.saleBalance.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amount.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amt = double.tryParse(_amount.text) ?? 0;
    if (amt <= 0) return;
    setState(() => _saving = true);
    await ref.read(creditPaymentsProvider.notifier).add(
          customerId: widget.customerId,
          customerName: widget.customerName,
          amount: amt,
          paymentMethod: _method,
          notes: _notesCtrl.text.trim(),
          referenceInvoice: widget.invoiceNumber,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        const Icon(Icons.payments_outlined, color: AppColors.accent),
        const SizedBox(width: 8),
        const Text('Receive Payment'),
      ]),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.nearExpiry.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(widget.invoiceNumber,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('This invoice due:',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      Text(
                        Formatters.currency(widget.saleBalance,
                            symbol: widget.symbol),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.nearExpiry),
                      ),
                    ],
                  ),
                  if (widget.customerBalance != widget.saleBalance)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total customer due:',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                        Text(
                          Formatters.currency(widget.customerBalance,
                              symbol: widget.symbol),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              fontSize: 12),
                        ),
                      ],
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount Received *',
                  prefixText: '${widget.symbol} ',
                ),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration:
                    const InputDecoration(labelText: 'Payment Method'),
                items: ['Cash', 'Card', 'Online', 'Other']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _method = v ?? 'Cash'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check),
          label: const Text('Confirm'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white),
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

// ── Shared widget helpers ─────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  const _TH(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13));
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _TotalRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        fontSize: bold ? 15 : 13,
        color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: style.copyWith(
                  color: color ?? AppColors.textMuted)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

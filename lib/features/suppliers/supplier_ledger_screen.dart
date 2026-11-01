import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/supplier.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../state/catalog_providers.dart';
import '../../state/core_providers.dart';
import '../../state/supplier_ledger_providers.dart';

class SupplierLedgerScreen extends ConsumerWidget {
  final String supplierId;
  const SupplierLedgerScreen({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);
    final supplier =
        suppliers.where((s) => s.id == supplierId).firstOrNull;
    final summary = ref.watch(supplierKhataSummaryProvider(supplierId));
    final ledger = ref.watch(supplierLedgerProvider(supplierId));
    final settings = ref.watch(settingsProvider);
    final symbol = settings.currencySymbol;

    final name = supplier?.name ?? summary.supplierName;
    final phone = supplier?.phone ?? '';
    final contact = supplier?.contactPerson ?? '';
    final hasBaqi = summary.currentBaqi > 0.005;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$name — Khata & Supplies'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        leading: BackButton(onPressed: () => context.go('/suppliers')),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.print, color: AppColors.primary),
            label: const Text('Print Khata PDF',
                style: TextStyle(color: AppColors.primary)),
            onPressed: () => _printSupplierLedger(
                supplier, summary, ledger, settings, symbol),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_card, size: 18),
            label: const Text('Cash Jama (Pay Supplier)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                _showPaymentDialog(context, ref, name, summary.currentBaqi, symbol),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: Column(
        children: [
          // ── Top Summary Card ──────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: (hasBaqi
                          ? AppColors.nearExpiry
                          : AppColors.primary)
                      .withValues(alpha: 0.15),
                  child: Icon(
                    Icons.local_shipping,
                    size: 32,
                    color: hasBaqi ? AppColors.nearExpiry : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      if (contact.isNotEmpty)
                        Text('Contact Person: $contact',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textMuted)),
                      if (phone.isNotEmpty)
                        Text('Phone: $phone',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textMuted)),
                      if (supplier?.address.isNotEmpty ?? false)
                        Text('Address: ${supplier!.address}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                // Khata Balance Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: (hasBaqi ? AppColors.nearExpiry : AppColors.inStock)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (hasBaqi ? AppColors.nearExpiry : AppColors.inStock)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hasBaqi ? 'Baqi (Dena Hai)' : 'All Cleared',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: hasBaqi
                                ? AppColors.nearExpiry
                                : AppColors.inStock),
                      ),
                      Text(
                        Formatters.currency(summary.currentBaqi, symbol: symbol),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: hasBaqi
                                ? AppColors.nearExpiry
                                : AppColors.inStock),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Maal Aya: ${Formatters.currency(summary.totalMaalAya, symbol: symbol)} (${summary.totalShipments} orders)',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                      Text(
                        'Total Cash Diya: ${Formatters.currency(summary.totalCashDiya, symbol: symbol)} (${summary.totalPayments} payments)',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.inStock),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Legend Bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _Legend(color: AppColors.primaryDark, label: 'Maal Aya (Stock Arrival / Bill)'),
                const SizedBox(width: 16),
                _Legend(color: AppColors.inStock, label: 'Cash Diya (Payment Given)'),
                const Spacer(),
                Text('${ledger.length} transactions recorded',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Ledger Transaction List ───────────────────────────────────
          Expanded(
            child: ledger.isEmpty
                ? const Center(
                    child: Text(
                      'No shipments or payments recorded yet.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: ledger.length,
                    itemBuilder: (context, i) {
                      final entry = ledger[i];
                      if (entry is SupplierPurchaseLedgerEntry) {
                        return _SupplierPurchaseTile(
                            entry: entry, symbol: symbol);
                      } else if (entry is SupplierPaymentLedgerEntry) {
                        return _SupplierPaymentTile(
                          entry: entry,
                          symbol: symbol,
                          onDelete: () async {
                            final ok = await showConfirmDialog(
                              context,
                              title: 'Delete Payment',
                              message:
                                  'Delete payment of ${Formatters.currency(entry.payment.amount, symbol: symbol)} recorded on ${Formatters.dateTime(entry.payment.dateTimeValue)}?',
                              confirmText: 'Delete',
                              isDestructive: true,
                            );
                            if (ok) {
                              await ref
                                  .read(supplierPaymentsProvider.notifier)
                                  .remove(entry.payment.id);
                            }
                          },
                        );
                      } else if (entry is SupplierOpeningLedgerEntry) {
                        return _SupplierOpeningTile(
                            entry: entry, symbol: symbol);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref,
      String supplierName, double currentBaqi, String symbol) {
    showDialog(
      context: context,
      builder: (ctx) => _AddSupplierPaymentDialog(
        supplierId: supplierId,
        supplierName: supplierName,
        currentBaqi: currentBaqi,
        symbol: symbol,
      ),
    );
  }

  Future<void> _printSupplierLedger(
    Supplier? supplier,
    SupplierKhataSummary summary,
    List<SupplierLedgerEntry> ledger,
    AppSettings settings,
    String symbol,
  ) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(settings.pharmacyName,
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    if (settings.address.isNotEmpty)
                      pw.Text(settings.address,
                          style: const pw.TextStyle(fontSize: 10)),
                    if (settings.phone.isNotEmpty)
                      pw.Text('Phone: ${settings.phone}',
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('SUPPLIER KHATA STATEMENT',
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        'Date: ${Formatters.dateTime(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 8),

            // Supplier Information & Summary
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Supplier: ${summary.supplierName}',
                          style: pw.TextStyle(
                              fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      if (supplier?.contactPerson.isNotEmpty ?? false)
                        pw.Text('Contact: ${supplier!.contactPerson}',
                            style: const pw.TextStyle(fontSize: 9)),
                      if (supplier?.phone.isNotEmpty ?? false)
                        pw.Text('Phone: ${supplier!.phone}',
                            style: const pw.TextStyle(fontSize: 9)),
                      if (supplier?.address.isNotEmpty ?? false)
                        pw.Text('Address: ${supplier!.address}',
                            style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                            'Total Maal Aya: ${Formatters.currency(summary.totalMaalAya, symbol: symbol)}',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(
                            'Total Cash Diya: ${Formatters.currency(summary.totalCashDiya, symbol: symbol)}',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Divider(thickness: 0.5),
                        pw.Text(
                            'NET BAQI (PAYABLE): ${Formatters.currency(summary.currentBaqi, symbol: symbol)}',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: summary.currentBaqi > 0
                                    ? PdfColors.red900
                                    : PdfColors.green900)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Table of Transactions
            pw.Text('Transaction History (Chronological)',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: [
                'Date & Time',
                'Type',
                'Reference / PO',
                'Maal Aya (+)',
                'Cash Diya (-)',
                'Running Baqi'
              ],
              data: ledger.map((entry) {
                if (entry is SupplierPurchaseLedgerEntry) {
                  final p = entry.purchase;
                  return [
                    Formatters.dateTime(p.dateTimeValue),
                    'Maal Aya',
                    p.purchaseNumber,
                    Formatters.currency(p.total, symbol: symbol),
                    '-',
                    Formatters.currency(entry.runningBalance, symbol: symbol),
                  ];
                } else if (entry is SupplierPaymentLedgerEntry) {
                  final pay = entry.payment;
                  return [
                    Formatters.dateTime(pay.dateTimeValue),
                    'Cash Diya (${pay.paymentMethod})',
                    pay.notes.isNotEmpty ? pay.notes : 'Payment',
                    '-',
                    Formatters.currency(pay.amount, symbol: symbol),
                    Formatters.currency(entry.runningBalance, symbol: symbol),
                  ];
                } else if (entry is SupplierOpeningLedgerEntry) {
                  return [
                    Formatters.dateTime(entry.dateTimeValue),
                    'Opening Balance',
                    'Initial Record',
                    Formatters.currency(entry.billed, symbol: symbol),
                    Formatters.currency(entry.paid, symbol: symbol),
                    Formatters.currency(entry.runningBalance, symbol: symbol),
                  ];
                }
                return ['', '', '', '', '', ''];
              }).toList(),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
            ),
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Prepared By: ____________________',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Supplier Signature: ____________________',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}

// ── Purchase Tile (Maal Aya) with Expandable Medicine Details ─────────────────

class _SupplierPurchaseTile extends StatefulWidget {
  final SupplierPurchaseLedgerEntry entry;
  final String symbol;
  const _SupplierPurchaseTile({required this.entry, required this.symbol});

  @override
  State<_SupplierPurchaseTile> createState() => _SupplierPurchaseTileState();
}

class _SupplierPurchaseTileState extends State<_SupplierPurchaseTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.entry.purchase;
    final total = p.total;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Blue bar for Maal Aya
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2,
                            size: 15, color: AppColors.primaryDark),
                        const SizedBox(width: 6),
                        Text(
                          'Maal Aya — ${p.purchaseNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${p.items.length} item${p.items.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          Formatters.dateTime(p.dateTimeValue),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    if (p.notes.isNotEmpty)
                      Text('Note: ${p.notes}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Bill: + ${Formatters.currency(total, symbol: widget.symbol)}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Baqi: ${Formatters.currency(widget.entry.runningBalance, symbol: widget.symbol)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearExpiry),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_expanded ? 'Hide Items' : 'View Items',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                        Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppColors.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_expanded) ...[
            const Divider(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Items in this shipment:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  ...p.items.map((item) {
                    final qtyText = item.packQty > 0
                        ? '${item.packQty} ${item.packName} (${item.quantity} ${item.unit})'
                        : '${item.quantity} ${item.unit}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.medicineName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  'Batch: ${item.batchNumber}  •  Exp: ${Formatters.date(DateTime.fromMillisecondsSinceEpoch(item.expiryDate))}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(qtyText,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              Formatters.currency(item.lineTotal,
                                  symbol: widget.symbol),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Payment Tile (Cash Diya) ─────────────────────────────────────────────────

class _SupplierPaymentTile extends StatelessWidget {
  final SupplierPaymentLedgerEntry entry;
  final String symbol;
  final VoidCallback onDelete;

  const _SupplierPaymentTile({
    required this.entry,
    required this.symbol,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pay = entry.payment;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Green bar for Cash Diya
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.inStock,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payments_outlined,
                        size: 15, color: AppColors.inStock),
                    const SizedBox(width: 6),
                    Text(
                      'Cash Diya — ${pay.paymentMethod}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      Formatters.dateTime(pay.dateTimeValue),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
                if (pay.notes.isNotEmpty)
                  Text('Note: ${pay.notes}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Paid: - ${Formatters.currency(pay.amount, symbol: symbol)}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inStock),
              ),
              const SizedBox(height: 2),
              Text(
                'Baqi: ${Formatters.currency(entry.runningBalance, symbol: symbol)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearExpiry),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete payment record',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Opening Balance Tile (For legacy records) ────────────────────────────────

class _SupplierOpeningTile extends StatelessWidget {
  final SupplierOpeningLedgerEntry entry;
  final String symbol;
  const _SupplierOpeningTile({required this.entry, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Initial Opening Balance',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('Recorded prior to detailed order tracking',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Billed: ${Formatters.currency(entry.billed, symbol: symbol)}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Paid: ${Formatters.currency(entry.paid, symbol: symbol)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inStock),
              ),
              Text(
                'Baqi: ${Formatters.currency(entry.runningBalance, symbol: symbol)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.nearExpiry),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add Supplier Payment Dialog ──────────────────────────────────────────────

class _AddSupplierPaymentDialog extends ConsumerStatefulWidget {
  final String supplierId;
  final String supplierName;
  final double currentBaqi;
  final String symbol;

  const _AddSupplierPaymentDialog({
    required this.supplierId,
    required this.supplierName,
    required this.currentBaqi,
    required this.symbol,
  });

  @override
  ConsumerState<_AddSupplierPaymentDialog> createState() =>
      _AddSupplierPaymentDialogState();
}

class _AddSupplierPaymentDialogState
    extends ConsumerState<_AddSupplierPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  final _notesCtrl = TextEditingController();
  String _method = 'Cash';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.currentBaqi > 0 ? widget.currentBaqi.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amt <= 0) return;

    setState(() => _saving = true);
    await ref.read(supplierPaymentsProvider.notifier).add(
          supplierId: widget.supplierId,
          supplierName: widget.supplierName,
          amount: amt,
          paymentMethod: _method,
          notes: _notesCtrl.text.trim(),
          date: _date,
        );

    // Also update supplier paidAmount in catalog
    final sup = ref
        .read(suppliersProvider)
        .where((s) => s.id == widget.supplierId)
        .firstOrNull;
    if (sup != null) {
      await ref
          .read(suppliersProvider.notifier)
          .update(sup.copyWith(paidAmount: sup.paidAmount + amt));
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          const Icon(Icons.add_card, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(child: Text('Pay Supplier — ${widget.supplierName}')),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.nearExpiry.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Baqi (Payable):',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      Formatters.currency(widget.currentBaqi,
                          symbol: widget.symbol),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.nearExpiry),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Payment Amount *',
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
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: ['Cash', 'Bank Transfer', 'Cheque', 'Online', 'Other']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _method = v ?? 'Cash'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate == null) return;
                  if (!context.mounted) return;
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_date),
                  );
                  if (!context.mounted) return;
                  setState(() {
                    _date = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime?.hour ?? _date.hour,
                      pickedTime?.minute ?? _date.minute,
                    );
                  });
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Payment Date & Time',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(Formatters.dateTime(_date)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes / Cheque # (optional)',
                  hintText: 'e.g. Paid via Cheque #1029',
                ),
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
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Payment'),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
    ]);
  }
}

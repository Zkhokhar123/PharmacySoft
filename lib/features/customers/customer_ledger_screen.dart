import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/customer.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../state/catalog_providers.dart';
import '../../state/core_providers.dart';
import '../../state/credit_providers.dart';

class CustomerLedgerScreen extends ConsumerWidget {
  final String customerId;
  const CustomerLedgerScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(customerCreditProvider);
    final summary =
        summaries.where((s) => s.customerId == customerId).firstOrNull;
    final customers = ref.watch(customersProvider);
    final customer =
        customers.where((c) => c.id == customerId).firstOrNull;
    final symbol = ref.watch(settingsProvider).currencySymbol;
    final ledger = ref.watch(customerLedgerProvider(customerId));

    final name = customer?.name ?? summary?.customerName ?? customerId;
    final phone = customer?.phone ?? '';
    final balance = summary?.outstanding ?? 0.0;
    final hasBalance = balance > 0.005;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(name),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        leading:
            BackButton(onPressed: () => context.go('/customers')),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.print, color: AppColors.primary),
            label: const Text('Print Khata PDF',
                style: TextStyle(color: AppColors.primary)),
            onPressed: () => _printCustomerLedger(
                customer, summary, ledger, ref.watch(settingsProvider), symbol),
          ),
          const SizedBox(width: 4),
          if (customer != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.primary),
              tooltip: 'Edit customer',
              onPressed: () => _showEditDialog(context, ref, customer),
            ),
          if (hasBalance)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Receive Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 38),
                ),
                onPressed: () =>
                    _showPaymentDialog(context, ref, name, balance, symbol),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── summary header ────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: (hasBalance
                          ? AppColors.nearExpiry
                          : AppColors.primary)
                      .withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: hasBalance
                            ? AppColors.nearExpiry
                            : AppColors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      if (phone.isNotEmpty)
                        Text(phone,
                            style: const TextStyle(
                                color: AppColors.textMuted)),
                    ],
                  ),
                ),
                // balance box
                _BalanceBox(
                    balance: balance,
                    symbol: symbol,
                    totalCharged: summary?.totalCharged ?? 0,
                    totalPaid: (summary?.totalPaidAtSale ?? 0) +
                        (summary?.totalCreditReceived ?? 0)),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── legend ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(children: [
              _Legend(color: AppColors.outOfStock, label: 'Sale (debit)'),
              const SizedBox(width: 16),
              _Legend(color: AppColors.inStock, label: 'Payment (credit)'),
              const Spacer(),
              Text('${ledger.length} entries',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
            ]),
          ),
          const Divider(height: 1),

          // ── ledger entries ────────────────────────────────────────────
          Expanded(
            child: ledger.isEmpty
                ? const Center(
                    child: Text('No transactions yet.',
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: ledger.length,
                    itemBuilder: (context, i) {
                      final entry = ledger[i];
                      if (entry is LedgerSaleEntry) {
                        return _SaleLedgerTile(
                            entry: entry, symbol: symbol);
                      } else {
                        return _PaymentLedgerTile(
                          entry: entry as LedgerPaymentEntry,
                          symbol: symbol,
                          onDelete: () async {
                            final ok = await showConfirmDialog(
                              context,
                              title: 'Delete Payment',
                              message:
                                  'Delete this payment record of ${Formatters.currency(entry.payment.amount, symbol: symbol)}?',
                              confirmText: 'Delete',
                              isDestructive: true,
                            );
                            if (ok) {
                              await ref
                                  .read(creditPaymentsProvider.notifier)
                                  .remove(entry.payment.id);
                            }
                          },
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref,
      String name, double maxBalance, String symbol) {
    showDialog(
      context: context,
      builder: (ctx) => _ReceivePaymentDialog(
        customerId: customerId,
        customerName: name,
        maxBalance: maxBalance,
        symbol: symbol,
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, customer) {
    // reuse the form from customers_screen
    showDialog(
      context: context,
      builder: (ctx) => _EditCustomerDialog(customer: customer),
    );
  }

  Future<void> _printCustomerLedger(
    Customer? customer,
    CustomerCreditSummary? summary,
    List<LedgerEntry> ledger,
    AppSettings settings,
    String symbol,
  ) async {
    final doc = pw.Document();
    final name = customer?.name ?? summary?.customerName ?? 'Customer';
    final balance = summary?.outstanding ?? 0.0;
    final totalCharged = summary?.totalCharged ?? 0.0;
    final totalPaid = (summary?.totalPaidAtSale ?? 0.0) +
        (summary?.totalCreditReceived ?? 0.0);

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
                    pw.Text('CUSTOMER KHATA STATEMENT',
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

            // Customer Info & Summary Box
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer: $name',
                          style: pw.TextStyle(
                              fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      if (customer?.phone.isNotEmpty ?? false)
                        pw.Text('Phone: ${customer!.phone}',
                            style: const pw.TextStyle(fontSize: 10)),
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
                            'Total Charged: ${Formatters.currency(totalCharged, symbol: symbol)}',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(
                            'Total Received: ${Formatters.currency(totalPaid, symbol: symbol)}',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Divider(thickness: 0.5),
                        pw.Text(
                            'BALANCE DUE: ${Formatters.currency(balance, symbol: symbol)}',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: balance > 0
                                    ? PdfColors.red900
                                    : PdfColors.green900)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Transactions Table
            pw.Text('Ledger Transactions (Chronological)',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: [
                'Date & Time',
                'Type',
                'Invoice / Note',
                'Total Bill',
                'Amount Paid',
                'Balance'
              ],
              data: ledger.map((entry) {
                if (entry is LedgerSaleEntry) {
                  final s = entry.sale;
                  final credit = s.total - s.paid;
                  return [
                    Formatters.dateTime(s.dateTimeValue),
                    'Sale Bill (${s.items.length} items)',
                    s.invoiceNumber,
                    Formatters.currency(s.total, symbol: symbol),
                    Formatters.currency(s.paid, symbol: symbol),
                    credit > 0.005
                        ? Formatters.currency(credit, symbol: symbol)
                        : 'Cleared',
                  ];
                } else if (entry is LedgerPaymentEntry) {
                  final p = entry.payment;
                  return [
                    Formatters.dateTime(p.dateTimeValue),
                    'Payment Received',
                    '${p.paymentMethod}${p.notes.isNotEmpty ? ' - ${p.notes}' : ''}',
                    '-',
                    Formatters.currency(p.amount, symbol: symbol),
                    'Credited',
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
                pw.Text('Customer Signature: ____________________',
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

// ── Balance summary box ──────────────────────────────────────────────────────

class _BalanceBox extends StatelessWidget {
  final double balance;
  final String symbol;
  final double totalCharged;
  final double totalPaid;

  const _BalanceBox({
    required this.balance,
    required this.symbol,
    required this.totalCharged,
    required this.totalPaid,
  });

  @override
  Widget build(BuildContext context) {
    final hasBalance = balance > 0.005;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (hasBalance ? AppColors.nearExpiry : AppColors.inStock)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (hasBalance ? AppColors.nearExpiry : AppColors.inStock)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            hasBalance ? 'Outstanding' : 'All Clear',
            style: TextStyle(
                fontSize: 11,
                color: hasBalance
                    ? AppColors.nearExpiry
                    : AppColors.inStock),
          ),
          Text(
            Formatters.currency(balance.abs(), symbol: symbol),
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: hasBalance
                    ? AppColors.nearExpiry
                    : AppColors.inStock),
          ),
          const SizedBox(height: 4),
          Text(
            'Charged: ${Formatters.currencyCompact(totalCharged, symbol: symbol)}',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textMuted),
          ),
          Text(
            'Received: ${Formatters.currencyCompact(totalPaid, symbol: symbol)}',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Legend dot ───────────────────────────────────────────────────────────────

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
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style:
              const TextStyle(fontSize: 12, color: AppColors.textMuted)),
    ]);
  }
}

// ── Sale ledger tile ─────────────────────────────────────────────────────────

class _SaleLedgerTile extends StatefulWidget {
  final LedgerSaleEntry entry;
  final String symbol;
  const _SaleLedgerTile({required this.entry, required this.symbol});

  @override
  State<_SaleLedgerTile> createState() => _SaleLedgerTileState();
}

class _SaleLedgerTileState extends State<_SaleLedgerTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sale = widget.entry.sale;
    final credit = sale.total - sale.paid;
    final isCredit = credit > 0.005;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // left coloured bar
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: isCredit
                      ? AppColors.outOfStock
                      : AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.receipt_long,
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(sale.invoiceNumber,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        '(${sale.items.length} item${sale.items.length == 1 ? '' : 's'})',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(Formatters.dateTime(sale.dateTimeValue),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Bill: ${Formatters.currency(sale.total, symbol: widget.symbol)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Paid: ${Formatters.currency(sale.paid, symbol: widget.symbol)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inStock),
                  ),
                  if (isCredit)
                    Text(
                      'Due: ${Formatters.currency(credit, symbol: widget.symbol)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.outOfStock),
                    ),
                  const SizedBox(height: 2),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Medicines Taken At This Time:',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted)),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 12),
                        label: const Text('View Full Invoice',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () =>
                            context.go('/sales/invoice/${sale.id}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...sale.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(item.medicineName,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('${item.quantity} ${item.unit}',
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
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Payment ledger tile ──────────────────────────────────────────────────────

class _PaymentLedgerTile extends StatelessWidget {
  final LedgerPaymentEntry entry;
  final String symbol;
  final VoidCallback onDelete;

  const _PaymentLedgerTile({
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
          // left coloured bar — green for payment
          Container(
            width: 4,
            height: 48,
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
                Row(children: [
                  const Icon(Icons.payments_outlined,
                      size: 14, color: AppColors.inStock),
                  const SizedBox(width: 4),
                  const Text('Payment Received',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(Formatters.dateTime(pay.dateTimeValue),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ],
                ),
                if (pay.notes.isNotEmpty)
                  Text('Note: ${pay.notes}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                Text('Method: ${pay.paymentMethod}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(
            '+ ${Formatters.currency(pay.amount, symbol: symbol)}',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.inStock),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.outOfStock),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Receive payment dialog ────────────────────────────────────────────────────

class _ReceivePaymentDialog extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final double maxBalance;
  final String symbol;

  const _ReceivePaymentDialog({
    required this.customerId,
    required this.customerName,
    required this.maxBalance,
    required this.symbol,
  });

  @override
  ConsumerState<_ReceivePaymentDialog> createState() =>
      _ReceivePaymentDialogState();
}

class _ReceivePaymentDialogState
    extends ConsumerState<_ReceivePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final _notesCtrl = TextEditingController();
  String _method = 'Cash';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // default to full outstanding amount
    _amount = TextEditingController(
        text: widget.maxBalance.toStringAsFixed(2));
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
    if (amt <= 0) {
      setState(() => _error = 'Amount must be greater than 0');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(creditPaymentsProvider.notifier).add(
            customerId: widget.customerId,
            customerName: widget.customerName,
            amount: amt,
            paymentMethod: _method,
            notes: _notesCtrl.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        const Icon(Icons.payments_outlined, color: AppColors.accent),
        const SizedBox(width: 8),
        const Text('Receive Payment'),
      ]),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // customer + outstanding
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.nearExpiry.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Customer',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12)),
                        Text(widget.customerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Outstanding',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12)),
                        Text(
                          Formatters.currency(widget.maxBalance,
                              symbol: widget.symbol),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.nearExpiry),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // amount field
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

              // payment method
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration:
                    const InputDecoration(labelText: 'Payment Method'),
                items: ['Cash', 'Card', 'Online', 'Other']
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _method = v ?? 'Cash'),
              ),
              const SizedBox(height: 12),

              // notes
              TextFormField(
                controller: _notesCtrl,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.outOfStock, fontSize: 13)),
              ],
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
          label: const Text('Confirm Payment'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white),
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

// ── Edit customer stub (reuses same form from customers_screen) ───────────────

class _EditCustomerDialog extends ConsumerStatefulWidget {
  final dynamic customer; // Customer
  const _EditCustomerDialog({required this.customer});

  @override
  ConsumerState<_EditCustomerDialog> createState() =>
      _EditCustomerDialogState();
}

class _EditCustomerDialogState
    extends ConsumerState<_EditCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer.name ?? '');
    _phone = TextEditingController(text: widget.customer.phone ?? '');
    _address =
        TextEditingController(text: widget.customer.address ?? '');
    _notes = TextEditingController(text: widget.customer.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final updated = widget.customer.copyWith(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      notes: _notes.text.trim(),
    );
    await ref.read(customersProvider.notifier).update(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Edit Customer'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _phone,
                  decoration:
                      const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _address,
                  decoration:
                      const InputDecoration(labelText: 'Address'),
                  maxLines: 2),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _notes,
                  decoration:
                      const InputDecoration(labelText: 'Notes')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: const Text('Update'),
        ),
      ],
    );
  }
}

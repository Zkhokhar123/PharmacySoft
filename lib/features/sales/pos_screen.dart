import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../core/pack_qty.dart';
import '../../data/models/customer.dart';
import '../../data/models/medicine.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/barcode_field.dart';
import '../../shared/widgets/status_badge.dart';
import '../../state/catalog_providers.dart';
import '../../state/core_providers.dart';
import '../../state/inventory_providers.dart';
import '../../state/sales_providers.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _discountCtrl = TextEditingController(text: '0');
  final _taxRateCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'Cash';
  String? _errorMsg;
  bool _userEditedPaid = false; // tracks if user manually set paid amount

  @override
  void dispose() {
    _discountCtrl.dispose();
    _taxRateCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onBarcode(String code) {
    final db = ref.read(databaseProvider);
    final med = db.findByBarcode(code);
    if (med == null) {
      setState(() => _errorMsg = 'No medicine found for barcode: $code');
      return;
    }
    _addMedicineToCart(med);
  }

  void _addMedicineToCart(Medicine med) {
    final best = bestBatchForSale(ref, med.id);
    if (best == null) {
      setState(() => _errorMsg = '${med.name}: No stock available');
      return;
    }
    if (best.quantity < 1) {
      setState(() => _errorMsg = '${med.name}: Out of stock');
      return;
    }
    setState(() => _errorMsg = null);
    ref.read(posCartProvider.notifier).addItem(CartItem(
          medicineId: med.id,
          medicineName: med.name,
          unit: med.unit,
          packName: med.packName,
          unitsPerPack: PackQty.normalizePackSize(med.unitsPerPack),
          batchId: best.id,
          batchNumber: best.batchNumber,
          expiryDate: best.expiryDate,
          availableQty: best.quantity,
          quantity: 1,
          unitPrice: best.salePrice > 0 ? best.salePrice : med.salePrice,
          purchasePrice:
              best.purchasePrice > 0 ? best.purchasePrice : med.purchasePrice,
        ));
  }

  Future<void> _checkout() async {
    final total = ref.read(posCartProvider).total;
    final paid = double.tryParse(_paidCtrl.text) ?? total;
    ref.read(posCartProvider.notifier)
      ..setDiscount(double.tryParse(_discountCtrl.text) ?? 0)
      ..setTaxRate(double.tryParse(_taxRateCtrl.text) ?? 0)
      ..setPaymentMethod(_paymentMethod)
      ..setPaid(paid)
      ..setNotes(_notesCtrl.text.trim());

    try {
      final sale = await ref.read(posCartProvider.notifier).checkout();
      if (mounted) {
        // reset payment field for next sale
        _discountCtrl.text = '0';
        _taxRateCtrl.text = '0';
        _paidCtrl.text = '0';
        _notesCtrl.clear();
        setState(() {
          _paymentMethod = 'Cash';
          _userEditedPaid = false;
        });
        context.go('/sales/invoice/${sale.id}?autoPrint=true');
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    }
  }

  void _showHeldCartsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        final held = ref.watch(heldCartsProvider);
        return AlertDialog(
          title: const Text('Held Sales (Parked Carts)'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: held.isEmpty
                ? const Text('No held carts.')
                : SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: held.length,
                      itemBuilder: (c, i) {
                        final item = held[i];
                        return ListTile(
                          leading: const Icon(Icons.shopping_bag_outlined,
                              color: AppColors.primary),
                          title: Text(item.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${item.session.items.length} items • Total: Rs ${item.session.total.toStringAsFixed(0)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: const Size(0, 30),
                                ),
                                onPressed: () {
                                  final recalled = ref
                                      .read(heldCartsProvider.notifier)
                                      .recall(item.id);
                                  if (recalled != null) {
                                    ref
                                        .read(posCartProvider.notifier)
                                        .loadSession(recalled);
                                  }
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Resume'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: AppColors.outOfStock),
                                onPressed: () {
                                  ref
                                      .read(heldCartsProvider.notifier)
                                      .remove(item.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(posCartProvider);
    final symbol = ref.watch(settingsProvider).currencySymbol;
    final heldCarts = ref.watch(heldCartsProvider);

    // Auto-sync paid to total unless user has manually changed it
    if (!_userEditedPaid) {
      _paidCtrl.text = cart.total.toStringAsFixed(2);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Sale'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          if (heldCarts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TextButton.icon(
                icon: const Icon(Icons.pause_circle_outline,
                    color: AppColors.nearExpiry),
                label: Text('Held (${heldCarts.length})',
                    style: const TextStyle(
                        color: AppColors.nearExpiry,
                        fontWeight: FontWeight.w600)),
                onPressed: () => _showHeldCartsDialog(context, ref),
              ),
            ),
          if (!cart.isEmpty) ...[
            TextButton.icon(
              icon: const Icon(Icons.pause_outlined, color: AppColors.primary),
              label: const Text('Hold Sale',
                  style: TextStyle(color: AppColors.primary)),
              onPressed: () {
                ref.read(heldCartsProvider.notifier).hold(cart);
                ref.read(posCartProvider.notifier).clear();
                _discountCtrl.text = '0';
                _taxRateCtrl.text = '0';
                _paidCtrl.text = '0';
                setState(() {
                  _errorMsg = null;
                  _userEditedPaid = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sale put on hold.')),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.clear, color: AppColors.outOfStock),
              label: const Text('Clear Cart',
                  style: TextStyle(color: AppColors.outOfStock)),
              onPressed: () {
                ref.read(posCartProvider.notifier).clear();
                _discountCtrl.text = '0';
                _taxRateCtrl.text = '0';
                _paidCtrl.text = '0';
                setState(() {
                  _errorMsg = null;
                  _userEditedPaid = false;
                });
              },
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 960;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 3,
                    child: _ProductPanel(onAdd: _addMedicineToCart)),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 400,
                  child: _CartPanel(
                    cart: cart,
                    symbol: symbol,
                    discountCtrl: _discountCtrl,
                    taxRateCtrl: _taxRateCtrl,
                    paidCtrl: _paidCtrl,
                    notesCtrl: _notesCtrl,
                    paymentMethod: _paymentMethod,
                    onPaymentMethodChanged: (v) {
                      setState(() {
                        _paymentMethod = v;
                        // When switching TO credit, clear paid so user sets it
                        if (v == 'Credit') {
                          _paidCtrl.text = '0';
                          _userEditedPaid = true;
                        } else {
                          // Switch back to cash → reset paid to total
                          _userEditedPaid = false;
                        }
                      });
                    },
                    onPaidEdited: () => setState(() => _userEditedPaid = true),
                    errorMsg: _errorMsg,
                    onBarcode: _onBarcode,
                    onCheckout: _checkout,
                  ),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                _CartPanel(
                  cart: cart,
                  symbol: symbol,
                  discountCtrl: _discountCtrl,
                  taxRateCtrl: _taxRateCtrl,
                  paidCtrl: _paidCtrl,
                  notesCtrl: _notesCtrl,
                  paymentMethod: _paymentMethod,
                  onPaymentMethodChanged: (v) {
                    setState(() {
                      _paymentMethod = v;
                      if (v == 'Credit') {
                        _paidCtrl.text = '0';
                        _userEditedPaid = true;
                      } else {
                        _userEditedPaid = false;
                      }
                    });
                  },
                  onPaidEdited: () => setState(() => _userEditedPaid = true),
                  errorMsg: _errorMsg,
                  onBarcode: _onBarcode,
                  onCheckout: _checkout,
                ),
                _ProductPanel(onAdd: _addMedicineToCart),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Product search panel ────────────────────────────────────────────────────

class _ProductPanel extends ConsumerStatefulWidget {
  final void Function(Medicine med) onAdd;
  const _ProductPanel({required this.onAdd});

  @override
  ConsumerState<_ProductPanel> createState() => _ProductPanelState();
}

class _ProductPanelState extends ConsumerState<_ProductPanel> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(medicineStockProvider);
    final filtered = _search.isEmpty
        ? all
        : all.where((s) {
            final q = _search.toLowerCase();
            return s.medicine.name.toLowerCase().contains(q) ||
                s.medicine.genericName.toLowerCase().contains(q);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search medicine to add…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No results',
                      style: TextStyle(color: AppColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      onTap: s.hasStock
                          ? () => widget.onAdd(s.medicine)
                          : null,
                      color: s.hasStock
                          ? AppColors.surface
                          : AppColors.background,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(s.medicine.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: s.hasStock
                                                  ? AppColors.textPrimary
                                                  : AppColors.textMuted)),
                                    ),
                                    if (s.medicine.shelfLocation.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          s.medicine.shelfLocation,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primaryDark,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  'Stock: ${s.totalStock} ${s.medicine.unit}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted),
                                ),
                                if (s.medicine.genericName.isNotEmpty)
                                  Text(
                                    s.medicine.genericName,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (s.hasStock) ...[
                            if (s.medicine.genericName.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.swap_horiz, size: 18),
                                tooltip: 'Substitutes / Same Formula',
                                color: AppColors.textMuted,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () =>
                                    _showSubstitutesDialog(context, s.medicine),
                              ),
                            const Icon(Icons.add_circle,
                                color: AppColors.primary, size: 22),
                          ] else ...[
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                              ),
                              icon: const Icon(Icons.swap_horiz, size: 16),
                              label: const Text('Substitutes',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () =>
                                  _showSubstitutesDialog(context, s.medicine),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showSubstitutesDialog(BuildContext context, Medicine targetMed) {
    final all = ref.read(medicineStockProvider);
    final formula = targetMed.genericName.trim().toLowerCase();
    final alternatives = formula.isEmpty
        ? <MedicineStockInfo>[]
        : all
            .where((s) =>
                s.medicine.id != targetMed.id &&
                s.medicine.genericName.trim().toLowerCase() == formula)
            .toList();

    showDialog(
      context: context,
      builder: (ctx) {
        final symbol = ref.read(settingsProvider).currencySymbol;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.swap_horiz, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Substitutes: ${targetMed.name}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    if (targetMed.genericName.isNotEmpty)
                      Text('Formula: ${targetMed.genericName}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: formula.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Is dawa ka Generic Formula enter nahi hai.\nInventory mein ja kar Generic Name add karein.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                : alternatives.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Formula "${targetMed.genericName}" ka koi doosra brand system mein nahi mila.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: alternatives.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final alt = alternatives[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            title: Text(alt.medicine.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            subtitle: Text(
                              '${alt.medicine.manufacturer.isNotEmpty ? '${alt.medicine.manufacturer} • ' : ''}'
                              '${Formatters.currency(alt.medicine.salePrice, symbol: symbol)} / ${alt.medicine.unit}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StockStatusBadge(
                                  status: alt.status,
                                  stock: alt.totalStock,
                                  stockLabel:
                                      '${alt.totalStock} ${alt.medicine.unit}',
                                ),
                                const SizedBox(width: 8),
                                if (alt.hasStock)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                    ),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      widget.onAdd(alt.medicine);
                                    },
                                    child: const Text('Add',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

// ─── Cart panel ──────────────────────────────────────────────────────────────

class _CartPanel extends ConsumerWidget {
  final PosSession cart;
  final String symbol;
  final TextEditingController discountCtrl;
  final TextEditingController taxRateCtrl;
  final TextEditingController paidCtrl;
  final TextEditingController notesCtrl;
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onPaidEdited; // called when user manually changes paid
  final String? errorMsg;
  final ValueChanged<String> onBarcode;
  final VoidCallback onCheckout;

  const _CartPanel({
    required this.cart,
    required this.symbol,
    required this.discountCtrl,
    required this.taxRateCtrl,
    required this.paidCtrl,
    required this.notesCtrl,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.onPaidEdited,
    required this.errorMsg,
    required this.onBarcode,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider)
        .where((c) => c.id != Customer.walkInId)
        .toList();

    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // ── barcode field ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: BarcodeField(
              onScanned: onBarcode,
              hint: 'Scan barcode to add item…',
            ),
          ),

          // ── customer selector ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: _CustomerSelector(
              customers: customers,
              currentId: cart.customerId,
              currentName: cart.customerName,
            ),
          ),

          if (errorMsg != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                const Icon(Icons.error,
                    size: 16, color: AppColors.outOfStock),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(errorMsg!,
                        style: const TextStyle(
                            color: AppColors.outOfStock, fontSize: 13))),
              ]),
            ),
          const Divider(height: 1),

          // ── cart items ───────────────────────────────────────────────
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 48, color: AppColors.border),
                        SizedBox(height: 8),
                        Text('Cart is empty',
                            style:
                                TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: cart.items.length,
                    itemBuilder: (context, i) => _CartItemTile(
                        item: cart.items[i],
                        symbol: symbol,
                        index: i),
                  ),
          ),
          const Divider(height: 1),

          // ── totals + payment ─────────────────────────────────────────
          _CartSummary(
            cart: cart,
            symbol: symbol,
            discountCtrl: discountCtrl,
            taxRateCtrl: taxRateCtrl,
            paidCtrl: paidCtrl,
            notesCtrl: notesCtrl,
            paymentMethod: paymentMethod,
            onPaymentMethodChanged: onPaymentMethodChanged,
            onPaidEdited: onPaidEdited,
            onCheckout: onCheckout,
          ),
        ],
      ),
    );
  }
}

// ─── Customer selector (inline in cart) ──────────────────────────────────────

class _CustomerSelector extends ConsumerWidget {
  final List<Customer> customers;
  final String currentId;
  final String currentName;

  const _CustomerSelector({
    required this.customers,
    required this.currentId,
    required this.currentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(posCartProvider.notifier);
    return Row(
      children: [
        const Icon(Icons.person_outline,
            size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: customers.any((c) => c.id == currentId)
                  ? currentId
                  : null,
              hint: Text(currentId == Customer.walkInId
                  ? 'Walk-in Customer'
                  : currentName),
              isExpanded: true,
              isDense: true,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14),
              items: [
                // walk-in option
                const DropdownMenuItem(
                  value: Customer.walkInId,
                  child: Text('Walk-in Customer'),
                ),
                // registered customers
                ...customers.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    )),
              ],
              onChanged: (id) {
                if (id == null) return;
                if (id == Customer.walkInId) {
                  notifier.setCustomer(
                      Customer.walkInId, 'Walk-in Customer');
                } else {
                  final c =
                      customers.firstWhere((c) => c.id == id);
                  notifier.setCustomer(c.id, c.name);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Cart item tile ───────────────────────────────────────────────────────────

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  final String symbol;
  final int index;

  const _CartItemTile(
      {required this.item, required this.symbol, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(posCartProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.medicineName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                    '${item.quantity} ${item.unit}  •  Batch ${item.batchNumber}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                ExpiryBadge(expiryDate: item.expiryDate, size: 11),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.currency(item.lineTotal, symbol: symbol),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.primary,
                  onPressed: item.quantity <= 1
                      ? null
                      : () => notifier.updateLine(
                          index, item.copyWith(quantity: item.quantity - 1)),
                ),
                InkWell(
                  onTap: () =>
                      _showEditQtyDialog(context, notifier, item, index),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('${item.quantity}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.primary,
                  onPressed: item.quantity >= item.availableQty
                      ? null
                      : () => notifier.updateLine(
                          index, item.copyWith(quantity: item.quantity + 1)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.outOfStock,
                  onPressed: () => notifier.removeLine(index),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditQtyDialog(BuildContext context, PosCartNotifier notifier,
      CartItem item, int index) {
    final ctrl = TextEditingController(text: '${item.quantity}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Quantity: ${item.medicineName}'),
        content: SizedBox(
          width: 260,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity (${item.unit})',
              helperText: 'Available: ${item.availableQty} ${item.unit}',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0 && val <= item.availableQty) {
                notifier.updateLine(index, item.copyWith(quantity: val));
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}

// ─── Cart summary / totals ────────────────────────────────────────────────────

class _CartSummary extends StatelessWidget {
  final PosSession cart;
  final String symbol;
  final TextEditingController discountCtrl;
  final TextEditingController taxRateCtrl;
  final TextEditingController paidCtrl;
  final TextEditingController notesCtrl;
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onPaidEdited;
  final VoidCallback onCheckout;

  const _CartSummary({
    required this.cart,
    required this.symbol,
    required this.discountCtrl,
    required this.taxRateCtrl,
    required this.paidCtrl,
    required this.notesCtrl,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.onPaidEdited,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final balance = cart.total - (double.tryParse(paidCtrl.text) ?? cart.total);
    final hasCredit = balance > 0.005;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _SummaryRow('Subtotal',
              Formatters.currency(cart.subtotal, symbol: symbol)),
          // discount row
          Row(children: [
            const Text('Discount',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
            const Spacer(),
            SizedBox(
              width: 90,
              child: TextField(
                controller: discountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6)),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          // tax row
          Row(children: [
            const Text('Tax %',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
            const Spacer(),
            SizedBox(
              width: 70,
              child: TextField(
                controller: taxRateCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6)),
              ),
            ),
          ]),
          if (cart.taxAmount > 0) ...[
            const SizedBox(height: 4),
            _SummaryRow('Tax Amount',
                Formatters.currency(cart.taxAmount, symbol: symbol)),
          ],
          const Divider(height: 12),
          _SummaryRow(
            'TOTAL',
            Formatters.currency(cart.total, symbol: symbol),
            bold: true,
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),

          // payment method + paid amount
          Row(children: [
            const Text('Method',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(width: 6),
            DropdownButton<String>(
              value: paymentMethod,
              underline: const SizedBox.shrink(),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
              items: ['Cash', 'Card', 'Online', 'Credit']
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => onPaymentMethodChanged(v ?? 'Cash'),
            ),
            const Spacer(),
            SizedBox(
              width: 115,
              child: TextField(
                controller: paidCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.right,
                onChanged: (_) => onPaidEdited(), // mark as user-edited
                decoration: const InputDecoration(
                  labelText: 'Amount Paid',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                ),
              ),
            ),
          ]),

          // credit note
          if (hasCredit)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.nearExpiry.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.nearExpiry.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.nearExpiry),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Credit: ${Formatters.currency(balance, symbol: symbol)} will be added to customer balance',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.nearExpiry),
                  ),
                ),
              ]),
            ),
          if (balance < -0.005)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inStock.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.inStock.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Change / Return to Customer:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inStock)),
                  Text(
                    Formatters.currency(-balance, symbol: symbol),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inStock),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: Text(
                  hasCredit ? 'Complete Sale (Credit)' : 'Complete Sale & Print'),
              onPressed: cart.isEmpty ? null : onCheckout,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor:
                    hasCredit ? AppColors.nearExpiry : AppColors.primary,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _SummaryRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color ?? AppColors.textPrimary,
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      fontSize: bold ? 16 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label,
              style: bold
                  ? style
                  : style.copyWith(color: AppColors.textMuted)),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}

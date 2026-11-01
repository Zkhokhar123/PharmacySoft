import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../core/pack_qty.dart';
import '../../data/models/medicine.dart';
import '../../shared/widgets/app_card.dart';
import '../../state/catalog_providers.dart';
import '../../state/core_providers.dart';
import '../../state/inventory_providers.dart';
import '../../state/purchases_providers.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  final String? initialMedicineId;
  const PurchaseFormScreen({super.key, this.initialMedicineId});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<PurchaseFormScreen> {
  final _notesCtrl = TextEditingController();
  String _supplierId = '';
  String _supplierName = '';
  final List<PurchaseDraftItem> _items = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialMedicineId != null &&
        widget.initialMedicineId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _addLine(initialMedicineId: widget.initialMedicineId);
        }
      });
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one item');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(purchasesProvider.notifier).createPurchase(
            supplierId: _supplierId,
            supplierName: _supplierName,
            draftItems: _items,
            notes: _notesCtrl.text.trim(),
          );
      if (mounted) context.go('/purchases');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  Future<void> _addLine({String? initialMedicineId}) async {
    final item = await showDialog<PurchaseDraftItem>(
      context: context,
      builder: (context) =>
          _AddItemDialog(initialMedicineId: initialMedicineId),
    );
    if (item != null) setState(() => _items.add(item));
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    final symbol = ref.watch(settingsProvider).currencySymbol;
    final total = _items.fold(0.0, (s, i) => s + i.lineTotal);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Purchase / Stock-In'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        leading: BackButton(onPressed: () => context.go('/purchases')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                // ── header card ──────────────────────────────────────────
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Purchase Details',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _supplierId.isEmpty ? null : _supplierId,
                            decoration: const InputDecoration(
                                labelText: 'Supplier (optional)'),
                            hint: const Text('Select supplier'),
                            items: suppliers
                                .map((s) => DropdownMenuItem(
                                    value: s.id, child: Text(s.name)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _supplierId = v ?? '';
                              _supplierName = suppliers
                                      .where((s) => s.id == v)
                                      .firstOrNull
                                      ?.name ??
                                  '';
                            }),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Notes (optional)'),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── items card ───────────────────────────────────────────
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('Items',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                          onPressed: _addLine,
                        ),
                      ]),
                      const SizedBox(height: 12),

                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                                'No items added yet. Tap "Add Item" to begin.',
                                style:
                                    TextStyle(color: AppColors.textMuted)),
                          ),
                        )
                      else ...[
                        // table header
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(flex: 3, child: Text('Medicine', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            Expanded(flex: 2, child: Text('Batch', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            Expanded(flex: 3, child: Text('Stock in', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            SizedBox(width: 90, child: Text('Box rate', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            SizedBox(width: 80, child: Text('Sale/Tab', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            SizedBox(width: 100, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            SizedBox(width: 40),
                          ]),
                        ),
                        const Divider(height: 4),
                        ..._items.asMap().entries.map((e) {
                          final i = e.key;
                          final item = e.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Expanded(flex: 3, child: Text(item.medicineName, style: const TextStyle(fontSize: 13))),
                              Expanded(flex: 2, child: Text(item.batchNumber, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  PackQty.format(
                                    item.quantity,
                                    unitsPerPack: item.unitsPerPack,
                                    unit: item.unit,
                                    packName: item.packName,
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  Formatters.currency(
                                    item.packPurchasePrice > 0
                                        ? item.packPurchasePrice
                                        : item.purchasePrice,
                                    symbol: symbol,
                                  ),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              SizedBox(width: 80, child: Text(Formatters.currency(item.salePrice, symbol: symbol), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                              SizedBox(width: 100, child: Text(Formatters.currency(item.lineTotal, symbol: symbol), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              SizedBox(
                                width: 40,
                                child: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.outOfStock),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => setState(() => _items.removeAt(i)),
                                ),
                              ),
                            ]),
                          );
                        }),
                        const Divider(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Total: ${Formatters.currency(total, symbol: symbol)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                      ],

                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: const TextStyle(
                                color: AppColors.outOfStock)),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => context.go('/purchases'),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.save),
                            label: const Text('Save & Update Stock'),
                            onPressed: _saving ? null : _save,
                          ),
                        ],
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
}

// ── Add item dialog ──────────────────────────────────────────────────────────

class _AddItemDialog extends ConsumerStatefulWidget {
  final String? initialMedicineId;
  const _AddItemDialog({this.initialMedicineId});

  @override
  ConsumerState<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _medicineId;
  String _medicineName = '';
  String _packName = 'Box';
  String _unit = 'Tab';
  final _batchCtrl = TextEditingController();
  final _packQtyCtrl = TextEditingController(text: '1');
  final _unitsPerPackCtrl = TextEditingController(text: '1');
  final _packPurchaseCtrl = TextEditingController(text: '0');
  final _salePriceCtrl = TextEditingController(text: '0');
  DateTime _expiry = DateTime.now().add(const Duration(days: 365));

  int get _packQty => int.tryParse(_packQtyCtrl.text) ?? 0;
  int get _unitsPerPack => PackQty.normalizePackSize(
      int.tryParse(_unitsPerPackCtrl.text) ?? 1);
  int get _totalUnits => PackQty.totalUnits(
      packs: _packQty, unitsPerPack: _unitsPerPack);
  double get _packRate => double.tryParse(_packPurchaseCtrl.text) ?? 0;
  double get _perTabCost => PackQty.perUnitFromPack(_packRate, _unitsPerPack);

  @override
  void initState() {
    super.initState();
    if (widget.initialMedicineId != null &&
        widget.initialMedicineId!.isNotEmpty) {
      _medicineId = widget.initialMedicineId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final medicines = ref.read(medicinesProvider);
        final med = medicines
            .where((m) => m.id == widget.initialMedicineId)
            .firstOrNull;
        if (med != null) {
          setState(() => _applyMedicine(med));
        }
      });
    }
  }

  @override
  void dispose() {
    _batchCtrl.dispose();
    _packQtyCtrl.dispose();
    _unitsPerPackCtrl.dispose();
    _packPurchaseCtrl.dispose();
    _salePriceCtrl.dispose();
    super.dispose();
  }

  void _applyMedicine(Medicine? med) {
    _medicineName = med?.name ?? '';
    _packName = med?.packName ?? 'Box';
    _unit = med?.unit ?? 'Tab';
    final pack = PackQty.normalizePackSize(med?.unitsPerPack ?? 1);
    _unitsPerPackCtrl.text = '$pack';
    _salePriceCtrl.text = (med?.salePrice ?? 0).toString();
    _packPurchaseCtrl.text =
        PackQty.packFromPerUnit(med?.purchasePrice ?? 0, pack)
            .toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(medicinesProvider);
    final symbol = ref.watch(settingsProvider).currencySymbol;

    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Add Item'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _medicineId,
                  decoration:
                      const InputDecoration(labelText: 'Medicine *'),
                  hint: const Text('Select medicine'),
                  items: medicines
                      .map((m) => DropdownMenuItem(
                          value: m.id, child: Text(m.name)))
                      .toList(),
                  validator: (v) => v == null ? 'Required' : null,
                  onChanged: (v) {
                    final med =
                        medicines.where((m) => m.id == v).firstOrNull;
                    setState(() {
                      _medicineId = v;
                      _applyMedicine(med);
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _batchCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Batch Number *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _packQtyCtrl,
                      decoration: InputDecoration(
                          labelText: 'How many $_packName? *'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          (int.tryParse(v ?? '') ?? 0) <= 0
                              ? 'Enter boxes > 0'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitsPerPackCtrl,
                      decoration: InputDecoration(
                          labelText: '$_unit per $_packName *'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          (int.tryParse(v ?? '') ?? 0) <= 0
                              ? 'Must be at least 1'
                              : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _packQty > 0
                        ? 'Stock in: $_packQty $_packName × $_unitsPerPack $_unit = $_totalUnits $_unit'
                        : 'Example: 4 Box × 50 Tab = 200 Tab',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _packPurchaseCtrl,
                      decoration: InputDecoration(
                          labelText: 'Purchase rate per $_packName *'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          double.tryParse(v ?? '') == null
                              ? 'Enter a number'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salePriceCtrl,
                      decoration: InputDecoration(
                          labelText: 'Sale price per $_unit *'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          double.tryParse(v ?? '') == null
                              ? 'Enter a number'
                              : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Cost per $_unit: ${Formatters.currency(_perTabCost, symbol: symbol)}'
                  '  •  Line total: ${Formatters.currency(_packQty * _packRate, symbol: symbol)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.event, color: AppColors.primary),
                  title: Text(
                      'Expiry: ${Formatters.date(_expiry)}'),
                  subtitle: const Text('Tap to change'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expiry,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 3650)),
                    );
                    if (picked != null) setState(() => _expiry = picked);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(PurchaseDraftItem(
              medicineId: _medicineId!,
              medicineName: _medicineName,
              batchNumber: _batchCtrl.text.trim(),
              quantity: _totalUnits,
              packQty: _packQty,
              unitsPerPack: _unitsPerPack,
              packName: _packName,
              unit: _unit,
              purchasePrice: _perTabCost,
              packPurchasePrice: _packRate,
              salePrice: double.parse(_salePriceCtrl.text),
              expiryDate: _expiry.millisecondsSinceEpoch,
            ));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

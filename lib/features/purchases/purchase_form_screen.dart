import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../core/id_generator.dart';
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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddItemDialog(
        initialMedicineId: initialMedicineId,
        onItemAdded: (item) {
          setState(() {
            _items.add(item);
            _error = null;
          });
        },
      ),
    );
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
                        Text('Items (${_items.length})',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                          onPressed: () => _addLine(),
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
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Another Item'),
                              onPressed: () => _addLine(),
                            ),
                            const Spacer(),
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

DateTime? parseExpiryDate(String text) {
  final clean = text.trim();
  if (clean.isEmpty) return null;

  // Format 1: DD/MM/YYYY or DD-MM-YYYY (e.g. 15/12/2026)
  final ddmmyyyy =
      RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$').firstMatch(clean);
  if (ddmmyyyy != null) {
    final d = int.tryParse(ddmmyyyy.group(1)!);
    final m = int.tryParse(ddmmyyyy.group(2)!);
    final y = int.tryParse(ddmmyyyy.group(3)!);
    if (d != null &&
        m != null &&
        y != null &&
        m >= 1 &&
        m <= 12 &&
        d >= 1 &&
        d <= 31) {
      return DateTime(y, m, d, 23, 59, 59);
    }
  }

  // Format 2: DD/MM/YY or DD-MM-YY (e.g. 15/12/26)
  final ddmmyy =
      RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2})$').firstMatch(clean);
  if (ddmmyy != null) {
    final d = int.tryParse(ddmmyy.group(1)!);
    final m = int.tryParse(ddmmyy.group(2)!);
    final y = 2000 + (int.tryParse(ddmmyy.group(3)!) ?? 0);
    if (d != null && m != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
      return DateTime(y, m, d, 23, 59, 59);
    }
  }

  // Format 3: MM/YY or MM-YY (e.g. 12/26 or 05/27)
  final mmyy = RegExp(r'^(\d{1,2})[\/\-](\d{2})$').firstMatch(clean);
  if (mmyy != null) {
    final m = int.tryParse(mmyy.group(1)!);
    final y = 2000 + (int.tryParse(mmyy.group(2)!) ?? 0);
    if (m != null && m >= 1 && m <= 12) {
      final lastDay = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, lastDay, 23, 59, 59);
    }
  }

  // Format 4: MM/YYYY or MM-YYYY (e.g. 12/2026)
  final mmyyyy = RegExp(r'^(\d{1,2})[\/\-](\d{4})$').firstMatch(clean);
  if (mmyyyy != null) {
    final m = int.tryParse(mmyyyy.group(1)!);
    final y = int.tryParse(mmyyyy.group(2)!);
    if (m != null && y != null && m >= 1 && m <= 12) {
      final lastDay = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, lastDay, 23, 59, 59);
    }
  }

  // Format 5: YYYY-MM-DD
  final yyyymmdd =
      RegExp(r'^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$').firstMatch(clean);
  if (yyyymmdd != null) {
    final y = int.tryParse(yyyymmdd.group(1)!);
    final m = int.tryParse(yyyymmdd.group(2)!);
    final d = int.tryParse(yyyymmdd.group(3)!);
    if (d != null &&
        m != null &&
        y != null &&
        m >= 1 &&
        m <= 12 &&
        d >= 1 &&
        d <= 31) {
      return DateTime(y, m, d, 23, 59, 59);
    }
  }

  // Format 6: 4 digits MMYY (e.g. 1226)
  if (clean.length == 4 && int.tryParse(clean) != null) {
    final m = int.parse(clean.substring(0, 2));
    final y = 2000 + int.parse(clean.substring(2, 4));
    if (m >= 1 && m <= 12) {
      final lastDay = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, lastDay, 23, 59, 59);
    }
  }

  // Format 7: 6 digits MMYYYY (e.g. 122026)
  if (clean.length == 6 && int.tryParse(clean) != null) {
    final m = int.parse(clean.substring(0, 2));
    final y = int.parse(clean.substring(2, 6));
    if (m >= 1 && m <= 12) {
      final lastDay = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, lastDay, 23, 59, 59);
    }
  }

  return null;
}

class _AddItemDialog extends ConsumerStatefulWidget {
  final String? initialMedicineId;
  final ValueChanged<PurchaseDraftItem>? onItemAdded;
  const _AddItemDialog({this.initialMedicineId, this.onItemAdded});

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
  late final TextEditingController _expiryCtrl;
  DateTime _expiry = DateTime.now().add(const Duration(days: 365));
  int _sessionAddedCount = 0;

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
    final defaultExp = DateTime.now().add(const Duration(days: 365));
    _expiry = defaultExp;
    _expiryCtrl = TextEditingController(
      text:
          '${defaultExp.month.toString().padLeft(2, '0')}/${defaultExp.year.toString().substring(2)}',
    );

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
    _expiryCtrl.dispose();
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

  PurchaseDraftItem? _buildDraftItem() {
    if (!_formKey.currentState!.validate()) return null;
    if (_medicineId == null || _medicineId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a medicine first')),
      );
      return null;
    }
    final parsedExp = parseExpiryDate(_expiryCtrl.text) ?? _expiry;
    final batchNo = _batchCtrl.text.trim().isEmpty
        ? 'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
        : _batchCtrl.text.trim();

    return PurchaseDraftItem(
      medicineId: _medicineId!,
      medicineName: _medicineName,
      batchNumber: batchNo,
      quantity: _totalUnits,
      packQty: _packQty,
      unitsPerPack: _unitsPerPack,
      packName: _packName,
      unit: _unit,
      purchasePrice: _perTabCost,
      packPurchasePrice: _packRate,
      salePrice: double.tryParse(_salePriceCtrl.text) ?? 0,
      expiryDate: parsedExp.millisecondsSinceEpoch,
    );
  }

  void _resetForNext() {
    setState(() {
      _sessionAddedCount++;
      _medicineId = null;
      _medicineName = '';
      _batchCtrl.clear();
      _packQtyCtrl.text = '1';
      _unitsPerPackCtrl.text = '1';
      _packPurchaseCtrl.text = '0';
      _salePriceCtrl.text = '0';
      final defaultExp = DateTime.now().add(const Duration(days: 365));
      _expiry = defaultExp;
      _expiryCtrl.text =
          '${defaultExp.month.toString().padLeft(2, '0')}/${defaultExp.year.toString().substring(2)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(medicinesProvider);
    final symbol = ref.watch(settingsProvider).currencySymbol;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          const Icon(Icons.add_shopping_cart, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Add Purchase Item'),
          if (_sessionAddedCount > 0) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_sessionAddedCount added',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medicine selector with + Quick Add button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _medicineId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Medicine *',
                          hintText: 'Select medicine',
                        ),
                        items: medicines.map((m) {
                          final sub = m.genericName.isNotEmpty
                              ? ' (${m.genericName})'
                              : '';
                          return DropdownMenuItem(
                            value: m.id,
                            child: Text(
                              '${m.name}$sub',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        validator: (v) =>
                            v == null ? 'Please select a medicine' : null,
                        onChanged: (v) {
                          final med =
                              medicines.where((m) => m.id == v).firstOrNull;
                          setState(() {
                            _medicineId = v;
                            _applyMedicine(med);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Tooltip(
                        message: 'Quickly register a new medicine',
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 14),
                          ),
                          onPressed: () async {
                            final created = await showDialog<Medicine>(
                              context: context,
                              builder: (ctx) =>
                                  const _QuickAddMedicineDialog(),
                            );
                            if (created != null && mounted) {
                              setState(() {
                                _medicineId = created.id;
                                _applyMedicine(created);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Batch Number (auto button)
                TextFormField(
                  controller: _batchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Batch Number',
                    hintText: 'e.g. B-101 (optional, auto if blank)',
                    suffixIcon: TextButton(
                      onPressed: () {
                        final auto =
                            'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                        _batchCtrl.text = auto;
                        setState(() {});
                      },
                      child:
                          const Text('Auto', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Manual Expiry Date field + Calendar button
                TextFormField(
                  controller: _expiryCtrl,
                  decoration: InputDecoration(
                    labelText: 'Expiry Date (MM/YY or MM/YYYY) *',
                    hintText: 'e.g. 12/26 or 12/2026',
                    helperText:
                        'Manual enter: MM/YY (e.g. 12/26) or tap calendar',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month,
                          color: AppColors.primary),
                      tooltip: 'Select from calendar',
                      onPressed: () async {
                        final parsed =
                            parseExpiryDate(_expiryCtrl.text) ?? _expiry;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: parsed.isBefore(DateTime.now())
                              ? DateTime.now()
                              : parsed,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2050),
                        );
                        if (picked != null) {
                          setState(() {
                            _expiry = picked;
                            _expiryCtrl.text =
                                '${picked.month.toString().padLeft(2, '0')}/${picked.year.toString().substring(2)}';
                          });
                        }
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter expiry date (e.g. 12/26)';
                    }
                    if (parseExpiryDate(v) == null) {
                      return 'Invalid format. Use MM/YY (e.g. 12/26) or DD/MM/YYYY';
                    }
                    return null;
                  },
                  onChanged: (v) {
                    final parsed = parseExpiryDate(v);
                    if (parsed != null) _expiry = parsed;
                  },
                ),
                const SizedBox(height: 12),

                // Quantity & Units per pack
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
                              ? 'Enter packs > 0'
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
                        : 'Example: 4 Box × 50 Tab = 200 Tab (or 10 Bottles)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),

                // Purchase Rate & Sale Price
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
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_sessionAddedCount > 0 ? 'Done' : 'Cancel'),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add & Next Item'),
          onPressed: () {
            final item = _buildDraftItem();
            if (item == null) return;
            widget.onItemAdded?.call(item);
            _resetForNext();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.medicineName} added! Enter next item.'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Add & Done'),
          onPressed: () {
            final item = _buildDraftItem();
            if (item == null) return;
            widget.onItemAdded?.call(item);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// ── Quick Add Medicine Dialog ────────────────────────────────────────────────

class _QuickAddMedicineDialog extends ConsumerStatefulWidget {
  const _QuickAddMedicineDialog();

  @override
  ConsumerState<_QuickAddMedicineDialog> createState() =>
      _QuickAddMedicineDialogState();
}

class _QuickAddMedicineDialogState
    extends ConsumerState<_QuickAddMedicineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _genericCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'Tab');
  final _packNameCtrl = TextEditingController(text: 'Box');
  final _unitsPerPackCtrl = TextEditingController(text: '1');
  final _salePriceCtrl = TextEditingController(text: '0');
  final _purchasePriceCtrl = TextEditingController(text: '0');
  String _categoryId = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _genericCtrl.dispose();
    _unitCtrl.dispose();
    _packNameCtrl.dispose();
    _unitsPerPackCtrl.dispose();
    _salePriceCtrl.dispose();
    _purchasePriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.medication, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Quick Add Medicine'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name *',
                    hintText: 'e.g. Hydryllin Syrup, Panadol 500mg',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _genericCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Generic / Formula Name',
                    hintText: 'e.g. Paracetamol, Aminophylline',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId.isEmpty ? null : _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  hint: const Text('Select category'),
                  items: categories
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v ?? ''),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _unitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Base Unit *',
                          hintText: 'Tab / Bottle / ml',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _packNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Pack Name *',
                          hintText: 'Box / Carton / Strip',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitsPerPackCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Units/Pack *',
                          hintText: 'e.g. 1 or 50',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                            ? 'Min 1'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchasePriceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Purchase Rate per Unit',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _salePriceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Sale Rate per Unit',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
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
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final med = Medicine(
              id: IdGenerator.generate('med'),
              name: _nameCtrl.text.trim(),
              genericName: _genericCtrl.text.trim(),
              categoryId: _categoryId,
              unit:
                  _unitCtrl.text.trim().isEmpty ? 'Tab' : _unitCtrl.text.trim(),
              packName: _packNameCtrl.text.trim().isEmpty
                  ? 'Box'
                  : _packNameCtrl.text.trim(),
              unitsPerPack: int.tryParse(_unitsPerPackCtrl.text) ?? 1,
              purchasePrice: double.tryParse(_purchasePriceCtrl.text) ?? 0,
              salePrice: double.tryParse(_salePriceCtrl.text) ?? 0,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            );
            await ref.read(medicinesProvider.notifier).add(med);
            if (context.mounted) Navigator.of(context).pop(med);
          },
          child: const Text('Save & Select'),
        ),
      ],
    );
  }
}

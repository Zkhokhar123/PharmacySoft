import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/id_generator.dart';
import '../../data/models/medicine.dart';
import '../../shared/widgets/app_card.dart';
import '../../state/catalog_providers.dart';
import '../../state/inventory_providers.dart';

class MedicineFormScreen extends ConsumerStatefulWidget {
  final String? medicineId; // null = add new
  const MedicineFormScreen({super.key, this.medicineId});

  @override
  ConsumerState<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends ConsumerState<MedicineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _generic;
  late final TextEditingController _manufacturer;
  late final TextEditingController _barcode;
  late final TextEditingController _description;
  late final TextEditingController _unit;
  late final TextEditingController _packName;
  late final TextEditingController _unitsPerPack;
  late final TextEditingController _salePrice;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _reorderLevel;
  late final TextEditingController _shelfLocation;
  String _categoryId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.medicineId != null
        ? ref
            .read(medicinesProvider)
            .where((m) => m.id == widget.medicineId)
            .firstOrNull
        : null;
    _name = TextEditingController(text: existing?.name ?? '');
    _generic = TextEditingController(text: existing?.genericName ?? '');
    _manufacturer = TextEditingController(text: existing?.manufacturer ?? '');
    _barcode = TextEditingController(text: existing?.barcode ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _unit = TextEditingController(text: existing?.unit ?? 'Tab');
    _packName = TextEditingController(text: existing?.packName ?? 'Box');
    _unitsPerPack = TextEditingController(
        text: (existing?.unitsPerPack ?? 1).toString());
    _salePrice =
        TextEditingController(text: existing?.salePrice.toString() ?? '0');
    _purchasePrice =
        TextEditingController(text: existing?.purchasePrice.toString() ?? '0');
    _reorderLevel =
        TextEditingController(text: existing?.reorderLevel.toString() ?? '10');
    _shelfLocation =
        TextEditingController(text: existing?.shelfLocation ?? '');
    _categoryId = existing?.categoryId ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _name, _generic, _manufacturer, _barcode, _description,
      _unit, _packName, _unitsPerPack, _salePrice, _purchasePrice, _reorderLevel, _shelfLocation,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final isEdit = widget.medicineId != null;
    final medicine = Medicine(
      id: isEdit ? widget.medicineId! : IdGenerator.generate('med'),
      name: _name.text.trim(),
      genericName: _generic.text.trim(),
      categoryId: _categoryId,
      manufacturer: _manufacturer.text.trim(),
      barcode: _barcode.text.trim(),
      description: _description.text.trim(),
      unit: _unit.text.trim().isEmpty ? 'Tab' : _unit.text.trim(),
      packName: _packName.text.trim().isEmpty ? 'Box' : _packName.text.trim(),
      unitsPerPack: int.tryParse(_unitsPerPack.text) ?? 1,
      salePrice: double.tryParse(_salePrice.text) ?? 0,
      purchasePrice: double.tryParse(_purchasePrice.text) ?? 0,
      reorderLevel: int.tryParse(_reorderLevel.text) ?? 0,
      shelfLocation: _shelfLocation.text.trim(),
      createdAt: isEdit
          ? (ref
                  .read(medicinesProvider)
                  .where((m) => m.id == widget.medicineId)
                  .firstOrNull
                  ?.createdAt ??
              DateTime.now().millisecondsSinceEpoch)
          : DateTime.now().millisecondsSinceEpoch,
    );
    if (isEdit) {
      await ref.read(medicinesProvider.notifier).update(medicine);
    } else {
      await ref.read(medicinesProvider.notifier).add(medicine);
    }
    if (mounted) {
      context.go(isEdit ? '/inventory/detail/${medicine.id}' : '/inventory');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final isEdit = widget.medicineId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Medicine' : 'Add Medicine'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        leading: BackButton(
          onPressed: () =>
              isEdit ? context.go('/inventory/detail/${widget.medicineId}') : context.go('/inventory'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Form(
              key: _formKey,
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Product Information',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    _row([
                      _field(_name, 'Medicine Name *',
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null),
                      _field(_generic, 'Generic Name'),
                    ]),
                    const SizedBox(height: 14),
                    _row([
                      _field(_manufacturer, 'Manufacturer'),
                      _field(_barcode, 'Barcode'),
                    ]),
                    const SizedBox(height: 14),
                    _row([
                      _field(_unit, 'Base unit (Tab / ml / Bottle)'),
                      _dropdown(categories, 'Category'),
                    ]),
                    const SizedBox(height: 14),
                    _row([
                      _field(_packName, 'Pack name (Box / Daba / Strip)'),
                      _field(_unitsPerPack, 'Tabs per box (e.g. 50)',
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              (int.tryParse(v ?? '') ?? 0) <= 0
                                  ? 'Must be at least 1'
                                  : null),
                    ]),
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Example: 1 Box = 50 Tab. Buying 4 boxes adds 200 Tab to stock.',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _field(_description, 'Description (optional)',
                        maxLines: 2),
                    const SizedBox(height: 20),
                    const Text('Pricing & Stock',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    _row([
                      _field(_salePrice, 'Sale price per Tab',
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              double.tryParse(v ?? '') == null ? 'Enter a number' : null),
                      _field(_purchasePrice, 'Purchase price per Tab',
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              double.tryParse(v ?? '') == null ? 'Enter a number' : null),
                    ]),
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Box rate is calculated automatically: tabs-per-box × per-tab price.',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _row([
                      _field(
                        _reorderLevel,
                        'Reorder Level (low-stock threshold)',
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            int.tryParse(v ?? '') == null ? 'Enter a whole number' : null,
                      ),
                      _field(_shelfLocation, 'Shelf / Rack Location (e.g. Rack A-2, Drawer 1)'),
                    ]),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => isEdit
                              ? context.go('/inventory/detail/${widget.medicineId}')
                              : context.go('/inventory'),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save),
                          label: Text(isEdit ? 'Update' : 'Add Medicine'),
                          onPressed: _saving ? null : _save,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i < children.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _dropdown(List categories, String label) {
    return DropdownButtonFormField<String>(
      initialValue: _categoryId.isEmpty ? null : _categoryId,
      decoration: InputDecoration(labelText: label),
      hint: const Text('Select category'),
      items: categories
          .map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name)))
          .toList(),
      onChanged: (v) => setState(() => _categoryId = v ?? ''),
    );
  }
}

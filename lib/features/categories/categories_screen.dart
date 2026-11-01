import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/id_generator.dart';
import '../../data/models/category.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/catalog_providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text('Add', style: TextStyle(color: AppColors.primary)),
            onPressed: () => _showForm(context, ref, null),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: categories.isEmpty
          ? EmptyState(
              icon: Icons.category_outlined,
              title: 'No categories yet',
              action: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
                onPressed: () => _showForm(context, ref, null),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              itemBuilder: (context, i) {
                final cat = categories[i];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(cat.colorValue).withValues(alpha: 0.2),
                        child: Icon(Icons.category, color: Color(cat.colorValue)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15)),
                            if (cat.description.isNotEmpty)
                              Text(cat.description,
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: AppColors.primary,
                        onPressed: () => _showForm(context, ref, cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppColors.outOfStock,
                        onPressed: () async {
                          final ok = await showConfirmDialog(
                            context,
                            title: 'Delete Category',
                            message: 'Delete "${cat.name}"?',
                            confirmText: 'Delete',
                            isDestructive: true,
                          );
                          if (ok) {
                            await ref
                                .read(categoriesProvider.notifier)
                                .remove(cat.id);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Category? existing) {
    showDialog(
      context: context,
      builder: (context) => _CategoryFormDialog(existing: existing),
    );
  }
}

class _CategoryFormDialog extends ConsumerStatefulWidget {
  final Category? existing;
  const _CategoryFormDialog({this.existing});

  @override
  ConsumerState<_CategoryFormDialog> createState() =>
      _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _description =
        TextEditingController(text: widget.existing?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final category = Category(
      id: widget.existing?.id ?? IdGenerator.generate('cat'),
      name: _name.text.trim(),
      description: _description.text.trim(),
      colorValue: widget.existing?.colorValue ?? 0xFF0D9488,
    );
    if (widget.existing != null) {
      await ref.read(categoriesProvider.notifier).update(category);
    } else {
      await ref.read(categoriesProvider.notifier).add(category);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(widget.existing != null ? 'Edit Category' : 'Add Category'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Category Name *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
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
          child: Text(widget.existing != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}

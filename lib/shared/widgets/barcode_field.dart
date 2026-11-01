import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// A text field optimised for barcode entry. USB/Bluetooth barcode scanners
/// act as keyboards: they type the code quickly and finish with Enter, which
/// triggers [onScanned]. Manual entry + Enter also works. The field keeps
/// focus and clears itself after each scan so scanning can continue.
class BarcodeField extends StatefulWidget {
  final ValueChanged<String> onScanned;
  final String? hint;
  final bool autofocus;
  final FocusNode? focusNode;

  const BarcodeField({
    super.key,
    required this.onScanned,
    this.hint,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<BarcodeField> createState() => _BarcodeFieldState();
}

class _BarcodeFieldState extends State<BarcodeField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final code = value.trim();
    if (code.isEmpty) return;
    widget.onScanned(code);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onSubmitted: _submit,
      style: const TextStyle(fontSize: 16, letterSpacing: 1.2),
      decoration: InputDecoration(
        hintText: widget.hint ?? 'Scan or type barcode, then Enter',
        hintStyle: const TextStyle(letterSpacing: 0),
        prefixIcon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search, color: AppColors.primary),
          onPressed: () => _submit(_controller.text),
        ),
      ),
      textInputAction: TextInputAction.done,
    );
  }
}

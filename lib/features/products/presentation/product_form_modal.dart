import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../domain/barcode_gen.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';
import 'product_thumb.dart';

bool get _isMobile =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Opens the product modal. Pass [product] to edit an existing one; otherwise it
/// creates a new product. Returns true if saved.
Future<bool?> showProductFormModal(
  BuildContext context, {
  String? prefilledBarcode,
  Product? product,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ProductFormModal(prefilledBarcode: prefilledBarcode, product: product),
  );
}

/// Create or edit a product in a popup modal (Req 2.1, 2.3).
class _ProductFormModal extends ConsumerStatefulWidget {
  const _ProductFormModal({this.prefilledBarcode, this.product});

  final String? prefilledBarcode;
  final Product? product;

  @override
  ConsumerState<_ProductFormModal> createState() => _ProductFormModalState();
}

class _ProductFormModalState extends ConsumerState<_ProductFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _barcode = TextEditingController(
      text: widget.product?.barcode ?? widget.prefilledBarcode ?? '');
  late final _price = TextEditingController(
      text: widget.product != null ? '${widget.product!.price}' : '');
  late final _cost = TextEditingController(
      text: widget.product != null ? '${widget.product!.cost}' : '');
  late final _stock = TextEditingController(
      text: '${widget.product?.stockQuantity ?? 0}');
  final _picker = ImagePicker();
  late String? _image = widget.product?.image;
  bool _busy = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    // Auto-generate a barcode for new products (no scanner in use).
    if (!_isEdit && _barcode.text.trim().isEmpty) {
      _barcode.text = generateBarcode();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _price.dispose();
    _cost.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 60,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _image = base64Encode(bytes));
    } catch (_) {
      if (!mounted) return;
      AppSnack.error(context, 'Could not load image.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(productRepositoryProvider);
    if (repo == null) return;

    setState(() => _busy = true);
    try {
      final base = widget.product ?? const Product(
            id: '_',
            name: '',
            barcode: '',
            price: 0,
            cost: 0,
            stockQuantity: 0,
          );
      final product = base.copyWith(
        name: _name.text.trim(),
        barcode: _barcode.text.trim(),
        price: double.tryParse(_price.text) ?? 0,
        cost: double.tryParse(_cost.text) ?? 0,
        stockQuantity: int.tryParse(_stock.text) ?? 0,
        image: _image,
      );

      if (_isEdit) {
        await repo.update(product);
      } else {
        await repo.create(product);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ProductValidationException catch (e) {
      AppSnack.error(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit product' : 'New product'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ImagePickerRow(
                  image: _image,
                  onChoose: () => _pick(ImageSource.gallery),
                  onCamera: _isMobile ? () => _pick(ImageSource.camera) : null,
                  onClear:
                      _image == null ? null : () => setState(() => _image = null),
                ),
                const SizedBox(height: 16),
                _field(_name, 'Name'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _barcode,
                    decoration: InputDecoration(
                      labelText: 'Barcode',
                      helperText: _isEdit
                          ? null
                          : 'Auto-generated. Tap the icon to regenerate.',
                      suffixIcon: IconButton(
                        tooltip: 'Generate new barcode',
                        icon: const Icon(Icons.autorenew),
                        onPressed: () => setState(
                            () => _barcode.text = generateBarcode()),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Barcode is required'
                        : null,
                  ),
                ),
                _field(
                  _price,
                  'Price',
                  number: true,
                  helper: 'What the customer pays (selling price).',
                ),
                _field(
                  _cost,
                  'Cost',
                  number: true,
                  helper: 'What you pay the supplier (buying price).',
                ),
                _field(_stock, 'Stock quantity', number: true),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEdit ? 'Save changes' : 'Save product'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool number = false,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, helperText: helper),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? '$label is required' : null,
      ),
    );
  }
}

class _ImagePickerRow extends StatelessWidget {
  const _ImagePickerRow({
    required this.image,
    required this.onChoose,
    required this.onCamera,
    required this.onClear,
  });

  final String? image;
  final VoidCallback onChoose;
  final VoidCallback? onCamera;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductThumb(image: image, size: 76),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Product photo',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onChoose,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Choose'),
                  ),
                  if (onCamera != null)
                    OutlinedButton.icon(
                      onPressed: onCamera,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Camera'),
                    ),
                  if (onClear != null)
                    TextButton.icon(
                      onPressed: onClear,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

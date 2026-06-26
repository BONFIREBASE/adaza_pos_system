import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_nav_scaffold.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/skeleton.dart';
import '../products/domain/product.dart';
import 'label_service.dart';
import 'labels_controller.dart';

/// A4/Letter/Long label designer: tap a product to drop its barcode, drag to
/// position, pick paper size, then print. Layout persists across navigation.
class LabelsScreen extends ConsumerWidget {
  const LabelsScreen({super.key});

  static const double _labelWFrac = 0.30;

  Future<void> _print(BuildContext context, LabelsState s) async {
    if (s.placed.isEmpty) {
      AppSnack.info(context, 'Add at least one barcode to the page.');
      return;
    }
    final format =
        s.landscape ? s.paper.format.landscape : s.paper.format.portrait;
    try {
      await Printing.layoutPdf(
        name: 'Adaza Labels',
        format: format,
        onLayout: (_) => LabelService.designed(
          format: format,
          items: s.placed
              .map((p) => LabelPlacement(
                    code: p.product.barcode,
                    xFrac: p.x,
                    yFrac: p.y,
                    wFrac: _labelWFrac,
                  ))
              .toList(),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        AppSnack.error(context, 'Could not generate the sheet.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(productRepositoryProvider);
    final state = ref.watch(labelsControllerProvider);
    final controller = ref.read(labelsControllerProvider.notifier);
    final isWide = MediaQuery.sizeOf(context).width >= 760;

    return AppNavScaffold(
      title: 'Labels',
      currentRoute: '/labels',
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<PaperSize>(
              value: state.paper,
              borderRadius: BorderRadius.circular(12),
              items: [
                for (final p in PaperSize.values)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (v) =>
                  controller.setPaper(v ?? PaperSize.a4),
            ),
          ),
        ),
        IconButton(
          tooltip: state.landscape ? 'Landscape' : 'Portrait',
          icon: Icon(state.landscape
              ? Icons.crop_landscape_outlined
              : Icons.crop_portrait_outlined),
          onPressed: () => controller.setLandscape(!state.landscape),
        ),
        const SizedBox(width: 8),
        if (state.placed.isNotEmpty)
          TextButton.icon(
            onPressed: controller.clear,
            icon: const Icon(Icons.layers_clear_outlined, size: 18),
            label: const Text('Clear'),
          ),
        TextButton.icon(
          onPressed: () => _print(context, state),
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Print'),
        ),
      ],
      body: repo == null
          ? const SkeletonList()
          : _SearchableBody(
              isWide: isWide,
              state: state,
              controller: controller,
              labelWFrac: _labelWFrac,
            ),
    );
  }
}

class _SearchableBody extends ConsumerStatefulWidget {
  const _SearchableBody({
    required this.isWide,
    required this.state,
    required this.controller,
    required this.labelWFrac,
  });

  final bool isWide;
  final LabelsState state;
  final LabelsController controller;
  final double labelWFrac;

  @override
  ConsumerState<_SearchableBody> createState() => _SearchableBodyState();
}

class _SearchableBodyState extends ConsumerState<_SearchableBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(productRepositoryProvider)!;
    return StreamBuilder<List<Product>>(
      stream: repo.watchProducts(),
      builder: (context, snap) {
        if (!snap.hasData) return const SkeletonList();
        final products = snap.data!
            .where((p) =>
                p.name.toLowerCase().contains(_query) ||
                p.barcode.contains(_query))
            .toList()
          ..sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        final panel = _ProductsPanel(
          products: products,
          onAdd: widget.controller.add,
          onSearch: (v) => setState(() => _query = v.toLowerCase()),
        );
        final canvas = _Canvas(
          placed: widget.state.placed,
          labelWFrac: widget.labelWFrac,
          ratio: widget.state.ratio,
          paperLabel: widget.state.paper.label,
          onMove: widget.controller.move,
          onRemove: widget.controller.remove,
        );

        if (widget.isWide) {
          return Row(
            children: [
              SizedBox(width: 280, child: panel),
              const VerticalDivider(width: 1),
              Expanded(child: canvas),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(height: 170, child: panel),
            const Divider(height: 1),
            Expanded(child: canvas),
          ],
        );
      },
    );
  }
}

class _ProductsPanel extends StatelessWidget {
  const _ProductsPanel({
    required this.products,
    required this.onAdd,
    required this.onSearch,
  });
  final List<Product> products;
  final ValueChanged<Product> onAdd;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search),
              hintText: 'Search products',
            ),
            onChanged: onSearch,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('Tap a product to add its barcode to the page',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('No products.'))
              : ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final p = products[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onAdd(p),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              BarcodeWidget(
                                barcode: Barcode.code128(),
                                data: p.barcode,
                                width: 84,
                                height: 32,
                                drawText: false,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              const Icon(Icons.add_circle_outline,
                                  color: AppColors.teal, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Canvas extends StatefulWidget {
  const _Canvas({
    required this.placed,
    required this.labelWFrac,
    required this.ratio,
    required this.paperLabel,
    required this.onMove,
    required this.onRemove,
  });

  final List<PlacedLabel> placed;
  final double labelWFrac;
  final double ratio; // page width / height
  final String paperLabel;
  final void Function(int id, double xFrac, double yFrac) onMove;
  final ValueChanged<int> onRemove;

  @override
  State<_Canvas> createState() => _CanvasState();
}

class _CanvasState extends State<_Canvas> {
  final TransformationController _tc = TransformationController();
  double _scale = 1;

  double get _currentScale => _tc.value.getMaxScaleOnAxis();

  void _setScale(double s) {
    setState(() {
      _scale = s.clamp(0.5, 4.0);
      _tc.value = Matrix4.diagonal3Values(_scale, _scale, 1);
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cream,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _tc,
              minScale: 0.5,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(120),
              onInteractionEnd: (_) {
                final s = _currentScale;
                if ((s - _scale).abs() > 0.001) setState(() => _scale = s);
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _sheet(),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _ZoomBar(
              scale: _scale,
              onIn: () => _setScale(_scale * 1.25),
              onOut: () => _setScale(_scale / 1.25),
              onReset: () => _setScale(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheet() {
    return Center(
      child: LayoutBuilder(
        builder: (context, c) {
          var w = c.maxWidth;
          var h = w / widget.ratio;
          final maxH = c.maxHeight.isFinite ? c.maxHeight : double.infinity;
          if (h > maxH) {
            h = maxH;
            w = h * widget.ratio;
          }
          final labelW = w * widget.labelWFrac;
          final labelH = labelW * 0.42;

          return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (widget.placed.isEmpty)
                  Center(
                    child: Text(
                      '${widget.paperLabel} sheet\n'
                      'Tap a product on the left to add its barcode',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textSecondary, height: 1.5),
                    ),
                  ),
                for (final p in widget.placed)
                  Positioned(
                    left: p.x * w,
                    top: p.y * h,
                    child: _DragLabel(
                      key: ValueKey(p.id),
                      product: p.product,
                      width: labelW,
                      height: labelH,
                      baseLeft: p.x * w,
                      baseTop: p.y * h,
                      maxLeft: w - labelW,
                      maxTop: h - labelH,
                      scaleOf: () => _currentScale,
                      onCommit: (left, top) => widget.onMove(
                        p.id,
                        (left / w).clamp(0.0, 1 - widget.labelWFrac),
                        (top / h).clamp(0.0, 1 - (labelH / h)),
                      ),
                      onRemove: () => widget.onRemove(p.id),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ZoomBar extends StatelessWidget {
  const _ZoomBar({
    required this.scale,
    required this.onIn,
    required this.onOut,
    required this.onReset,
  });
  final double scale;
  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'Zoom out',
              onPressed: onOut,
            ),
            InkWell(
              onTap: onReset,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('${(scale * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Zoom in',
              onPressed: onIn,
            ),
          ],
        ),
      ),
    );
  }
}

class _DragLabel extends StatefulWidget {
  const _DragLabel({
    super.key,
    required this.product,
    required this.width,
    required this.height,
    required this.baseLeft,
    required this.baseTop,
    required this.maxLeft,
    required this.maxTop,
    required this.scaleOf,
    required this.onCommit,
    required this.onRemove,
  });

  final Product product;
  final double width;
  final double height;
  final double baseLeft;
  final double baseTop;
  final double maxLeft;
  final double maxTop;
  final double Function() scaleOf;
  final void Function(double left, double top) onCommit;
  final VoidCallback onRemove;

  @override
  State<_DragLabel> createState() => _DragLabelState();
}

class _DragLabelState extends State<_DragLabel> {
  // Local drag offset (px) relative to the committed base position. Tracking it
  // locally keeps dragging smooth; we commit to shared state on release.
  Offset _offset = Offset.zero;

  void _onUpdate(DragUpdateDetails e) {
    final scale = widget.scaleOf();
    final dx = e.delta.dx / scale;
    final dy = e.delta.dy / scale;
    setState(() {
      final nl =
          (widget.baseLeft + _offset.dx + dx).clamp(0.0, widget.maxLeft);
      final nt = (widget.baseTop + _offset.dy + dy).clamp(0.0, widget.maxTop);
      _offset = Offset(nl - widget.baseLeft, nt - widget.baseTop);
    });
  }

  void _onEnd(DragEndDetails _) {
    widget.onCommit(widget.baseLeft + _offset.dx, widget.baseTop + _offset.dy);
    _offset = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _offset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: _onUpdate,
        onPanEnd: _onEnd,
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: SizedBox(
            width: widget.width,
            height: widget.height + 6,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: widget.width,
                  height: widget.height,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: widget.product.barcode,
                    drawText: true,
                    style: const TextStyle(fontSize: 8, letterSpacing: 1),
                  ),
                ),
                Positioned(
                  right: -8,
                  top: -8,
                  child: GestureDetector(
                    onTap: widget.onRemove,
                    child: const CircleAvatar(
                      radius: 9,
                      backgroundColor: AppColors.error,
                      child: Icon(Icons.close, size: 11, color: Colors.white),
                    ),
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

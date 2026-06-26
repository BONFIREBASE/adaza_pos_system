import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../products/domain/product.dart';
import 'label_service.dart';

/// A barcode placed on the designer canvas. Position is fractions (0–1) of the
/// page so it maps cleanly to the printed sheet.
class PlacedLabel {
  const PlacedLabel({
    required this.id,
    required this.product,
    required this.x,
    required this.y,
  });

  final int id;
  final Product product;
  final double x;
  final double y;

  PlacedLabel copyWith({double? x, double? y}) => PlacedLabel(
        id: id,
        product: product,
        x: x ?? this.x,
        y: y ?? this.y,
      );
}

class LabelsState {
  const LabelsState({
    this.placed = const [],
    this.paper = PaperSize.a4,
    this.landscape = false,
    this.nextId = 0,
    this.added = 0,
  });

  final List<PlacedLabel> placed;
  final PaperSize paper;
  final bool landscape;
  final int nextId;
  final int added;

  /// On-screen aspect (width / height) accounting for orientation.
  double get ratio => landscape ? 1 / paper.ratio : paper.ratio;

  LabelsState copyWith({
    List<PlacedLabel>? placed,
    PaperSize? paper,
    bool? landscape,
    int? nextId,
    int? added,
  }) =>
      LabelsState(
        placed: placed ?? this.placed,
        paper: paper ?? this.paper,
        landscape: landscape ?? this.landscape,
        nextId: nextId ?? this.nextId,
        added: added ?? this.added,
      );
}

/// Holds the label-designer layout so it persists while navigating between
/// pages within the session.
class LabelsController extends Notifier<LabelsState> {
  @override
  LabelsState build() => const LabelsState();

  void add(Product product) {
    final i = state.added;
    final col = i % 2;
    final row = (i ~/ 2) % 7;
    final placed = [
      ...state.placed,
      PlacedLabel(
        id: state.nextId,
        product: product,
        x: col == 0 ? 0.07 : 0.55,
        y: 0.04 + row * 0.13,
      ),
    ];
    state = state.copyWith(
      placed: placed,
      nextId: state.nextId + 1,
      added: state.added + 1,
    );
  }

  void move(int id, double x, double y) {
    state = state.copyWith(
      placed: [
        for (final p in state.placed)
          if (p.id == id) p.copyWith(x: x, y: y) else p,
      ],
    );
  }

  void remove(int id) {
    state = state.copyWith(
      placed: state.placed.where((p) => p.id != id).toList(),
    );
  }

  void clear() => state = state.copyWith(placed: const [], added: 0);

  void setPaper(PaperSize paper) => state = state.copyWith(paper: paper);

  void setLandscape(bool landscape) =>
      state = state.copyWith(landscape: landscape);
}

final labelsControllerProvider =
    NotifierProvider<LabelsController, LabelsState>(LabelsController.new);

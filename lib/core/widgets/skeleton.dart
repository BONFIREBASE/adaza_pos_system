import 'package:flutter/material.dart';

/// A shimmering placeholder box used for skeleton loading states.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
    this.shape = BoxShape.rectangle,
  });

  /// Circular avatar-style skeleton.
  const Skeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = 0,
        shape = BoxShape.circle;

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.radius)
                : null,
            gradient: LinearGradient(
              colors: const [
                Color(0xFFEAE3D4),
                Color(0xFFF6F1E6),
                Color(0xFFEAE3D4),
              ],
              stops: const [0.1, 0.3, 0.4],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              transform: _SlideGradient(_c.value),
            ),
          ),
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);
  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Sweep the highlight from left to right across the box.
    final dx = (t * 2 - 1) * bounds.width * 1.5;
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// A card-shaped skeleton matching the dashboard stat cards.
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key, this.width});
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 36, height: 36, radius: 10),
              SizedBox(height: 14),
              Skeleton(width: 110, height: 22),
              SizedBox(height: 8),
              Skeleton(width: 80, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// A skeleton list-row (avatar + two lines + trailing) for list screens.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Skeleton(width: 44, height: 44, radius: 10),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 180, height: 14),
                SizedBox(height: 8),
                Skeleton(width: 120, height: 12),
              ],
            ),
          ),
          SizedBox(width: 14),
          Skeleton(width: 64, height: 16),
        ],
      ),
    );
  }
}

/// A vertical list of [SkeletonListTile]s.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: count,
      itemBuilder: (_, __) => const SkeletonListTile(),
    );
  }
}

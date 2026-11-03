import 'package:flutter/material.dart';

/// Widget khung xương đang tải (Skeleton Shimmer Loading Card)
class ShimmerLoadingCard extends StatefulWidget {
  final double height;
  final double width;
  final double borderRadius;

  const ShimmerLoadingCard({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.borderRadius = 16,
  });

  @override
  State<ShimmerLoadingCard> createState() => _ShimmerLoadingCardState();
}

class _ShimmerLoadingCardState extends State<ShimmerLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

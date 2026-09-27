import 'package:flutter/material.dart';

class PulsingRingMarker extends StatefulWidget {
  final double size;
  final Color color;

  const PulsingRingMarker({
    super.key,
    this.size = 56.0,
    this.color = const Color(0xFF086C61),
  });

  @override
  State<PulsingRingMarker> createState() => _PulsingRingMarkerState();
}

class _PulsingRingMarkerState extends State<PulsingRingMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final scale = 1.0 + (progress * 0.8);
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withValues(alpha: opacity * 0.6),
                width: 2.0,
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

class RatingStarsWidget extends StatelessWidget {
  final double rating;
  final bool interactive;
  final ValueChanged<int>? onRatingChanged;
  final double size;
  final Color? selectedColor;
  final Color? unselectedColor;
  final bool enabled;

  const RatingStarsWidget({
    super.key,
    required this.rating,
    this.interactive = false,
    this.onRatingChanged,
    this.size = 24,
    this.selectedColor,
    this.unselectedColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = rating.clamp(0, 5).toDouble();
    final label = interactive ? 'Chọn mức đánh giá' : '$clamped trên 5 sao';
    return Semantics(
      label: label,
      container: true,
      child: SizedBox(
        width: interactive ? 240 : size * 5,
        height: interactive ? 48 : size,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 1; index <= 5; index++)
              _star(context, index, clamped),
          ],
        ),
      ),
    );
  }

  Widget _star(BuildContext context, int index, double value) {
    final filled = value >= index;
    final half = !filled && value > index - 0.5;
    final icon = filled
        ? Icons.star
        : half
        ? Icons.star_half
        : Icons.star_border;
    final iconWidget = Icon(
      icon,
      size: size,
      color: filled || half
          ? selectedColor ?? Colors.amber.shade700
          : unselectedColor ?? Theme.of(context).colorScheme.outline,
    );
    if (!interactive || onRatingChanged == null) return iconWidget;
    return Semantics(
      button: true,
      label: '$index sao',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onRatingChanged!(index) : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: iconWidget),
          ),
        ),
      ),
    );
  }
}

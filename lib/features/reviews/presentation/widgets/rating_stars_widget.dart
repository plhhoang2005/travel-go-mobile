import 'package:flutter/material.dart';

/// Reusable widget for rating stars (1 to 5 stars), supporting both read-only
/// display (fractional/half-stars) and interactive star selection (48dp touch targets).
/// Unified for Place Reviews (Member 3) and Trip Community (Member 4).
class RatingStarsWidget extends StatelessWidget {
  final double rating;
  final ValueChanged<int>? onRatingChanged;
  final double size;
  final Color? color;
  final bool? interactive;
  final Color? activeColor;
  final Color? unselectedColor;

  const RatingStarsWidget({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.size = 24,
    this.color,
    this.interactive,
    this.activeColor,
    this.unselectedColor,
  });

  bool get isInteractive => (interactive ?? false) || onRatingChanged != null;

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? activeColor ?? Theme.of(context).colorScheme.tertiary;
    final emptyColor = unselectedColor ?? Theme.of(context).colorScheme.outlineVariant;
    final clamped = rating.clamp(0, 5).toDouble();

    return Semantics(
      label: isInteractive
          ? 'Chọn mức đánh giá, hiện tại ${clamped.round()} trên 5 sao'
          : 'Đánh giá ${clamped.toStringAsFixed(1)} trên 5 sao',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final value = index + 1;
          final filled = clamped >= value;
          final half = !filled && clamped >= value - 0.5;
          final icon = filled
              ? Icons.star_rounded
              : half
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded;

          final iconWidget = Icon(
            icon,
            size: size,
            color: filled || half ? starColor : emptyColor,
          );

          if (!isInteractive || onRatingChanged == null) {
            return ExcludeSemantics(child: iconWidget);
          }

          final selected = value <= clamped.round();
          return Semantics(
            button: true,
            selected: selected,
            label: '$value sao',
            child: IconButton(
              key: ValueKey('rating-star-$value'),
              tooltip: 'Chọn $value sao',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: EdgeInsets.zero,
              onPressed: () => onRatingChanged!(value),
              icon: ExcludeSemantics(
                child: iconWidget,
              ),
            ),
          );
        }),
      ),
    );
  }
}

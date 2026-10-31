import 'package:flutter/material.dart';

class RatingStarsWidget extends StatelessWidget {
  final double rating;
  final ValueChanged<int>? onRatingChanged;
  final double size;
  final Color? color;

  const RatingStarsWidget({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.size = 24,
    this.color,
  });

  bool get isInteractive => onRatingChanged != null;

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? Theme.of(context).colorScheme.tertiary;
    final clamped = rating.clamp(0, 5).toDouble();
    return Semantics(
      label: isInteractive
          ? 'Chọn mức đánh giá, hiện tại ${clamped.round()} trên 5 sao'
          : 'Đánh giá ${clamped.toStringAsFixed(1)} trên 5 sao',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final value = index + 1;
          final difference = clamped - index;
          final icon = difference >= 1
              ? Icons.star_rounded
              : difference >= .5
              ? Icons.star_half_rounded
              : Icons.star_border_rounded;
          if (!isInteractive) {
            return ExcludeSemantics(
              child: Icon(icon, size: size, color: starColor),
            );
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
                child: Icon(
                  selected ? Icons.star_rounded : Icons.star_border_rounded,
                  size: size,
                  color: starColor,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

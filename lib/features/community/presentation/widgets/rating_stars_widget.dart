import 'package:flutter/material.dart';

/// Widget hiển thị và tương tác chấm điểm sao (1 - 5 sao) cho Chuyến đi Cộng đồng.
/// Tương thích hoàn toàn với giao diện tiêu chuẩn mà không phụ thuộc vào nhánh chưa merge.
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
    final starSelectedColor = selectedColor ?? const Color(0xFFF59E0B); // Amber 500
    final starUnselectedColor =
        unselectedColor ?? Theme.of(context).colorScheme.outlineVariant;

    return Semantics(
      label: label,
      container: true,
      child: SizedBox(
        width: interactive ? (size + 16) * 5 : size * 5,
        height: interactive ? size + 16 : size,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 1; index <= 5; index++)
              _buildStar(
                context,
                index: index,
                clampedRating: clamped,
                selectedColor: starSelectedColor,
                unselectedColor: starUnselectedColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStar(
    BuildContext context, {
    required int index,
    required double clampedRating,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    final filled = clampedRating >= index;
    final half = !filled && clampedRating >= index - 0.5;
    final icon = filled
        ? Icons.star_rounded
        : half
            ? Icons.star_half_rounded
            : Icons.star_outline_rounded;

    final iconWidget = Icon(
      icon,
      size: size,
      color: filled || half ? selectedColor : unselectedColor,
    );

    if (!interactive || onRatingChanged == null) {
      return iconWidget;
    }

    return Semantics(
      button: true,
      label: '$index sao',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onRatingChanged!(index) : null,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: iconWidget,
          ),
        ),
      ),
    );
  }
}

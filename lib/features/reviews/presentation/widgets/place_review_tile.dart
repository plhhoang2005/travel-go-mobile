import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/place_review.dart';
import 'rating_stars_widget.dart';

class PlaceReviewTile extends StatefulWidget {
  final PlaceReview review;
  const PlaceReviewTile({super.key, required this.review});

  @override
  State<PlaceReviewTile> createState() => _PlaceReviewTileState();
}

class _PlaceReviewTileState extends State<PlaceReviewTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final localDate = review.createdAt.toLocal();
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Kiểm tra độ tràn dòng với TextPainter giới hạn 3 dòng
        final span = TextSpan(text: review.content, style: textStyle);
        final maxWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 320.0;
        final tp = TextPainter(
          text: span,
          textDirection: Directionality.of(context),
          maxLines: 3,
        )..layout(maxWidth: maxWidth);

        final isLongContent = tp.didExceedMaxLines ||
            review.content.split('\n').length > 3 ||
            review.content.length > 120;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        review.reviewerDisplayName.trim().isNotEmpty
                            ? review.reviewerDisplayName.trim()[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.reviewerDisplayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(localDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    RatingStarsWidget(rating: review.rating.toDouble(), size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  review.content,
                  maxLines: _isExpanded ? null : 3,
                  overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: textStyle,
                ),
                if (isLongContent) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    key: const ValueKey('review_expand_collapse_button'),
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _isExpanded ? 'Thu gọn' : 'Xem thêm',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

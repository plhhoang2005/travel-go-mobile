import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/place_review.dart';
import 'rating_stars_widget.dart';

class PlaceReviewTile extends StatelessWidget {
  final PlaceReview review;
  const PlaceReviewTile({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final localDate = review.createdAt.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  review.reviewerDisplayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                DateFormat('dd/MM/yyyy').format(localDate),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          RatingStarsWidget(rating: review.rating.toDouble(), size: 20),
          const SizedBox(height: 8),
          Text(review.content),
        ],
      ),
    );
  }
}

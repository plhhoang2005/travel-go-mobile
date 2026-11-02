import 'dart:async';

import 'package:flutter/material.dart';

import '../../providers/place_reviews_provider.dart';
import '../../services/review_service.dart';
import '../screens/place_reviews_list_screen.dart';
import 'rating_stars_widget.dart';
import 'review_input_bottom_sheet.dart';

class PlaceReviewSummaryCard extends StatefulWidget {
  final String placeId;
  final String placeName;
  final ReviewService service;

  const PlaceReviewSummaryCard({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.service,
  });

  @override
  State<PlaceReviewSummaryCard> createState() => _PlaceReviewSummaryCardState();
}

class _PlaceReviewSummaryCardState extends State<PlaceReviewSummaryCard> {
  late final PlaceReviewsProvider _provider = PlaceReviewsProvider(
    service: widget.service,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_provider.load(widget.placeId));
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _writeReview() async {
    if (!_provider.canSubmit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để gửi đánh giá.')),
      );
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReviewInputBottomSheet(
        onSubmit: (rating, comment) => _provider.submit(
          placeId: widget.placeId,
          rating: rating,
          comment: comment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _provider,
    builder: (context, _) {
      if (_provider.state == PlaceReviewsLoadState.loading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(),
        );
      }
      if (_provider.state == PlaceReviewsLoadState.error) {
        return Card(
          child: ListTile(
            title: const Text('Chưa tải được đánh giá'),
            subtitle: Text(_provider.errorMessage ?? 'Có lỗi xảy ra.'),
            trailing: IconButton(
              tooltip: 'Thử lại',
              onPressed: () => _provider.load(widget.placeId, force: true),
              icon: const Icon(Icons.refresh),
            ),
          ),
        );
      }
      final summary = _provider.summary;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Đánh giá ${widget.placeName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (summary.averageRating != null)
                    Text(
                      '${summary.averageRating!.toStringAsFixed(1)}/5',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (summary.totalCount == 0)
                const Text('Chưa có đánh giá nào cho địa điểm này.')
              else ...[
                Row(
                  children: [
                    RatingStarsWidget(rating: summary.averageRating ?? 0),
                    const SizedBox(width: 8),
                    Text('${summary.totalCount} đánh giá'),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _writeReview,
                    child: const Text('Viết đánh giá'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PlaceReviewsListScreen(
                          placeId: widget.placeId,
                          placeName: widget.placeName,
                          provider: _provider,
                        ),
                      ),
                    ),
                    child: Text('Xem tất cả (${summary.totalCount})'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';

import '../../models/place_review.dart';
import '../../providers/place_reviews_provider.dart';
import '../../services/review_service.dart';
import '../widgets/rating_stars_widget.dart';

class PlaceReviewsListScreen extends StatefulWidget {
  final String placeId;
  final String placeName;
  final PlaceReviewsProvider? provider;
  final ReviewService? service;

  const PlaceReviewsListScreen({
    super.key,
    required this.placeId,
    required this.placeName,
    this.provider,
    this.service,
  });

  @override
  State<PlaceReviewsListScreen> createState() => _PlaceReviewsListScreenState();
}

class _PlaceReviewsListScreenState extends State<PlaceReviewsListScreen> {
  late final PlaceReviewsProvider _provider;
  late final bool _ownsProvider;

  @override
  void initState() {
    super.initState();
    _ownsProvider = widget.provider == null;
    _provider =
        widget.provider ??
        PlaceReviewsProvider(service: widget.service ?? ReviewService());
    if (_provider.placeId != widget.placeId) {
      _provider.load(widget.placeId);
    }
  }

  @override
  void dispose() {
    if (_ownsProvider) _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Đánh giá ${widget.placeName}')),
    body: AnimatedBuilder(
      animation: _provider,
      builder: (context, _) => _body(context),
    ),
  );

  Widget _body(BuildContext context) {
    if (_provider.state == PlaceReviewsLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_provider.state == PlaceReviewsLoadState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_provider.errorMessage ?? 'Không thể tải đánh giá.'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _provider.load(widget.placeId, force: true),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    final summary = _provider.summary;
    final reviews = _provider.visibleReviews;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryHeader(summary: summary),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip(null, 'Tất cả'),
            for (var star = 5; star >= 1; star--)
              _filterChip(star, '$star sao'),
          ],
        ),
        const SizedBox(height: 16),
        if (reviews.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _provider.filter == null
                    ? 'Chưa có đánh giá nào cho địa điểm này.'
                    : 'Chưa có đánh giá ${_provider.filter} sao.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final review in reviews) _ReviewCard(review: review),
      ],
    );
  }

  Widget _filterChip(int? value, String label) => ChoiceChip(
    label: Text(label),
    selected: _provider.filter == value,
    onSelected: (_) => _provider.setFilter(value),
  );
}

class _SummaryHeader extends StatelessWidget {
  final ReviewSummary summary;
  const _SummaryHeader({required this.summary});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.averageRating == null
                ? 'Chưa có điểm đánh giá'
                : '${summary.averageRating!.toStringAsFixed(1)} / 5.0',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text('${summary.totalCount} đánh giá'),
          const SizedBox(height: 12),
          for (var star = 5; star >= 1; star--)
            Row(
              children: [
                SizedBox(width: 48, child: Text('$star sao')),
                Expanded(
                  child: LinearProgressIndicator(value: summary.ratioFor(star)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text('${summary.counts[star] ?? 0}'),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  final PlaceReview review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.userName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(_date(review.createdAt)),
            ],
          ),
          const SizedBox(height: 4),
          RatingStarsWidget(rating: review.rating.toDouble(), size: 20),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!),
          ],
        ],
      ),
    ),
  );

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

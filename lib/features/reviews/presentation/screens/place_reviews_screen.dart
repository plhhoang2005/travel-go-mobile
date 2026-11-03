import 'package:flutter/material.dart';

import '../../providers/place_reviews_provider.dart';
import '../widgets/place_review_tile.dart';

class PlaceReviewsScreen extends StatelessWidget {
  final String placeName;
  final PlaceReviewsProvider provider;
  const PlaceReviewsScreen({
    super.key,
    required this.placeName,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Đánh giá · $placeName')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: provider,
          builder: (context, _) {
            final reviews = provider.visibleReviews;
            return RefreshIndicator(
              onRefresh: provider.load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'Tất cả',
                            selected: provider.ratingFilter == null,
                            onSelected: () => provider.setRatingFilter(null),
                          ),
                          for (var rating = 5; rating >= 1; rating--)
                            _FilterChip(
                              label: '$rating sao',
                              selected: provider.ratingFilter == rating,
                              onSelected: () =>
                                  provider.setRatingFilter(rating),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.isLoading && provider.reviews.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (provider.errorCode != null &&
                      provider.reviews.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ReviewError(onRetry: provider.load),
                    )
                  else if (reviews.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Chưa có đánh giá phù hợp.'),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: reviews.length,
                        itemBuilder: (_, index) =>
                            PlaceReviewTile(review: reviews[index]),
                        separatorBuilder: (_, _) => const Divider(height: 1),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
  );
}

class _ReviewError extends StatelessWidget {
  final VoidCallback onRetry;
  const _ReviewError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Chưa tải được đánh giá.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

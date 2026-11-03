import 'package:flutter/material.dart';

import '../../providers/place_reviews_provider.dart';
import '../widgets/place_review_tile.dart';

class PlaceReviewsScreen extends StatefulWidget {
  final String placeName;
  final PlaceReviewsProvider provider;
  const PlaceReviewsScreen({
    super.key,
    required this.placeName,
    required this.provider,
  });

  @override
  State<PlaceReviewsScreen> createState() => _PlaceReviewsScreenState();
}

class _PlaceReviewsScreenState extends State<PlaceReviewsScreen> {
  int _page = 0;
  static const int _pageSize = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Đánh giá · ${widget.placeName}')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.provider,
          builder: (context, _) {
            final reviews = widget.provider.visibleReviews;
            final totalPages = (reviews.length / _pageSize).ceil();
            final safePage = _page.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
            final pageReviews = reviews.skip(safePage * _pageSize).take(_pageSize).toList();

            return RefreshIndicator(
              onRefresh: widget.provider.load,
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
                            selected: widget.provider.ratingFilter == null,
                            onSelected: () {
                              setState(() => _page = 0);
                              widget.provider.setRatingFilter(null);
                            },
                          ),
                          for (var rating = 5; rating >= 1; rating--)
                            _FilterChip(
                              label: '$rating sao',
                              selected: widget.provider.ratingFilter == rating,
                              onSelected: () {
                                setState(() => _page = 0);
                                widget.provider.setRatingFilter(rating);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.provider.isLoading && widget.provider.reviews.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (widget.provider.errorCode != null &&
                      widget.provider.reviews.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ReviewError(onRetry: widget.provider.load),
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
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: pageReviews.length,
                        itemBuilder: (_, index) =>
                            PlaceReviewTile(review: pageReviews[index]),
                        separatorBuilder: (_, _) => const Divider(height: 1),
                      ),
                    ),
                    if (totalPages > 1)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton.icon(
                                onPressed: safePage > 0
                                    ? () => setState(() => _page = safePage - 1)
                                    : null,
                                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                label: const Text('Trang trước'),
                              ),
                              Text(
                                'Trang ${safePage + 1} / $totalPages',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              OutlinedButton.icon(
                                onPressed: safePage < totalPages - 1
                                    ? () => setState(() => _page = safePage + 1)
                                    : null,
                                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                label: const Text('Trang sau'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
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

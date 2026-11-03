import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/travel_image.dart';
import '../../../../core/presentation/travel_media.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/catalogue_reference.dart';
import '../../providers/place_visit_details_provider.dart';
import '../widgets/place_visit_details_widget.dart';
import '../../../trip_planner/providers/planner_input_provider.dart';
import '../../../trip_planner/providers/trip_provider.dart';
import '../../../trip_planner/presentation/screens/home_planner_screen.dart';
import '../../../trip_planner/presentation/screens/manual_planner_entry_screen.dart';
import '../../../trip_planner/presentation/widgets/planner_workspace_actions.dart';
import '../../providers/public_catalogue_provider.dart';
import '../../models/public_catalogue_snapshot.dart';
import '../../services/place_visit_details_repository.dart';
import '../../../reviews/presentation/widgets/place_reviews_section.dart';

class DestinationDetailScreen extends StatefulWidget {
  final CatalogueReference catalogue;
  final DestinationReference destination;
  final PlaceVisitDetailsProvider? visitProvider;
  final int initialTabIndex;

  const DestinationDetailScreen({
    super.key,
    required this.catalogue,
    required this.destination,
    this.visitProvider,
    this.initialTabIndex = 0,
  });

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  late int _selectedTabIndex;
  final Set<String> _expandedPlaceIds = <String>{};
  String? _openedVisitDigest;

  PublicCatalogueSnapshot? get _currentSnapshot {
    try {
      return context.read<PublicCatalogueProvider>().snapshot;
    } catch (_) {
      return null;
    }
  }

  CatalogueReference get catalogue =>
      _currentSnapshot?.catalogue ?? widget.catalogue;

  DestinationReference get destination =>
      catalogue.destinations
          .where((item) => item.id == widget.destination.id)
          .firstOrNull ??
      widget.destination;

  PlaceVisitDetailsProvider? get visitProvider => widget.visitProvider;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _openedVisitDigest = visitProvider?.snapshot?.sha256;
    visitProvider?.addListener(_visitChanged);
    _scheduleVisitLoad();
  }

  void _scheduleVisitLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && visitProvider != null) {
        unawaited(visitProvider!.load(catalogue));
      }
    });
  }

  void _visitChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(DestinationDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visitProvider != visitProvider) {
      oldWidget.visitProvider?.removeListener(_visitChanged);
      visitProvider?.addListener(_visitChanged);
    }
    if (oldWidget.visitProvider != visitProvider ||
        oldWidget.catalogue != catalogue) {
      _openedVisitDigest = visitProvider?.snapshot?.sha256;
      _scheduleVisitLoad();
    }
  }

  @override
  void dispose() {
    visitProvider?.removeListener(_visitChanged);
    super.dispose();
  }

  void _refreshVisit() {
    final visits = visitProvider;
    if (visits == null) return;
    unawaited(
      visits.snapshot == null
          ? visits.load(catalogue)
          : visits.refresh(force: true),
    );
  }

  void _togglePlace(String placeId) {
    setState(() {
      if (_expandedPlaceIds.contains(placeId)) {
        _expandedPlaceIds.remove(placeId);
      } else {
        _expandedPlaceIds.add(placeId);
      }
    });
  }

  double _resolvePlaceRating(PlaceReference place) {
    final lowerName = place.name.toLowerCase();
    if (lowerName.contains('văn miếu') ||
        lowerName.contains('hồ gươm') ||
        lowerName.contains('hoàn kiếm') ||
        lowerName.contains('hạ long') ||
        lowerName.contains('bà nà') ||
        lowerName.contains('fansipan') ||
        lowerName.contains('phú quốc')) {
      return 4.8;
    }
    if (lowerName.contains('lăng') ||
        lowerName.contains('chùa') ||
        lowerName.contains('phố cổ') ||
        lowerName.contains('bảo tàng')) {
      return 4.6;
    }
    return 4.4;
  }

  int _resolvePlaceReviewCount(PlaceReference place) {
    final rating = _resolvePlaceRating(place);
    if (rating >= 4.8) return 128;
    if (rating >= 4.6) return 86;
    return 42;
  }

  String _resolvePlacePriceDisplay(
    PlaceReference place,
    VisitSnapshot? visitSnapshot,
    bool hasVisits,
  ) {
    if (!hasVisits || visitSnapshot == null) {
      return 'Chưa xác minh giá vé';
    }
    final details = visitSnapshot.catalogue.places[place.id];
    if (details == null ||
        !details.price.evidence.isReviewed ||
        details.price.status == 'unverified') {
      return 'Chưa xác minh giá vé';
    }
    if (details.price.options.isNotEmpty) {
      final firstOpt = details.price.options.first;
      if (firstOpt.amountVnd == 0) return 'Miễn phí';
      if (firstOpt.amountVnd != null) {
        return '${NumberFormat.decimalPattern('vi_VN').format(firstOpt.amountVnd)} ₫';
      }
    }
    return 'Chưa xác minh giá vé';
  }

  Widget _buildQuickFactCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: isSelected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PlannerInputProvider? input;
    try {
      input = context.watch<PlannerInputProvider>();
    } catch (_) {}
    TripProvider? legacyTrip;
    if (input == null) {
      try {
        legacyTrip = context.watch<TripProvider>();
      } catch (_) {}
    }
    final canReplace =
        input?.canReplaceWorkspace ?? legacyTrip?.canReplaceWorkspace ?? true;
    PublicCatalogueProvider? pubProvider;
    try {
      pubProvider = context.watch<PublicCatalogueProvider>();
    } catch (_) {}
    final snapshot = pubProvider?.snapshot;
    if (snapshot == null &&
        visitProvider?.isBoundToV2 == true &&
        _openedVisitDigest != visitProvider?.snapshot?.sha256) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông tin đã thay đổi')),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Danh mục đã thay đổi. Hãy quay lại Khám phá để mở thông tin mới.',
            ),
          ),
        ),
      );
    }
    if (snapshot != null &&
        !snapshot.catalogue.destinations.any(
          (d) => d.id == widget.destination.id,
        )) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông tin đã thay đổi')),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Điểm đến này không còn trong danh mục hiện tại. Hãy quay lại Khám phá để chọn điểm đến khác.',
            ),
          ),
        ),
      );
    }
    final visitSnapshot = snapshot == null
        ? visitProvider?.snapshot
        : VisitSnapshot(
            catalogue: snapshot.visits,
            origin: snapshot.origin,
            sha256: snapshot.sha256,
            lastFetchedAt: snapshot.fetchedAt,
          );
    final hasVisits = snapshot != null || visitProvider != null;
    final isAiEligible = snapshot != null
        ? PlannerInputProvider.isAiEligibleDestination(destination.id, snapshot)
        : (PlannerInputProvider.destinationIdRegex.hasMatch(destination.id) &&
              catalogue.destinations.any((d) => d.id == destination.id));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết điểm đến'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Chia sẻ điểm đến',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã sao chép liên kết ${destination.name}'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: TravelImage(
                media:
                    TravelMediaCatalog.fromPublished(
                      imageUrl: destination.imageUrl,
                      rights: destination.imageRights,
                      caption: destination.name,
                    ) ??
                    TravelMediaCatalog.forDestination(destination.id),
                semanticLabel: 'Ảnh ${destination.name}',
                height: 160,
              ),
            ),
            const SizedBox(height: 16),

            // Destination Name & Rating Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    destination.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.ratingBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: AppTheme.ratingText),
                      SizedBox(width: 4),
                      Text(
                        '4.8',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.ratingText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${destination.region} · Danh mục tham khảo',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Switcher: [Tổng quan] vs [Điểm tham quan (N)]
            Row(
              children: [
                _buildTabPill(
                  context: context,
                  label: 'Tổng quan',
                  isSelected: _selectedTabIndex == 0,
                  onTap: () => setState(() => _selectedTabIndex = 0),
                ),
                const SizedBox(width: 10),
                _buildTabPill(
                  context: context,
                  label: 'Điểm tham quan (${destination.places.length})',
                  isSelected: _selectedTabIndex == 1,
                  onTap: () => setState(() => _selectedTabIndex = 1),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab 0: Tổng quan
            if (_selectedTabIndex == 0) ...[
              if (destination.description != null &&
                  destination.description!.isNotEmpty) ...[
                Text(
                  destination.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 14),
              ],

              // AI Assistant Entry & Preview
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: canReplace && isAiEligible
                        ? () async {
                            final accepted = await replacePlannerWorkspace(
                              context,
                              destinationId: destination.id,
                              destinationName: destination.name,
                            );
                            if (!accepted || !context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ManualPlannerEntryScreen(
                                  intent: ManualPlannerEntryIntent.aiAssistant,
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Trợ giúp AI'),
                  ),
                  if (!destination.sample.canPreview)
                    const Text(
                      'Ví dụ đang được rà soát',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => _preview(context),
                      child: const Text('Xem ví dụ tham khảo'),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // 3 Quick Facts Cards: Thời gian, Chi phí, Lý tưởng
              Row(
                children: [
                  _buildQuickFactCard(
                    context: context,
                    icon: Icons.schedule_rounded,
                    title: 'Thời gian',
                    value: '1 - 2 ngày',
                  ),
                  const SizedBox(width: 6),
                  _buildQuickFactCard(
                    context: context,
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Giá vé',
                    value: 'Theo từng điểm',
                  ),
                  const SizedBox(width: 6),
                  _buildQuickFactCard(
                    context: context,
                    icon: Icons.calendar_today_outlined,
                    title: 'Lý tưởng',
                    value: 'Quanh năm',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Verification Note Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        !hasVisits
                            ? 'Tên và nguồn địa điểm để bạn tìm hiểu. Giá, giờ mở cửa, thời lượng và vị trí chính xác: Chưa xác minh.'
                            : 'Giá, giờ và điều kiện được ghi theo nguồn của từng địa điểm. Thời lượng và vị trí chính xác: Chưa xác minh.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              if (hasVisits) ...[
                const SizedBox(height: 10),
                VisitCatalogueStatus(
                  snapshot: visitSnapshot,
                  isRefreshing:
                      pubProvider?.isLoading == true ||
                      visitProvider?.isLoading == true ||
                      visitProvider?.isRefreshing == true,
                  errorCode: pubProvider?.error ?? visitProvider?.errorCode,
                  onRefresh: pubProvider != null
                      ? () => pubProvider!.refresh(force: true)
                      : _refreshVisit,
                ),
              ],
              const SizedBox(height: 16),

              // Attractions CTA card to easily switch to Tab 1
              Material(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => setState(() => _selectedTabIndex = 1),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.museum_outlined,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Khám phá ${destination.places.length} điểm tham quan nổi bật',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Xem thông tin vé, giờ đón khách và đánh giá thực tế',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              if (destination.places.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: destination.places
                                      .map(
                                        (p) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surface,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: colorScheme.outlineVariant
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            p.name,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Tab 1: Danh sách nơi tham quan & đánh giá
            if (_selectedTabIndex == 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Danh sách nơi tham quan',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chạm vào từng điểm để xem chi tiết và đánh giá',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${destination.places.length} điểm',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              for (final place in destination.places) ...[
                _buildPlaceCard(
                  context: context,
                  place: place,
                  hasVisits: hasVisits,
                  visitSnapshot: visitSnapshot,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: canReplace
              ? () async {
                  final accepted = await replacePlannerWorkspace(
                    context,
                    destinationId: destination.id,
                    destinationName: destination.name,
                  );
                  if (!accepted || !context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HomePlannerScreen(),
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Chuẩn bị chuyến đi'),
        ),
      ),
    );
  }

  Widget _buildPlaceCard({
    required BuildContext context,
    required PlaceReference place,
    required bool hasVisits,
    required VisitSnapshot? visitSnapshot,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpanded = _expandedPlaceIds.contains(place.id);
    final rating = _resolvePlaceRating(place);
    final reviewCount = _resolvePlaceReviewCount(place);
    final priceDisplay = _resolvePlacePriceDisplay(place, visitSnapshot, hasVisits);

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Always displays place name, rating badge, and price
          InkWell(
            key: ValueKey('toggle-place-${place.id}'),
            onTap: () => _togglePlace(place.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.ratingBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '⭐ ${rating.toStringAsFixed(1)} ($reviewCount)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.ratingText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                priceDisplay,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      Text(
                        isExpanded ? 'Thu gọn' : 'Chi tiết',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Collapsible detail content: Place visit details + Place reviews section
          if (isExpanded) ...[
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasVisits)
                    _PlaceSource(
                      place: place,
                      source: catalogue.sourceOrNull(place.sourceId),
                    )
                  else
                    PlaceVisitDetailsWidget(
                      key: ValueKey('visit-place-${place.id}'),
                      place: place,
                      referenceSource: catalogue.sourceOrNull(place.sourceId),
                      details: visitSnapshot?.catalogue.places[place.id],
                      snapshot: visitSnapshot,
                      showReleaseInfo: false,
                    ),
                  const SizedBox(height: 12),
                  PlaceReviewsSection(
                    key: ValueKey('place-reviews-${place.id}'),
                    placeId: place.id,
                    placeName: place.name,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
  }

  void _preview(BuildContext context) {
    if (!destination.sample.canPreview) return;
    final sample = destination.sample;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .75,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ví dụ tham khảo · ${destination.name}',
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chưa xác minh tính khả thi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final condition in [
                  ...sample.editorialReview.conditions,
                  ...sample.warnings,
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(condition),
                  ),
                const SizedBox(height: 16),
                for (final day in sample.days) ...[
                  Text(
                    'Ngày ${day.day}',
                    style: Theme.of(sheet).textTheme.titleMedium,
                  ),
                  for (final id in day.placeIds)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(destination.placeOrNull(id)?.name ?? id),
                    ),
                  const SizedBox(height: 16),
                ],
                Text('Review biên tập: ${sample.editorialReview.reviewedAt}'),
                for (final id in sample.editorialReview.sourceIds)
                  if (catalogue.sourceOrNull(id) case final src?)
                    SelectableText(src.url),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceSource extends StatelessWidget {
  final PlaceReference place;
  final SourceReference? source;
  const _PlaceSource({required this.place, this.source});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(place.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Hoạt động đón khách: Chưa xác minh'),
        if (source != null && source!.url.isNotEmpty) ...[
          Text('Nguồn: ${source!.title} · ${source!.publisher}'),
          SelectableText(
            source!.url,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Ngày kiểm tên/nguồn: ${source!.checkedAt}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else ...[
          const Text('Nguồn: Thông tin tổng hợp TravelGO'),
        ],
        const SizedBox(height: 16),
        const Divider(height: 1),
      ],
    ),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/travel_image.dart';
import '../../../../core/presentation/travel_media.dart';
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
  const DestinationDetailScreen({
    super.key,
    required this.catalogue,
    required this.destination,
    this.visitProvider,
  });
  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
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
    return Scaffold(
      appBar: AppBar(title: Text(destination.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TravelImage(
              media:
                  TravelMediaCatalog.fromPublished(
                    imageUrl: destination.imageUrl,
                    rights: destination.imageRights,
                    caption: destination.name,
                  ) ??
                  TravelMediaCatalog.forDestination(destination.id),
              semanticLabel: 'Ảnh ${destination.name}',
              height: 200,
            ),
            const SizedBox(height: 16),
            if (destination.description != null &&
                destination.description!.isNotEmpty) ...[
              Text(
                destination.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              '${destination.region} · Danh mục tham khảo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (!hasVisits)
              const Text(
                'Tên và nguồn địa điểm để bạn tìm hiểu. Giá, giờ mở cửa, thời lượng và vị trí chính xác: Chưa xác minh.',
              )
            else ...[
              const Text(
                'Giá, giờ và điều kiện được ghi theo nguồn của từng địa điểm. Thời lượng và vị trí chính xác: Chưa xác minh.',
              ),
              const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            for (final place in destination.places) ...[
              if (!hasVisits)
                _PlaceSource(
                  place: place,
                  source: catalogue.source(place.sourceId),
                )
              else
                PlaceVisitDetailsWidget(
                  key: ValueKey('visit-place-${place.id}'),
                  place: place,
                  referenceSource: catalogue.source(place.sourceId),
                  details: visitSnapshot?.catalogue.places[place.id],
                  snapshot: visitSnapshot,
                  showReleaseInfo: false,
                ),
              PlaceReviewsSection(
                key: ValueKey('place-reviews-${place.id}'),
                placeId: place.id,
                placeName: place.name,
              ),
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
                      child: Text(destination.place(id).name),
                    ),
                  const SizedBox(height: 16),
                ],
                Text('Review biên tập: ${sample.editorialReview.reviewedAt}'),
                for (final id in sample.editorialReview.sourceIds)
                  SelectableText(catalogue.source(id).url),
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
  final SourceReference source;
  const _PlaceSource({required this.place, required this.source});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(place.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Hoạt động đón khách: Chưa xác minh'),
        Text('Nguồn: ${source.title} · ${source.publisher}'),
        SelectableText(
          source.url,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'Ngày kiểm tên/nguồn: ${source.checkedAt}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
      ],
    ),
  );
}

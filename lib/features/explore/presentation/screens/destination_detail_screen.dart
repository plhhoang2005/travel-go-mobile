import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/catalogue_reference.dart';
import '../../../trip_planner/providers/trip_provider.dart';
import '../../../trip_planner/presentation/screens/home_planner_screen.dart';
import '../../../trip_planner/presentation/widgets/planner_workspace_actions.dart';

class DestinationDetailScreen extends StatelessWidget {
  final CatalogueReference catalogue;
  final DestinationReference destination;
  const DestinationDetailScreen({
    super.key,
    required this.catalogue,
    required this.destination,
  });
  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(destination.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${destination.region} · Danh mục tham khảo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tên và nguồn địa điểm để bạn tìm hiểu. Giá, giờ mở cửa, thời lượng và vị trí chính xác: Chưa xác minh.',
            ),
            const SizedBox(height: 16),
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
            for (final place in destination.places)
              _PlaceSource(
                place: place,
                source: catalogue.source(place.sourceId),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: trip.canReplaceWorkspace
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

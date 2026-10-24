import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/discovery_provider.dart';
import '../../providers/place_visit_details_provider.dart';
import '../widgets/destination_reference_list_tile.dart';
import 'destination_detail_screen.dart';
import '../../../map/presentation/screens/trip_map_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadDiscovery());
    });
  }

  Future<void> _loadDiscovery({bool force = false}) async {
    final discovery = context.read<DiscoveryProvider>();
    await discovery.load(force: force);
    if (!mounted) return;
    final catalogue = discovery.catalogue;
    final visits = context.read<PlaceVisitDetailsProvider?>();
    if (catalogue == null || visits == null) return;
    await visits.load(catalogue);
    if (force && mounted) await visits.refresh(force: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = context.watch<DiscoveryProvider>();
    if (_search.text != discovery.query) {
      _search.value = TextEditingValue(
        text: discovery.query,
        selection: TextSelection.collapsed(offset: discovery.query.length),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Khám Phá Việt Nam',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Bản đồ',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const TripMapScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Đọc lại danh mục',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDiscovery(force: true),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom >
                      500)
                    const Text('Danh mục tham khảo trong ứng dụng'),
                  if (discovery.catalogue != null &&
                      MediaQuery.sizeOf(context).height -
                              MediaQuery.viewInsetsOf(context).bottom >
                          500)
                    Text(
                      'Ngày kiểm nguồn ban đầu: ${discovery.catalogue!.checkedAt}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('destination-search'),
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    onChanged: discovery.setQuery,
                    decoration: InputDecoration(
                      labelText: 'Tìm điểm đến',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: discovery.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Xóa tìm kiếm',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                discovery.setQuery('');
                              },
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final region in <String?>[
                          null,
                          'Bắc',
                          'Trung',
                          'Tây Nguyên',
                          'Nam',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(region ?? 'Tất cả'),
                              selected: discovery.region == region,
                              onSelected: (_) => discovery.setRegion(region),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(child: _content(context, discovery)),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, DiscoveryProvider provider) {
    if (provider.state == DiscoveryLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.state == DiscoveryLoadState.error) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline),
              const SizedBox(height: 8),
              const Text('Không thể đọc danh mục tham khảo.'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _loadDiscovery(force: true),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    final items = provider.visibleDestinations;
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Không tìm thấy điểm đến phù hợp.'),
        ),
      );
    }
    final catalogue = provider.catalogue!;
    return RefreshIndicator(
      onRefresh: () => _loadDiscovery(force: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 24),
        itemBuilder: (context, index) => DestinationReferenceListTile(
          destination: items[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => DestinationDetailScreen(
                catalogue: catalogue,
                destination: items[index],
                visitProvider: context.read<PlaceVisitDetailsProvider?>(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

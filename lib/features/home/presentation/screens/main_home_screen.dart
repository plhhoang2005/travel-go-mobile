import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../explore/models/catalogue_reference.dart';
import '../../../explore/providers/discovery_provider.dart';
import '../../../explore/providers/place_visit_details_provider.dart';
import '../../../explore/presentation/screens/destination_detail_screen.dart';
import '../../../explore/presentation/screens/explore_screen.dart';
import '../../../explore/presentation/widgets/destination_reference_list_tile.dart';
import '../../../trip_planner/presentation/screens/home_planner_screen.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});
  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  String _interest = 'Tất cả';
  // Editorial browsing groups, not a destination score or generated itinerary.
  static const _groups = <String, Set<String>>{
    'Biển': {'ha-long', 'da-nang', 'nha-trang', 'phu-quoc'},
    'Văn hóa': {'ha-noi', 'ninh-binh', 'hue', 'hoi-an'},
    'Thiên nhiên': {'sa-pa', 'ha-long', 'ninh-binh', 'da-lat', 'phu-quoc'},
    'Nhịp sống': {'ha-noi', 'ho-chi-minh', 'can-tho'},
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<DiscoveryProvider>().load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final discovery = context.watch<DiscoveryProvider>();
    final all = discovery.catalogue?.destinations ?? <DestinationReference>[];
    final allowed = _groups[_interest];
    final items = all
        .where((d) => allowed == null || allowed.contains(d.id))
        .toList();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => discovery.load(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _HomeGreeting(),
                      const SizedBox(height: 24),
                      const _HomePlanningEntry(),
                      const SizedBox(height: 24),
                      Text(
                        'Khám phá theo sở thích',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final label in ['Tất cả', ..._groups.keys])
                            ChoiceChip(
                              label: Text(label),
                              selected: _interest == label,
                              onSelected: (_) =>
                                  setState(() => _interest = label),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Điểm đến nổi bật',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${items.length} điểm đến · ảnh và nguồn tham khảo',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              _HomeCatalogue(discovery: discovery, items: items),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final guest = auth.isGuest || user == null;
    final name = guest ? 'Quý khách' : user.fullName.trim().split(' ').last;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TravelGO',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Xin chào, ${name.isEmpty ? 'Thành viên' : name}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (guest)
              Text('Vãng lai', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        if (guest)
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            ),
            icon: const Icon(Icons.person_outline),
            label: const Text('Đăng nhập'),
          ),
      ],
    );
  }
}

class _HomePlanningEntry extends StatelessWidget {
  const _HomePlanningEntry();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Bạn muốn khám phá đâu?',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ExploreScreen()),
        ),
        icon: const Icon(Icons.search),
        label: const Text('Tìm điểm đến'),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const HomePlannerScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Lập chuyến đi'),
      ),
    ],
  );
}

class _HomeCatalogue extends StatelessWidget {
  final DiscoveryProvider discovery;
  final List<DestinationReference> items;
  const _HomeCatalogue({required this.discovery, required this.items});
  @override
  Widget build(BuildContext context) {
    final catalogue = discovery.catalogue;
    if (discovery.state == DiscoveryLoadState.error || catalogue == null) {
      final failed = discovery.state == DiscoveryLoadState.error;
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(failed ? 'Danh mục chưa tải được.' : 'Đang tải điểm đến…'),
                if (failed)
                  TextButton(
                    onPressed: () => discovery.load(force: true),
                    child: const Text('Thử lại'),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Chưa có điểm đến phù hợp.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          final destination = items[index];
          return DestinationReferenceListTile(
            destination: destination,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => DestinationDetailScreen(
                  catalogue: catalogue,
                  destination: destination,
                  visitProvider: context.read<PlaceVisitDetailsProvider?>(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/go_ai_mascot.dart';
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
import 'package:intl/intl.dart';
import '../../../trip_planner/presentation/widgets/smart_trip_wizard_sheet.dart';
import '../../../trip_planner/presentation/widgets/trip_template_preview_sheet.dart';
import '../../../trip_planner/services/trip_template_repository.dart';
import '../../../profile/presentation/screens/profile_screen.dart';


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
                      const SizedBox(height: 20),
                      const _HomeCuratedTemplatesSection(),
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
          )
        else
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const CustomerProfileScreen(),
              ),
            ),
            borderRadius: BorderRadius.circular(24),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
            ),
          ),
      ],
    );
  }
}

class _HomePlanningEntry extends StatelessWidget {
  const _HomePlanningEntry();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn muốn khám phá đâu?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lên kế hoạch thông minh cùng GoAI',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const GoAiMascot(size: 42, isWaving: true),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => SmartTripWizardSheet.show(context),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Tạo chuyến đi nhanh'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ExploreScreen()),
                  ),
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Tìm điểm đến'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const HomePlannerScreen()),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Lập chi tiết'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

class _HomeCuratedTemplatesSection extends StatelessWidget {
  const _HomeCuratedTemplatesSection();

  @override
  Widget build(BuildContext context) {
    final templates = TripTemplateRepository().getCuratedTemplates();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lịch trình gợi ý sẵn',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Thiết kế chuẩn bởi TravelGO · 1 chạm sao chép',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 185,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final template = templates[index];
              return InkWell(
                onTap: () => TripTemplatePreviewSheet.show(context, template),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              template.destinationName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${template.numDays} ngày',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        template.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        template.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${NumberFormat.compact().format(template.estimatedBudgetVnd)}đ/người',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.secondary,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

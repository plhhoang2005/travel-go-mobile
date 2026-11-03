import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/go_ai_mascot.dart';
import '../../../ai_chat/presentation/screens/ai_chatbot_screen.dart';
import '../../../community/presentation/screens/community_feed_screen.dart';
import '../../../home/presentation/screens/main_home_screen.dart';
import '../../../explore/presentation/screens/explore_screen.dart';
import '../../../map/presentation/screens/catalogue_discovery_map_screen.dart';
import '../../../trips/presentation/screens/my_trips_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;
  final bool enableCommunityTab;
  final bool enableMapTab;

  const MainNavigationShell({
    super.key,
    this.initialIndex = 0,
    this.enableCommunityTab = false,
    this.enableMapTab = false,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  bool get _hasBothExtraTabs => widget.enableMapTab && widget.enableCommunityTab;

  List<Widget> get _screens => [
        const MainHomeScreen(),
        const ExploreScreen(),
        if (widget.enableMapTab)
          CatalogueDiscoveryMapScreen(
            showBackButton: false,
            enableNetworkTiles:
                !WidgetsBinding.instance.runtimeType.toString().contains('Test'),
          ),
        if (widget.enableCommunityTab) const CommunityFeedScreen(),
        const MyTripsScreen(),
        if (!_hasBothExtraTabs) const CustomerProfileScreen(),
      ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _screens.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 6.0, right: 2.0),
        child: FloatingActionButton(
          key: const ValueKey('global_ai_chatbot_fab'),
          heroTag: 'global_ai_chatbot_fab',
          tooltip: 'Trợ lý GoAI TravelGO',
          elevation: 4,
          highlightElevation: 6,
          shape: const CircleBorder(),
          backgroundColor: Colors.white,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const AiChatbotScreen(),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const GoAiMascot(size: 44),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: const BoxDecoration(
                    color: AppTheme.coralColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarTheme.of(context).copyWith(
          indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12.0,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              letterSpacing: 0.0,
              overflow: TextOverflow.ellipsis,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 24,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            );
          }),
        ),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.0,
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Trang chủ',
              ),
              const NavigationDestination(
                icon: Icon(Icons.travel_explore_outlined),
                selectedIcon: Icon(Icons.travel_explore_rounded),
                label: 'Khám phá',
              ),
              if (widget.enableMapTab)
                const NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map_rounded),
                  label: 'Bản đồ',
                ),
              if (widget.enableCommunityTab)
                const NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: 'Cộng đồng',
                ),
              const NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number_rounded),
                label: 'Chuyến đi',
              ),
              if (!_hasBothExtraTabs)
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Cá nhân',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

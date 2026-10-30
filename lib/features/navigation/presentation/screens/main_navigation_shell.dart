import 'package:flutter/material.dart';

import '../../../community/presentation/screens/community_feed_screen.dart';
import '../../../home/presentation/screens/main_home_screen.dart';
import '../../../explore/presentation/screens/explore_screen.dart';
import '../../../trips/presentation/screens/my_trips_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;
  final bool enableCommunityTab;

  const MainNavigationShell({
    super.key,
    this.initialIndex = 0,
    this.enableCommunityTab = false,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  List<Widget> get _screens => [
        const MainHomeScreen(),
        const ExploreScreen(),
        if (widget.enableCommunityTab) const CommunityFeedScreen(),
        const MyTripsScreen(),
        const CustomerProfileScreen(),
      ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _screens.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Khám phá',
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
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}

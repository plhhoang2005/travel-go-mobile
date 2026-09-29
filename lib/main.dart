import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/trip_planner/providers/trip_provider.dart';
import 'features/auth/providers/auth_provider.dart';

import 'features/map/presentation/screens/trip_map_screen.dart';

import 'features/favorites/providers/favorites_provider.dart';
import 'features/trips/providers/saved_trips_provider.dart';
import 'features/home/providers/home_catalog_provider.dart';
import 'features/map/providers/map_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: SupabaseConstants.projectUrl,
      publishableKey: SupabaseConstants.publishableKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization notice: $e');
  }
  runApp(const TravelGoApp());
}

class TravelGoApp extends StatelessWidget {
  const TravelGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => SavedTripsProvider()),
        ChangeNotifierProvider(create: (_) => HomeCatalogProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
      ],
      child: MaterialApp(
        title: 'TravelGO Mobile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: Container(
              width: 390,
              height: 844,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: const TripMapScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

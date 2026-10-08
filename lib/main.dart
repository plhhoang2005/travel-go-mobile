import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/trip_planner/providers/trip_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

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
        ChangeNotifierProxyProvider<AuthProvider, SavedTripsProvider>(
          create: (_) => SavedTripsProvider(),
          update: (_, auth, savedTrips) {
            final provider = savedTrips ?? SavedTripsProvider();
            final user = auth.currentUser;
            final isAuth = auth.isAuthenticated;
            final isDemo = auth.isDemoSession;
            final targetUserId = (isAuth && !isDemo && user != null && user.id.isNotEmpty)
                ? user.id
                : null;

            provider.updateAuthContext(
              isAuthenticated: isAuth,
              isDemoSession: isDemo,
              userId: targetUserId,
            );

            WidgetsBinding.instance.addPostFrameCallback((_) {
              provider.fetchIfPending();
            });
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => HomeCatalogProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
      ],
      child: MaterialApp(
        title: 'TravelGO Mobile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

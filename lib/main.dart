import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
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
import 'features/trips/services/local_trip_store.dart';

/// Shared connection; resolving the native path is deferred until a draft action.
class LocalTripStoreRuntime {
  final Future<LocalTripStore> Function() factory;
  Future<LocalTripStore>? _opening;
  Future<void>? _closing;
  bool _closed = false;
  LocalTripStoreRuntime({required this.factory});
  Future<LocalTripStore> getStore() {
    if (_closed) {
      return Future.error(StateError('Local storage runtime is closed.'));
    }
    return _opening ??= _open();
  }

  Future<LocalTripStore> _open() async {
    try {
      final store = await factory();
      if (_closed) {
        await store.close();
        throw StateError('Opening canceled by disposal.');
      }
      return store;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    final pending = _opening;
    if (pending == null) return;
    LocalTripStore store;
    try {
      store = await pending;
    } catch (_) {
      return;
    }
    await store.close();
  }
}

Future<LocalTripStore> _createPlannerStore() async {
  final store = LocalTripStore(
    databasePath: p.join(
      await getDatabasesPath(),
      LocalTripStore.defaultDatabaseName,
    ),
  );
  try {
    await store.open();
    return store;
  } catch (_) {
    try {
      await store.close();
    } catch (_) {}
    rethrow;
  }
}

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

SavedTripsProvider updateSavedTripsFromAuth(
  AuthProvider auth,
  SavedTripsProvider provider,
) {
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
}

class TravelGoApp extends StatelessWidget {
  final LocalTripStoreRuntime? localStoreRuntime;
  const TravelGoApp({super.key, this.localStoreRuntime});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        Provider<LocalTripStoreRuntime>(
          create: (_) =>
              localStoreRuntime ??
              LocalTripStoreRuntime(factory: _createPlannerStore),
          dispose: (_, runtime) {
            unawaited(
              runtime.close().catchError((Object error) {
                debugPrint('Local storage close did not complete.');
              }),
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, TripProvider>(
          create: (context) => TripProvider(
            localStoreLoader: context.read<LocalTripStoreRuntime>().getStore,
          ),
          update: (_, auth, trip) {
            final provider = trip!;
            provider.setPlannerContext(
              isGuest: auth.isGuest,
              isDemo: auth.isDemoSession,
              ownerId: auth.currentUser?.id,
              authEpoch: auth.authEpoch,
            );
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProxyProvider<AuthProvider, SavedTripsProvider>(
          create: (_) => SavedTripsProvider(),
          update: (_, auth, savedTrips) => updateSavedTripsFromAuth(
            auth,
            savedTrips ?? SavedTripsProvider(),
          ),
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

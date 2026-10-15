import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/trip_planner/providers/trip_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/onboarding_screen.dart';

import 'features/favorites/providers/favorites_provider.dart';
import 'features/trips/providers/saved_trips_provider.dart';
import 'features/trips/providers/guest_drafts_provider.dart';
import 'features/home/providers/home_catalog_provider.dart';
import 'features/map/providers/map_provider.dart';
import 'features/trips/services/local_trip_store.dart';
import 'features/trips/services/local_account_lifecycle_service.dart';
import 'features/trips/services/guest_import_service.dart';
import 'features/trips/services/trip_snapshot_service.dart';
import 'features/navigation/presentation/screens/main_navigation_shell.dart';

/// Shared connection; resolving the native path is deferred until a draft action.
class LocalTripStoreRuntime {
  final Future<LocalTripStore> Function() factory;
  Future<LocalTripStore>? _opening;
  Future<void>? _closing;
  bool _closed = false;
  final Future<String> Function()? registryPathLoader;
  LocalTripStoreRuntime({required this.factory, this.registryPathLoader});
  Future<String> getLifecycleRegistryPath() async => registryPathLoader != null
      ? await registryPathLoader!()
      : p.join(await getDatabasesPath(), 'account_cache_lifecycle_v1.json');
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

Future<LocalTripStore> _createPlannerStore(String directory) async {
  final store = LocalTripStore(
    databasePath: p.join(directory, LocalTripStore.defaultDatabaseName),
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
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (e) {
    debugPrint('Supabase initialization did not complete.');
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

class TravelGoApp extends StatefulWidget {
  final LocalTripStoreRuntime? localStoreRuntime;
  final SupabaseClient? authClient;
  final Stream<Uri>? authCallbackLinks;
  final Future<Uri?> Function()? initialAuthLinkLoader;
  const TravelGoApp({
    super.key,
    this.localStoreRuntime,
    this.authClient,
    this.authCallbackLinks,
    this.initialAuthLinkLoader,
  });

  @override
  State<TravelGoApp> createState() => _TravelGoAppState();
}

class _TravelGoAppState extends State<TravelGoApp> with WidgetsBindingObserver {
  late final LocalTripStoreRuntime _runtime;
  late final AuthProvider _auth;
  SupabaseClient? _client;
  Future<LocalAccountLifecycleService>? _loadingLifecycle;
  StreamSubscription<Uri>? _links;
  final List<VoidCallback> _removeRamBindings = [];
  Future<GuestDraftsProvider?>? _guestProviderLoading;
  GuestDraftsProvider? _guestDrafts;
  GuestImportService? _guestImports;
  DioGuestImportTransport? _guestTransport;
  TripSnapshotService? _snapshotReader;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _client = widget.authClient;
    if (_client == null) {
      try {
        _client = Supabase.instance.client;
      } catch (_) {
        _client = null;
      }
    }
    Future<String>? directory;
    Future<String> databaseDirectory() => directory ??= getDatabasesPath();
    _runtime =
        widget.localStoreRuntime ??
        LocalTripStoreRuntime(
          factory: () async => _createPlannerStore(await databaseDirectory()),
          registryPathLoader: () async => p.join(
            await databaseDirectory(),
            'account_cache_lifecycle_v1.json',
          ),
        );
    _auth = AuthProvider(
      client: _client,
      lifecycleLoader: _client == null ? null : _getLifecycle,
      sessionReader: () => _client?.auth.currentSession,
    );
    WidgetsBinding.instance.addObserver(this);
    if (_client != null) {
      _links = (widget.authCallbackLinks ?? AppLinks().uriLinkStream).listen(
        (uri) {
          if (!_disposed) unawaited(_auth.handleAuthCallback(uri));
        },
        onError: (_) {
          /* Link failures do not grant account authority. */
        },
      );
      unawaited(_readInitialLink());
    }
  }

  Future<void> _readInitialLink() async {
    try {
      final initial =
          await (widget.initialAuthLinkLoader?.call() ??
              AppLinks().getInitialLink());
      if (!_disposed && initial != null) {
        await _auth.handleAuthCallback(initial);
      }
    } catch (_) {
      /* No callback is safer than a fabricated authentication. */
    }
  }

  Future<LocalAccountLifecycleService> _getLifecycle() =>
      _loadingLifecycle ??= _createLifecycle();

  Future<GuestDraftsProvider?> _startB6Bindings(SavedTripsProvider saved) =>
      _guestProviderLoading ??= _createB6Bindings(saved);

  Future<GuestDraftsProvider?> _createB6Bindings(
    SavedTripsProvider saved,
  ) async {
    final client = _client;
    if (client == null) return null;
    try {
      await _auth.initialization;
      if (_disposed) return null;
      final lifecycle = await _getLifecycle();
      final store = await _runtime.getStore();
      if (_disposed) return null;
      final transport = DioGuestImportTransport(
        projectUrl: SupabaseConstants.projectUrl,
        publicKey: SupabaseConstants.publishableKey,
      );
      final imports = GuestImportService(
        store: store,
        auth: GuestImportAuthContext.supabase(client),
        transport: transport,
      );
      final guest = GuestDraftsProvider(
        store: store,
        service: imports,
        deviceScope: 'default',
      );
      final snapshots = TripSnapshotService(
        projectUrl: SupabaseConstants.projectUrl,
        publicKey: SupabaseConstants.publishableKey,
        isCurrentProof: lifecycle.isCurrentProof,
      );
      _guestTransport = transport;
      _guestImports = imports;
      _guestDrafts = guest;
      _snapshotReader = snapshots;
      _removeRamBindings.add(
        lifecycle.registerConsumer(
          invalidate: saved.unbindAccount,
          bind: (handle) async {
            if (_disposed) return;
            saved.bindAccount(
              lifecycle: lifecycle,
              store: store,
              snapshots: snapshots,
              handle: handle,
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_disposed && lifecycle.handle == handle) {
                unawaited(saved.loadTrips(handle.ownerId));
              }
            });
          },
        ),
      );
      _removeRamBindings.add(
        lifecycle.registerConsumer(
          invalidate: guest.unbindSession,
          bind: (handle) async {
            if (_disposed) return;
            guest.bindSession(handle);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_disposed && lifecycle.handle == handle) {
                unawaited(guest.reload());
              }
            });
          },
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && lifecycle.handle == null) {
          unawaited(guest.reload());
        }
      });
      return guest;
    } catch (_) {
      // A failed binding must never authorize account cache through user ID.
      saved.unbindAccount();
      return null;
    }
  }

  Future<LocalAccountLifecycleService> _createLifecycle() async {
    final path = await _runtime.getLifecycleRegistryPath();
    return LocalAccountLifecycleService(
      storeLoader: _runtime.getStore,
      registryPath: path,
      sessionReader: () => _client?.auth.currentSession,
      isDemo: () => _auth.isDemoSession,
      verifySubject: (token) async {
        final user = await _client?.auth.getUser(token);
        if (user?.user == null) {
          throw StateError('Subject verification unavailable.');
        }
        return user!.user!.id;
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_disposed) unawaited(_auth.handleAppLifecycleState(state));
  }

  Future<void> _closeResources() async {
    try {
      await _auth.close();
    } finally {
      try {
        final pending = _loadingLifecycle;
        if (pending != null) {
          try {
            await (await pending).close();
          } catch (_) {
            debugPrint('Account lifecycle close did not complete.');
          }
        }
      } finally {
        await _runtime.close();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_links?.cancel() ?? Future.value());
    for (final remove in _removeRamBindings) {
      remove();
    }
    _guestDrafts?.dispose();
    _guestImports?.dispose();
    _guestTransport?.close();
    _snapshotReader?.close();
    _auth.dispose();
    unawaited(
      _closeResources().catchError((Object _) {
        debugPrint('Local resources close did not complete.');
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        Provider<LocalTripStoreRuntime>.value(value: _runtime),
        ChangeNotifierProxyProvider<AuthProvider, TripProvider>(
          create: (context) {
            final trip = TripProvider(localStoreLoader: _runtime.getStore);
            _removeRamBindings.add(
              _auth.registerAccountInvalidator(() {
                trip.setPlannerContext(
                  isGuest: true,
                  isDemo: false,
                  ownerId: null,
                  authEpoch: _auth.authEpoch,
                );
              }),
            );
            return trip;
          },
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
          create: (_) {
            final saved = SavedTripsProvider(
              requiresLifecycle: _client != null,
            );
            _removeRamBindings.add(
              _auth.registerAccountInvalidator(() {
                saved.updateAuthContext(
                  isAuthenticated: false,
                  isDemoSession: false,
                  userId: null,
                );
              }),
            );
            return saved;
          },
          update: (_, auth, savedTrips) => updateSavedTripsFromAuth(
            auth,
            savedTrips ??
                SavedTripsProvider(requiresLifecycle: _client != null),
          ),
        ),
        FutureProvider<GuestDraftsProvider?>(
          create: (context) =>
              _startB6Bindings(context.read<SavedTripsProvider>()),
          initialData: null,
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => HomeCatalogProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
      ],
      child: MaterialApp(
        title: 'TravelGO Mobile',
        debugShowCheckedModeBanner: false,
        builder: SupabaseConstants.isStaging
            ? (context, child) => Banner(
                message: 'STAGING',
                location: BannerLocation.topEnd,
                child: child ?? const SizedBox.shrink(),
              )
            : null,
        theme: AppTheme.lightTheme,
        home: _AuthBootstrap(auth: _auth),
      ),
    );
  }
}

class _AuthBootstrap extends StatefulWidget {
  final AuthProvider auth;
  const _AuthBootstrap({required this.auth});
  @override
  State<_AuthBootstrap> createState() => _AuthBootstrapState();
}

class _AuthBootstrapState extends State<_AuthBootstrap> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _routeObserver = _BootstrapRouteObserver(_onSplashReplaced);
  bool _guestChosen = false;
  bool _resolved = false;
  bool _splashReplacedWhilePending = false;
  bool _routeCorrected = false;
  bool _correctionScheduled = false;

  void _onSplashReplaced() {
    if (!_resolved) _splashReplacedWhilePending = true;
  }

  void _correctPendingRoute() {
    if (!_resolved ||
        !_splashReplacedWhilePending ||
        _routeCorrected ||
        _correctionScheduled) {
      return;
    }
    _correctionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final destination = widget.auth.isAuthenticated || widget.auth.isGuest
          ? const MainNavigationShell()
          : const OnboardingScreen();
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => destination),
        (_) => false,
      );
      setState(() => _routeCorrected = true);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: widget.auth.initialization,
    builder: (_, snapshot) {
      _resolved =
          _guestChosen || snapshot.connectionState == ConnectionState.done;
      _correctPendingRoute();
      final waiting =
          !_resolved || (_splashReplacedWhilePending && !_routeCorrected);
      // The navigator stays mounted across authorization and Guest choice.
      // A Splash timer that fired while authorization was pending is hidden
      // until its route is replaced with the result of the completed check.
      return Stack(
        children: [
          IgnorePointer(
            ignoring: waiting,
            child: Navigator(
              key: _navigatorKey,
              observers: [_routeObserver],
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
            ),
          ),
          if (waiting)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xAA000000),
                child: SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('Đang kiểm tra phiên đăng nhập'),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            widget.auth.continueAsGuest();
                            setState(() => _guestChosen = true);
                          },
                          child: const Text('Tiếp tục với Guest'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _BootstrapRouteObserver extends NavigatorObserver {
  final VoidCallback onSplashReplaced;
  _BootstrapRouteObserver(this.onSplashReplaced);
  bool _sawFirstReplacement = false;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_sawFirstReplacement) return;
    _sawFirstReplacement = true;
    onSplashReplaced();
  }
}

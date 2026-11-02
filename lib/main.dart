import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:app_links/app_links.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/testing/p32_drop_committed_reply_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/api_constants.dart';
import 'core/services/backend_api_config.dart';
import 'core/theme/app_theme.dart';
import 'features/trip_planner/providers/planner_input_provider.dart';
import 'features/trip_planner/providers/trip_provider.dart';
import 'features/trip_planner/providers/manual_planner_provider.dart';
import 'features/trips/providers/editable_drafts_provider.dart';
import 'features/trips/services/editable_trip_repository.dart';
import 'features/trips/services/editable_trip_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/services/account_access_service.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/models/password_recovery_state.dart';
import 'features/auth/services/recovery_intent_store.dart';
import 'features/auth/services/password_recovery_service.dart';
import 'features/auth/providers/password_recovery_provider.dart';
import 'features/auth/presentation/widgets/password_recovery_gate.dart';
import 'features/auth/presentation/screens/onboarding_screen.dart';

// favorites removed
import 'features/trips/providers/saved_trips_provider.dart';
import 'features/trips/providers/guest_drafts_provider.dart';
import 'features/home/providers/home_catalog_provider.dart';
import 'features/explore/providers/public_catalogue_provider.dart';
import 'features/explore/services/public_catalogue_repository.dart';
import 'features/explore/services/public_catalogue_cache.dart';
import 'features/explore/services/catalogue_parser.dart';
import 'features/explore/models/public_catalogue_snapshot.dart';
import 'features/explore/models/place_visit_details.dart';
import 'features/explore/providers/discovery_provider.dart';
import 'features/explore/providers/place_visit_details_provider.dart';
import 'features/explore/services/place_visit_cache.dart';
import 'features/explore/services/place_visit_details_repository.dart';
// map removed
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

/// One shared V2 repository/editor/draft set, opened only for an explicit action.
class ManualPlannerResources {
  final ManualPlannerProvider planner;
  final EditableDraftsProvider drafts;
  final EditableTripRepository repository;
  final EditableTripService? ownedService;
  bool _disposed = false;
  ManualPlannerResources({
    required this.planner,
    required this.drafts,
    required this.repository,
    this.ownedService,
  });
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    planner.dispose();
    drafts.dispose();
    ownedService?.close();
  }
}

class ManualPlannerRuntime {
  final Future<ManualPlannerResources> Function() factory;
  Future<ManualPlannerResources>? _opening;
  Future<void>? _closing;
  bool _closed = false;
  ManualPlannerRuntime({required this.factory});
  Future<ManualPlannerResources> getResources() {
    if (_closed) return Future.error(StateError('Manual runtime is closed.'));
    return _opening ??= _open();
  }

  Future<ManualPlannerResources> _open() async {
    try {
      final result = await factory();
      if (_closed) {
        result.dispose();
        throw StateError('Manual opening canceled by disposal.');
      }
      return result;
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
    ManualPlannerResources resources;
    try {
      resources = await pending;
    } catch (_) {
      return;
    }
    resources.dispose();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences could not be loaded: $e');
  }
  final backendConfig = await BackendApiConfig.load(prefs);
  ApiConstants.configure(backendConfig);

  PendingRecovery? initialRecovery;
  if (prefs != null) {
    try {
      final store = RecoveryIntentStore(prefs, projectNamespace: 'travelgo');
      initialRecovery = await store.read();
    } catch (_) {}
  }

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
  runApp(
    TravelGoApp(
      backendConfig: backendConfig,
      initialRecoveryIntentId: initialRecovery?.intentId,
    ),
  );
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
  final BackendApiConfig? backendConfig;
  final AuthProvider? authProvider;
  final PasswordRecoveryProvider? recoveryProvider;
  final RecoveryIntentStore? recoveryIntentStore;
  final PasswordRecoveryService? recoveryService;
  final String? initialRecoveryIntentId;
  final TripProvider? legacyTrip;
  const TravelGoApp({
    super.key,
    this.localStoreRuntime,
    this.authClient,
    this.authCallbackLinks,
    this.initialAuthLinkLoader,
    this.backendConfig,
    this.authProvider,
    this.recoveryProvider,
    this.recoveryIntentStore,
    this.recoveryService,
    this.initialRecoveryIntentId,
    this.legacyTrip,
  });

  @override
  State<TravelGoApp> createState() => _TravelGoAppState();
}

class _TravelGoAppState extends State<TravelGoApp> with WidgetsBindingObserver {
  late final LocalTripStoreRuntime _runtime;
  late final ManualPlannerRuntime _manualRuntime;
  late final AuthProvider _auth;
  late final BackendApiConfig _backendConfig;
  late final PasswordRecoveryProvider _recoveryProvider;
  SupabaseClient? _client;
  Future<LocalAccountLifecycleService>? _loadingLifecycle;
  StreamSubscription<Uri>? _links;
  final List<VoidCallback> _removeRamBindings = [];
  Future<GuestDraftsProvider?>? _guestProviderLoading;
  GuestDraftsProvider? _guestDrafts;
  GuestImportService? _guestImports;
  DioGuestImportTransport? _guestTransport;
  TripSnapshotService? _snapshotReader;
  EditableTripRepository? _editableRepository;
  EditableTripService? _editableService;
  PublicCatalogueProvider? _publicCatalogueProvider;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _backendConfig = widget.backendConfig ?? BackendApiConfig.unpersisted();
    ApiConstants.configure(_backendConfig);
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
    _auth = widget.authProvider ??
        AuthProvider(
      client: _client,
      lifecycleLoader: _client == null ? null : _getLifecycle,
      sessionReader: () => _client?.auth.currentSession,
      initialRecoveryIntentId: widget.initialRecoveryIntentId,
    );
    final recoveryStore = widget.recoveryIntentStore ??
        RecoveryIntentStore(
          _backendConfig.preferences,
          projectNamespace: 'travelgo',
        );
    _recoveryProvider = widget.recoveryProvider ??
        PasswordRecoveryProvider(
          service: widget.recoveryService ?? PasswordRecoveryService(),
          store: recoveryStore,
          auth: _auth,
          clientProvider: () => _client,
        );
    unawaited(_recoveryProvider.initializeFromStore());
    _manualRuntime = ManualPlannerRuntime(factory: _createManualResources);
    WidgetsBinding.instance.addObserver(this);
    if (_client != null) {
      _links = (widget.authCallbackLinks ?? AppLinks().uriLinkStream).listen(
        (uri) {
          if (!_disposed) {
            if (uri.queryParameters['flow'] == 'recovery') {
              unawaited(_recoveryProvider.handleCallback(uri));
            } else {
              unawaited(_auth.handleAuthCallback(uri));
            }
          }
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
        if (initial.queryParameters['flow'] == 'recovery') {
          await _recoveryProvider.handleCallback(initial);
        } else {
          await _auth.handleAuthCallback(initial);
        }
      }
    } catch (_) {
      /* No callback is safer than a fabricated authentication. */
    }
  }

  Future<LocalAccountLifecycleService> _getLifecycle() =>
      _loadingLifecycle ??= _createLifecycle();

  Future<ManualPlannerResources> _createManualResources() async {
    final lifecycle = await _getLifecycle();
    final store = await _runtime.getStore();
    if (_disposed) throw StateError('App resources are closed.');
    final repository = _getEditableRepository(lifecycle, store);
    return ManualPlannerResources(
      repository: repository,
      planner: ManualPlannerProvider(
        repositoryLoader: () async => repository,
        lifecycle: lifecycle,
      ),
      drafts: EditableDraftsProvider(
        storeLoader: _runtime.getStore,
        repositoryLoader: () async => repository,
        lifecycle: lifecycle,
        deviceScope: 'default',
      ),
    );
  }

  EditableTripRepository _getEditableRepository(
    LocalAccountLifecycleService lifecycle,
    LocalTripStore store,
  ) {
    final existing = _editableRepository;
    if (existing != null) return existing;
    final service = EditableTripService(
      projectUrl: SupabaseConstants.projectUrl,
      publicKey: SupabaseConstants.publishableKey,
      isCurrentProof: lifecycle.isCurrentProof,
      adapter: const bool.fromEnvironment('TRAVELGO_P32_DROP_UI_REPLY')
          ? P32DropCommittedReplyAdapter()
          : null,
    );
    _editableService = service;
    return _editableRepository = EditableTripRepository(
      store: store,
      lifecycle: lifecycle,
      service: service,
    );
  }

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
            final editable = _getEditableRepository(lifecycle, store);
            saved.bindAccount(
              lifecycle: lifecycle,
              store: store,
              snapshots: snapshots,
              handle: handle,
            );
            saved.bindEditableRepository(editable);
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
        final subjectId = user!.user!.id;
        final accessService = AccountAccessService(client: _client);
        final access = await accessService.verify(token);
        if (access.subjectId != subjectId) {
          throw StateError('Subject mismatch during access verification');
        }
        if (!access.isEnabled) {
          throw StateError('Account access not enabled: ${access.state}');
        }
        return subjectId;
      },
    );
  }

  PublicCatalogueProvider _getPublicCatalogueProvider() {
    return _publicCatalogueProvider ??= PublicCatalogueProvider(
      repository: PublicCatalogueRepository(
        seedLoader: () async {
          final text = await rootBundle.loadString('assets/catalogue/catalogue_readiness_v1.json');
          final catalogue = CatalogueParser().parse(text);
          final manifest = DiscoveryManifest(
            contract: 'travelgo.discovery.manifest.v2',
            schemaVersion: 2,
            version: 1,
            objectKey: 'releases/v2/1.json',
            sha256: 'c14cecc97149a3acf64f439d44662333bbb8756bd580e18f368ac053bdd1542a',
            byteLength: text.length,
            publishedAt: DateTime.utc(2026, 10, 20),
          );
          return PublicCatalogueSnapshot(
            version: 1,
            sha256: manifest.sha256,
            origin: 'seed',
            manifest: manifest,
            catalogue: catalogue,
            visits: VisitCatalogue.fromPublicProjection(
              version: 1,
              publishedAt: manifest.publishedAt,
              releaseSha256: manifest.sha256,
              data: const {
                'sources': <Map<String, Object?>>[],
                'packages': <Map<String, Object?>>[],
                'places': <Map<String, Object?>>[],
              },
              expectedPlaceIds: catalogue.destinations.expand((d) => d.places).map((p) => p.id).toSet(),
              now: DateTime.now(),
            ),
            fetchedAt: DateTime.now(),
            payloadText: text,
          );
        },
        cache: PublicCatalogueCache(
          databasePath: () async => p.join(await getDatabasesPath(), 'public_discovery_v2.db'),
        ),
        client: Dio(),
        projectOrigin: SupabaseConstants.projectUrl,
        publishableKey: SupabaseConstants.publishableKey,
      ),
    )..initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_disposed) {
      unawaited(_auth.handleAppLifecycleState(state));
      if (state == AppLifecycleState.resumed) {
        unawaited(_publicCatalogueProvider?.onResume() ?? Future.value());
      }
    }
  }

  Future<void> _closeResources() async {
    try {
      await _manualRuntime.close();
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
    _editableService?.close();
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
        ChangeNotifierProvider.value(value: _backendConfig),
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider<PasswordRecoveryProvider>.value(
          value: _recoveryProvider,
        ),
        Provider<Future<LocalAccountLifecycleService> Function()>.value(value: _getLifecycle),
        Provider<LocalTripStoreRuntime>.value(value: _runtime),
        Provider<ManualPlannerRuntime>.value(value: _manualRuntime),
        ChangeNotifierProvider<PlannerInputProvider>(
          create: (context) {
            final input = PlannerInputProvider();
            _removeRamBindings.add(
              _auth.registerAccountInvalidator(() {
                input.reset();
              }),
            );
            return input;
          },
        ),
        if (widget.legacyTrip != null)
          ChangeNotifierProxyProvider<AuthProvider, TripProvider>(
            create: (_) => widget.legacyTrip!,
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
        // favorites provider removed
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
        ChangeNotifierProvider<PublicCatalogueProvider>.value(
          value: _getPublicCatalogueProvider(),
        ),
        ChangeNotifierProxyProvider<PublicCatalogueProvider, HomeCatalogProvider>(
          create: (_) => HomeCatalogProvider(),
          update: (_, publicCat, home) {
            final h = home ?? HomeCatalogProvider();
            final snapshot = publicCat.snapshot;
            if (snapshot != null) {
              h.bindPublicSnapshot(snapshot);
            }
            return h;
          },
        ),
        ChangeNotifierProxyProvider<PublicCatalogueProvider, DiscoveryProvider>(
          create: (_) => DiscoveryProvider(
            publicSnapshotLoader: (force) async {
              final pub = _getPublicCatalogueProvider();
              await pub.refresh(force: force);
              return pub.snapshot ?? await pub.repository.load();
            },
          ),
          update: (_, publicCat, discovery) {
            final d = discovery ?? DiscoveryProvider(
              publicSnapshotLoader: (force) async {
                await publicCat.refresh(force: force);
                return publicCat.snapshot ?? await publicCat.repository.load();
              },
            );
            final snapshot = publicCat.snapshot;
            if (snapshot != null) {
              d.bindPublicSnapshot(snapshot);
            }
            return d;
          },
        ),
        ChangeNotifierProxyProvider<PublicCatalogueProvider, PlaceVisitDetailsProvider>(
          create: (_) => PlaceVisitDetailsProvider(
            now: DateTime.now,
            repositoryFactory: (catalogue) async => VisitDetailsRepository(
              dio: Dio(),
              ownsDio: true,
              cache: SqliteVisitReleaseCache(
                databasePath: () async => p.join(
                  await getDatabasesPath(),
                  'travelgo_discovery_public_v1.db',
                ),
              ),
              seedLoader: () => rootBundle.loadString(
                'assets/catalogue/place_visit_details_v1.json',
              ),
              projectOrigin: Uri.parse(SupabaseConstants.projectUrl),
              remoteEnabled: SupabaseConstants.isStaging,
              expectedPlaceIds: catalogue.destinations
                  .expand((destination) => destination.places)
                  .map((place) => place.id)
                  .toSet(),
              expectedCatalogueSha256: 'c14cecc97149a3acf64f439d44662333bbb8756bd580e18f368ac053bdd1542a',
              now: DateTime.now,
            ),
          ),
          update: (_, publicCat, visitsProvider) {
            final vp = visitsProvider ?? PlaceVisitDetailsProvider(
              now: DateTime.now,
              repositoryFactory: (catalogue) async => VisitDetailsRepository(
                dio: Dio(),
                ownsDio: true,
                cache: SqliteVisitReleaseCache(
                  databasePath: () async => p.join(
                    await getDatabasesPath(),
                    'travelgo_discovery_public_v1.db',
                  ),
                ),
                seedLoader: () => rootBundle.loadString(
                  'assets/catalogue/place_visit_details_v1.json',
                ),
                projectOrigin: Uri.parse(SupabaseConstants.projectUrl),
                remoteEnabled: SupabaseConstants.isStaging,
                expectedPlaceIds: catalogue.destinations
                    .expand((destination) => destination.places)
                    .map((place) => place.id)
                    .toSet(),
                expectedCatalogueSha256: 'c14cecc97149a3acf64f439d44662333bbb8756bd580e18f368ac053bdd1542a',
                now: DateTime.now,
              ),
            );
            final snapshot = publicCat.snapshot;
            if (snapshot != null) {
              vp.bindPublicSnapshot(snapshot);
            }
            return vp;
          },
        ),
        // map provider removed
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
        home: PasswordRecoveryGate(
          child: _AuthBootstrap(auth: _auth),
        ),
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
          ? const MainNavigationShell(enableCommunityTab: true)
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
            child: NavigatorPopHandler<Object?>(
              enabled: !waiting,
              onPopWithResult: (result) {
                if (!waiting) _navigatorKey.currentState?.maybePop(result);
              },
              child: Navigator(
                key: _navigatorKey,
                observers: [_routeObserver],
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => const SplashScreen(),
                ),
              ),
            ),
          ),
          if (waiting)
            Positioned.fill(
              child: _BootstrapWaitingOverlay(
                onGuest: () {
                  widget.auth.continueAsGuest();
                  setState(() => _guestChosen = true);
                },
              ),
            ),
        ],
      );
    },
  );
}

class _BootstrapWaitingOverlay extends StatelessWidget {
  final VoidCallback onGuest;
  const _BootstrapWaitingOverlay({required this.onGuest});
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Đang kiểm tra phiên đăng nhập',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onGuest,
                child: const Text('Tiếp tục với Guest'),
              ),
            ],
          ),
        ),
      ),
    ),
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

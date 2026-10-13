import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:travelgo_mobile/features/trips/providers/guest_drafts_provider.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trips/services/guest_import_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';
import 'package:travelgo_mobile/features/trips/services/trip_snapshot_service.dart';

import 'guest_import_service_test.dart' as imports;
import 'local_account_lifecycle_test.dart' as accounts;
import 'local_trip_store_test.dart' as fixtures;

class _OfflineReader extends TripSnapshotService {
  _OfflineReader(LocalAccountLifecycleService lifecycle)
    : super(
        projectUrl: 'https://fixture.example.test',
        publicKey: 'fixture-public',
        isCurrentProof: lifecycle.isCurrentProof,
      );

  @override
  Future<SnapshotFetchBatch> fetchSnapshots({
    required AccountSessionProof proof,
  }) async => throw DioException(
    requestOptions: RequestOptions(path: '/trips'),
    type: DioExceptionType.connectionError,
  );
}

class _Runtime {
  bool _closed = false;
  final fixtures.TestStoreContext context;
  Session session;
  late final LocalAccountLifecycleService lifecycle;
  late final GuestImportService importer;
  late final GuestDraftsProvider drafts;
  late final _OfflineReader reader;
  final saved = SavedTripsProvider(requiresLifecycle: true);

  _Runtime(this.context, this.session, imports.FakeImportTransport transport) {
    lifecycle = LocalAccountLifecycleService(
      storeLoader: () async => context.store,
      sessionReader: () => session,
      registryPath: '${context.tempDir.path}/batch_b_lifecycle.json',
    );
    importer = GuestImportService(
      store: context.store,
      auth: GuestImportAuthContext(() => session),
      transport: transport,
    );
    drafts = GuestDraftsProvider(
      store: context.store,
      service: importer,
      deviceScope: 'default',
    );
    reader = _OfflineReader(lifecycle);
    lifecycle.registerConsumer(
      invalidate: () {
        drafts.unbindSession();
        saved.unbindAccount();
      },
      bind: (handle) async {
        drafts.bindSession(handle);
        saved.bindAccount(
          lifecycle: lifecycle,
          store: context.store,
          snapshots: reader,
          handle: handle,
        );
        await drafts.reload();
      },
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    // Invalidate registered consumers while they are still alive.
    await lifecycle.close();
    drafts.dispose();
    importer.dispose();
    saved.dispose();
    reader.close();
  }
}

Future<void> _reopen(fixtures.TestStoreContext context) async {
  await context.store.close();
  context.store = LocalTripStore(
    databaseFactory: databaseFactoryFfi,
    databasePath: context.dbPath,
  );
  await context.store.open();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'B9 lost ack, newer edit, restart, explicit retry and offline logout',
    () async {
      await fixtures.runWithStore((ctx) async {
        final session = accounts.sessionFor(accounts.ownerA);
        final remote = imports.FakeImportTransport();
        var runtime = _Runtime(ctx, session, remote);
        try {
          await ctx.store.saveDraftRevision(
            draftId: 'selected',
            payload: fixtures.createValidPayload(),
          );
          await ctx.store.saveDraftRevision(
            draftId: 'unselected',
            payload: fixtures.createValidPayload(includePlan: false),
          );
          expect(
            await runtime.lifecycle.establishAccount(freshAuthentication: true),
            isNotNull,
          );
          expect(runtime.drafts.selectedSources, isEmpty);
          final source = runtime.drafts.sourceFor(
            runtime.drafts.drafts.firstWhere((d) => d.draftId == 'selected'),
          )!;
          runtime.drafts.select(source, true);
          remote.loseReply = true;
          expect(
            (await runtime.drafts.confirmAndImport()).single.status,
            GuestImportStatus.pendingRetry,
          );
          expect(remote.remote, hasLength(1));
          await ctx.store.saveDraftRevision(
            draftId: 'selected',
            payload: fixtures.createValidPayload(title: 'Newer edit'),
          );
          expect(await runtime.lifecycle.sealForPause(), isTrue);
          await runtime.close();
          await _reopen(ctx);
          runtime = _Runtime(ctx, session, remote);
          expect(await runtime.lifecycle.resumeAccount(), isNotNull);
          expect(runtime.drafts.selectedSources, isEmpty);
          expect(remote.calls, hasLength(1));
          expect(runtime.drafts.attempts.single.sourceRevision, 1);
          remote.loseReply = false;
          expect(
            (await runtime.drafts.retry(source)).status,
            GuestImportStatus.committed,
          );
          expect(remote.calls[1], remote.calls[0]);
          expect(remote.remote, hasLength(1));
          final guest = await ctx.store.listGuestDrafts();
          expect(
            guest.map((d) => d.draftId),
            containsAll(['selected', 'unselected']),
          );
          expect(
            guest.firstWhere((d) => d.draftId == 'selected').currentRevision,
            2,
          );
          expect(
            await ctx.store.getDraftRevision(draftId: 'selected', revision: 1),
            isNull,
          );
          await runtime.saved.loadTrips(accounts.ownerA);
          expect(runtime.saved.cacheState, AccountCacheState.offline);
          expect(
            runtime.saved.accountSnapshots.single.cachedPayload.metadata.title,
            isNot('Newer edit'),
          );
          expect(
            runtime
                .saved
                .accountSnapshots
                .single
                .cachedPayload
                .plan!
                .itineraryDays
                .single
                .activities
                .single
                .title,
            'Tắm biển',
          );
          expect(await runtime.lifecycle.revokeAccount(), isTrue);
          expect(runtime.saved.trips, isEmpty);
          expect(runtime.drafts.attempts, isEmpty);
          expect(
            await ctx.store.rawDb.query('account_trip_snapshots'),
            isEmpty,
          );
          expect(await ctx.store.rawDb.query('local_import_journal'), isEmpty);
          expect(remote.remote, hasLength(1));
          expect(await ctx.store.listGuestDrafts(), hasLength(2));
        } finally {
          await runtime.close();
        }
      });
    },
  );

  test(
    'B9 pending A quarantine cannot be imported by B after restart',
    () async {
      await fixtures.runWithStore((ctx) async {
        final remote = imports.FakeImportTransport()..loseReply = true;
        final sessionA = accounts.sessionFor(accounts.ownerA);
        var runtime = _Runtime(ctx, sessionA, remote);
        try {
          await ctx.store.saveDraftRevision(
            draftId: 'pending',
            payload: fixtures.createValidPayload(),
          );
          expect(
            await runtime.lifecycle.establishAccount(freshAuthentication: true),
            isNotNull,
          );
          final source = runtime.drafts.sourceFor(
            runtime.drafts.drafts.single,
          )!;
          runtime.drafts.select(source, true);
          expect(
            (await runtime.drafts.confirmAndImport()).single.status,
            GuestImportStatus.pendingRetry,
          );
          expect(await runtime.lifecycle.revokeAccount(), isTrue);
          await runtime.close();
          await _reopen(ctx);
          runtime = _Runtime(ctx, accounts.sessionFor(accounts.ownerB), remote);
          expect(
            await runtime.lifecycle.establishAccount(freshAuthentication: true),
            isNotNull,
          );
          expect(runtime.drafts.attempts, isEmpty);
          expect(
            (await runtime.drafts.retry(source)).status,
            GuestImportStatus.rejected,
          );
          expect(remote.calls, hasLength(1));
          await runtime.saved.loadTrips(accounts.ownerB);
          expect(runtime.saved.cacheState, AccountCacheState.unavailable);
          expect(runtime.saved.accountSnapshots, isEmpty);
          expect(await runtime.lifecycle.revokeAccount(), isTrue);
          await runtime.close();
          await _reopen(ctx);
          runtime = _Runtime(ctx, sessionA, remote);
          expect(
            await runtime.lifecycle.establishAccount(freshAuthentication: true),
            isNotNull,
          );
          expect(runtime.drafts.selectedSources, isEmpty);
          expect(runtime.drafts.attempts.single.state, 'quarantined');
          remote.loseReply = false;
          expect(
            (await runtime.drafts.retry(source)).status,
            GuestImportStatus.committed,
          );
          expect(remote.calls[1], remote.calls[0]);
          expect(remote.remote, hasLength(1));
        } finally {
          await runtime.close();
        }
      });
    },
  );

  test(
    'B9 failed purge marker plus restart denies stale cache and retains Guest',
    () async {
      await fixtures.runWithStore((ctx) async {
        final remote = imports.FakeImportTransport();
        final session = accounts.sessionFor(accounts.ownerA);
        var runtime = _Runtime(ctx, session, remote);
        try {
          await ctx.store.saveDraftRevision(
            draftId: 'guest',
            payload: fixtures.createValidPayload(),
          );
          expect(
            await runtime.lifecycle.establishAccount(freshAuthentication: true),
            isNotNull,
          );
          await ctx.store.replaceSnapshot(
            handle: runtime.lifecycle.handle!,
            tripId: 'owned',
            payload: fixtures.createValidPayload(),
            fetchedAt: DateTime.now().toUtc(),
          );
          await runtime.saved.loadTrips(accounts.ownerA);
          expect(runtime.saved.cacheState, AccountCacheState.offline);
          ctx.store.onPurgeStepForTesting = (step) async {
            if (step == 'before_marker_txn') {
              throw StateError('Injected marker fault');
            }
          };
          expect(await runtime.lifecycle.revokeAccount(), isFalse);
          expect(runtime.saved.accountSnapshots, isEmpty);
          expect(
            await ctx.store.rawDb.query('account_trip_snapshots'),
            hasLength(1),
          );
          await runtime.close();
          await _reopen(ctx);
          runtime = _Runtime(ctx, session, remote);
          expect(await runtime.lifecycle.resumeAccount(), isNull);
          expect(runtime.saved.accountSnapshots, isEmpty);
          expect(
            await ctx.store.rawDb.query('account_trip_snapshots'),
            isEmpty,
          );
          expect(await ctx.store.listGuestDrafts(), hasLength(1));
          expect(remote.calls, isEmpty);
        } finally {
          await runtime.close();
        }
      });
    },
  );
}

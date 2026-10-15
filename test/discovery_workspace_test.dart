import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

import 'guest_draft_planner_test.dart' show DraftApi, planner;
import 'local_trip_store_test.dart' as fixtures;

bool selectHue(TripProvider p, {bool replace = false, int? generation}) =>
    p.prepareDestinationWorkspace(
      destinationId: 'hue',
      destinationName: 'Huế',
      expectedWorkspaceGeneration: generation ?? p.workspaceGeneration,
      replaceDirty: replace,
    );

void main() {
  sqfliteFfiInit();
  test('selection retains every input field, detaches identity, rejects invalid/stale/dirty', () async {
    await fixtures.runWithStore((ctx) async {
      final api = DraftApi();
      final p = planner(ctx, api);
      addTearDown(p.dispose);
      p.updateRequest(
        p.currentRequest.copyWith(
          origin: 'Hà Nội',
          numDays: 6,
          numPeople: 7,
          budgetVnd: 8765432,
          preferences: ['văn hóa'],
          priority: 'fastest',
        ),
      );
      final old = await p.saveGuestDraft();
      final request = p.currentRequest.toJson();
      final generation = p.workspaceGeneration;
      expect(selectHue(p), true);
      expect(p.currentRequest.toJson(), request);
      expect(p.currentMetadata.destinationId, 'hue');
      expect(p.currentMetadata.startDate, isNull);
      expect(p.currentMetadata.timezone, isNull);
      expect(p.activeDraftId, isNull);
      expect(p.activeDraftRevision, isNull);
      expect(p.isDraftDirty, true);
      expect(p.currentResponse, isNull);
      expect(selectHue(p), false);
      expect(selectHue(p, replace: true, generation: generation), false);
      expect(
        p.prepareDestinationWorkspace(
          destinationId: '',
          destinationName: 'bad',
          expectedWorkspaceGeneration: p.workspaceGeneration,
          replaceDirty: true,
        ),
        false,
      );
      expect(
        (await ctx.store.getDraftRevision(
          draftId: old!.draftId,
          revision: 1,
        ))!.payloadJson,
        old.payloadJson,
      );
      expect(api.plans, 0);
    });
  });
  test('disk save/reopen selected input preserves V1/hash, revisions and blocks engine', () async {
    await fixtures.runWithStore((ctx) async {
      final api = DraftApi();
      final p = planner(ctx, api);
      addTearDown(p.dispose);
      expect(selectHue(p), true);
      final row = await p.saveGuestDraft();
      final next = await p.saveGuestDraft();
      expect(next!.draftId, row!.draftId);
      expect(next.revision, 2);
      expect(TripPayloadCodec.computeDigest(row.cachedPayload), row.digest);
      await ctx.store.close();
      await ctx.store.open();
      final reopened = planner(ctx, api);
      addTearDown(reopened.dispose);
      expect(
        await reopened.openGuestDraft(
          draftId: row.draftId,
          revision: 2,
          expectedWorkspaceGeneration: reopened.workspaceGeneration,
        ),
        true,
      );
      expect(reopened.currentMetadata.destinationId, 'hue');
      expect(reopened.currentMetadata.destinationName, 'Huế');
      expect(reopened.currentResponse, isNull);
      expect(reopened.isDraftDirty, false);
      await reopened.init();
      expect(await reopened.submitPlan(), false);
      expect(api.plans, 0);
      expect(api.health, 0);
      expect(
        reopened.useSuggestedDestination(
          expectedWorkspaceGeneration: reopened.workspaceGeneration,
        ),
        true,
      );
      expect(reopened.currentMetadata.destinationId, isNull);
      expect(reopened.activeDraftId, isNull);
      expect(await reopened.submitPlan(), true);
      expect(api.plans, 1);
      expect(await ctx.store.listGuestDrafts(), hasLength(1));
    });
  });
  test('selected guard preserves saved plan-only result and old dates are not copied', () async {
    await fixtures.runWithStore((ctx) async {
      final original = fixtures.createValidPayload();
      await ctx.store.saveDraftRevision(
        draftId: 'with-plan',
        payload: CanonicalTripPayloadV1(
          metadata: TripMetadataV1(
            title: 'Cũ',
            destinationId: 'hue',
            destinationName: 'Huế',
            startDate: '2026-11-01',
            endDate: '2026-11-03',
            timezone: 'Asia/Ho_Chi_Minh',
          ),
          request: null,
          plan: original.plan,
        ),
      );
      final api = DraftApi();
      final p = planner(ctx, api);
      addTearDown(p.dispose);
      await p.openGuestDraft(
        draftId: 'with-plan',
        revision: 1,
        expectedWorkspaceGeneration: p.workspaceGeneration,
      );
      final response = p.currentResponse;
      expect(await p.submitPlan(), false);
      expect(identical(p.currentResponse, response), true);
      expect(selectHue(p), true);
      expect(p.hasPlannerInput, true);
      expect(p.currentMetadata.title, 'Chuyến đi Huế');
      expect(p.currentMetadata.startDate, isNull);
      expect(api.plans, 0);
    });
  });
  test('pending save/load, Auth epoch and dispose reject replacement without mutation', () async {
    final loader = Completer<LocalTripStore>();
    final p = TripProvider(localStoreLoader: () => loader.future);
    final saving = p.saveGuestDraft();
    final before = p.currentRequest;
    expect(p.canReplaceWorkspace, false);
    expect(selectHue(p, replace: true), false);
    expect(identical(p.currentRequest, before), true);
    loader.completeError(StateError('test disk'));
    await saving;
    final generation = p.workspaceGeneration;
    p.setPlannerContext(
      isGuest: true,
      isDemo: false,
      ownerId: null,
      authEpoch: 1,
    );
    expect(selectHue(p, replace: true, generation: generation), false);
    p.dispose();
    expect(selectHue(p, replace: true), false);
  });
  test('pending load rejects selection until completion', () async {
    final loader = Completer<LocalTripStore>();
    final p = TripProvider(localStoreLoader: () => loader.future);
    addTearDown(p.dispose);
    final loading = p.listGuestDrafts();
    expect(selectHue(p), false);
    loader.completeError(StateError('test load'));
    await loading;
    expect(p.canReplaceWorkspace, true);
  });
  test('late API response cannot replace destination workspace', () async {
    final api = DraftApi()..delayed = true;
    final p = TripProvider(apiService: api);
    addTearDown(p.dispose);
    final pending = p.submitPlan();
    expect(selectHue(p, replace: true), true);
    api.pending.single.complete(fixtures.createValidPayload().plan!);
    expect(await pending, false);
    expect(p.currentResponse, isNull);
    expect(p.currentMetadata.destinationId, 'hue');
    expect(p.isLoading, false);
  });
  test(
    'Guest checkpoint survives account A/B selections without writes',
    () async {
      var opens = 0;
      final p = TripProvider(
        apiService: DraftApi(),
        localStoreLoader: () {
          opens++;
          throw StateError('must not write');
        },
      );
      addTearDown(p.dispose);
      expect(selectHue(p), true);
      final guestRequest = p.currentRequest.toJson();
      p.setPlannerContext(
        isGuest: false,
        isDemo: false,
        ownerId: 'A',
        authEpoch: 1,
      );
      expect(p.isAccountWorkspace, true);
      expect(
        p.prepareDestinationWorkspace(
          destinationId: 'da-lat',
          destinationName: 'Đà Lạt',
          expectedWorkspaceGeneration: p.workspaceGeneration,
          replaceDirty: true,
        ),
        true,
      );
      expect(p.canPersistGuestDraft, false);
      p.setPlannerContext(
        isGuest: false,
        isDemo: false,
        ownerId: 'B',
        authEpoch: 2,
      );
      expect(p.currentMetadata.destinationId, 'hue');
      expect(selectHue(p, replace: true), true);
      p.setPlannerContext(
        isGuest: true,
        isDemo: false,
        ownerId: null,
        authEpoch: 3,
      );
      expect(p.currentMetadata.destinationId, 'hue');
      expect(p.currentRequest.toJson(), guestRequest);
      expect(opens, 0);
    },
  );
}

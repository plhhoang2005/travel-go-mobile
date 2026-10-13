import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:travelgo_mobile/main.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/auth/presentation/screens/splash_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_api_service.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/home_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/dashboard_result_screen.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';

import 'local_trip_store_test.dart' as fixtures;

class DraftApi extends TripApiService {
  int plans = 0;
  int health = 0;
  final pending = <Completer<PlanTripResponse>>[];
  bool delayed = false;
  @override
  Future<bool> checkHealth() async {
    health++;
    return false;
  }

  @override
  Future<PlanTripResponse> planTrip(PlanTripRequest request) {
    plans++;
    if (delayed) {
      final c = Completer<PlanTripResponse>();
      pending.add(c);
      return c.future;
    }
    return Future.value(fixtures.createValidPayload().plan!);
  }
}

TripProvider planner(fixtures.TestStoreContext ctx, DraftApi api) {
  var id = 0;
  final provider = TripProvider(
    apiService: api,
    localStoreLoader: () => Future.value(ctx.store),
    draftIdFactory: () => 'draft-${id++}',
  );
  provider.setPlannerContext(
    isGuest: true,
    isDemo: false,
    ownerId: null,
    authEpoch: 0,
  );
  return provider;
}

Future<void> pumpPlanner(
  WidgetTester tester,
  TripProvider trip, {
  Widget? screen,
  double textScale = 1,
}) async {
  final auth = AuthProvider()..continueAsGuest();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<TripProvider>.value(value: trip),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen ?? const HomePlannerScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(auth.dispose);
}

void main() {
  sqfliteFfiInit();
  testWidgets(
    'T08/T09 production ProxyProvider shares lazy runtime and preserves Guest across A/B',
    (tester) async {
      await tester.runAsync(
        () => fixtures.runWithStore((ctx) async {
          var opens = 0;
          final runtime = LocalTripStoreRuntime(
            factory: () async {
              opens++;
              return ctx.store;
            },
          );
          await tester.pumpWidget(TravelGoApp(localStoreRuntime: runtime));
          final context = tester.element(find.byType(SplashScreen));
          final auth = context.read<AuthProvider>();
          final trip = context.read<TripProvider>();
          expect(opens, 0);
          expect(trip.canPersistGuestDraft, false);
          auth.continueAsGuest();
          await tester.pump();
          context.read<TripProvider>();
          expect(trip.canPersistGuestDraft, true);
          trip.applyPreset(2);
          expect(await trip.saveGuestDraft(), isNotNull);
          expect(opens, 1);
          auth.simulateSupabaseUser(
            User(
              id: 'A',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '',
            ),
          );
          await tester.pump();
          context.read<TripProvider>();
          expect(trip.canPersistGuestDraft, false);
          trip.applyPreset(3);
          auth.simulateSupabaseUser(
            User(
              id: 'B',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '',
            ),
          );
          await tester.pump();
          context.read<TripProvider>();
          expect(trip.currentRequest.numDays, 4);
          auth.continueAsGuest();
          await tester.pump();
          context.read<TripProvider>();
          expect(trip.canPersistGuestDraft, true);
          expect(trip.currentRequest.numDays, 4);
          expect(opens, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await runtime.close();
        }),
      );
    },
  );
  test(
    'T03 lazy loader failure preserves input and explicit retry succeeds',
    () async {
      await fixtures.runWithStore((ctx) async {
        var calls = 0;
        final trip = TripProvider(
          apiService: DraftApi(),
          localStoreLoader: () async {
            if (calls++ == 0) throw StateError('storage unavailable');
            return ctx.store;
          },
        );
        addTearDown(trip.dispose);
        trip.applyPreset(2);
        expect(await trip.saveGuestDraft(), isNull);
        expect(trip.currentRequest.budgetVnd, 8000000);
        expect(trip.isDraftDirty, true);
        expect(trip.isSavingDraft, false);
        expect(await trip.saveGuestDraft(), isNotNull);
        expect(calls, 2);
      });
    },
  );
  test(
    'T04 preset/new/open/context/dispose fence delayed DE replies',
    () async {
      await fixtures.runWithStore((ctx) async {
        await ctx.store.saveDraftRevision(
          draftId: 'open',
          payload: fixtures.createValidPayload(includePlan: false),
        );
        for (final action in ['preset', 'new', 'open', 'context', 'dispose']) {
          final api = DraftApi()..delayed = true;
          final trip = planner(ctx, api);
          final response = trip.submitPlan();
          if (action == 'preset') trip.applyPreset(2);
          if (action == 'new') {
            trip.startNewGuestDraft(
              expectedWorkspaceGeneration: trip.workspaceGeneration,
            );
          }
          if (action == 'open') {
            await trip.openGuestDraft(
              draftId: 'open',
              revision: 1,
              expectedWorkspaceGeneration: trip.workspaceGeneration,
            );
          }
          if (action == 'context') {
            trip.setPlannerContext(
              isGuest: false,
              isDemo: false,
              ownerId: 'A',
              authEpoch: 1,
            );
          }
          if (action == 'dispose') trip.dispose();
          api.pending.single.complete(fixtures.createValidPayload().plan!);
          expect(await response, false);
          expect(trip.currentResponse, isNull);
          if (action != 'dispose') trip.dispose();
        }
      });
    },
  );
  test(
    'T06 late open after edits preserves newer input and exact older revision',
    () async {
      await fixtures.runWithStore((ctx) async {
        final a = await ctx.store.saveDraftRevision(
          draftId: 'source',
          payload: fixtures.createValidPayload(
            includePlan: false,
            title: 'old',
          ),
        );
        await ctx.store.saveDraftRevision(
          draftId: 'source',
          payload: fixtures.createValidPayload(
            includePlan: false,
            title: 'new',
          ),
        );
        final gate = Completer<void>();
        final trip = TripProvider(
          apiService: DraftApi(),
          localStoreLoader: () async {
            await gate.future;
            return ctx.store;
          },
        );
        addTearDown(trip.dispose);
        final opening = trip.openGuestDraft(
          draftId: 'source',
          revision: 1,
          expectedWorkspaceGeneration: trip.workspaceGeneration,
        );
        trip.applyPreset(2);
        gate.complete();
        expect(await opening, false);
        expect(trip.currentRequest.numDays, 4);
        expect(
          await trip.openGuestDraft(
            draftId: 'source',
            revision: a.revision,
            expectedWorkspaceGeneration: trip.workspaceGeneration,
          ),
          true,
        );
        expect(trip.activeDraftRevision, 1);
        expect(
          (await trip.saveGuestDraft())!.cachedPayload.metadata.title,
          'old',
        );
      });
    },
  );
  test('T09 successful runtime one initialization; planner disposal leaves shared store open', () async {
    await fixtures.runWithStore((ctx) async {
      var calls = 0;
      final runtime = LocalTripStoreRuntime(
        factory: () async {
          calls++;
          return ctx.store;
        },
      );
      final values = await Future.wait([
        runtime.getStore(),
        runtime.getStore(),
      ]);
      expect(values.first, same(values.last));
      expect(calls, 1);
      final trip = TripProvider(
        apiService: DraftApi(),
        localStoreLoader: runtime.getStore,
      );
      await trip.saveGuestDraft();
      trip.dispose();
      expect(await ctx.store.listGuestDrafts(), hasLength(1));
      await runtime.close();
      await ctx.store.open();
    });
  });
  test('T01 input-only disk save and explicit reopen call no API', () async {
    await fixtures.runWithStore((ctx) async {
      final api = DraftApi();
      final trip = planner(ctx, api);
      addTearDown(trip.dispose);
      trip.updateRequest(trip.currentRequest.copyWith(budgetVnd: 7654321));
      final saved = await trip.saveGuestDraft();
      expect(saved, isNotNull);
      expect(saved!.cachedPayload.plan, isNull);
      expect(trip.isDraftDirty, false);
      await ctx.store.close();
      await ctx.store.open();
      final restored = planner(ctx, api);
      addTearDown(restored.dispose);
      expect(
        await restored.openGuestDraft(
          draftId: saved.draftId,
          revision: saved.revision,
          expectedWorkspaceGeneration: restored.workspaceGeneration,
        ),
        true,
      );
      expect(restored.currentRequest.budgetVnd, 7654321);
      expect(restored.currentResponse, isNull);
      expect(api.plans, 0);
      expect(api.health, 0);
    });
  });
  test(
    'T01 full saved result preserves bytes dates fallback and false',
    () async {
      await fixtures.runWithStore((ctx) async {
        final raw = jsonDecode(
          TripPayloadCodec.encode(fixtures.createValidPayload()),
        ) as Map<String, dynamic>;
        (raw['metadata'] as Map).addAll(<String, dynamic>{
          'startDate': '2026-12-01',
          'endDate': '2026-12-03',
        });
        ((raw['plan'] as Map)['dataSources'] as Map)['mode'] =
            'offline fallback';
        (((raw['plan'] as Map)['transportOptions'] as List).first
                as Map)['paretoOptimal'] =
            false;
        final original = await ctx.store.saveDraftRevision(
          draftId: 'existing',
          payload: TripPayloadCodec.decode(raw),
        );
        final api = DraftApi();
        final trip = planner(ctx, api);
        addTearDown(trip.dispose);
        expect(
          await trip.openGuestDraft(
            draftId: 'existing',
            revision: 1,
            expectedWorkspaceGeneration: trip.workspaceGeneration,
          ),
          true,
        );
        final saved = await trip.saveGuestDraft();
        expect(saved!.payloadJson, original.payloadJson);
        expect(saved.revision, 2);
        expect(trip.currentResponse!.isFallback, true);
        expect(
          trip.currentResponse!.transportOptions.first.isParetoOptimal,
          false,
        );
        expect(api.plans, 0);
      });
    },
  );
  test('T02 same header new revisions; new action distinct identity; double tap one write', () async {
    await fixtures.runWithStore((ctx) async {
      final trip = planner(ctx, DraftApi());
      addTearDown(trip.dispose);
      final one = trip.saveGuestDraft();
      final two = trip.saveGuestDraft();
      final a = await one;
      final b = await two;
      expect(a!.revision, 1);
      expect(b!.revision, 1);
      trip.updateRequest(trip.currentRequest.copyWith(numDays: 5));
      final next = await trip.saveGuestDraft();
      expect(next!.draftId, a.draftId);
      expect(next.revision, 2);
      expect(
        trip.startNewGuestDraft(
          expectedWorkspaceGeneration: trip.workspaceGeneration,
        ),
        true,
      );
      final other = await trip.saveGuestDraft();
      expect(other!.draftId, isNot(a.draftId));
      expect(await ctx.store.listGuestDrafts(), hasLength(2));
    });
  });
  test('T03 actual revision-insert fault rolls back and retains input, retry succeeds', () async {
    await fixtures.runWithStore((ctx) async {
      final trip = planner(ctx, DraftApi());
      addTearDown(trip.dispose);
      trip.applyPreset(2);
      ctx.store.onSaveDraftStepForTesting = (step) async {
        if (step == 'after_revision_insert') throw StateError('fault');
      };
      expect(await trip.saveGuestDraft(), isNull);
      expect(trip.currentRequest.numDays, 4);
      expect(trip.isDraftDirty, true);
      expect(trip.draftErrorMessage, isNotNull);
      await ctx.store.close();
      await ctx.store.open();
      expect(await ctx.store.listGuestDrafts(), isEmpty);
      ctx.store.onSaveDraftStepForTesting = null;
      expect(await trip.saveGuestDraft(), isNotNull);
    });
  });
  test(
    'T04 response after edited request cannot publish or pair with new input',
    () async {
      await fixtures.runWithStore((ctx) async {
        final api = DraftApi()..delayed = true;
        final trip = planner(ctx, api);
        addTearDown(trip.dispose);
        final pending = trip.submitPlan();
        trip.updateRequest(trip.currentRequest.copyWith(numDays: 6));
        final saved = await trip.saveGuestDraft();
        expect(saved!.cachedPayload.plan, isNull);
        api.pending.single.complete(fixtures.createValidPayload().plan!);
        expect(await pending, false);
        expect(trip.currentResponse, isNull);
        expect(trip.currentRequest.numDays, 6);
      });
    },
  );
  test('T04 superseded request cannot clear newer loading or result', () async {
    await fixtures.runWithStore((ctx) async {
      final api = DraftApi()..delayed = true;
      final trip = planner(ctx, api);
      addTearDown(trip.dispose);
      final first = trip.submitPlan();
      final second = trip.submitPlan();
      api.pending[0].complete(fixtures.createValidPayload().plan!);
      expect(await first, false);
      expect(trip.isLoading, true);
      api.pending[1].complete(fixtures.createValidPayload().plan!);
      expect(await second, true);
      expect(trip.isLoading, false);
    });
  });
  for (final action in ['edit', 'new', 'context', 'dispose']) {
    test(
      'T05 $action during disk write never marks new workspace saved',
      () async {
        await fixtures.runWithStore((ctx) async {
          final trip = planner(ctx, DraftApi());
          if (action != 'dispose') addTearDown(trip.dispose);
          final entered = Completer<void>();
          final release = Completer<void>();
          ctx.store.onSaveDraftStepForTesting = (step) async {
            entered.complete();
            await release.future;
          };
          final writing = trip.saveGuestDraft();
          await entered.future;
          if (action == 'edit') trip.applyPreset(2);
          if (action == 'new') {
            trip.startNewGuestDraft(
              expectedWorkspaceGeneration: trip.workspaceGeneration,
            );
          }
          if (action == 'context') {
            trip.setPlannerContext(
              isGuest: false,
              isDemo: false,
              ownerId: 'A',
              authEpoch: 1,
            );
          }
          if (action == 'dispose') trip.dispose();
          release.complete();
          expect(await writing, isNull);
          expect(await ctx.store.listGuestDrafts(), hasLength(1));
          if (action == 'edit') {
            expect(trip.currentRequest.numDays, 4);
            expect(trip.isDraftDirty, true);
          }
        });
      },
    );
  }
  test('T06 corrupt, missing and stale open preserve workspace', () async {
    await fixtures.runWithStore((ctx) async {
      final row = await ctx.store.saveDraftRevision(
        draftId: 'bad',
        payload: fixtures.createValidPayload(),
      );
      final trip = planner(ctx, DraftApi());
      addTearDown(trip.dispose);
      trip.applyPreset(2);
      final oldGeneration = trip.workspaceGeneration;
      trip.applyPreset(3);
      expect(
        await trip.openGuestDraft(
          draftId: row.draftId,
          revision: 1,
          expectedWorkspaceGeneration: oldGeneration,
        ),
        false,
      );
      await ctx.store.rawDb.update('guest_draft_revisions', {
        'digest': '0' * 64,
      });
      expect(
        await trip.openGuestDraft(
          draftId: 'bad',
          revision: 1,
          expectedWorkspaceGeneration: trip.workspaceGeneration,
        ),
        false,
      );
      expect(trip.currentRequest.numDays, 2);
      expect(
        await trip.openGuestDraft(
          draftId: 'missing',
          revision: 1,
          expectedWorkspaceGeneration: trip.workspaceGeneration,
        ),
        false,
      );
    });
  });
  test('T07 plan-only never invents saved input', () async {
    await fixtures.runWithStore((ctx) async {
      final full = fixtures.createValidPayload();
      await ctx.store.saveDraftRevision(
        draftId: 'plan',
        payload: CanonicalTripPayloadV1(
          metadata: full.metadata,
          request: null,
          plan: full.plan,
        ),
      );
      final api = DraftApi();
      final trip = planner(ctx, api);
      addTearDown(trip.dispose);
      expect(
        await trip.openGuestDraft(
          draftId: 'plan',
          revision: 1,
          expectedWorkspaceGeneration: trip.workspaceGeneration,
        ),
        true,
      );
      expect(trip.hasPlannerInput, false);
      expect(await trip.submitPlan(), false);
      expect((await trip.saveGuestDraft())!.cachedPayload.request, isNull);
      expect(api.plans, 0);
      trip.startNewGuestDraft(
        expectedWorkspaceGeneration: trip.workspaceGeneration,
      );
      expect(trip.hasPlannerInput, true);
    });
  });
  test(
    'T08 Guest checkpoint survives A/B edits, no account/demo persistence',
    () async {
      await fixtures.runWithStore((ctx) async {
        final trip = planner(ctx, DraftApi());
        addTearDown(trip.dispose);
        trip.applyPreset(2);
        final saved = await trip.saveGuestDraft();
        trip.setPlannerContext(
          isGuest: false,
          isDemo: false,
          ownerId: 'A',
          authEpoch: 1,
        );
        trip.applyPreset(3);
        expect(await trip.saveGuestDraft(), isNull);
        trip.setPlannerContext(
          isGuest: false,
          isDemo: false,
          ownerId: 'B',
          authEpoch: 2,
        );
        expect(trip.currentRequest.numDays, 4);
        trip.setPlannerContext(
          isGuest: true,
          isDemo: false,
          ownerId: null,
          authEpoch: 3,
        );
        expect(trip.currentRequest.numDays, 4);
        expect(trip.activeDraftId, saved!.draftId);
        trip.setPlannerContext(
          isGuest: false,
          isDemo: true,
          ownerId: 'demo',
          authEpoch: 4,
        );
        expect(await trip.saveGuestDraft(), isNull);
        expect(await ctx.store.listGuestDrafts(), hasLength(1));
      });
    },
  );
  test(
    'T09 runtime shares initialization, retries error, closes late opening',
    () async {
      await fixtures.runWithStore((ctx) async {
        var calls = 0;
        final release = Completer<void>();
        final runtime = LocalTripStoreRuntime(
          factory: () async {
            calls++;
            await release.future;
            return ctx.store;
          },
        );
        final a = runtime.getStore();
        final b = runtime.getStore();
        final closed = runtime.close();
        release.complete();
        await expectLater(a, throwsA(isA<StateError>()));
        await expectLater(b, throwsA(isA<StateError>()));
        await closed;
        expect(calls, 1);
        await ctx.store.open();
        var attempts = 0;
        final retry = LocalTripStoreRuntime(
          factory: () async {
            if (attempts++ == 0) throw StateError('open failed');
            return ctx.store;
          },
        );
        await expectLater(retry.getStore(), throwsA(isA<StateError>()));
        expect(await retry.getStore(), same(ctx.store));
        await retry.close();
      });
    },
  );
  for (final width in [360.0, 390.0]) {
    testWidgets('T10/T13 Guest controls at $width with out-of-range values', (
      tester,
    ) async {
      await tester.runAsync(
        () => fixtures.runWithStore((ctx) async {
          final trip = planner(ctx, DraftApi());
          addTearDown(trip.dispose);
          trip.updateRequest(
            trip.currentRequest.copyWith(
              numDays: 10,
              numPeople: 20,
              budgetVnd: 20000000,
            ),
          );
          tester.view.physicalSize = Size(width, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await pumpPlanner(tester, trip, textScale: 1.3);
          expect(find.text('Bản nháp trên máy'), findsOneWidget);
          expect(find.text('Lưu bản nháp trên máy'), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(trip.currentRequest.numDays, 10);
          await tester.pumpWidget(const SizedBox());
        }),
      );
    });
  }
  testWidgets(
    'T11 open list confirms dirty replacement; cancel keeps current input',
    (tester) async {
      await tester.runAsync(
        () => fixtures.runWithStore((ctx) async {
          await ctx.store.saveDraftRevision(
            draftId: 'saved',
            payload: fixtures.createValidPayload(
              includePlan: false,
              title: 'Draft để mở',
            ),
          );
          final trip = planner(ctx, DraftApi());
          addTearDown(trip.dispose);
          trip.applyPreset(3);
          await pumpPlanner(tester, trip);
          await tester.ensureVisible(find.text('Bản nháp trên máy'));
          await tester.tap(find.text('Bản nháp trên máy'));
          while (trip.isLoadingDraft) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          await tester.pumpAndSettle();
          await tester.tap(find.text('Draft để mở'));
          await tester.pumpAndSettle();
          expect(find.text('Thay nội dung chưa lưu?'), findsOneWidget);
          await tester.tap(find.text('Hủy'));
          await tester.pumpAndSettle();
          expect(trip.currentRequest.numDays, 2);
          await tester.pumpWidget(const SizedBox());
        }),
      );
    },
  );
  testWidgets(
    'T14 dashboard Guest action is local and restored result labeled',
    (tester) async {
      await tester.runAsync(
        () => fixtures.runWithStore((ctx) async {
          await ctx.store.saveDraftRevision(
            draftId: 'result',
            payload: fixtures.createValidPayload(),
          );
          final trip = planner(ctx, DraftApi());
          addTearDown(trip.dispose);
          await trip.openGuestDraft(
            draftId: 'result',
            revision: 1,
            expectedWorkspaceGeneration: trip.workspaceGeneration,
          );
          await pumpPlanner(
            tester,
            trip,
            screen: const DashboardResultScreen(),
          );
          expect(find.text('Bản nháp trên máy'), findsOneWidget);
          expect(find.text('Lưu bản nháp trên máy'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        }),
      );
    },
  );
  testWidgets(
    'T10 Guest disk save failure retries and saves title without cloud',
    (tester) async {
      await tester.runAsync(
        () => fixtures.runWithStore((ctx) async {
          final api = DraftApi();
          final trip = planner(ctx, api);
          addTearDown(trip.dispose);
          await pumpPlanner(tester, trip);
          await tester.ensureVisible(find.text('Lưu bản nháp trên máy'));
          await tester.tap(find.text('Lưu bản nháp trên máy'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'Bản nháp Huế');
          ctx.store.onSaveDraftStepForTesting = (step) async {
            throw StateError('disk fault');
          };
          await tester.tap(find.text('Lưu'));
          while (trip.isSavingDraft) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(trip.draftErrorMessage, isNotNull);
          expect(await ctx.store.listGuestDrafts(), isEmpty);
          ctx.store.onSaveDraftStepForTesting = null;
          await tester.tap(find.text('Lưu'));
          while (trip.isSavingDraft) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(
            (await ctx.store.listGuestDrafts()).single.title,
            'Bản nháp Huế',
          );
          expect(api.plans, 0);
          await tester.pumpWidget(const SizedBox());
        }),
      );
    },
  );
  testWidgets(
    'T12 removing saving dialog disposes controller and drops late toast',
    (tester) async {
      await tester.runAsync(
        () => fixtures.runWithStore((ctx) async {
          final trip = planner(ctx, DraftApi());
          addTearDown(trip.dispose);
          final entered = Completer<void>();
          final release = Completer<void>();
          ctx.store.onSaveDraftStepForTesting = (step) async {
            entered.complete();
            await release.future;
          };
          await pumpPlanner(tester, trip);
          await tester.ensureVisible(find.text('Lưu bản nháp trên máy'));
          await tester.tap(find.text('Lưu bản nháp trên máy'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Lưu'));
          await entered.future;
          await tester.pumpWidget(const SizedBox());
          release.complete();
          while (trip.isSavingDraft) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(await ctx.store.listGuestDrafts(), hasLength(1));
        }),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:travelgo_mobile/main.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_repository.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/saved_trip_snapshot_screen.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/editable_trip_detail_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';

import 'editable_trip_repository_test.dart' as repository;
import 'editable_local_store_test.dart' as records;
import 'local_trip_store_test.dart' as legacy;
import 'manual_discovery_flow_test.dart' show resources;
import 'manual_budget_ui_test.dart' show tapText;
import 'manual_planner_screen_test.dart' show documentWithLinkedActivity;

class UiTrips extends SavedTripsProvider {
  List<OwnedTripSummary> rows = [];
  List<AccountTripSnapshotRecord> snapshots = [];
  @override
  List<SavedTrip> get trips => rows
      .where((r) => r.kind == OwnedTripKind.legacyV1)
      .map(
        (r) => SavedTrip(
          id: r.tripId,
          userId: r.ownerId,
          title: r.title,
          destinationName: r.destinationName,
          tripPlanData: const {},
        ),
      )
      .toList();
  bool more = false;
  int loads = 0;
  @override
  String? get currentUserId => records.ownerA;
  @override
  AccountCacheState get cacheState => AccountCacheState.online;
  @override
  bool get isLoading => false;
  @override
  List<OwnedTripSummary> get visibleTrips => rows;
  @override
  List<AccountTripSnapshotRecord> get accountSnapshots => snapshots;
  @override
  bool get hasMoreTrips => more;
  @override
  Future<void> loadTrips(String? owner) async {
    loads++;
    notifyListeners();
  }

  @override
  Future<void> loadMoreTrips() async {
    more = false;
    loads++;
    notifyListeners();
  }
}

class UiRepository extends EditableTripRepository {
  bool conflict = false;
  EditableHead? deletedBase;
  UiRepository(repository.Context ctx)
    : super(
        store: ctx.disk.store,
        lifecycle: ctx.lifecycle,
        service: ctx.remote,
      );
  @override
  Future<EditableMutationReply> deleteTrip(EditableHead base) {
    deletedBase = base;
    if (conflict) {
      throw const EditableRemoteException(
        EditableRemoteFailure.rejected,
        'version_conflict',
      );
    }
    return super.deleteTrip(base);
  }
}

OwnedTripSummary summary(String id, OwnedTripKind kind) => OwnedTripSummary(
  kind: kind,
  tripId: id,
  ownerId: records.ownerA,
  title: kind == OwnedTripKind.editableV2 ? 'Lịch tự lập' : 'Chuyến cũ',
  destinationName: 'Huế',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  version: kind == OwnedTripKind.editableV2 ? 1 : null,
);
User user(String id) => User(
  id: id,
  email: 'fixture@example.test',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-15T00:00:00Z',
);
Future<void> withUi(
  WidgetTester tester,
  Future<void> Function(
    repository.Context,
    AuthProvider,
    UiTrips,
    ManualPlannerRuntime,
    UiRepository,
  )
  body,
) async {
  await tester.runAsync(
    () => repository.run((ctx) async {
      await ctx.login();
      ctx.server.latest = records.head(document: documentWithLinkedActivity());
      final auth = AuthProvider(trustedRoleFetcher: (_) async => 'customer');
      await auth.initialization;
      auth.simulateSupabaseUser(user(records.ownerA));
      final trips = UiTrips();
      final repo = UiRepository(ctx);
      final bundle = resources(ctx);
      final runtime = ManualPlannerRuntime(
        factory: () async => ManualPlannerResources(
          planner: bundle.planner,
          drafts: bundle.drafts,
          repository: repo,
        ),
      );
      try {
        await body(ctx, auth, trips, runtime, repo);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await runtime.close();
        bundle.dispose();
        trips.dispose();
        auth.dispose();
      }
    }),
  );
}

Future<void> pumpUi(
  WidgetTester tester,
  Widget home,
  AuthProvider auth,
  UiTrips trips,
  ManualPlannerRuntime runtime,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider<SavedTripsProvider>.value(value: trips),
        Provider.value(value: runtime),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    ),
  );
  await tester.pump();
  await Future<void>.delayed(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

const detail = EditableTripDetailScreen(
  tripId: records.tripId,
  expectedOwnerId: records.ownerA,
);
void main() {
  testWidgets(
    'mixed list routes V2 to real detail and opens matching editable base',
    (tester) async {
      await withUi(tester, (ctx, auth, trips, runtime, repo) async {
        trips.rows = [
          summary(records.tripId, OwnedTripKind.editableV2),
          summary(
            'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            OwnedTripKind.legacyV1,
          ),
        ];
        trips.more = true;
        await pumpUi(tester, const MyTripsScreen(), auth, trips, runtime);
        expect(find.textContaining('Đã tải 2'), findsOneWidget);
        expect(find.text('Chuyến cũ'), findsOneWidget);
        expect(find.text('Xem lịch trình đã lưu'), findsOneWidget);
        expect(find.textContaining('1970'), findsNothing);
        await tapText(tester, 'Xem thêm chuyến đi');
        expect(trips.loads, 1);
        await tester.ensureVisible(find.text('Xem lịch trình tự lập'));
        await tester.tap(find.text('Xem lịch trình tự lập'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(find.byType(EditableTripDetailScreen), findsOneWidget);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        await tapText(tester, 'Chỉnh sửa lịch trình');
        expect(find.byType(ManualPlannerScreen), findsOneWidget);
        final planner = (await runtime.getResources()).planner;
        expect(planner.baseHead!.tripId, records.tripId);
        expect(planner.baseHead!.version, 1);
        expect(
          planner.document!.actualExpenses.length,
          documentWithLinkedActivity().actualExpenses.length,
        );
      });
    },
  );
  testWidgets(
    'cached V2 shows complete read only document and disables writes',
    (tester) async {
      await withUi(tester, (ctx, auth, trips, runtime, repo) async {
        await ctx.disk.store.putEditableSnapshot(
          handle: ctx.lifecycle.handle!,
          head: records.head(document: documentWithLinkedActivity()),
        );
        ctx.server.offline = true;
        await pumpUi(tester, detail, auth, trips, runtime);
        expect(find.text('Ngoại tuyến · bản trên máy chỉ đọc'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Chỉnh sửa lịch trình'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Xóa chuyến và sổ chi'),
              )
              .onPressed,
          isNull,
        );
        await tester.scrollUntilVisible(
          find.text(documentWithLinkedActivity().items.first.title),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(
          find.textContaining(documentWithLinkedActivity().items.first.title),
          findsWidgets,
        );
        await tapText(tester, 'Chi thực tế');
        expect(
          find.textContaining(
            documentWithLinkedActivity().actualExpenses.first.description,
          ),
          findsWidgets,
        );
        expect(ctx.server.updates, 0);
        expect(ctx.server.deletes, 0);
      });
    },
  );
  testWidgets('uncached offline V2 is unavailable without invented itinerary', (
    tester,
  ) async {
    await withUi(tester, (ctx, auth, trips, runtime, repo) async {
      ctx.server.offline = true;
      await pumpUi(tester, detail, auth, trips, runtime);
      expect(
        find.text('Không có bản lưu khả dụng cho chuyến đi này.'),
        findsOneWidget,
      );
      expect(find.text(records.doc().input.title), findsNothing);
    });
  });
  testWidgets(
    'delete cancel sends nothing; version conflict keeps detail and list',
    (tester) async {
      await withUi(tester, (ctx, auth, trips, runtime, repo) async {
        trips.rows = [summary(records.tripId, OwnedTripKind.editableV2)];
        repo.conflict = true;
        await pumpUi(tester, detail, auth, trips, runtime);
        await tapText(tester, 'Xóa chuyến và sổ chi');
        expect(find.textContaining('chi thực tế'), findsWidgets);
        await tapText(tester, 'Giữ chuyến đi');
        expect(repo.deletedBase, isNull);
        await tapText(tester, 'Xóa chuyến và sổ chi');
        await tapText(tester, 'Xóa toàn bộ chuyến');
        expect(repo.deletedBase!.version, 1);
        expect(trips.rows.length, 1);
        expect(find.textContaining('đã thay đổi'), findsWidgets);
        expect(find.text(records.doc().input.title), findsOneWidget);
      });
    },
  );
  testWidgets('confirmed V2 delete removes cached head and refreshes list', (
    tester,
  ) async {
    await withUi(tester, (ctx, auth, trips, runtime, repo) async {
      await pumpUi(tester, detail, auth, trips, runtime);
      await tapText(tester, 'Xóa chuyến và sổ chi');
      await tapText(tester, 'Xóa toàn bộ chuyến');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(ctx.server.deletes, 1);
      expect(trips.loads, 1);
      expect(
        await ctx.disk.store.readEditableSnapshot(
          handle: ctx.lifecycle.handle!,
          tripId: records.tripId,
        ),
        isNull,
      );
      expect(find.text(records.doc().input.title), findsNothing);
    });
  });
  testWidgets('account switch hides V2 immediately and revokes delete dialog', (
    tester,
  ) async {
    await withUi(tester, (ctx, auth, trips, runtime, repo) async {
      await pumpUi(tester, detail, auth, trips, runtime);
      await tapText(tester, 'Xóa chuyến và sổ chi');
      auth.simulateSupabaseUser(user(records.ownerB));
      ctx.lifecycle.invalidateAccountContext();
      await tester.pump();
      expect(find.text(records.doc().input.title), findsNothing);
      await tapText(tester, 'Xóa toàn bộ chuyến');
      expect(repo.deletedBase, isNull);
      expect(ctx.server.deletes, 0);
    });
  });
  testWidgets(
    'V1 copy preview cancel leaves original; confirm opens new V2 without actuals',
    (tester) async {
      await withUi(tester, (ctx, auth, trips, runtime, repo) async {
        final old = legacy.createValidPayload();
        final payload = CanonicalTripPayloadV1(
          metadata: TripMetadataV1(
            title: 'Bản gốc',
            destinationId: 'hue',
            destinationName: 'Huế',
            startDate: '2026-11-01',
            endDate: '2026-11-03',
          ),
          request: old.request,
          plan: PlanTripResponse.fromJson({
            ...old.plan!.toJson(),
            'winnerId': 'hue',
          }),
        );
        final snapshot = await ctx.disk.store.replaceSnapshot(
          handle: ctx.lifecycle.handle!,
          tripId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          payload: payload,
          remoteVersion: 1,
          fetchedAt: DateTime.utc(2026, 10, 15),
        );
        trips.snapshots = await ctx.disk.store.listSnapshots(
          handle: ctx.lifecycle.handle!,
        );
        final digest = trips.snapshots.single.digest;
        await pumpUi(
          tester,
          const SavedTripSnapshotScreen(
            tripId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            expectedOwnerId: records.ownerA,
          ),
          auth,
          trips,
          runtime,
        );
        await tapText(tester, 'Tạo bản sao để chỉnh sửa', scroll: 'saved.v1');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('Xem lại bản sao'), findsOneWidget);
        await tapText(tester, 'Hủy bản sao', scroll: 'copy.preview');
        expect((await runtime.getResources()).planner.document, isNull);
        expect(ctx.server.creates, 0);
        await tapText(tester, 'Tạo bản sao để chỉnh sửa', scroll: 'saved.v1');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        await tapText(
          tester,
          'Mở bản sao để chỉnh sửa',
          scroll: 'copy.preview',
        );
        final planner = (await runtime.getResources()).planner;
        expect(planner.document!.actualExpenses, isEmpty);
        expect(planner.baseHead, isNull);
        expect(planner.document!.source.kind, 'manual_v1_copy');
        expect(
          planner.document!.source.sourceId,
          'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        );
        expect(planner.document!.items.single.title, 'Tắm biển');
        expect(
          (await ctx.disk.store.listSnapshots(handle: ctx.lifecycle.handle!))
              .single
              .digest,
          digest,
        );
        expect(ctx.server.creates, 0);
        expect(snapshot, isNotNull);
      });
    },
  );
}

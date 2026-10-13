import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:travelgo_mobile/features/trips/presentation/widgets/guest_draft_import_sheet.dart';
import 'package:travelgo_mobile/features/trips/providers/guest_drafts_provider.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trips/services/guest_import_service.dart';

import 'guest_import_service_test.dart' as support;
import 'local_trip_store_test.dart' as fixtures;

User _user(String owner) => User(
  id: owner,
  email: 'owner@example.test',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-13T00:00:00Z',
);

Future<void> _waitForOutcome(
  GuestDraftsProvider drafts,
  GuestImportStatus status,
) async {
  if (drafts.outcomes.any((item) => item.status == status)) return;
  final ready = Completer<void>();
  void onChanged() {
    if (!ready.isCompleted &&
        drafts.outcomes.any((item) => item.status == status)) {
      ready.complete();
    }
  }

  drafts.addListener(onChanged);
  try {
    await ready.future.timeout(const Duration(seconds: 5));
  } finally {
    drafts.removeListener(onChanged);
  }
}

Future<void> _withSheet(
  WidgetTester tester,
  Future<void> Function(
    support.ServiceHarness,
    GuestDraftsProvider,
    AuthProvider,
  )
  body,
) async {
  await tester.runAsync(() async {
    await fixtures.runWithStore((ctx) async {
      final harness = support.ServiceHarness(ctx);
      await harness.bind();
      await harness.save();
      final drafts = GuestDraftsProvider(
        store: ctx.store,
        service: harness.service,
        deviceScope: 'default',
      );
      drafts.bindSession(harness.handle);
      await drafts.reload();
      final auth = AuthProvider(trustedRoleFetcher: (_) async => 'customer');
      await auth.initialization;
      auth.simulateSupabaseUser(_user(support.ownerA));
      try {
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              home: Scaffold(
                body: GuestDraftImportSheet(
                  drafts: drafts,
                  expectedOwnerId: support.ownerA,
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await tester.pump();
        await body(harness, drafts, auth);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        drafts.dispose();
        auth.dispose();
        harness.service.dispose();
      }
    });
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets('opening and canceling consent never sends an import', (
    tester,
  ) async {
    await _withSheet(tester, (harness, drafts, auth) async {
      expect(drafts.selectedSources, isEmpty);
      expect(harness.transport.calls, isEmpty);
      final correct = drafts.sourceFor(drafts.drafts.single)!;
      expect(
        () => drafts.select(
          ImportSource(
            deviceScope: correct.deviceScope,
            draftId: correct.draftId,
            revision: correct.revision,
            digest: '0' * 64,
          ),
          true,
        ),
        throwsArgumentError,
      );
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      expect(drafts.selectedSources, hasLength(1));
      await tester.tap(find.text('Chuyển 1 bản nháp đã chọn'));
      await tester.pump();
      expect(find.text('Chuyển 1 bản nháp?'), findsOneWidget);
      expect(find.textContaining('owner@example.test'), findsWidgets);
      await tester.tap(find.text('Hủy'));
      await tester.pump();
      expect(harness.transport.calls, isEmpty);
    });
  });

  testWidgets('demo account has no Guest import action', (tester) async {
    final auth = AuthProvider();
    final saved = SavedTripsProvider();
    try {
      await auth.initialization;
      await tester.runAsync(() => auth.quickDemoLogin(UserRole.customer));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<SavedTripsProvider>.value(value: saved),
          ],
          child: const MaterialApp(home: MyTripsScreen()),
        ),
      );
      expect(find.byTooltip('Chuyển bản nháp Guest'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
      saved.dispose();
    }
  });

  testWidgets('explicit confirmation sends once and requires server receipt', (
    tester,
  ) async {
    await _withSheet(tester, (harness, drafts, auth) async {
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      await tester.tap(find.text('Chuyển 1 bản nháp đã chọn'));
      await tester.pump();
      await tester.tap(find.text('Xác nhận'));
      await _waitForOutcome(drafts, GuestImportStatus.committed);
      await tester.pump();
      expect(harness.transport.calls, hasLength(1));
      expect(find.text('Đã chuyển sau xác nhận của server.'), findsOneWidget);
      expect(drafts.selectedSources, isEmpty);
    });
  });

  testWidgets('account change disables transfer and retains Guest draft', (
    tester,
  ) async {
    await _withSheet(tester, (harness, drafts, auth) async {
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      auth.simulateSupabaseUser(_user(support.ownerB));
      drafts.unbindSession();
      await tester.pump();
      expect(find.textContaining('Tài khoản đã thay đổi'), findsOneWidget);
      expect(harness.transport.calls, isEmpty);
      expect(
        await harness.ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
        isNotNull,
      );
    });
  });

  testWidgets('pending lost response is shown; retry needs new confirmation', (
    tester,
  ) async {
    await _withSheet(tester, (harness, drafts, auth) async {
      harness.transport.loseReply = true;
      final source = drafts.sourceFor(drafts.drafts.single)!;
      drafts.select(source, true);
      final first = await drafts.confirmAndImport();
      expect(first.single.status.name, 'pendingRetry');
      harness.transport.loseReply = false;
      await tester.pump();
      await tester.ensureVisible(find.text('Thử lại'));
      await tester.tap(find.text('Thử lại'));
      await tester.pump();
      expect(find.textContaining('Thử lại bản nháp'), findsOneWidget);
      expect(harness.transport.calls, hasLength(1));
      await tester.tap(find.text('Xác nhận'));
      await _waitForOutcome(drafts, GuestImportStatus.committed);
      await tester.pump();
      expect(harness.transport.calls, hasLength(2));
      expect(find.text('Đã chuyển sau xác nhận của server.'), findsOneWidget);
    });
  });
}

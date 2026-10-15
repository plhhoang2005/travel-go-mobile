import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trips/providers/editable_drafts_provider.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

import 'editable_local_store_test.dart' as records;
import 'editable_trip_repository_test.dart' as repository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('incomplete Guest cannot import and uncertain imports keep the frozen selection', () async {
    await repository.run((ctx) async {
      final base = records.doc();
      final incomplete = base.copyWith(
        input: TripInput.fromJson({
          ...base.input.toJson(),
          'startDate': null,
          'endDate': null,
        }),
        days: [
          TripDay.fromJson({...base.days.single.toJson(), 'date': null}),
        ],
      );
      await ctx.repository.saveGuest(
        scope: 'default',
        draftId: records.draftId,
        expectedRevision: null,
        document: incomplete,
      );
      await ctx.repository.saveGuest(
        scope: 'default',
        draftId: records.requestId,
        expectedRevision: null,
        document: base,
      );
      await ctx.login();
      final provider = EditableDraftsProvider(
        storeLoader: () async => ctx.disk.store,
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
        deviceScope: 'default',
      );
      try {
        await provider.load();
        provider.select(records.draftId, true);
        expect(await provider.importSelected(), isEmpty);
        expect(provider.errorMessage, contains('chưa đủ thông tin'));
        expect(ctx.server.creates, 0);
        provider.select(records.draftId, false);
        provider.select(records.requestId, true);
        ctx.server.offline = true;
        expect(await provider.importSelected(), isEmpty);
        expect(provider.uncertain, isTrue);
        await provider.load();
        expect(provider.selected.single.draftId, records.requestId);
        ctx.server.offline = false;
        expect(await provider.importSelected(), hasLength(1));
        expect(ctx.server.creates, 1);
        expect(provider.uncertain, isFalse);
      } finally {
        provider.dispose();
      }
    });
  });
  test('account sees Guest choices but imports only the explicitly selected revision', () async {
    await repository.run((ctx) async {
      for (final id in [records.draftId, records.requestId]) {
        await ctx.repository.saveGuest(
          scope: 'default',
          draftId: id,
          expectedRevision: null,
          document: records.doc(),
        );
      }
      await ctx.login();
      final provider = EditableDraftsProvider(
        storeLoader: () async => ctx.disk.store,
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
        deviceScope: 'default',
      );
      try {
        await provider.load();
        expect(provider.drafts, hasLength(2));
        expect(ctx.server.creates, 0);
        expect(await provider.importSelected(), isEmpty);
        provider.select(records.draftId, true);
        final replies = await provider.importSelected();
        expect(replies, hasLength(1));
        expect(ctx.server.creates, 1);
        expect(provider.drafts.single.draftId, records.requestId);
        expect(provider.outcomes, hasLength(1));
        ctx.session.expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        expect(provider.outcomes, isEmpty);
      } finally {
        provider.dispose();
      }
    });
  });

  test('selection is invalidated by a newer disk revision before account import', () async {
    await repository.run((ctx) async {
      await ctx.repository.saveGuest(
        scope: 'default',
        draftId: records.draftId,
        expectedRevision: null,
        document: records.doc(),
      );
      final provider = EditableDraftsProvider(
        storeLoader: () async => ctx.disk.store,
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
        deviceScope: 'default',
      );
      try {
        await provider.load();
        provider.select(records.draftId, true);
        await ctx.repository.saveGuest(
          scope: 'default',
          draftId: records.draftId,
          expectedRevision: 1,
          document: records.doc(),
        );
        await ctx.login();
        // Login clears Guest selections; the account selector must be explicit.
        expect(provider.selected, isEmpty);
        await provider.load();
        provider.select(records.draftId, true);
        expect(provider.selected.single.revision, 2);
        await provider.importSelected();
        expect(ctx.server.creates, 1);
      } finally {
        provider.dispose();
      }
    });
  });

  test(
    'late load completion cannot publish after context change or disposal',
    () async {
      await repository.run((ctx) async {
        final entered = Completer<void>();
        final release = Completer<LocalTripStore>();
        final provider = EditableDraftsProvider(
          storeLoader: () {
            entered.complete();
            return release.future;
          },
          repositoryLoader: () async => ctx.repository,
          lifecycle: ctx.lifecycle,
          deviceScope: 'default',
        );
        final loading = provider.load();
        await entered.future;
        ctx.lifecycle.invalidateAccountContext();
        provider.dispose();
        release.complete(ctx.disk.store);
        await loading;
        expect(provider.drafts, isEmpty);
        expect(ctx.server.creates, 0);
      });
    },
  );
}

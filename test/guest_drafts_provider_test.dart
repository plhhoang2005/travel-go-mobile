import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/trips/providers/guest_drafts_provider.dart';
import 'package:travelgo_mobile/features/trips/services/guest_import_service.dart';

import 'guest_import_service_test.dart' as support;
import 'local_trip_store_test.dart' as fixtures;

void main() {
  sqfliteFfiInit();
  test(
    'G13 reload/bind do not send or preselect; explicit confirm transfers',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = support.ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        final provider = GuestDraftsProvider(
          store: ctx.store,
          service: h.service,
          deviceScope: 'default',
        );
        addTearDown(provider.dispose);
        await provider.reload();
        provider.bindSession(h.handle);
        await provider.reload();
        expect(provider.selectedSources, isEmpty);
        expect(h.transport.calls, isEmpty);
        expect(await provider.confirmAndImport(), isEmpty);
        provider.select(source, true);
        expect(
          (await provider.confirmAndImport()).single.status,
          GuestImportStatus.committed,
        );
        expect(provider.isImporting, false);
      });
    },
  );
  test(
    'G13 deselect cancels; editing does not auto-select new revision',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = support.ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        final provider = GuestDraftsProvider(
          store: ctx.store,
          service: h.service,
          deviceScope: 'default',
        );
        addTearDown(provider.dispose);
        provider.bindSession(h.handle);
        await provider.reload();
        provider.select(source, true);
        provider.select(source, false);
        expect(await provider.confirmAndImport(), isEmpty);
        await h.save();
        await provider.reload();
        expect(provider.selectedSources, isEmpty);
        expect(h.transport.calls, isEmpty);
      });
    },
  );
  test(
    'G14 inventory shows pending older revision after editing and reopen',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = support.ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        h.transport.loseReply = true;
        await h.import(source);
        await h.save();
        await ctx.store.close();
        await ctx.store.open();
        await h.bind();
        final provider = GuestDraftsProvider(
          store: ctx.store,
          service: h.service,
          deviceScope: 'default',
        );
        addTearDown(provider.dispose);
        provider.bindSession(h.handle);
        await provider.reload();
        expect(provider.drafts.single.currentRevision, 2);
        expect(provider.attempts.single.sourceRevision, 1);
        expect(provider.selectedSources, isEmpty);
        expect(h.transport.calls.length, 1);
      });
    },
  );
  for (final dispose in [false, true]) {
    test(
      'G15 ${dispose ? 'dispose' : 'unbind'} drops late result and notifications',
      () async {
        await fixtures.runWithStore((ctx) async {
          final h = support.ServiceHarness(ctx);
          await h.bind();
          final source = await h.save();
          final provider = GuestDraftsProvider(
            store: ctx.store,
            service: h.service,
            deviceScope: 'default',
          );
          if (!dispose) addTearDown(provider.dispose);
          provider.bindSession(h.handle);
          await provider.reload();
          provider.select(source, true);
          h.transport.entered = Completer();
          h.transport.release = Completer();
          var notifications = 0;
          provider.addListener(() => notifications++);
          final action = provider.confirmAndImport();
          await h.transport.entered!.future;
          if (dispose) {
            provider.dispose();
          } else {
            provider.unbindSession();
          }
          final previous = notifications;
          h.transport.release!.complete();
          expect(await action, isEmpty);
          expect(notifications, previous);
          expect(provider.outcomes, isEmpty);
          expect(
            await ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
            isNotNull,
          );
        });
      },
    );
  }
}

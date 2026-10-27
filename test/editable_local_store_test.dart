import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/editable_local_records.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

import 'local_trip_store_test.dart' as legacy;

const ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const tripId = '00000000-0000-4000-8000-000000000050';
const requestId = '00000000-0000-4000-8000-000000000051';
const draftId = '00000000-0000-4000-8000-000000000052';
EditableTripDocumentV2 doc() {
  final rows = jsonDecode(
    File('test/fixtures/editable_trip_v2_vectors.json').readAsStringSync(),
  ) as List;
  final base = EditableTripCodec.decode(rows.first['rawText'] as String);
  return base.copyWith(
    input: TripInput.fromJson({
      ...base.input.toJson(),
      'startDate': '2026-10-15',
      'endDate': '2026-10-15',
    }),
    days: [
      TripDay.fromJson({...base.days.single.toJson(), 'date': '2026-10-15'}),
    ],
  );
}

EditableHead head({int version = 1, EditableTripDocumentV2? document}) {
  final d = document ?? doc();
  final text = EditableTripCodec.encode(d);
  return EditableHead(
    tripId: tripId,
    ownerId: ownerA,
    version: version,
    payloadText: text,
    contentDigest: EditableTripCodec.digestText(text),
    fetchedAt: DateTime.utc(2026, 10, 15),
    document: d,
  );
}

EditablePendingAttempt attempt({SourceBinding? binding}) {
  final text = EditableTripCodec.encode(doc());
  final request = EditableTripCodec.canonicalJson({
    'payloadText': text,
    'contentDigest': EditableTripCodec.digestText(text),
    'sourceBinding': binding?.toJson(),
  });
  return EditablePendingAttempt(
    requestId: requestId,
    ownerId: ownerA,
    operation: 'create',
    requestText: request,
    requestDigest: EditableTripCodec.digestText(request),
    contentDigest: EditableTripCodec.digestText(text),
    sourceBinding: binding,
  );
}

EditableMutationReply ack(EditablePendingAttempt a, {EditableHead? latest}) =>
    EditableMutationReply(
      status: EditableMutationStatus.committed,
      receipt: EditableReceipt(
        requestId: a.requestId,
        ownerId: ownerA,
        tripId: tripId,
        operation: 'create',
        requestDigest: a.requestDigest,
        contentDigest: a.contentDigest,
        resultVersion: 1,
        committedAt: DateTime.utc(2026, 10, 15),
        sourceBinding: a.sourceBinding,
      ),
      head: latest ?? head(),
    );
Future<void> reopen(legacy.TestStoreContext ctx) async {
  await ctx.store.close();
  ctx.store = LocalTripStore(
    databaseFactory: databaseFactoryFfi,
    databasePath: ctx.dbPath,
  );
  await ctx.store.open();
}

void main() {
  test('Guest write fault rolls back and an older ack cannot downgrade newer cache', () async {
    await legacy.runWithStore((ctx) async {
      await ctx.store.saveEditableDraft(
        deviceScope: 'default',
        draftId: draftId,
        expectedRevision: null,
        document: doc(),
      );
      ctx.store.onEditableStepForTesting = (step) async {
        if (step == 'draft_written') {
          throw StateError('owned Guest write fault');
        }
      };
      await expectLater(
        ctx.store.saveEditableDraft(
          deviceScope: 'default',
          draftId: draftId,
          expectedRevision: 1,
          document: doc(),
        ),
        throwsA(isA<StateError>()),
      );
      ctx.store.onEditableStepForTesting = null;
      expect(
        (await ctx.store.readEditableDraft(
          deviceScope: 'default',
          draftId: draftId,
        ))!.revision,
        1,
      );
      final handle = await ctx.store.activateSession(
        ownerId: ownerA,
        coordinatorEpoch: 1,
      );
      final a = attempt();
      await ctx.store.stageEditableAttempt(handle: handle, attempt: a);
      final newer = doc().copyWith(
        input: TripInput.fromJson({
          ...doc().input.toJson(),
          'title': 'Version 3',
        }),
      );
      await ctx.store.putEditableSnapshot(
        handle: handle,
        head: head(version: 3, document: newer),
      );
      await ctx.store.commitEditableAck(handle: handle, reply: ack(a));
      expect(
        (await ctx.store.readEditableSnapshot(
          handle: handle,
          tripId: tripId,
        ))!.head.version,
        3,
      );
    });
  });
  test(
    'deleted import receipt is terminal without recreating a snapshot',
    () async {
      await legacy.runWithStore((ctx) async {
        await ctx.store.saveEditableDraft(
          deviceScope: 'default',
          draftId: draftId,
          expectedRevision: null,
          document: doc(),
        );
        final handle = await ctx.store.activateSession(
          ownerId: ownerA,
          coordinatorEpoch: 1,
        );
        final a = attempt(
          binding: const SourceBinding.guest(
            deviceScope: 'default',
            draftId: draftId,
            sourceRevision: 1,
          ),
        );
        await ctx.store.stageEditableAttempt(handle: handle, attempt: a);
        await ctx.store.commitEditableAck(
          handle: handle,
          reply: EditableMutationReply(
            status: EditableMutationStatus.deleted,
            receipt: ack(a).receipt,
          ),
        );
        expect(
          await ctx.store.readEditableSnapshot(handle: handle, tripId: tripId),
          isNull,
        );
        expect(
          await ctx.store.readEditableDraft(
            deviceScope: 'default',
            draftId: draftId,
          ),
          isNull,
        );
        expect(await ctx.store.listEditableAttempts(handle: handle), isEmpty);
      });
    },
  );
  test('tampered snapshot digest is rejected before publication', () async {
    await legacy.runWithStore((ctx) async {
      final handle = await ctx.store.activateSession(
        ownerId: ownerA,
        coordinatorEpoch: 1,
      );
      await ctx.store.putEditableSnapshot(handle: handle, head: head());
      await ctx.store.rawDb.update('editable_trip_snapshots', {
        'content_digest': '0' * 64,
      });
      await expectLater(
        ctx.store.readEditableSnapshot(handle: handle, tripId: tripId),
        throwsA(isA<CorruptDatabaseException>()),
      );
    });
  });
  test('Guest revision CAS survives disk reopen and account writes cannot use Guest path', () async {
    await legacy.runWithStore((ctx) async {
      final first = await ctx.store.saveEditableDraft(
        deviceScope: 'default',
        draftId: draftId,
        expectedRevision: null,
        document: doc(),
      );
      expect(first.revision, 1);
      await expectLater(
        ctx.store.saveEditableDraft(
          deviceScope: 'default',
          draftId: draftId,
          expectedRevision: null,
          document: doc(),
        ),
        throwsA(isA<EditableDraftConflictException>()),
      );
      final next = doc().copyWith(
        input: TripInput.fromJson({
          ...doc().input.toJson(),
          'title': 'Bản sửa',
        }),
      );
      await ctx.store.saveEditableDraft(
        deviceScope: 'default',
        draftId: draftId,
        expectedRevision: 1,
        document: next,
      );
      await reopen(ctx);
      expect(
        (await ctx.store.readEditableDraft(
          deviceScope: 'default',
          draftId: draftId,
        ))!.document.input.title,
        'Bản sửa',
      );
      await ctx.store.activateSession(ownerId: ownerA, coordinatorEpoch: 1);
      await expectLater(
        ctx.store.saveEditableDraft(
          deviceScope: 'default',
          draftId: draftId,
          expectedRevision: 2,
          document: next,
        ),
        throwsA(isA<UnauthorizedAccountAccessException>()),
      );
    });
  });
  test(
    'populated V1 upgrade is additive and upgrade fault rolls back',
    () async {
      await legacy.runWithStore((ctx) async {
        final v1 = await ctx.store.saveDraftRevision(
          draftId: 'v1-preserve',
          payload: legacy.createValidPayload(),
        );
        await ctx.store.close();
        final raw = await databaseFactoryFfi.openDatabase(ctx.dbPath);
        for (final table in [
          'editable_import_journal',
          'editable_mutation_outbox',
          'editable_trip_snapshots',
          'guest_editable_drafts',
        ]) {
          await raw.execute('DROP TABLE $table');
        }
        await raw.execute('PRAGMA user_version = 1');
        await raw.close();
        ctx.store = LocalTripStore(
          databaseFactory: databaseFactoryFfi,
          databasePath: ctx.dbPath,
        );
        ctx.store.onEditableStepForTesting = (step) async {
          if (step == 'schema_guest_created') {
            throw StateError('owned upgrade fault');
          }
        };
        await expectLater(ctx.store.open(), throwsA(isA<Object>()));
        await ctx.store.close();
        final check = await databaseFactoryFfi.openDatabase(ctx.dbPath);
        expect(
          (await check.rawQuery('PRAGMA user_version')).single.values.single,
          1,
        );
        expect(
          await check.rawQuery(
            "SELECT name FROM sqlite_master WHERE name='guest_editable_drafts'",
          ),
          isEmpty,
        );
        await check.close();
        await reopen(ctx);
        final old = await ctx.store.getLatestDraft(draftId: 'v1-preserve');
        expect(old!.digest, v1.digest);
        expect(old.payloadJson, v1.payloadJson);
      });
    },
  );
  test(
    'cache is monotonic and same-version different content is corrupt',
    () async {
      await legacy.runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: ownerA,
          coordinatorEpoch: 1,
        );
        await ctx.store.putEditableSnapshot(
          handle: handle,
          head: head(version: 2),
        );
        await expectLater(
          ctx.store.putEditableSnapshot(handle: handle, head: head(version: 1)),
          throwsA(isA<SnapshotStaleVersionException>()),
        );
        final changed = doc().copyWith(
          input: TripInput.fromJson({...doc().input.toJson(), 'title': 'Khác'}),
        );
        await expectLater(
          ctx.store.putEditableSnapshot(
            handle: handle,
            head: head(version: 2, document: changed),
          ),
          throwsA(isA<SnapshotConflictException>()),
        );
        expect(
          (await ctx.store.readEditableSnapshot(
            handle: handle,
            tripId: tripId,
          ))!.head.version,
          2,
        );
      });
    },
  );
  test(
    'import ack is atomic and never removes a newer Guest revision',
    () async {
      await legacy.runWithStore((ctx) async {
        await ctx.store.saveEditableDraft(
          deviceScope: 'default',
          draftId: draftId,
          expectedRevision: null,
          document: doc(),
        );
        var handle = await ctx.store.activateSession(
          ownerId: ownerA,
          coordinatorEpoch: 1,
        );
        final a = attempt(
          binding: const SourceBinding.guest(
            deviceScope: 'default',
            draftId: draftId,
            sourceRevision: 1,
          ),
        );
        await ctx.store.stageEditableAttempt(handle: handle, attempt: a);
        ctx.store.unbindSession();
        final newer = doc().copyWith(
          input: TripInput.fromJson({
            ...doc().input.toJson(),
            'title': 'Revision mới',
          }),
        );
        await ctx.store.saveEditableDraft(
          deviceScope: 'default',
          draftId: draftId,
          expectedRevision: 1,
          document: newer,
        );
        handle = await ctx.store.activateSession(
          ownerId: ownerA,
          coordinatorEpoch: 2,
        );
        ctx.store.onEditableStepForTesting = (step) async {
          if (step == 'ack_snapshot_written') {
            throw StateError('owned ack fault');
          }
        };
        await expectLater(
          ctx.store.commitEditableAck(handle: handle, reply: ack(a)),
          throwsA(isA<StateError>()),
        );
        expect(
          await ctx.store.readEditableSnapshot(handle: handle, tripId: tripId),
          isNull,
        );
        expect(
          (await ctx.store.listEditableAttempts(handle: handle)).length,
          1,
        );
        ctx.store.onEditableStepForTesting = null;
        await ctx.store.commitEditableAck(handle: handle, reply: ack(a));
        await ctx.store.commitEditableAck(handle: handle, reply: ack(a));
        expect(await ctx.store.listEditableAttempts(handle: handle), isEmpty);
        final guest = await ctx.store.readEditableDraft(
          deviceScope: 'default',
          draftId: draftId,
        );
        expect(guest!.revision, 2);
        expect(guest.document.input.title, 'Revision mới');
        expect(
          await ctx.store.rawDb.query(
            'guest_editable_drafts',
            where: 'revision = 1',
          ),
          isEmpty,
        );
      });
    },
  );
  test('stale session during write rolls back; pending cleanup purges all V2 tables on reopen', () async {
    await legacy.runWithStore((ctx) async {
      final handle = await ctx.store.activateSession(
        ownerId: ownerA,
        coordinatorEpoch: 1,
      );
      ctx.store.onEditableStepForTesting = (step) async {
        if (step == 'snapshot_written') {
          ctx.store.unbindSession();
        }
      };
      await expectLater(
        ctx.store.putEditableSnapshot(handle: handle, head: head()),
        throwsA(isA<StaleSessionEpochException>()),
      );
      ctx.store.onEditableStepForTesting = null;
      final next = await ctx.store.activateSession(
        ownerId: ownerA,
        coordinatorEpoch: 2,
      );
      expect(
        await ctx.store.readEditableSnapshot(handle: next, tripId: tripId),
        isNull,
      );
      await ctx.store.putEditableSnapshot(handle: next, head: head());
      await ctx.store.stageEditableAttempt(handle: next, attempt: attempt());
      ctx.store.onPurgeStepForTesting = (step) async {
        if (step == 'inside_purge_txn') {
          throw StateError('owned purge fault');
        }
      };
      await expectLater(
        ctx.store.purgeAccountData(targetOwnerId: ownerA, reason: 'test'),
        throwsA(isA<StateError>()),
      );
      await reopen(ctx);
      final b = await ctx.store.activateSession(
        ownerId: ownerB,
        coordinatorEpoch: 3,
      );
      expect(await ctx.store.listEditableSnapshots(handle: b), isEmpty);
      expect(await ctx.store.listEditableAttempts(handle: b), isEmpty);
      for (final table in [
        'editable_trip_snapshots',
        'editable_import_journal',
        'editable_mutation_outbox',
      ]) {
        expect(await ctx.store.rawDb.query(table), isEmpty);
      }
    });
  });
  test(
    'reply with newer head keeps distinct receipt and cache digests',
    () async {
      await legacy.runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: ownerA,
          coordinatorEpoch: 1,
        );
        final a = attempt();
        await ctx.store.stageEditableAttempt(handle: handle, attempt: a);
        final newer = doc().copyWith(
          input: TripInput.fromJson({
            ...doc().input.toJson(),
            'title': 'Server version 3',
          }),
        );
        await ctx.store.commitEditableAck(
          handle: handle,
          reply: ack(a, latest: head(version: 3, document: newer)),
        );
        final cached = (await ctx.store.readEditableSnapshot(
          handle: handle,
          tripId: tripId,
        ))!.head;
        expect(cached.version, 3);
        expect(cached.document.input.title, 'Server version 3');
        expect(cached.contentDigest, isNot(a.contentDigest));
        expect(
          (await ctx.store.rawDb.query('editable_mutation_outbox'))
              .single['receipt_json'],
          contains(a.contentDigest!),
        );
      });
    },
  );
}

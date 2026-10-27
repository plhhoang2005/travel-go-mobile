import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

CanonicalTripPayloadV1 createValidPayload({
  String? title,
  bool includePlan = true,
  String destination = 'Đà Nẵng',
}) {
  final req = PlanTripRequest(
    origin: 'TP. Hồ Chí Minh',
    numDays: 3,
    numPeople: 2,
    budgetVnd: 5000000,
    preferences: ['biển', 'ẩm thực'],
    priority: 'balanced',
  );

  final plan = includePlan
      ? PlanTripResponse(
          winnerId: 'winner-1',
          topDestinations: [
            DestinationCard(
              id: 'dest-1',
              name: destination,
              totalScore: 90.0,
              normalizedScores: {'weather': 0.9},
              scoreContributions: {'weather': 0.3},
              estimatedCostVnd: 4500000,
              weatherSource: 'OpenWeather',
              avgTempMax: 30.0,
              avgPrecipitation: 0.0,
              latitude: 16.0544,
              longitude: 108.2022,
              region: 'Miền Trung',
            ),
          ],
          transportOptions: [
            TransportOption(
              mode: 'flight',
              displayName: 'Máy bay',
              priceTotalVnd: 2000000,
              durationHours: 1.5,
              comfortScore: 9,
              isParetoOptimal: true,
              tradeoffType: 'fastest',
              recommendationReason: 'Chuyến bay thẳng',
            ),
          ],
          itineraryDays: [
            ItineraryDay(
              day: 1,
              title: 'Khám phá',
              activities: [
                Activity(
                  time: '08:00',
                  title: 'Tắm biển',
                  costVnd: 0,
                  durationHours: 2.0,
                ),
              ],
            ),
          ],
          budgetBreakdown: BudgetBreakdown(
            transport: 2000000,
            accommodation: 1500000,
            food: 1000000,
            attractions: 500000,
            remainingSafetyMargin: 500000,
          ),
          aiExplanation: 'Chuyến đi hợp lý nhất cho mùa hè.',
          dataSources: {'rule': 'v1'},
          assumptions: ['Thời tiết thuận lợi'],
        )
      : null;

  return CanonicalTripPayloadV1(
    metadata: TripMetadataV1(
      title: title ?? 'Chuyến đi $destination',
      destinationName: destination,
      startDate: '2026-11-01',
      endDate: '2026-11-03',
    ),
    request: req,
    plan: plan,
  );
}

LocalImportReceipt createValidReceipt({
  String deviceScope = 'default',
  String targetOwner = 'owner-1',
  String draftId = 'draft-1',
  int sourceRevision = 1,
  String requestKey = 'req-key-1',
  required String contentDigest,
  String receiptId = 'rcpt-1',
  String tripId = 'trip-1',
  int remoteVersion = 1,
  DateTime? committedAt,
}) {
  return LocalImportReceipt(
    deviceScope: deviceScope,
    targetOwner: targetOwner,
    draftId: draftId,
    sourceRevision: sourceRevision,
    requestKey: requestKey,
    contentDigest: contentDigest,
    receiptId: receiptId,
    tripId: tripId,
    remoteVersion: remoteVersion,
    committedAt: committedAt ?? DateTime.utc(2026, 10, 11, 10, 0, 0),
  );
}

class TestStoreContext {
  final Directory tempDir;
  final String dbPath;
  LocalTripStore store;
  final String canonicalOwnedPath;
  final String canonicalTempRoot;

  static void deleteOwnedDirectory(
    Directory target,
    String ownedPath,
    String tempRoot,
  ) {
    if (!target.existsSync()) return;
    final resolved = target.resolveSymbolicLinksSync();
    String normalized(String path) {
      final value = p.normalize(p.absolute(path));
      return Platform.isWindows ? value.toLowerCase() : value;
    }

    final current = normalized(resolved);
    final owned = normalized(ownedPath);
    final root = normalized(tempRoot);
    if (current != owned ||
        current == root ||
        !p.isWithin(root, current) ||
        !p.basename(current).startsWith('b2_test_')) {
      throw StateError(
        'Refusing to delete unowned or unsafe directory: $resolved',
      );
    }
    target.deleteSync(recursive: true);
  }

  TestStoreContext._({
    required this.tempDir,
    required this.dbPath,
    required this.store,
    required this.canonicalOwnedPath,
    required this.canonicalTempRoot,
  });

  TestStoreContext({
    required Directory tempDir,
    required String dbPath,
    required LocalTripStore store,
  }) : this._(
         tempDir: tempDir,
         dbPath: dbPath,
         store: store,
         canonicalOwnedPath: tempDir.resolveSymbolicLinksSync(),
         canonicalTempRoot: Directory.systemTemp.resolveSymbolicLinksSync(),
       );

  Future<void> dispose() async {
    Object? closeError;
    StackTrace? closeStack;
    try {
      await store.close();
    } catch (e, st) {
      closeError = e;
      closeStack = st;
    }

    Object? deleteError;
    StackTrace? deleteStack;
    try {
      deleteOwnedDirectory(tempDir, canonicalOwnedPath, canonicalTempRoot);
    } catch (e, st) {
      deleteError = e;
      deleteStack = st;
    }

    if (closeError != null && deleteError != null) {
      // ignore: avoid_print
      print('Secondary delete error: $deleteError\n$deleteStack');
      Error.throwWithStackTrace(closeError, closeStack!);
    } else if (closeError != null) {
      Error.throwWithStackTrace(closeError, closeStack!);
    } else if (deleteError != null) {
      Error.throwWithStackTrace(deleteError, deleteStack!);
    }
  }
}

Future<void> runWithStore(
  Future<void> Function(TestStoreContext ctx) testBody, {
  Future<void> Function(TestStoreContext ctx)? setup,
}) async {
  final tempDir = Directory.systemTemp.createTempSync('b2_test_');
  TestStoreContext? ctx;
  String? ownedPath;
  String? tempRoot;
  dynamic primaryError;
  StackTrace? primaryStackTrace;

  try {
    tempRoot = Directory.systemTemp.resolveSymbolicLinksSync();
    ownedPath = tempDir.resolveSymbolicLinksSync();
    final dbPath = p.join(tempDir.path, LocalTripStore.defaultDatabaseName);
    final store = LocalTripStore(
      databaseFactory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    ctx = TestStoreContext(tempDir: tempDir, dbPath: dbPath, store: store);
    await setup?.call(ctx);
    await ctx.store.open();
    await testBody(ctx);
  } catch (e, st) {
    primaryError = e;
    primaryStackTrace = st;
  } finally {
    if (ctx != null) {
      try {
        await ctx.dispose();
      } catch (cleanupError, cleanupStack) {
        if (primaryError != null) {
          // Log secondary cleanup failure and preserve primary error (C10)
          // ignore: avoid_print
          print(
            'Secondary cleanup error in test: $cleanupError\n$cleanupStack',
          );
          Error.throwWithStackTrace(primaryError, primaryStackTrace!);
        } else {
          rethrow;
        }
      }
    } else {
      try {
        if (ownedPath == null || tempRoot == null) {
          throw StateError(
            'Temp ownership could not be established; refusing recursive cleanup.',
          );
        }
        TestStoreContext.deleteOwnedDirectory(tempDir, ownedPath, tempRoot);
      } catch (cleanupError, cleanupStack) {
        if (primaryError == null) rethrow;
        // ignore: avoid_print
        print('Secondary setup cleanup error: $cleanupError\n$cleanupStack');
      }
    }

    if (primaryError != null) {
      Error.throwWithStackTrace(primaryError, primaryStackTrace!);
    }
  }
}

void main() {
  group('Codex completion: durable identity and cancellation', () {
    test(
      'strict receipt parser rejects missing extra and non-integer fields',
      () {
        final base = createValidReceipt(contentDigest: 'a' * 64)
            .toWhitelistedMap();
        final invalid = <Map<String, dynamic>>[
          {...base, 'extra': true},
          {...base}..remove('receiptId'),
          {...base, 'sourceRevision': 1.0},
          {...base, 'remoteVersion': 1.0},
          {...base, 'sourceRevision': '1'},
          {...base, 'remoteVersion': null},
          {...base, 'committedAt': 'invalidZ'},
          {...base, 'receiptId': 7},
        ];
        for (final map in invalid) {
          expect(
            () => LocalImportReceipt.fromMap(map),
            throwsA(isA<CorruptDatabaseException>()),
          );
        }
      },
    );

    test('close during activation query cancels pending generation', () async {
      await runWithStore((ctx) async {
        Future<void>? closing;
        ctx.store.onActivationStepForTesting = (at) async {
          if (at == 'after_marker_read') closing = ctx.store.close();
        };
        await expectLater(
          ctx.store.activateSession(ownerId: 'owner', coordinatorEpoch: 1),
          throwsA(isA<StaleSessionEpochException>()),
        );
        await closing;
        ctx.store.onActivationStepForTesting = null;
        await ctx.store.open();
        final fresh = await ctx.store.activateSession(
          ownerId: 'owner',
          coordinatorEpoch: 2,
        );
        expect(await ctx.store.listSnapshots(handle: fresh), isEmpty);
      });
    });

    test(
      'CAS no-op and repeated ack reject corrupt existing snapshot bytes',
      () async {
        await runWithStore((ctx) async {
          final payload = createValidPayload();
          final source = await ctx.store.saveDraftRevision(
            draftId: 'cas',
            payload: payload,
          );
          final handle = await ctx.store.activateSession(
            ownerId: 'owner',
            coordinatorEpoch: 1,
          );
          await ctx.store.prepareImportJournal(
            handle: handle,
            draftId: 'cas',
            sourceRevision: 1,
            requestKey: 'key',
          );
          final receipt = createValidReceipt(
            targetOwner: 'owner',
            draftId: 'cas',
            requestKey: 'key',
            contentDigest: source.digest,
          );
          await ctx.store.commitImportAck(
            handle: handle,
            receipt: receipt,
            payload: payload,
          );
          await ctx.store.rawDb.update('account_trip_snapshots', {
            'payload_json': '{}',
          });
          await expectLater(
            ctx.store.replaceSnapshot(
              handle: handle,
              tripId: receipt.tripId,
              payload: payload,
              remoteVersion: 1,
              fetchedAt: DateTime.utc(2027),
            ),
            throwsA(isA<CorruptDatabaseException>()),
          );
          await expectLater(
            ctx.store.commitImportAck(
              handle: handle,
              receipt: receipt,
              payload: payload,
            ),
            throwsA(isA<CorruptDatabaseException>()),
          );
          expect(
            (await ctx.store.rawDb.query('account_trip_snapshots'))
                .single['payload_json'],
            '{}',
          );
          expect(
            (await ctx.store.rawDb.query('local_import_journal'))
                .single['state'],
            'committed',
          );
        });
      },
    );

    test('startup honors blocked marker even without pending flag', () async {
      await runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: 'owner',
          coordinatorEpoch: 1,
        );
        await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'trip',
          payload: createValidPayload(),
          remoteVersion: 1,
          fetchedAt: DateTime.utc(2026),
        );
        final now = DateTime.utc(2026).toIso8601String();
        await ctx.store.rawDb.insert('local_cleanup_state', {
          'namespace': 'account:owner',
          'is_blocked': 1,
          'purge_pending': 0,
          'reason': 'blocked',
          'created_at': now,
          'updated_at': now,
        });
        await ctx.store.close();
        await ctx.store.open();
        final fresh = await ctx.store.activateSession(
          ownerId: 'owner',
          coordinatorEpoch: 2,
        );
        expect(await ctx.store.listSnapshots(handle: fresh), isEmpty);
        expect(await ctx.store.rawDb.query('local_cleanup_state'), isEmpty);
      });
    });

    test(
      'setup failure preserves primary stack and deletes its owned directory',
      () async {
        String? path;
        final primary = FormatException('setup primary');
        await expectLater(
          runWithStore(
            (_) async {
              fail('body must not execute');
            },
            setup: (ctx) async {
              path = ctx.tempDir.path;
              throw primary;
            },
          ),
          throwsA(same(primary)),
        );
        expect(Directory(path!).existsSync(), isFalse);
      },
    );

    test(
      'actual harness preserves body failure when close also fails',
      () async {
        String? path;
        final primary = FormatException('body primary');
        await expectLater(
          runWithStore(
            (ctx) async {
              path = ctx.tempDir.path;
              throw primary;
            },
            setup: (ctx) async {
              await ctx.store.close();
              ctx.store = _FailingCloseStore(
                databaseFactory: databaseFactoryFfi,
                databasePath: ctx.dbPath,
              );
            },
          ),
          throwsA(same(primary)),
        );
        expect(Directory(path!).existsSync(), isFalse);
      },
    );

    test('cleanup rejects root and escaped ownership before any deletion', () {
      final root = Directory.systemTemp.resolveSymbolicLinksSync();
      expect(
        () =>
            TestStoreContext.deleteOwnedDirectory(Directory(root), root, root),
        throwsStateError,
      );
      expect(
        () => TestStoreContext.deleteOwnedDirectory(
          Directory(root),
          p.join(root, 'b2_test_missing'),
          root,
        ),
        throwsStateError,
      );
      expect(Directory(root).existsSync(), isTrue);
    });

    test('all ten valid stored receipt mutations reject repeated ack without writes', () async {
      await runWithStore((ctx) async {
        final payload = createValidPayload();
        final source = await ctx.store.saveDraftRevision(
          draftId: 'mutations',
          payload: payload,
        );
        final handle = await ctx.store.activateSession(
          ownerId: 'owner',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'mutations',
          sourceRevision: 1,
          requestKey: 'key',
        );
        final receipt = createValidReceipt(
          targetOwner: 'owner',
          draftId: 'mutations',
          requestKey: 'key',
          contentDigest: source.digest,
        );
        await ctx.store.commitImportAck(
          handle: handle,
          receipt: receipt,
          payload: payload,
        );
        final mutations = <String, Object>{
          'deviceScope': 'other',
          'targetOwner': 'other',
          'draftId': 'other',
          'sourceRevision': 2,
          'requestKey': 'other',
          'contentDigest': 'b' * 64,
          'receiptId': 'other',
          'tripId': 'other',
          'remoteVersion': 2,
          'committedAt': DateTime.utc(2027).toIso8601String(),
        };
        for (final entry in mutations.entries) {
          final raw = jsonEncode({
            ...receipt.toWhitelistedMap(),
            entry.key: entry.value,
          });
          await ctx.store.rawDb.update('local_import_journal', {
            'receipt_payload': raw,
          });
          await expectLater(
            ctx.store.commitImportAck(
              handle: handle,
              receipt: receipt,
              payload: payload,
            ),
            throwsA(isA<LocalTripStoreException>()),
            reason: entry.key,
          );
          expect(
            (await ctx.store.rawDb.query('local_import_journal'))
                .single['receipt_payload'],
            raw,
          );
          expect(
            await ctx.store.rawDb.query('account_trip_snapshots'),
            hasLength(1),
          );
          expect(await ctx.store.rawDb.query('guest_draft_revisions'), isEmpty);
        }
      });
    });

    for (final boundary in [
      'queue_entry',
      'after_marker',
      'before_commit',
      'before_layer3',
    ]) {
      for (final operation in ['read', 'write', 'ack']) {
        test(
          '$operation canceled at $boundary never publishes and cleans committed work',
          () async {
            await runWithStore((ctx) async {
              final payload = createValidPayload();
              final source = await ctx.store.saveDraftRevision(
                draftId: 'race',
                payload: payload,
              );
              final handle = await ctx.store.activateSession(
                ownerId: 'owner',
                coordinatorEpoch: 1,
              );
              await ctx.store.prepareImportJournal(
                handle: handle,
                draftId: 'race',
                sourceRevision: 1,
                requestKey: 'key',
              );
              await ctx.store.replaceSnapshot(
                handle: handle,
                tripId: 'baseline',
                payload: payload,
                remoteVersion: 1,
                fetchedAt: DateTime.utc(2026),
              );
              ctx.store.onAccountOpStepForTesting = (step) async {
                if (step == boundary) ctx.store.unbindSession();
              };
              final Future<Object?> result;
              if (operation == 'read') {
                result = ctx.store.getSnapshot(
                  handle: handle,
                  tripId: 'baseline',
                );
              } else if (operation == 'write') {
                result = ctx.store.replaceSnapshot(
                  handle: handle,
                  tripId: 'new',
                  payload: payload,
                  remoteVersion: 1,
                  fetchedAt: DateTime.utc(2026),
                );
              } else {
                result = ctx.store.commitImportAck(
                  handle: handle,
                  receipt: createValidReceipt(
                    targetOwner: 'owner',
                    draftId: 'race',
                    requestKey: 'key',
                    contentDigest: source.digest,
                  ),
                  payload: payload,
                );
              }
              await expectLater(
                result,
                throwsA(isA<StaleSessionEpochException>()),
              );
              ctx.store.onAccountOpStepForTesting = null;
              final committed = boundary == 'before_layer3';
              expect(
                await ctx.store.rawDb.query('guest_draft_revisions'),
                hasLength(operation == 'ack' && committed ? 0 : 1),
              );
              if (committed) {
                await expectLater(
                  ctx.store.activateSession(
                    ownerId: 'owner',
                    coordinatorEpoch: 2,
                  ),
                  throwsA(isA<AccountNamespaceBlockedException>()),
                );
              }
              await ctx.store.purgeAccountData(
                targetOwnerId: 'owner',
                reason: 'race cleanup',
              );
              final fresh = await ctx.store.activateSession(
                ownerId: 'owner',
                coordinatorEpoch: 3,
              );
              expect(await ctx.store.listSnapshots(handle: fresh), isEmpty);
              await ctx.store.close();
              await ctx.store.open();
              expect(
                await ctx.store.rawDb.query('account_trip_snapshots'),
                isEmpty,
              );
            });
          },
        );
      }
    }

    for (final step in ['before_marker_read', 'after_marker_read']) {
      test('activation canceled at $step cannot restore account RAM', () async {
        await runWithStore((ctx) async {
          ctx.store.onActivationStepForTesting = (at) async {
            if (at == step) ctx.store.unbindSession();
          };
          await expectLater(
            ctx.store.activateSession(ownerId: 'owner', coordinatorEpoch: 1),
            throwsA(isA<StaleSessionEpochException>()),
          );
          ctx.store.onActivationStepForTesting = null;
          final fresh = await ctx.store.activateSession(
            ownerId: 'owner',
            coordinatorEpoch: 2,
          );
          expect(await ctx.store.listSnapshots(handle: fresh), isEmpty);
        });
      });
    }

    test('only latest queued activation binds and close cancels pending activation', () async {
      await runWithStore((ctx) async {
        final first = ctx.store.activateSession(
          ownerId: 'first',
          coordinatorEpoch: 1,
        );
        final rejected = expectLater(
          first,
          throwsA(isA<StaleSessionEpochException>()),
        );
        final latest = await ctx.store.activateSession(
          ownerId: 'latest',
          coordinatorEpoch: 2,
        );
        await rejected;
        expect(latest.ownerId, 'latest');
        final pending = ctx.store.activateSession(
          ownerId: 'pending',
          coordinatorEpoch: 3,
        );
        final canceled = expectLater(
          pending,
          throwsA(isA<StaleSessionEpochException>()),
        );
        final closed = ctx.store.close();
        await canceled;
        await closed;
        await ctx.store.open();
        final fresh = await ctx.store.activateSession(
          ownerId: 'fresh',
          coordinatorEpoch: 4,
        );
        expect(await ctx.store.listSnapshots(handle: fresh), isEmpty);
      });
    });

    test(
      'failed activation leaves queue usable and old handle invalid',
      () async {
        await runWithStore((ctx) async {
          final old = await ctx.store.activateSession(
            ownerId: 'old',
            coordinatorEpoch: 1,
          );
          ctx.store.onActivationStepForTesting = (_) async {
            throw StateError('marker read fault');
          };
          await expectLater(
            ctx.store.activateSession(ownerId: 'new', coordinatorEpoch: 2),
            throwsStateError,
          );
          ctx.store.onActivationStepForTesting = null;
          await expectLater(
            ctx.store.listSnapshots(handle: old),
            throwsA(isA<StaleSessionEpochException>()),
          );
          final fresh = await ctx.store.activateSession(
            ownerId: 'new',
            coordinatorEpoch: 3,
          );
          expect(await ctx.store.listSnapshots(handle: fresh), isEmpty);
        });
      },
    );

    for (final step in ['inside_purge_txn', 'inside_completion_txn']) {
      test(
        '$step rollback preserves marker and file reopen finishes cleanup',
        () async {
          await runWithStore((ctx) async {
            final payload = createValidPayload();
            await ctx.store.saveDraftRevision(
              draftId: 'guest',
              payload: payload,
            );
            final handle = await ctx.store.activateSession(
              ownerId: 'owner',
              coordinatorEpoch: 1,
            );
            await ctx.store.prepareImportJournal(
              handle: handle,
              draftId: 'guest',
              sourceRevision: 1,
              requestKey: 'key',
            );
            await ctx.store.replaceSnapshot(
              handle: handle,
              tripId: 'trip',
              payload: payload,
              remoteVersion: 1,
              fetchedAt: DateTime.utc(2026),
            );
            ctx.store.onPurgeStepForTesting = (at) async {
              if (at == step) throw StateError('transaction fault');
            };
            await expectLater(
              ctx.store.purgeAccountData(
                targetOwnerId: 'owner',
                reason: 'test',
              ),
              throwsStateError,
            );
            expect(
              await ctx.store.rawDb.query('local_cleanup_state'),
              hasLength(1),
            );
            expect(
              await ctx.store.rawDb.query('account_trip_snapshots'),
              hasLength(step == 'inside_purge_txn' ? 1 : 0),
            );
            await ctx.store.close();
            ctx.store = LocalTripStore(
              databaseFactory: databaseFactoryFfi,
              databasePath: ctx.dbPath,
            );
            await ctx.store.open();
            final fresh = await ctx.store.activateSession(
              ownerId: 'owner',
              coordinatorEpoch: 2,
            );
            expect(await ctx.store.listSnapshots(handle: fresh), isEmpty);
            expect(
              (await ctx.store.getJournalEntry(
                handle: fresh,
                draftId: 'guest',
                sourceRevision: 1,
              ))!.state,
              'quarantined',
            );
            expect(await ctx.store.getLatestDraft(draftId: 'guest'), isNotNull);
            expect(await ctx.store.rawDb.query('local_cleanup_state'), isEmpty);
          });
        },
      );
    }

    test('failed marker stays blocked through same-instance reopen until purge succeeds', () async {
      await runWithStore((ctx) async {
        ctx.store.onPurgeStepForTesting = (step) async {
          if (step == 'before_marker_txn') throw StateError('disk fault');
        };
        await expectLater(
          ctx.store.purgeAccountData(targetOwnerId: 'owner', reason: 'test'),
          throwsA(isA<CleanupMarkerPersistenceException>()),
        );
        await ctx.store.close();
        await ctx.store.open();
        await expectLater(
          ctx.store.activateSession(ownerId: 'owner', coordinatorEpoch: 1),
          throwsA(isA<AccountNamespaceBlockedException>()),
        );
        ctx.store.onPurgeStepForTesting = null;
        await ctx.store.purgeAccountData(
          targetOwnerId: 'owner',
          reason: 'retry',
        );
        final fresh = await ctx.store.activateSession(
          ownerId: 'owner',
          coordinatorEpoch: 2,
        );
        expect(await ctx.store.listSnapshots(handle: fresh), isEmpty);
      });
    });

    test(
      'checked journal read rejects a valid receipt bound to another owner',
      () async {
        await runWithStore((ctx) async {
          final payload = createValidPayload();
          final source = await ctx.store.saveDraftRevision(
            draftId: 'binding',
            payload: payload,
          );
          final handle = await ctx.store.activateSession(
            ownerId: 'owner',
            coordinatorEpoch: 1,
          );
          await ctx.store.prepareImportJournal(
            handle: handle,
            draftId: 'binding',
            sourceRevision: 1,
            requestKey: 'binding-key',
          );
          final receipt = createValidReceipt(
            targetOwner: 'owner',
            draftId: 'binding',
            requestKey: 'binding-key',
            contentDigest: source.digest,
          );
          await ctx.store.commitImportAck(
            handle: handle,
            receipt: receipt,
            payload: payload,
          );
          await ctx.store.rawDb.update('local_import_journal', {
            'receipt_payload': jsonEncode({
              ...receipt.toWhitelistedMap(),
              'targetOwner': 'other-owner',
            }),
          });
          await expectLater(
            ctx.store.getJournalEntry(
              handle: handle,
              draftId: 'binding',
              sourceRevision: 1,
            ),
            throwsA(isA<CorruptDatabaseException>()),
          );
          await expectLater(
            ctx.store.prepareImportJournal(
              handle: handle,
              draftId: 'binding',
              sourceRevision: 1,
              requestKey: 'binding-key',
            ),
            throwsA(isA<CorruptDatabaseException>()),
          );
        });
      },
    );

    test(
      'post-commit stale write blocks activation until purge completes',
      () async {
        await runWithStore((ctx) async {
          final handle = await ctx.store.activateSession(
            ownerId: 'owner',
            coordinatorEpoch: 1,
          );
          ctx.store.onAccountOpStepForTesting = (step) async {
            if (step == 'before_layer3') ctx.store.unbindSession();
          };
          await expectLater(
            ctx.store.replaceSnapshot(
              handle: handle,
              tripId: 'late',
              payload: createValidPayload(),
              remoteVersion: 1,
              fetchedAt: DateTime.utc(2026),
            ),
            throwsA(isA<StaleSessionEpochException>()),
          );
          ctx.store.onAccountOpStepForTesting = null;
          expect(
            await ctx.store.rawDb.query('account_trip_snapshots'),
            hasLength(1),
          );
          await expectLater(
            ctx.store.activateSession(ownerId: 'owner', coordinatorEpoch: 2),
            throwsA(isA<AccountNamespaceBlockedException>()),
          );
          await ctx.store.purgeAccountData(
            targetOwnerId: 'owner',
            reason: 'late commit',
          );
          final fresh = await ctx.store.activateSession(
            ownerId: 'owner',
            coordinatorEpoch: 3,
          );
          expect(
            await ctx.store.getSnapshot(handle: fresh, tripId: 'late'),
            isNull,
          );
        });
      },
    );
  });

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('G1: Schema DDL, Integrity & PRAGMA Constraints', () {
    test('open_reopen_preserves_five_tables_and_pragmas', () async {
      await runWithStore((ctx) async {
        final db = ctx.store.rawDb;
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        );
        final tableNames = tables.map((r) => r['name'] as String).toSet();
        expect(
          tableNames,
          containsAll([
            'guest_draft_revisions',
            'guest_drafts',
            'account_trip_snapshots',
            'local_import_journal',
            'local_cleanup_state',
          ]),
        );

        final fkResult = await db.rawQuery('PRAGMA foreign_keys;');
        expect(fkResult.first.values.first, equals(1));

        await ctx.store.close();
        ctx.store = LocalTripStore(
          databaseFactory: databaseFactoryFfi,
          databasePath: ctx.dbPath,
        );
        await ctx.store.open();

        final fkReopen = await ctx.store.rawDb.rawQuery('PRAGMA foreign_keys;');
        expect(fkReopen.first.values.first, equals(1));
      });
    });

    test('fk_constraint_enforced_on_invalid_pointer', () async {
      await runWithStore((ctx) async {
        final db = ctx.store.rawDb;
        await expectLater(
          db.insert('guest_drafts', {
            'device_scope': 'default',
            'draft_id': 'draft-bad',
            'current_revision': 999, // Does not exist in guest_draft_revisions
            'highest_allocated_revision': 999,
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );
      });
    });

    test('check_constraints_reject_blank_id_fractional_revision_bad_digest_and_all_five_tables', () async {
      await runWithStore((ctx) async {
        final db = ctx.store.rawDb;

        // 1. guest_draft_revisions: blank draft_id, fractional revision, bad digest, invalid state
        await expectLater(
          db.insert('guest_draft_revisions', {
            'device_scope': 'default',
            'draft_id': '   ',
            'revision': 1,
            'payload_json': '{}',
            'schema_version': 1,
            'digest': 'a' * 64,
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'state': 'draft',
          }),
          throwsA(isA<DatabaseException>()),
        );

        await expectLater(
          db.insert('guest_draft_revisions', {
            'device_scope': 'default',
            'draft_id': 'draft-1',
            'revision': 1.5,
            'payload_json': '{}',
            'schema_version': 1,
            'digest': 'a' * 64,
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'state': 'draft',
          }),
          throwsA(isA<DatabaseException>()),
        );

        final badDigest = 'aa${'z' * 62}';
        await expectLater(
          db.insert('guest_draft_revisions', {
            'device_scope': 'default',
            'draft_id': 'draft-1',
            'revision': 1,
            'payload_json': '{}',
            'schema_version': 1,
            'digest': badDigest,
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'state': 'draft',
          }),
          throwsA(isA<DatabaseException>()),
        );

        await expectLater(
          db.insert('guest_draft_revisions', {
            'device_scope': 'default',
            'draft_id': 'draft-1',
            'revision': 1,
            'payload_json': '{}',
            'schema_version': 1,
            'digest': 'a' * 64,
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'state': 'invalid_state',
          }),
          throwsA(isA<DatabaseException>()),
        );

        // 2. guest_drafts: highest_allocated_revision < 1, current_revision > highest_allocated_revision, blank draft_id
        await expectLater(
          db.insert('guest_drafts', {
            'device_scope': 'default',
            'draft_id': 'draft-gd',
            'current_revision': 1,
            'highest_allocated_revision': 0,
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );

        await expectLater(
          db.insert('guest_drafts', {
            'device_scope': 'default',
            'draft_id': '   ',
            'current_revision': 1,
            'highest_allocated_revision': 1,
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );

        // 3. account_trip_snapshots: schema_version != 1, blank owner_id, blank trip_id, remote_version < 1
        await expectLater(
          db.insert('account_trip_snapshots', {
            'owner_id': 'owner-1',
            'trip_id': 'trip-1',
            'remote_version': 1,
            'schema_version': 2,
            'fetched_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'payload_json': '{}',
            'digest': 'a' * 64,
            'title': 'Trip',
            'destination_name': 'Dest',
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );

        await expectLater(
          db.insert('account_trip_snapshots', {
            'owner_id': '   ',
            'trip_id': 'trip-1',
            'remote_version': 1,
            'schema_version': 1,
            'fetched_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'payload_json': '{}',
            'digest': 'a' * 64,
            'title': 'Trip',
            'destination_name': 'Dest',
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );

        await expectLater(
          db.insert('account_trip_snapshots', {
            'owner_id': 'owner-1',
            'trip_id': 'trip-1',
            'remote_version': 0,
            'schema_version': 1,
            'fetched_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'payload_json': '{}',
            'digest': 'a' * 64,
            'title': 'Trip',
            'destination_name': 'Dest',
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );

        // 4. local_import_journal: source_revision < 1, invalid state, committed without receipt_payload, staged with receipt_payload
        await expectLater(
          db.insert('local_import_journal', {
            'device_scope': 'default',
            'target_owner': 'owner-1',
            'draft_id': 'draft-1',
            'source_revision': 0,
            'request_key': 'key-1',
            'content_digest': 'a' * 64,
            'state': 'staged',
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );

        await expectLater(
          db.insert('local_import_journal', {
            'device_scope': 'default',
            'target_owner': 'owner-1',
            'draft_id': 'draft-1',
            'source_revision': 1,
            'request_key': 'key-1',
            'content_digest': 'a' * 64,
            'state': 'invalid_state',
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );

        await expectLater(
          db.insert('local_import_journal', {
            'device_scope': 'default',
            'target_owner': 'owner-1',
            'draft_id': 'draft-1',
            'source_revision': 1,
            'request_key': 'key-1',
            'content_digest': 'a' * 64,
            'state': 'committed',
            'receipt_payload': null,
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );

        await expectLater(
          db.insert('local_import_journal', {
            'device_scope': 'default',
            'target_owner': 'owner-1',
            'draft_id': 'draft-1',
            'source_revision': 1,
            'request_key': 'key-1',
            'content_digest': 'a' * 64,
            'state': 'staged',
            'receipt_payload': '{"receiptId": "r1"}',
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );

        // 5. local_cleanup_state: is_blocked not in (0,1), purge_pending = 1 and is_blocked = 0, blank namespace
        await expectLater(
          db.insert('local_cleanup_state', {
            'namespace': 'account:u1',
            'is_blocked': 2,
            'purge_pending': 1,
            'reason': 'test',
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );

        await expectLater(
          db.insert('local_cleanup_state', {
            'namespace': 'account:u1',
            'is_blocked': 0,
            'purge_pending': 1,
            'reason': 'test',
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );

        await expectLater(
          db.insert('local_cleanup_state', {
            'namespace': '   ',
            'is_blocked': 1,
            'purge_pending': 1,
            'reason': 'test',
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );
      });
    });
  });

  group('G2: Survives Reopen without Drift', () {
    test('draft_survives_reopen_without_drift', () async {
      await runWithStore((ctx) async {
        final payload = createValidPayload(title: 'Phú Quốc trọn vẹn');
        final saved = await ctx.store.saveDraftRevision(
          draftId: 'draft-drift',
          payload: payload,
        );

        await ctx.store.close();
        ctx.store = LocalTripStore(
          databaseFactory: databaseFactoryFfi,
          databasePath: ctx.dbPath,
        );
        await ctx.store.open();

        final retrieved = await ctx.store.getLatestDraft(
          draftId: 'draft-drift',
        );
        expect(retrieved, isNotNull);
        expect(retrieved!.payloadJson, equals(saved.payloadJson));
        expect(retrieved.digest, equals(saved.digest));
        expect(
          retrieved.cachedPayload.metadata.title,
          equals('Phú Quốc trọn vẹn'),
        );
        expect(
          retrieved.cachedPayload.plan!.transportOptions.first.isParetoOptimal,
          isTrue,
        );
      });
    });

    test('input_only_draft_supported', () async {
      await runWithStore((ctx) async {
        final inputOnlyPayload = createValidPayload(includePlan: false);
        final saved = await ctx.store.saveDraftRevision(
          draftId: 'draft-input-only',
          payload: inputOnlyPayload,
        );

        expect(saved.cachedPayload.plan, isNull);
        expect(saved.cachedPayload.request, isNotNull);

        final retrieved = await ctx.store.getLatestDraft(
          draftId: 'draft-input-only',
        );
        expect(retrieved, isNotNull);
        expect(retrieved!.cachedPayload.plan, isNull);
        expect(
          retrieved.cachedPayload.request!.origin,
          equals('TP. Hồ Chí Minh'),
        );
      });
    });
  });

  group('G3: Monotonic Revision Allocation & History Preservation', () {
    test('revisions_append_monotonically_and_preserve_history', () async {
      await runWithStore((ctx) async {
        final p1 = createValidPayload(
          title: 'Phiên bản 1',
          destination: 'Hà Nội',
        );
        final p2 = createValidPayload(
          title: 'Phiên bản 2',
          destination: 'Hạ Long',
        );

        final r1 = await ctx.store.saveDraftRevision(
          draftId: 'draft-mono',
          payload: p1,
        );
        final r2 = await ctx.store.saveDraftRevision(
          draftId: 'draft-mono',
          payload: p2,
        );

        expect(r1.revision, equals(1));
        expect(r2.revision, equals(2));

        final historical1 = await ctx.store.getDraftRevision(
          draftId: 'draft-mono',
          revision: 1,
        );
        final historical2 = await ctx.store.getDraftRevision(
          draftId: 'draft-mono',
          revision: 2,
        );
        expect(
          historical1!.cachedPayload.metadata.title,
          equals('Phiên bản 1'),
        );
        expect(
          historical2!.cachedPayload.metadata.title,
          equals('Phiên bản 2'),
        );

        final latest = await ctx.store.getLatestDraft(draftId: 'draft-mono');
        expect(latest!.revision, equals(2));
      });
    });

    test('consumed_revision_number_never_reused', () async {
      await runWithStore((ctx) async {
        final p1 = createValidPayload(destination: 'Huế');
        final r1 = await ctx.store.saveDraftRevision(
          draftId: 'draft-reuse',
          payload: p1,
        );
        expect(r1.revision, equals(1));

        final handle = await ctx.store.activateSession(
          ownerId: 'user-reuse',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'draft-reuse',
          sourceRevision: 1,
          requestKey: 'key-reuse-1',
        );

        final receipt = createValidReceipt(
          targetOwner: 'user-reuse',
          draftId: 'draft-reuse',
          sourceRevision: 1,
          requestKey: 'key-reuse-1',
          contentDigest: r1.digest,
        );
        await ctx.store.commitImportAck(
          handle: handle,
          receipt: receipt,
          payload: p1,
        );

        // Draft rev 1 is now consumed. Saving the same draftId MUST allocate revision 2!
        final p2 = createValidPayload(destination: 'Đà Lạt');
        final r2 = await ctx.store.saveDraftRevision(
          draftId: 'draft-reuse',
          payload: p2,
        );
        expect(r2.revision, equals(2));
      });
    });

    test(
      'delete_draft_preserves_tombstone_counter_and_pointer_order',
      () async {
        await runWithStore((ctx) async {
          final p1 = createValidPayload(title: 'Trước khi xóa');
          final r1 = await ctx.store.saveDraftRevision(
            draftId: 'draft-tombstone',
            payload: p1,
          );
          expect(r1.revision, equals(1));

          await ctx.store.deleteDraft(draftId: 'draft-tombstone');

          final afterDelete = await ctx.store.getLatestDraft(
            draftId: 'draft-tombstone',
          );
          expect(afterDelete, isNull);

          // Saving again MUST NOT reuse revision 1! Tombstone preserves highest_allocated_revision.
          final p2 = createValidPayload(title: 'Sau khi xóa');
          final r2 = await ctx.store.saveDraftRevision(
            draftId: 'draft-tombstone',
            payload: p2,
          );
          expect(r2.revision, equals(2));
        });
      },
    );

    test('concurrent_saves_serialize_monotonically', () async {
      await runWithStore((ctx) async {
        final futures = List.generate(
          5,
          (i) => ctx.store.saveDraftRevision(
            draftId: 'draft-concurrent',
            payload: createValidPayload(title: 'Draft $i'),
          ),
        );

        final results = await Future.wait(futures);
        final revisions = results.map((r) => r.revision).toList();
        expect(revisions, equals([1, 2, 3, 4, 5]));
      });
    });
  });

  group('G4: Atomic Rollback on Draft Save', () {
    test('draft_save_failure_rolls_back_both_revision_and_pointer', () async {
      await runWithStore((ctx) async {
        ctx.store.onSaveDraftStepForTesting = (step) async {
          if (step == 'after_revision_insert') {
            throw const FormatException('Injected fault before header update');
          }
        };

        await expectLater(
          ctx.store.saveDraftRevision(
            draftId: 'draft-fault',
            payload: createValidPayload(),
          ),
          throwsA(isA<FormatException>()),
        );

        ctx.store.onSaveDraftStepForTesting = null;

        final rows = await ctx.store.rawDb.query(
          'guest_draft_revisions',
          where: 'draft_id = ?',
          whereArgs: ['draft-fault'],
        );
        expect(rows, isEmpty);

        final headers = await ctx.store.rawDb.query(
          'guest_drafts',
          where: 'draft_id = ?',
          whereArgs: ['draft-fault'],
        );
        expect(headers, isEmpty);
      });
    });
  });

  group('G5: Import Journal Lifecycle & Cross-Owner Isolation', () {
    test('same_source_retry_keeps_key_digest_state', () async {
      await runWithStore((ctx) async {
        final p1 = createValidPayload();
        final rev = await ctx.store.saveDraftRevision(
          draftId: 'draft-j1',
          payload: p1,
        );

        final handle = await ctx.store.activateSession(
          ownerId: 'owner-j1',
          coordinatorEpoch: 1,
        );
        final j1 = await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'draft-j1',
          sourceRevision: rev.revision,
          requestKey: 'key-j1',
        );

        final jRetry = await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'draft-j1',
          sourceRevision: rev.revision,
          requestKey: 'key-j1',
        );

        expect(jRetry.requestKey, equals(j1.requestKey));
        expect(jRetry.contentDigest, equals(j1.contentDigest));
        expect(jRetry.state, equals('staged'));
      });
    });

    test('scope_mismatch_cannot_return_another_journal', () async {
      await runWithStore((ctx) async {
        final p1 = createValidPayload();
        final rev = await ctx.store.saveDraftRevision(
          draftId: 'draft-scope',
          payload: p1,
          deviceScope: 'scope-a',
        );

        final handle = await ctx.store.activateSession(
          ownerId: 'owner-scope',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'draft-scope',
          sourceRevision: rev.revision,
          requestKey: 'key-scope-a',
          deviceScope: 'scope-a',
        );

        final otherScope = await ctx.store.getJournalEntry(
          handle: handle,
          draftId: 'draft-scope',
          sourceRevision: rev.revision,
          deviceScope: 'scope-b',
        );
        expect(otherScope, isNull);
      });
    });

    test('conflicting_retry_or_reused_key_rejected', () async {
      await runWithStore((ctx) async {
        final p1 = createValidPayload();
        final rev1 = await ctx.store.saveDraftRevision(
          draftId: 'draft-conf-1',
          payload: p1,
        );
        final rev2 = await ctx.store.saveDraftRevision(
          draftId: 'draft-conf-2',
          payload: p1,
        );

        final handle = await ctx.store.activateSession(
          ownerId: 'owner-conf',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'draft-conf-1',
          sourceRevision: rev1.revision,
          requestKey: 'key-shared',
        );

        // 1. Same source with different requestKey -> ImportAttemptConflictException
        await expectLater(
          ctx.store.prepareImportJournal(
            handle: handle,
            draftId: 'draft-conf-1',
            sourceRevision: rev1.revision,
            requestKey: 'key-different',
          ),
          throwsA(isA<ImportAttemptConflictException>()),
        );

        // 2. Reused requestKey for different draft -> DuplicateRequestKeyException
        await expectLater(
          ctx.store.prepareImportJournal(
            handle: handle,
            draftId: 'draft-conf-2',
            sourceRevision: rev2.revision,
            requestKey: 'key-shared',
          ),
          throwsA(isA<DuplicateRequestKeyException>()),
        );
      });
    });

    test('cross_owner_reservation_blocks_all_active_states', () async {
      await runWithStore((ctx) async {
        final p1 = createValidPayload();
        final rev = await ctx.store.saveDraftRevision(
          draftId: 'draft-cross',
          payload: p1,
        );

        // State 1: staged
        final handleA = await ctx.store.activateSession(
          ownerId: 'owner-a',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handleA,
          draftId: 'draft-cross',
          sourceRevision: rev.revision,
          requestKey: 'key-owner-a',
        );

        final handleB = await ctx.store.activateSession(
          ownerId: 'owner-b',
          coordinatorEpoch: 1,
        );
        await expectLater(
          ctx.store.prepareImportJournal(
            handle: handleB,
            draftId: 'draft-cross',
            sourceRevision: rev.revision,
            requestKey: 'key-owner-b1',
          ),
          throwsA(isA<DraftImportPendingException>()),
        );

        // State 2: pending_ack
        final handleA2 = await ctx.store.activateSession(
          ownerId: 'owner-a',
          coordinatorEpoch: 2,
        );
        await ctx.store.markJournalPendingAck(
          handle: handleA2,
          draftId: 'draft-cross',
          sourceRevision: rev.revision,
        );

        final handleB2 = await ctx.store.activateSession(
          ownerId: 'owner-b',
          coordinatorEpoch: 2,
        );
        await expectLater(
          ctx.store.prepareImportJournal(
            handle: handleB2,
            draftId: 'draft-cross',
            sourceRevision: rev.revision,
            requestKey: 'key-owner-b2',
          ),
          throwsA(isA<DraftImportPendingException>()),
        );

        // State 3: quarantined
        final now = DateTime.utc(2026, 10, 11, 10, 0, 0).toIso8601String();
        await ctx.store.rawDb.update(
          'local_import_journal',
          {'state': 'quarantined', 'updated_at': now},
          where: 'target_owner = ? AND draft_id = ? AND source_revision = ?',
          whereArgs: ['owner-a', 'draft-cross', rev.revision],
        );

        final handleB3 = await ctx.store.activateSession(
          ownerId: 'owner-b',
          coordinatorEpoch: 3,
        );
        await expectLater(
          ctx.store.prepareImportJournal(
            handle: handleB3,
            draftId: 'draft-cross',
            sourceRevision: rev.revision,
            requestKey: 'key-owner-b3',
          ),
          throwsA(isA<DraftImportPendingException>()),
        );
      });
    });

    test('contract: committed prepare retry does not require consumed source (Probe 1 / F1)', () async {
      await runWithStore((ctx) async {
        final payload = createValidPayload();
        final source = await ctx.store.saveDraftRevision(
          draftId: 'probe-1',
          payload: payload,
        );
        final handle = await ctx.store.activateSession(
          ownerId: 'owner-p1',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'probe-1',
          sourceRevision: 1,
          requestKey: 'key-p1',
        );
        final receipt = createValidReceipt(
          targetOwner: 'owner-p1',
          draftId: 'probe-1',
          sourceRevision: 1,
          requestKey: 'key-p1',
          contentDigest: source.digest,
        );
        await ctx.store.commitImportAck(
          handle: handle,
          receipt: receipt,
          payload: payload,
        );
        expect(
          await ctx.store.getDraftRevision(draftId: 'probe-1', revision: 1),
          isNull,
        );

        // Exact retry succeeds and returns existing committed identity and durable receipt
        final retry = await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'probe-1',
          sourceRevision: 1,
          requestKey: 'key-p1',
        );
        expect(retry.state, 'committed');
        expect(retry.cachedReceipt, receipt);

        // Conflicting retry with different requestKey is rejected
        await expectLater(
          ctx.store.prepareImportJournal(
            handle: handle,
            draftId: 'probe-1',
            sourceRevision: 1,
            requestKey: 'different-key',
          ),
          throwsA(isA<ImportAttemptConflictException>()),
        );

        // Retry survives file reopen
        await ctx.store.close();
        final reopenedStore = LocalTripStore(
          databaseFactory: databaseFactoryFfi,
          databasePath: ctx.dbPath,
        );
        await reopenedStore.open();
        final reopenedHandle = await reopenedStore.activateSession(
          ownerId: 'owner-p1',
          coordinatorEpoch: 2,
        );
        final reopenedRetry = await reopenedStore.prepareImportJournal(
          handle: reopenedHandle,
          draftId: 'probe-1',
          sourceRevision: 1,
          requestKey: 'key-p1',
        );
        expect(reopenedRetry.state, 'committed');
        expect(reopenedRetry.cachedReceipt, receipt);
        await reopenedStore.close();
      });
    });

    test('pinned_source_deletion_blocked', () async {
      await runWithStore((ctx) async {
        final p1 = createValidPayload();
        final rev = await ctx.store.saveDraftRevision(
          draftId: 'draft-pinned',
          payload: p1,
        );

        final handle = await ctx.store.activateSession(
          ownerId: 'owner-pinned',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'draft-pinned',
          sourceRevision: rev.revision,
          requestKey: 'key-pinned',
        );

        await expectLater(
          ctx.store.deleteDraft(draftId: 'draft-pinned'),
          throwsA(isA<DraftRevisionPinnedException>()),
        );
      });
    });
  });

  group('G6: Ack Commit Pointer-Safe & Consumption', () {
    test('strict_fractional_receipt_numbers_rejected', () {
      expect(
        () => LocalImportReceipt.fromMap({
          'deviceScope': 'default',
          'targetOwner': 'owner-1',
          'draftId': 'draft-1',
          'sourceRevision': 1.9, // Fractional double, not int
          'requestKey': 'k1',
          'contentDigest': 'a' * 64,
          'receiptId': 'r1',
          'tripId': 't1',
          'remoteVersion': 1,
          'committedAt': '2026-10-11T10:00:00Z',
        }),
        throwsA(isA<CorruptDatabaseException>()),
      );
    });

    test(
      'commit_ack_pointer_safe_order_consumes_source_and_nulls_pointer',
      () async {
        await runWithStore((ctx) async {
          final p1 = createValidPayload();
          final rev = await ctx.store.saveDraftRevision(
            draftId: 'draft-ack-1',
            payload: p1,
          );

          final handle = await ctx.store.activateSession(
            ownerId: 'owner-ack',
            coordinatorEpoch: 1,
          );
          await ctx.store.prepareImportJournal(
            handle: handle,
            draftId: 'draft-ack-1',
            sourceRevision: rev.revision,
            requestKey: 'key-ack-1',
          );

          final receipt = createValidReceipt(
            targetOwner: 'owner-ack',
            draftId: 'draft-ack-1',
            sourceRevision: rev.revision,
            requestKey: 'key-ack-1',
            contentDigest: rev.digest,
          );

          final result = await ctx.store.commitImportAck(
            handle: handle,
            receipt: receipt,
            payload: p1,
          );

          expect(result.snapshot.tripId, equals(receipt.tripId));
          expect(result.snapshot.remoteVersion, equals(1));

          // Guest source consumed and pointer unlinked
          final guestDraft = await ctx.store.getLatestDraft(
            draftId: 'draft-ack-1',
          );
          expect(guestDraft, isNull);

          final guestRev = await ctx.store.getDraftRevision(
            draftId: 'draft-ack-1',
            revision: rev.revision,
          );
          expect(guestRev, isNull);
        });
      },
    );

    test(
      'commit_ack_with_newer_revision_leaves_newer_guest_revision',
      () async {
        await runWithStore((ctx) async {
          final p1 = createValidPayload(destination: 'Cần Thơ');
          final p2 = createValidPayload(destination: 'An Giang');

          final r1 = await ctx.store.saveDraftRevision(
            draftId: 'draft-newer',
            payload: p1,
          );
          final r2 = await ctx.store.saveDraftRevision(
            draftId: 'draft-newer',
            payload: p2,
          );
          expect(r2.revision, equals(2));

          final handle = await ctx.store.activateSession(
            ownerId: 'owner-newer',
            coordinatorEpoch: 1,
          );
          await ctx.store.prepareImportJournal(
            handle: handle,
            draftId: 'draft-newer',
            sourceRevision: r1.revision,
            requestKey: 'key-newer-1',
          );

          final receipt = createValidReceipt(
            targetOwner: 'owner-newer',
            draftId: 'draft-newer',
            sourceRevision: r1.revision,
            requestKey: 'key-newer-1',
            contentDigest: r1.digest,
          );

          await ctx.store.commitImportAck(
            handle: handle,
            receipt: receipt,
            payload: p1,
          );

          // r1 is consumed, but r2 remains active in Guest!
          final latest = await ctx.store.getLatestDraft(draftId: 'draft-newer');
          expect(latest, isNotNull);
          expect(latest!.revision, equals(2));
          expect(
            latest.cachedPayload.metadata.destinationName,
            equals('An Giang'),
          );
        });
      },
    );

    test('transferred_source_not_guest_readable_or_importable', () async {
      await runWithStore((ctx) async {
        final p1 = createValidPayload();
        final r1 = await ctx.store.saveDraftRevision(
          draftId: 'draft-transferred',
          payload: p1,
        );

        final handle = await ctx.store.activateSession(
          ownerId: 'owner-tr',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'draft-transferred',
          sourceRevision: r1.revision,
          requestKey: 'key-tr',
        );

        final receipt = createValidReceipt(
          targetOwner: 'owner-tr',
          draftId: 'draft-transferred',
          sourceRevision: r1.revision,
          requestKey: 'key-tr',
          contentDigest: r1.digest,
        );
        await ctx.store.commitImportAck(
          handle: handle,
          receipt: receipt,
          payload: p1,
        );

        // 1. Not guest readable
        expect(
          await ctx.store.getLatestDraft(draftId: 'draft-transferred'),
          isNull,
        );
        expect(
          await ctx.store.getDraftRevision(
            draftId: 'draft-transferred',
            revision: r1.revision,
          ),
          isNull,
        );

        // 2. Cannot be imported by another owner (source revision missing)
        final handleB = await ctx.store.activateSession(
          ownerId: 'owner-tr-b',
          coordinatorEpoch: 1,
        );
        await expectLater(
          ctx.store.prepareImportJournal(
            handle: handleB,
            draftId: 'draft-transferred',
            sourceRevision: r1.revision,
            requestKey: 'key-tr-b',
          ),
          throwsA(isA<ImportJournalNotFoundException>()),
        );

        // 3. Original owner cannot re-prepare with different key
        final handleA2 = await ctx.store.activateSession(
          ownerId: 'owner-tr',
          coordinatorEpoch: 1,
        );
        await expectLater(
          ctx.store.prepareImportJournal(
            handle: handleA2,
            draftId: 'draft-transferred',
            sourceRevision: r1.revision,
            requestKey: 'key-tr-again',
          ),
          throwsA(isA<ImportAttemptConflictException>()),
        );
      });
    });

    test(
      'rollback_after_each_step_restores_clean_state_with_file_reopen',
      () async {
        final stepsToTest = [
          'after_journal_update',
          'after_snapshot_upsert',
          'after_pointer_null',
          'after_source_delete',
        ];

        for (final targetStep in stepsToTest) {
          await runWithStore((ctx) async {
            final draftId = 'draft-fault-$targetStep';
            final p1 = createValidPayload(title: 'Pre-fault Title');
            final r1 = await ctx.store.saveDraftRevision(
              draftId: draftId,
              payload: p1,
            );

            final handle = await ctx.store.activateSession(
              ownerId: 'owner-fault',
              coordinatorEpoch: 1,
            );
            await ctx.store.prepareImportJournal(
              handle: handle,
              draftId: draftId,
              sourceRevision: r1.revision,
              requestKey: 'key-$draftId',
            );
            await ctx.store.markJournalPendingAck(
              handle: handle,
              draftId: draftId,
              sourceRevision: r1.revision,
            );

            final receipt = createValidReceipt(
              targetOwner: 'owner-fault',
              draftId: draftId,
              sourceRevision: r1.revision,
              requestKey: 'key-$draftId',
              contentDigest: r1.digest,
              tripId: 'trip-$draftId',
            );

            ctx.store.onAckStepForTesting = (step) async {
              if (step == targetStep) {
                throw StateError('Injected fault at step: $step');
              }
            };

            await expectLater(
              ctx.store.commitImportAck(
                handle: handle,
                receipt: receipt,
                payload: p1,
              ),
              throwsA(isA<StateError>()),
            );

            ctx.store.onAckStepForTesting = null;

            // File reopen to verify durable pre-state restoration (F4)
            await ctx.store.close();
            final reopenedStore = LocalTripStore(
              databaseFactory: databaseFactoryFfi,
              databasePath: ctx.dbPath,
            );
            await reopenedStore.open();
            final reopenedHandle = await reopenedStore.activateSession(
              ownerId: 'owner-fault',
              coordinatorEpoch: 2,
            );

            // 1. Journal state rolled back to pending_ack (not committed)
            final journalEntry = await reopenedStore.getJournalEntry(
              handle: reopenedHandle,
              draftId: draftId,
              sourceRevision: r1.revision,
            );
            expect(journalEntry, isNotNull);
            expect(journalEntry!.state, equals('pending_ack'));
            expect(journalEntry.cachedReceipt, isNull);

            // 2. Snapshot was NOT committed
            final snapshot = await reopenedStore.getSnapshot(
              handle: reopenedHandle,
              tripId: 'trip-$draftId',
            );
            expect(snapshot, isNull);

            // 3. Guest draft revision and header pointer remain intact
            final draftRev = await reopenedStore.getDraftRevision(
              draftId: draftId,
              revision: r1.revision,
            );
            expect(draftRev, isNotNull);
            final latestDraft = await reopenedStore.getLatestDraft(
              draftId: draftId,
            );
            expect(latestDraft, isNotNull);
            expect(latestDraft!.revision, equals(1));

            await reopenedStore.close();
          });
        }
      },
    );

    test('repeated_identical_ack_is_idempotent_and_returns_advanced_current_snapshot', () async {
      await runWithStore((ctx) async {
        final p1 = createValidPayload(title: 'Original Title');
        final r1 = await ctx.store.saveDraftRevision(
          draftId: 'draft-idem',
          payload: p1,
        );

        final handle = await ctx.store.activateSession(
          ownerId: 'owner-idem',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'draft-idem',
          sourceRevision: r1.revision,
          requestKey: 'key-idem',
        );

        final receipt = createValidReceipt(
          targetOwner: 'owner-idem',
          draftId: 'draft-idem',
          sourceRevision: r1.revision,
          requestKey: 'key-idem',
          contentDigest: r1.digest,
          tripId: 'trip-idem',
          remoteVersion: 1,
        );

        final firstResult = await ctx.store.commitImportAck(
          handle: handle,
          receipt: receipt,
          payload: p1,
        );
        expect(firstResult.snapshot.remoteVersion, equals(1));
        expect(firstResult.snapshot.title, equals('Original Title'));

        // Advance snapshot via replaceSnapshot to higher remoteVersion (F4)
        final p2 = createValidPayload(title: 'Advanced Title');
        await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'trip-idem',
          payload: p2,
          remoteVersion: 2,
          fetchedAt: DateTime.utc(2026, 10, 11, 12, 0, 0),
        );

        // Repeated identical ack returns the current advanced snapshot!
        final repeatResult = await ctx.store.commitImportAck(
          handle: handle,
          receipt: receipt,
          payload: p1,
        );

        expect(
          repeatResult.receipt.receiptId,
          equals(firstResult.receipt.receiptId),
        );
        expect(repeatResult.snapshot.remoteVersion, equals(2));
        expect(repeatResult.snapshot.title, equals('Advanced Title'));
      });
    });
  });

  group('G7: Receipt Binding Mismatches & Digest Verification', () {
    test('each_incoming_receipt_field_independently_mismatched_rejects_ack', () async {
      await runWithStore((ctx) async {
        final p1 = createValidPayload();
        final r1 = await ctx.store.saveDraftRevision(
          draftId: 'draft-mismatch-all',
          payload: p1,
        );

        final handle = await ctx.store.activateSession(
          ownerId: 'owner-mismatch',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'draft-mismatch-all',
          sourceRevision: r1.revision,
          requestKey: 'key-mismatch-all',
        );

        final validReceipt = createValidReceipt(
          targetOwner: 'owner-mismatch',
          draftId: 'draft-mismatch-all',
          sourceRevision: r1.revision,
          requestKey: 'key-mismatch-all',
          contentDigest: r1.digest,
          receiptId: 'receipt-orig',
          tripId: 'trip-orig',
          remoteVersion: 1,
          committedAt: DateTime.utc(2026, 10, 11, 10, 0, 0),
        );

        // Commit first ack successfully
        await ctx.store.commitImportAck(
          handle: handle,
          receipt: validReceipt,
          payload: p1,
        );

        // Independent mutations of all 10 incoming receipt fields (F4 / C05)
        final mutations = <String, LocalImportReceipt>{
          '1. deviceScope': LocalImportReceipt(
            deviceScope: 'diff-scope',
            targetOwner: validReceipt.targetOwner,
            draftId: validReceipt.draftId,
            sourceRevision: validReceipt.sourceRevision,
            requestKey: validReceipt.requestKey,
            contentDigest: validReceipt.contentDigest,
            receiptId: validReceipt.receiptId,
            tripId: validReceipt.tripId,
            remoteVersion: validReceipt.remoteVersion,
            committedAt: validReceipt.committedAt,
          ),
          '2. targetOwner': LocalImportReceipt(
            deviceScope: validReceipt.deviceScope,
            targetOwner: 'diff-owner',
            draftId: validReceipt.draftId,
            sourceRevision: validReceipt.sourceRevision,
            requestKey: validReceipt.requestKey,
            contentDigest: validReceipt.contentDigest,
            receiptId: validReceipt.receiptId,
            tripId: validReceipt.tripId,
            remoteVersion: validReceipt.remoteVersion,
            committedAt: validReceipt.committedAt,
          ),
          '3. draftId': LocalImportReceipt(
            deviceScope: validReceipt.deviceScope,
            targetOwner: validReceipt.targetOwner,
            draftId: 'diff-draft',
            sourceRevision: validReceipt.sourceRevision,
            requestKey: validReceipt.requestKey,
            contentDigest: validReceipt.contentDigest,
            receiptId: validReceipt.receiptId,
            tripId: validReceipt.tripId,
            remoteVersion: validReceipt.remoteVersion,
            committedAt: validReceipt.committedAt,
          ),
          '4. sourceRevision': LocalImportReceipt(
            deviceScope: validReceipt.deviceScope,
            targetOwner: validReceipt.targetOwner,
            draftId: validReceipt.draftId,
            sourceRevision: 99,
            requestKey: validReceipt.requestKey,
            contentDigest: validReceipt.contentDigest,
            receiptId: validReceipt.receiptId,
            tripId: validReceipt.tripId,
            remoteVersion: validReceipt.remoteVersion,
            committedAt: validReceipt.committedAt,
          ),
          '5. requestKey': LocalImportReceipt(
            deviceScope: validReceipt.deviceScope,
            targetOwner: validReceipt.targetOwner,
            draftId: validReceipt.draftId,
            sourceRevision: validReceipt.sourceRevision,
            requestKey: 'diff-key',
            contentDigest: validReceipt.contentDigest,
            receiptId: validReceipt.receiptId,
            tripId: validReceipt.tripId,
            remoteVersion: validReceipt.remoteVersion,
            committedAt: validReceipt.committedAt,
          ),
          '6. contentDigest': LocalImportReceipt(
            deviceScope: validReceipt.deviceScope,
            targetOwner: validReceipt.targetOwner,
            draftId: validReceipt.draftId,
            sourceRevision: validReceipt.sourceRevision,
            requestKey: validReceipt.requestKey,
            contentDigest: 'b' * 64,
            receiptId: validReceipt.receiptId,
            tripId: validReceipt.tripId,
            remoteVersion: validReceipt.remoteVersion,
            committedAt: validReceipt.committedAt,
          ),
          '7. receiptId': LocalImportReceipt(
            deviceScope: validReceipt.deviceScope,
            targetOwner: validReceipt.targetOwner,
            draftId: validReceipt.draftId,
            sourceRevision: validReceipt.sourceRevision,
            requestKey: validReceipt.requestKey,
            contentDigest: validReceipt.contentDigest,
            receiptId: 'diff-receipt',
            tripId: validReceipt.tripId,
            remoteVersion: validReceipt.remoteVersion,
            committedAt: validReceipt.committedAt,
          ),
          '8. tripId': LocalImportReceipt(
            deviceScope: validReceipt.deviceScope,
            targetOwner: validReceipt.targetOwner,
            draftId: validReceipt.draftId,
            sourceRevision: validReceipt.sourceRevision,
            requestKey: validReceipt.requestKey,
            contentDigest: validReceipt.contentDigest,
            receiptId: validReceipt.receiptId,
            tripId: 'diff-trip',
            remoteVersion: validReceipt.remoteVersion,
            committedAt: validReceipt.committedAt,
          ),
          '9. remoteVersion': LocalImportReceipt(
            deviceScope: validReceipt.deviceScope,
            targetOwner: validReceipt.targetOwner,
            draftId: validReceipt.draftId,
            sourceRevision: validReceipt.sourceRevision,
            requestKey: validReceipt.requestKey,
            contentDigest: validReceipt.contentDigest,
            receiptId: validReceipt.receiptId,
            tripId: validReceipt.tripId,
            remoteVersion: 99,
            committedAt: validReceipt.committedAt,
          ),
          '10. committedAt': LocalImportReceipt(
            deviceScope: validReceipt.deviceScope,
            targetOwner: validReceipt.targetOwner,
            draftId: validReceipt.draftId,
            sourceRevision: validReceipt.sourceRevision,
            requestKey: validReceipt.requestKey,
            contentDigest: validReceipt.contentDigest,
            receiptId: validReceipt.receiptId,
            tripId: validReceipt.tripId,
            remoteVersion: validReceipt.remoteVersion,
            committedAt: DateTime.utc(2030, 1, 1, 0, 0, 0),
          ),
        };

        for (final entry in mutations.entries) {
          // 1. Direct equality helper verification for all 10 fields (C05)
          expect(
            LocalImportReceipt.areReceiptsEqual(validReceipt, entry.value),
            isFalse,
            reason: '${entry.key} must cause areReceiptsEqual to return false',
          );

          // 2. In commitImportAck, conflicting receipt bindings or unmapped sources are rejected with typed exception
          await expectLater(
            ctx.store.commitImportAck(
              handle: handle,
              receipt: entry.value,
              payload: p1,
            ),
            throwsA(
              anyOf(
                isA<ReceiptBindingMismatchException>(),
                isA<ImportJournalNotFoundException>(),
              ),
            ),
            reason:
                'Mutation of ${entry.key} must be rejected by commitImportAck',
          );
        }
      });
    });

    test('contract: malformed durable receipt yields typed corruption (Probe 4 / F2)', () async {
      await runWithStore((ctx) async {
        final payload = createValidPayload();
        final source = await ctx.store.saveDraftRevision(
          draftId: 'probe-4',
          payload: payload,
        );
        final handle = await ctx.store.activateSession(
          ownerId: 'owner-p4',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'probe-4',
          sourceRevision: 1,
          requestKey: 'key-p4',
        );
        final receipt = createValidReceipt(
          targetOwner: 'owner-p4',
          draftId: 'probe-4',
          sourceRevision: 1,
          requestKey: 'key-p4',
          contentDigest: source.digest,
        );
        await ctx.store.commitImportAck(
          handle: handle,
          receipt: receipt,
          payload: payload,
        );
        await ctx.store.rawDb.update(
          'local_import_journal',
          {'receipt_payload': '{'},
          where: 'target_owner = ?',
          whereArgs: ['owner-p4'],
        );
        await expectLater(
          ctx.store.getJournalEntry(
            handle: handle,
            draftId: 'probe-4',
            sourceRevision: 1,
          ),
          throwsA(isA<CorruptDatabaseException>()),
        );
      });
    });

    test('stored_receipt_corruption_and_mutations_yield_corrupt_database_exception', () async {
      await runWithStore((ctx) async {
        final payload = createValidPayload();
        final source = await ctx.store.saveDraftRevision(
          draftId: 'draft-stored-corrupt',
          payload: payload,
        );
        final handle = await ctx.store.activateSession(
          ownerId: 'owner-sc',
          coordinatorEpoch: 1,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'draft-stored-corrupt',
          sourceRevision: 1,
          requestKey: 'key-sc',
        );
        final receipt = createValidReceipt(
          targetOwner: 'owner-sc',
          draftId: 'draft-stored-corrupt',
          sourceRevision: 1,
          requestKey: 'key-sc',
          contentDigest: source.digest,
        );
        await ctx.store.commitImportAck(
          handle: handle,
          receipt: receipt,
          payload: payload,
        );

        final baseMap = receipt.toWhitelistedMap();

        // 10 stored payload mutations
        final storedMutations = <String, String>{
          '1. Non-map root': '"string_value"',
          '2. Extra unexpected key': jsonEncode({
            ...baseMap,
            'unexpected': 123,
          }),
          '3. Missing deviceScope': jsonEncode(
            {...baseMap}..remove('deviceScope'),
          ),
          '4. Missing targetOwner': jsonEncode(
            {...baseMap}..remove('targetOwner'),
          ),
          '5. Fractional sourceRevision': jsonEncode({
            ...baseMap,
            'sourceRevision': 1.5,
          }),
          '6. Fractional remoteVersion': jsonEncode({
            ...baseMap,
            'remoteVersion': 2.5,
          }),
          '7. Non-hex contentDigest': jsonEncode({
            ...baseMap,
            'contentDigest': 'z' * 64,
          }),
          '8. Non-UTC committedAt (+07:00)': jsonEncode({
            ...baseMap,
            'committedAt': '2026-01-01T10:00:00+07:00',
          }),
          '9. Non-Z committedAt': jsonEncode({
            ...baseMap,
            'committedAt': '2026-01-01T10:00:00',
          }),
          '10. Missing tripId': jsonEncode({...baseMap}..remove('tripId')),
        };

        for (final entry in storedMutations.entries) {
          await ctx.store.rawDb.update(
            'local_import_journal',
            {'receipt_payload': entry.value},
            where: 'target_owner = ? AND draft_id = ? AND source_revision = ?',
            whereArgs: ['owner-sc', 'draft-stored-corrupt', 1],
          );

          await expectLater(
            ctx.store.getJournalEntry(
              handle: handle,
              draftId: 'draft-stored-corrupt',
              sourceRevision: 1,
            ),
            throwsA(isA<CorruptDatabaseException>()),
            reason:
                'Stored mutation of ${entry.key} must throw CorruptDatabaseException',
          );
        }
      });
    });

    test(
      'tampered_source_with_different_digest_rejected_on_first_ack',
      () async {
        await runWithStore((ctx) async {
          final p1 = createValidPayload();
          final r1 = await ctx.store.saveDraftRevision(
            draftId: 'draft-tampered',
            payload: p1,
          );

          final handle = await ctx.store.activateSession(
            ownerId: 'owner-tampered',
            coordinatorEpoch: 1,
          );
          await ctx.store.prepareImportJournal(
            handle: handle,
            draftId: 'draft-tampered',
            sourceRevision: r1.revision,
            requestKey: 'key-tampered',
          );

          // Tamper with the draft revision row directly in SQLite
          final alteredPayload = createValidPayload(title: 'Bị sửa đổi');
          final alteredJson = TripPayloadCodec.encode(alteredPayload);
          final alteredDigest = TripPayloadCodec.computeDigest(alteredPayload);

          await ctx.store.rawDb.update(
            'guest_draft_revisions',
            {'payload_json': alteredJson, 'digest': alteredDigest},
            where: 'draft_id = ?',
            whereArgs: ['draft-tampered'],
          );

          final receipt = createValidReceipt(
            targetOwner: 'owner-tampered',
            draftId: 'draft-tampered',
            sourceRevision: r1.revision,
            requestKey: 'key-tampered',
            contentDigest: r1.digest,
          );

          // 4-way digest verification fails!
          await expectLater(
            ctx.store.commitImportAck(
              handle: handle,
              receipt: receipt,
              payload: p1,
            ),
            throwsA(isA<CorruptDatabaseException>()),
          );
        });
      },
    );
  });

  group('G8: Snapshot CAS Writer & Authoritative Versions', () {
    test('contract: snapshot projection cannot contradict explicit payload title (Probe 2 / F2)', () async {
      await runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: 'owner',
          coordinatorEpoch: 1,
        );
        await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'trip',
          payload: createValidPayload(title: 'Original'),
          remoteVersion: 1,
          fetchedAt: DateTime.utc(2026),
        );
        await ctx.store.rawDb.update(
          'account_trip_snapshots',
          {'title': 'Tampered'},
          where: 'owner_id = ? AND trip_id = ?',
          whereArgs: ['owner', 'trip'],
        );
        await expectLater(
          ctx.store.getSnapshot(handle: handle, tripId: 'trip'),
          throwsA(isA<CorruptDatabaseException>()),
        );
      });
    });

    test('contract: stored snapshot non-UTC timestamp is corruption (Probe 3 / F2)', () async {
      await runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: 'owner',
          coordinatorEpoch: 1,
        );
        await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'trip',
          payload: createValidPayload(),
          remoteVersion: 1,
          fetchedAt: DateTime.utc(2026),
        );
        await ctx.store.rawDb.update(
          'account_trip_snapshots',
          {'fetched_at': '2026-01-01T10:00:00+07:00'},
          where: 'owner_id = ? AND trip_id = ?',
          whereArgs: ['owner', 'trip'],
        );
        await expectLater(
          ctx.store.getSnapshot(handle: handle, tripId: 'trip'),
          throwsA(isA<CorruptDatabaseException>()),
        );
      });
    });

    test('snapshot_higher_version_replaces_and_lower_rejects', () async {
      await runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: 'owner-cas',
          coordinatorEpoch: 1,
        );
        final p1 = createValidPayload(title: 'Ver 1');
        final p2 = createValidPayload(title: 'Ver 2');
        final pOld = createValidPayload(title: 'Ver 0');

        final s1 = await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'trip-cas',
          payload: p1,
          remoteVersion: 2,
          fetchedAt: DateTime.utc(2026, 10, 11, 10, 0, 0),
        );
        expect(s1.remoteVersion, equals(2));

        // Higher version (3) replaces version 2
        final s2 = await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'trip-cas',
          payload: p2,
          remoteVersion: 3,
          fetchedAt: DateTime.utc(2026, 10, 11, 11, 0, 0),
        );
        expect(s2.remoteVersion, equals(3));
        expect(s2.title, equals('Ver 2'));

        // Lower version (1) is rejected
        await expectLater(
          ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'trip-cas',
            payload: pOld,
            remoteVersion: 1,
            fetchedAt: DateTime.utc(2026, 10, 11, 12, 0, 0),
          ),
          throwsA(isA<SnapshotStaleVersionException>()),
        );
      });
    });

    test('same_version_different_content_rejected', () async {
      await runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: 'owner-conflict',
          coordinatorEpoch: 1,
        );
        final p1 = createValidPayload(title: 'Content A');
        final p2 = createValidPayload(title: 'Content B');

        await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'trip-conf',
          payload: p1,
          remoteVersion: 2,
          fetchedAt: DateTime.utc(2026, 10, 11, 10, 0, 0),
        );

        await expectLater(
          ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'trip-conf',
            payload: p2,
            remoteVersion: 2,
            fetchedAt: DateTime.utc(2026, 10, 11, 10, 5, 0),
          ),
          throwsA(isA<SnapshotConflictException>()),
        );
      });
    });

    test(
      'legacy_null_version_policy_upgrades_cleanly_and_rejects_downgrade',
      () async {
        await runWithStore((ctx) async {
          final handle = await ctx.store.activateSession(
            ownerId: 'owner-legacy',
            coordinatorEpoch: 1,
          );
          final pLegacy = createValidPayload(title: 'Legacy Null');
          final pVersioned = createValidPayload(title: 'Versioned 1');

          await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'trip-leg',
            payload: pLegacy,
            remoteVersion: null,
            fetchedAt: DateTime.utc(2026, 10, 11, 10, 0, 0),
          );

          // Versioned replaces unversioned
          final upgraded = await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'trip-leg',
            payload: pVersioned,
            remoteVersion: 1,
            fetchedAt: DateTime.utc(2026, 10, 11, 11, 0, 0),
          );
          expect(upgraded.remoteVersion, equals(1));

          // Downgrade to null legacy rejected
          await expectLater(
            ctx.store.replaceSnapshot(
              handle: handle,
              tripId: 'trip-leg',
              payload: pLegacy,
              remoteVersion: null,
              fetchedAt: DateTime.utc(2026, 10, 11, 12, 0, 0),
            ),
            throwsA(isA<SnapshotStaleVersionException>()),
          );
        });
      },
    );

    test(
      'both_null_legacy_same_digest_touches_fetched_at_only_if_newer',
      () async {
        await runWithStore((ctx) async {
          final handle = await ctx.store.activateSession(
            ownerId: 'owner-touch',
            coordinatorEpoch: 1,
          );
          final p = createValidPayload(title: 'Same Content');

          final t1 = DateTime.utc(2026, 10, 11, 10, 0, 0);
          final t2 = DateTime.utc(2026, 10, 11, 11, 0, 0);

          await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'trip-touch',
            payload: p,
            remoteVersion: null,
            fetchedAt: t1,
          );

          final touched = await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'trip-touch',
            payload: p,
            remoteVersion: null,
            fetchedAt: t2,
          );
          expect(touched.fetchedAt, equals(t2));
        });
      },
    );

    test('conflicting_input_only_payload_preserves_good_snapshot', () async {
      await runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: 'owner-partial',
          coordinatorEpoch: 1,
        );
        final goodPayload = createValidPayload(title: 'Good Snapshot');

        await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'trip-part',
          payload: goodPayload,
          remoteVersion: 1,
          fetchedAt: DateTime.utc(2026, 10, 11, 10, 0, 0),
        );

        // Valid request-only content cannot replace different bytes at the same version.
        final partialPayload = createValidPayload(includePlan: false);
        await expectLater(
          ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'trip-part',
            payload: partialPayload,
            remoteVersion: 1,
            fetchedAt: DateTime.utc(2026, 10, 11, 11, 0, 0),
          ),
          throwsA(isA<SnapshotConflictException>()),
        );

        final preserved = await ctx.store.getSnapshot(
          handle: handle,
          tripId: 'trip-part',
        );
        expect(preserved!.title, equals('Good Snapshot'));
        expect(preserved.remoteVersion, equals(1));
      });
    });
  });

  group('Input-only B3 compatibility', () {
    test(
      'plan-only snapshots still reopen without synthesizing a request',
      () async {
        await runWithStore((ctx) async {
          final full = createValidPayload();
          final payload = CanonicalTripPayloadV1(
            metadata: full.metadata,
            plan: full.plan,
          );
          final handle = await ctx.store.activateSession(
            ownerId: 'input-owner',
            coordinatorEpoch: 1,
          );
          await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'plan-only',
            payload: payload,
            remoteVersion: 1,
            fetchedAt: DateTime.utc(2026, 10, 11),
          );
          await ctx.store.close();
          await ctx.store.open();
          final restored = await ctx.store.activateSession(
            ownerId: 'input-owner',
            coordinatorEpoch: 2,
          );
          final snapshot = await ctx.store.getSnapshot(
            handle: restored,
            tripId: 'plan-only',
          );
          expect(snapshot!.payloadJson, TripPayloadCodec.encode(payload));
          expect(snapshot.cachedPayload.request, isNull);
          expect(snapshot.cachedPayload.plan!.winnerId, full.plan!.winnerId);
        });
      },
    );

    test(
      'unversioned input-only updates preserve fetchedAt ordering',
      () async {
        await runWithStore((ctx) async {
          final handle = await ctx.store.activateSession(
            ownerId: 'input-owner',
            coordinatorEpoch: 1,
          );
          final payload = createValidPayload(includePlan: false);
          final time = DateTime.utc(2026, 10, 11);
          await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'legacy-input',
            payload: payload,
            remoteVersion: null,
            fetchedAt: time,
          );
          final changed = createValidPayload(
            includePlan: false,
            title: 'New input',
          );
          await expectLater(
            ctx.store.replaceSnapshot(
              handle: handle,
              tripId: 'legacy-input',
              payload: changed,
              remoteVersion: null,
              fetchedAt: time,
            ),
            throwsA(isA<SnapshotStaleVersionException>()),
          );
          final newer = time.add(const Duration(hours: 1));
          await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'legacy-input',
            payload: changed,
            remoteVersion: null,
            fetchedAt: newer,
          );
          final touched = await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'legacy-input',
            payload: changed,
            remoteVersion: null,
            fetchedAt: time,
          );
          expect(touched.fetchedAt, newer);
          expect(touched.title, 'New input');
          expect(touched.cachedPayload.plan, isNull);
        });
      },
    );

    Future<
      ({
        SessionHandle handle,
        GuestDraftRevisionRecord revision,
        LocalImportReceipt receipt,
        CanonicalTripPayloadV1 payload,
      })
    >
    prepare(TestStoreContext ctx) async {
      final payload = createValidPayload(includePlan: false);
      final revision = await ctx.store.saveDraftRevision(
        draftId: 'input',
        payload: payload,
      );
      final handle = await ctx.store.activateSession(
        ownerId: 'input-owner',
        coordinatorEpoch: 1,
      );
      await ctx.store.prepareImportJournal(
        handle: handle,
        draftId: 'input',
        sourceRevision: revision.revision,
        requestKey: 'input-key',
      );
      final receipt = createValidReceipt(
        targetOwner: 'input-owner',
        draftId: 'input',
        sourceRevision: revision.revision,
        requestKey: 'input-key',
        contentDigest: revision.digest,
        tripId: 'input-trip',
      );
      return (
        handle: handle,
        revision: revision,
        receipt: receipt,
        payload: payload,
      );
    }

    Future<SessionHandle> reopen(TestStoreContext ctx) async {
      await ctx.store.close();
      ctx.store = LocalTripStore(
        databaseFactory: databaseFactoryFfi,
        databasePath: ctx.dbPath,
      );
      await ctx.store.open();
      return ctx.store.activateSession(
        ownerId: 'input-owner',
        coordinatorEpoch: 2,
      );
    }

    test(
      'persists exact bytes through list, reopen and CAS without a plan',
      () async {
        await runWithStore((ctx) async {
          final payload = createValidPayload(includePlan: false);
          var handle = await ctx.store.activateSession(
            ownerId: 'input-owner',
            coordinatorEpoch: 1,
          );
          final time = DateTime.utc(2026, 10, 11);
          await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'input-trip',
            payload: payload,
            remoteVersion: 2,
            fetchedAt: time,
          );
          handle = await reopen(ctx);
          final snapshot = (await ctx.store.listSnapshots(handle: handle))
              .single;
          expect(snapshot.payloadJson, TripPayloadCodec.encode(payload));
          expect(snapshot.digest, TripPayloadCodec.computeDigest(payload));
          expect(snapshot.cachedPayload.plan, isNull);
          expect(
            snapshot.cachedPayload.request!.budgetVnd,
            payload.request!.budgetVnd,
          );
          expect(snapshot.startDate, payload.metadata.startDate);
          expect(snapshot.endDate, payload.metadata.endDate);
          final touched = await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'input-trip',
            payload: payload,
            remoteVersion: 2,
            fetchedAt: time.subtract(const Duration(days: 1)),
          );
          expect(touched.fetchedAt, time);
          await expectLater(
            ctx.store.replaceSnapshot(
              handle: handle,
              tripId: 'input-trip',
              payload: payload,
              remoteVersion: 1,
              fetchedAt: time,
            ),
            throwsA(isA<SnapshotStaleVersionException>()),
          );
          await expectLater(
            ctx.store.replaceSnapshot(
              handle: handle,
              tripId: 'input-trip',
              payload: createValidPayload(includePlan: false, title: 'Changed'),
              remoteVersion: 2,
              fetchedAt: time,
            ),
            throwsA(isA<SnapshotConflictException>()),
          );
          expect(
            (await ctx.store.getSnapshot(
              handle: handle,
              tripId: 'input-trip',
            ))!.digest,
            snapshot.digest,
          );
        });
      },
    );

    test('pending source survives missing/bad ack; valid ack is durable and idempotent', () async {
      await runWithStore((ctx) async {
        final item = await prepare(ctx);
        var handle = await reopen(ctx);
        expect(
          await ctx.store.getDraftRevision(
            draftId: 'input',
            revision: item.revision.revision,
          ),
          isNotNull,
        );
        expect(
          (await ctx.store.getJournalEntry(
            handle: handle,
            draftId: 'input',
            sourceRevision: item.revision.revision,
          ))!.cachedReceipt,
          isNull,
        );
        await expectLater(
          ctx.store.commitImportAck(
            handle: handle,
            receipt: item.receipt,
            payload: createValidPayload(
              includePlan: false,
              title: 'Wrong bytes',
            ),
          ),
          throwsA(isA<ReceiptBindingMismatchException>()),
        );
        final wrong = createValidReceipt(
          targetOwner: 'input-owner',
          draftId: 'input',
          sourceRevision: item.revision.revision,
          requestKey: 'wrong-key',
          contentDigest: item.revision.digest,
          tripId: 'input-trip',
        );
        await expectLater(
          ctx.store.commitImportAck(
            handle: handle,
            receipt: wrong,
            payload: item.payload,
          ),
          throwsA(isA<ReceiptBindingMismatchException>()),
        );
        expect(
          await ctx.store.getSnapshot(handle: handle, tripId: 'input-trip'),
          isNull,
        );
        expect(await ctx.store.getLatestDraft(draftId: 'input'), isNotNull);
        final first = await ctx.store.commitImportAck(
          handle: handle,
          receipt: item.receipt,
          payload: item.payload,
        );
        expect(first.snapshot.cachedPayload.plan, isNull);
        handle = await reopen(ctx);
        final retry = await ctx.store.commitImportAck(
          handle: handle,
          receipt: item.receipt,
          payload: item.payload,
        );
        expect(
          LocalImportReceipt.areReceiptsEqual(first.receipt, retry.receipt),
          isTrue,
        );
        expect(
          retry.snapshot.payloadJson,
          TripPayloadCodec.encode(item.payload),
        );
        expect(await ctx.store.getLatestDraft(draftId: 'input'), isNull);
        expect(
          await ctx.store.getDraftRevision(
            draftId: 'input',
            revision: item.revision.revision,
          ),
          isNull,
        );
        expect(await ctx.store.listSnapshots(handle: handle), hasLength(1));
        await ctx.store.rawDb.update('account_trip_snapshots', {
          'digest': '0' * 64,
        });
        await expectLater(
          ctx.store.commitImportAck(
            handle: handle,
            receipt: item.receipt,
            payload: item.payload,
          ),
          throwsA(isA<CorruptDatabaseException>()),
        );
      });
    });

    for (final step in [
      'after_journal_update',
      'after_snapshot_upsert',
      'after_pointer_null',
      'after_source_delete',
    ]) {
      test('rollback $step preserves input-only source after reopen', () async {
        await runWithStore((ctx) async {
          final item = await prepare(ctx);
          ctx.store.onAckStepForTesting = (current) async {
            if (current == step) {
              throw StateError('Owned input-only rollback probe');
            }
          };
          await expectLater(
            ctx.store.commitImportAck(
              handle: item.handle,
              receipt: item.receipt,
              payload: item.payload,
            ),
            throwsA(isA<StateError>()),
          );
          final handle = await reopen(ctx);
          expect(
            await ctx.store.getSnapshot(handle: handle, tripId: 'input-trip'),
            isNull,
          );
          final journal = await ctx.store.getJournalEntry(
            handle: handle,
            draftId: 'input',
            sourceRevision: item.revision.revision,
          );
          expect(journal!.state, isNot('committed'));
          expect(journal.cachedReceipt, isNull);
          expect(
            (await ctx.store.getLatestDraft(draftId: 'input'))!.digest,
            item.revision.digest,
          );
          final source = await ctx.store.getDraftRevision(
            draftId: 'input',
            revision: item.revision.revision,
          );
          expect(source!.payloadJson, TripPayloadCodec.encode(item.payload));
        });
      });
    }

    for (final corruption in ['digest', 'payload_json', 'title']) {
      test(
        'checked reads and CAS reject input-only $corruption corruption',
        () async {
          await runWithStore((ctx) async {
            final payload = createValidPayload(includePlan: false);
            final handle = await ctx.store.activateSession(
              ownerId: 'input-owner',
              coordinatorEpoch: 1,
            );
            final time = DateTime.utc(2026, 10, 11);
            await ctx.store.replaceSnapshot(
              handle: handle,
              tripId: 'input-trip',
              payload: payload,
              remoteVersion: 1,
              fetchedAt: time,
            );
            await ctx.store.rawDb.update('account_trip_snapshots', {
              corruption: corruption == 'digest' ? '0' * 64 : 'broken',
            });
            await expectLater(
              ctx.store.getSnapshot(handle: handle, tripId: 'input-trip'),
              throwsA(isA<CorruptDatabaseException>()),
            );
            await expectLater(
              ctx.store.listSnapshots(handle: handle),
              throwsA(isA<CorruptDatabaseException>()),
            );
            await expectLater(
              ctx.store.replaceSnapshot(
                handle: handle,
                tripId: 'input-trip',
                payload: payload,
                remoteVersion: 1,
                fetchedAt: time,
              ),
              throwsA(isA<CorruptDatabaseException>()),
            );
          });
        },
      );
    }

    test(
      'owner switch fences input-only reads and purge keeps Guest source',
      () async {
        await runWithStore((ctx) async {
          final item = await prepare(ctx);
          await ctx.store.replaceSnapshot(
            handle: item.handle,
            tripId: 'input-trip',
            payload: item.payload,
            remoteVersion: 1,
            fetchedAt: DateTime.utc(2026, 10, 11),
          );
          final other = await ctx.store.activateSession(
            ownerId: 'other-owner',
            coordinatorEpoch: 1,
          );
          expect(
            await ctx.store.getSnapshot(handle: other, tripId: 'input-trip'),
            isNull,
          );
          await expectLater(
            ctx.store.getSnapshot(handle: item.handle, tripId: 'input-trip'),
            throwsA(isA<StaleSessionEpochException>()),
          );
          await ctx.store.purgeAccountData(
            targetOwnerId: 'input-owner',
            reason: 'Owned logout probe',
          );
          expect(
            await ctx.store.rawDb.query('account_trip_snapshots'),
            isEmpty,
          );
          expect(
            (await ctx.store.getLatestDraft(draftId: 'input'))!.digest,
            item.revision.digest,
          );
        });
      },
    );

    test('input-only projections preserve explicit, preference and empty placeholders', () async {
      await runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: 'input-owner',
          coordinatorEpoch: 1,
        );
        final explicit = createValidPayload(includePlan: false);
        final request = explicit.request!;
        final emptyRequest = PlanTripRequest(
          origin: request.origin,
          numDays: request.numDays,
          numPeople: request.numPeople,
          budgetVnd: request.budgetVnd,
          preferences: [],
          priority: request.priority,
        );
        final cases = [
          (
            explicit,
            explicit.metadata.title!,
            explicit.metadata.destinationName!,
          ),
          (
            CanonicalTripPayloadV1(
              metadata: TripMetadataV1(),
              request: request,
            ),
            'Chuyến đi biển',
            'Điểm đến',
          ),
          (
            CanonicalTripPayloadV1(
              metadata: TripMetadataV1(),
              request: emptyRequest,
            ),
            'Chuyến đi',
            'Điểm đến',
          ),
        ];
        for (var i = 0; i < cases.length; i++) {
          final value = cases[i];
          final row = await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'projection-$i',
            payload: value.$1,
            remoteVersion: 1,
            fetchedAt: DateTime.utc(2026, 10, 11),
          );
          expect(row.title, value.$2);
          expect(row.destinationName, value.$3);
          expect(row.cachedPayload.plan, isNull);
        }
      });
    });
  });

  group('G9: Session Fencing & Monotonic Generation', () {
    test('multi_owner_snapshots_strictly_isolated', () async {
      await runWithStore((ctx) async {
        final handleA = await ctx.store.activateSession(
          ownerId: 'user-a',
          coordinatorEpoch: 1,
        );
        final pA = createValidPayload(title: 'Chuyến đi của A');
        await ctx.store.replaceSnapshot(
          handle: handleA,
          tripId: 'trip-shared-id',
          payload: pA,
          remoteVersion: 1,
          fetchedAt: DateTime.utc(2026, 10, 11, 10, 0, 0),
        );

        final handleB = await ctx.store.activateSession(
          ownerId: 'user-b',
          coordinatorEpoch: 1,
        );
        final snapB = await ctx.store.getSnapshot(
          handle: handleB,
          tripId: 'trip-shared-id',
        );
        expect(snapB, isNull);

        // Demo sessions cannot access account store
        await expectLater(
          ctx.store.activateSession(
            ownerId: 'user-c',
            coordinatorEpoch: 1,
            isDemo: true,
          ),
          throwsA(isA<UnauthorizedAccountAccessException>()),
        );
      });
    });

    test('store_generation_aba_and_stale_handle_rejected', () async {
      await runWithStore((ctx) async {
        final handleA1 = await ctx.store.activateSession(
          ownerId: 'user-aba',
          coordinatorEpoch: 1,
        );

        // Unbind and reactivate advances store generation
        ctx.store.unbindSession();
        await ctx.store.activateSession(
          ownerId: 'user-aba',
          coordinatorEpoch: 1,
        );

        // Stale handleA1 is rejected
        await expectLater(
          ctx.store.getSnapshot(handle: handleA1, tripId: 'trip-1'),
          throwsA(isA<StaleSessionEpochException>()),
        );
      });
    });

    test('late_returning_account_read_rejected_at_publication_layer', () async {
      await runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: 'user-late',
          coordinatorEpoch: 1,
        );
        final p = createValidPayload();
        await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'trip-late',
          payload: p,
          remoteVersion: 1,
          fetchedAt: DateTime.utc(2026, 10, 11, 10, 0, 0),
        );

        // Deterministic in-flight barrier: unbind right after txn commits, BEFORE publication layer check (F4 / C03)
        ctx.store.onAccountOpStepForTesting = (step) async {
          if (step == 'before_layer3') {
            ctx.store.unbindSession();
          }
        };

        await expectLater(
          ctx.store.getSnapshot(handle: handle, tripId: 'trip-late'),
          throwsA(isA<StaleSessionEpochException>()),
        );

        ctx.store.onAccountOpStepForTesting = null;
      });
    });
  });

  group('G10: Durable Purge Protocol & Quarantine', () {
    test(
      'logout_purges_snapshots_and_committed_receipts_quarantines_pending',
      () async {
        await runWithStore((ctx) async {
          final handle = await ctx.store.activateSession(
            ownerId: 'user-purge',
            coordinatorEpoch: 1,
          );
          final p1 = createValidPayload();
          final r1 = await ctx.store.saveDraftRevision(
            draftId: 'draft-p1',
            payload: p1,
          );

          // 1. Prepare journal (staged)
          await ctx.store.prepareImportJournal(
            handle: handle,
            draftId: 'draft-p1',
            sourceRevision: r1.revision,
            requestKey: 'key-p1',
          );

          // 2. Put snapshot
          await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'trip-p1',
            payload: p1,
            remoteVersion: 1,
            fetchedAt: DateTime.utc(2026, 10, 11, 10, 0, 0),
          );

          // 3. Purge account
          await ctx.store.purgeAccountData(
            targetOwnerId: 'user-purge',
            reason: 'User Logout',
          );

          // Verify snapshots are deleted
          final snapRows = await ctx.store.rawDb.query(
            'account_trip_snapshots',
            where: 'owner_id = ?',
            whereArgs: ['user-purge'],
          );
          expect(snapRows, isEmpty);

          // Verify staged journal transitioned to quarantined with receipt_payload = NULL
          final journalRows = await ctx.store.rawDb.query(
            'local_import_journal',
            where: 'target_owner = ?',
            whereArgs: ['user-purge'],
          );
          expect(journalRows.length, equals(1));
          expect(journalRows.first['state'], equals('quarantined'));
          expect(journalRows.first['receipt_payload'], isNull);

          // Untransferred guest drafts remain intact
          final guestDraft = await ctx.store.getLatestDraft(
            draftId: 'draft-p1',
          );
          expect(guestDraft, isNotNull);
        });
      },
    );

    test('owner_b_cannot_view_or_resume_owner_a_quarantine', () async {
      await runWithStore((ctx) async {
        final handleA = await ctx.store.activateSession(
          ownerId: 'owner-qa',
          coordinatorEpoch: 1,
        );
        final p1 = createValidPayload();
        final r1 = await ctx.store.saveDraftRevision(
          draftId: 'draft-qa',
          payload: p1,
        );
        await ctx.store.prepareImportJournal(
          handle: handleA,
          draftId: 'draft-qa',
          sourceRevision: r1.revision,
          requestKey: 'key-qa',
        );

        await ctx.store.purgeAccountData(
          targetOwnerId: 'owner-qa',
          reason: 'Logout',
        );

        final handleB = await ctx.store.activateSession(
          ownerId: 'owner-qb',
          coordinatorEpoch: 1,
        );
        final listB = await ctx.store.listQuarantinedJournals(handle: handleB);
        expect(listB, isEmpty);

        // Owner B cannot stage same source (still quarantined by Owner A)
        await expectLater(
          ctx.store.prepareImportJournal(
            handle: handleB,
            draftId: 'draft-qa',
            sourceRevision: r1.revision,
            requestKey: 'key-qb',
          ),
          throwsA(isA<DraftImportPendingException>()),
        );
      });
    });
  });

  group('G11: Queue Invariants & No Resurrect', () {
    test(
      'queued_and_in_flight_writes_cannot_resurrect_data_after_purge',
      () async {
        await runWithStore((ctx) async {
          final handle = await ctx.store.activateSession(
            ownerId: 'user-inflight',
            coordinatorEpoch: 1,
          );
          final p = createValidPayload();

          // Queue write then immediately purge
          final writeFuture = ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'trip-inflight',
            payload: p,
            remoteVersion: 1,
            fetchedAt: DateTime.utc(2026, 10, 11, 10, 0, 0),
          );
          final purgeFuture = ctx.store.purgeAccountData(
            targetOwnerId: 'user-inflight',
            reason: 'Emergency logout',
          );

          // Write might complete or fail with stale epoch, but purge runs afterwards and snapshots must be empty!
          try {
            await writeFuture;
          } catch (_) {}
          await purgeFuture;

          final snapRows = await ctx.store.rawDb.query(
            'account_trip_snapshots',
            where: 'owner_id = ?',
            whereArgs: ['user-inflight'],
          );
          expect(snapRows, isEmpty);
        });
      },
    );

    test('failed_queue_operation_does_not_poison_subsequent_cleanup', () async {
      await runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: 'user-poison',
          coordinatorEpoch: 1,
        );

        // Queue an operation that will fail
        await expectLater(
          ctx.store.commitImportAck(
            handle: handle,
            receipt: createValidReceipt(contentDigest: 'a' * 64),
            payload: createValidPayload(),
          ),
          throwsA(isA<ImportJournalNotFoundException>()),
        );

        // Subsequent purge completes cleanly
        await ctx.store.purgeAccountData(
          targetOwnerId: 'user-poison',
          reason: 'Cleanup after fail',
        );
        expect(true, isTrue);
      });
    });
  });

  group('G12: Crash Recovery & Startup Resumption', () {
    test('simulated_purge_crash_leaves_namespace_blocked', () async {
      await runWithStore((ctx) async {
        final handle = await ctx.store.activateSession(
          ownerId: 'user-crash',
          coordinatorEpoch: 1,
        );
        await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'trip-crash',
          payload: createValidPayload(),
          remoteVersion: 1,
          fetchedAt: DateTime.utc(2026, 10, 11, 10, 0, 0),
        );

        // Inject fault before Step 4 (Txn 3 marker deletion)
        ctx.store.onPurgeStepForTesting = (step) async {
          if (step == 'before_delete_marker_txn') {
            throw StateError('Simulated crash during purge deletion');
          }
        };

        await expectLater(
          ctx.store.purgeAccountData(
            targetOwnerId: 'user-crash',
            reason: 'Crash test',
          ),
          throwsA(isA<StateError>()),
        );

        ctx.store.onPurgeStepForTesting = null;

        // Namespace is blocked in SQLite!
        final blocked = await ctx.store.rawDb.query(
          'local_cleanup_state',
          where: 'namespace = ? AND is_blocked = 1',
          whereArgs: ['account:user-crash'],
        );
        expect(blocked, isNotEmpty);

        // Activation attempt is blocked
        await expectLater(
          ctx.store.activateSession(ownerId: 'user-crash', coordinatorEpoch: 2),
          throwsA(isA<AccountNamespaceBlockedException>()),
        );
      });
    });

    test(
      'startup_recovery_resumes_purge_and_unlocks_with_preexisting_data',
      () async {
        await runWithStore((ctx) async {
          final now = DateTime.utc(2026, 10, 11, 10, 0, 0).toIso8601String();

          // 1. Preexisting snapshot for user-recovery (must be purged)
          final p = createValidPayload(title: 'Trip to Purge');
          await ctx.store.rawDb.insert('account_trip_snapshots', {
            'owner_id': 'user-recovery',
            'trip_id': 'trip-purge-1',
            'remote_version': 1,
            'schema_version': 1,
            'fetched_at': now,
            'payload_json': TripPayloadCodec.encode(p),
            'digest': TripPayloadCodec.computeDigest(p),
            'title': 'Trip to Purge',
            'destination_name': 'Dest',
            'updated_at': now,
          });

          // 2. Preexisting committed import journal for user-recovery (must be purged)
          final receipt = createValidReceipt(
            targetOwner: 'user-recovery',
            draftId: 'draft-comm-1',
            sourceRevision: 1,
            requestKey: 'key-comm-1',
            contentDigest: 'a' * 64,
          );
          await ctx.store.rawDb.insert('local_import_journal', {
            'device_scope': 'default',
            'target_owner': 'user-recovery',
            'draft_id': 'draft-comm-1',
            'source_revision': 1,
            'request_key': 'key-comm-1',
            'content_digest': 'a' * 64,
            'state': 'committed',
            'receipt_payload': jsonEncode(receipt.toWhitelistedMap()),
            'created_at': now,
            'updated_at': now,
          });

          // 3. Preexisting staged import journal for user-recovery (must be quarantined)
          await ctx.store.rawDb.insert('local_import_journal', {
            'device_scope': 'default',
            'target_owner': 'user-recovery',
            'draft_id': 'draft-staged-1',
            'source_revision': 1,
            'request_key': 'key-staged-1',
            'content_digest': 'b' * 64,
            'state': 'staged',
            'receipt_payload': null,
            'created_at': now,
            'updated_at': now,
          });

          // 4. Preexisting guest draft (must be PRESERVED)
          final guestPayload = createValidPayload(title: 'Guest Kept');
          await ctx.store.saveDraftRevision(
            draftId: 'draft-guest-keep',
            payload: guestPayload,
          );

          // 5. Uncompleted cleanup marker in SQLite
          await ctx.store.rawDb.insert('local_cleanup_state', {
            'namespace': 'account:user-recovery',
            'is_blocked': 1,
            'purge_pending': 1,
            'reason': 'Interrupted purge',
            'created_at': now,
            'updated_at': now,
          });

          // Close and reopen store
          await ctx.store.close();
          final reopenedStore = LocalTripStore(
            databaseFactory: databaseFactoryFfi,
            databasePath: ctx.dbPath,
          );
          await reopenedStore.open();

          // Verification 1: Snapshots for user-recovery were deleted
          final snapRows = await reopenedStore.rawDb.query(
            'account_trip_snapshots',
            where: 'owner_id = ?',
            whereArgs: ['user-recovery'],
          );
          expect(snapRows, isEmpty);

          // Verification 2: Committed journal entries for user-recovery were deleted
          final commRows = await reopenedStore.rawDb.query(
            'local_import_journal',
            where: 'target_owner = ? AND state = ?',
            whereArgs: ['user-recovery', 'committed'],
          );
          expect(commRows, isEmpty);

          // Verification 3: Staged journal entry was quarantined
          final quarRows = await reopenedStore.rawDb.query(
            'local_import_journal',
            where: 'target_owner = ? AND draft_id = ?',
            whereArgs: ['user-recovery', 'draft-staged-1'],
          );
          expect(quarRows, isNotEmpty);
          expect(quarRows.first['state'], equals('quarantined'));
          expect(quarRows.first['receipt_payload'], isNull);

          // Verification 4: Guest drafts were completely preserved
          final preservedDraft = await reopenedStore.getLatestDraft(
            draftId: 'draft-guest-keep',
          );
          expect(preservedDraft, isNotNull);
          expect(preservedDraft!.revision, equals(1));

          // Verification 5: Cleanup marker was deleted
          final markers = await reopenedStore.rawDb.query(
            'local_cleanup_state',
            where: 'namespace = ?',
            whereArgs: ['account:user-recovery'],
          );
          expect(markers, isEmpty);

          // Verification 6: Activation now succeeds
          final handle = await reopenedStore.activateSession(
            ownerId: 'user-recovery',
            coordinatorEpoch: 1,
          );
          expect(handle.ownerId, equals('user-recovery'));
          await reopenedStore.close();
        });
      },
    );

    test(
      'startup_recovery_rejects_malformed_marker_and_fails_closed',
      () async {
        await runWithStore((ctx) async {
          final now = DateTime.utc(2026, 10, 11, 10, 0, 0).toIso8601String();
          // Insert malformed marker (namespace does not start with account:)
          await ctx.store.rawDb.insert('local_cleanup_state', {
            'namespace': 'invalid_scope_name',
            'is_blocked': 1,
            'purge_pending': 1,
            'reason': 'Malformed test',
            'created_at': now,
            'updated_at': now,
          });

          await ctx.store.close();
          final failedOpenStore = LocalTripStore(
            databaseFactory: databaseFactoryFfi,
            databasePath: ctx.dbPath,
          );

          // open() throws CorruptDatabaseException and closes database cleanly
          await expectLater(
            failedOpenStore.open(),
            throwsA(isA<CorruptDatabaseException>()),
          );

          // Store is not opened
          await expectLater(
            failedOpenStore.getLatestDraft(draftId: 'draft-any'),
            throwsA(isA<StoreUnavailableException>()),
          );
        });
      },
    );
  });

  group('G13: Fail-Closed on Marker Failure', () {
    test('marker_write_failure_disables_cache_fail_closed', () async {
      await runWithStore((ctx) async {
        // Inject fault before marker txn
        ctx.store.onPurgeStepForTesting = (step) async {
          if (step == 'before_marker_txn') {
            throw const SocketException(
              'Simulated disk full during marker write',
            );
          }
        };

        await expectLater(
          ctx.store.purgeAccountData(
            targetOwnerId: 'user-fail-marker',
            reason: 'Test fail-closed',
          ),
          throwsA(isA<CleanupMarkerPersistenceException>()),
        );

        ctx.store.onPurgeStepForTesting = null;

        // Process cache is locked (in _blockedOwners): activating user-fail-marker throws!
        await expectLater(
          ctx.store.activateSession(
            ownerId: 'user-fail-marker',
            coordinatorEpoch: 1,
          ),
          throwsA(isA<AccountNamespaceBlockedException>()),
        );
      });
    });
  });

  group('G14: Future Schema & Integrity Checks', () {
    test('unsupported_future_schema_rejects_without_data_loss', () async {
      await runWithStore((ctx) async {
        await ctx.store.close();

        // Always test an unsupported future version, even after a supported upgrade.
        final rawDb = await databaseFactoryFfi.openDatabase(ctx.dbPath);
        final futureVersion = LocalTripStore.databaseSchemaVersion + 1;
        await rawDb.execute('PRAGMA user_version = $futureVersion;');
        await rawDb.close();

        final futureStore = LocalTripStore(
          databaseFactory: databaseFactoryFfi,
          databasePath: ctx.dbPath,
        );

        try {
          await expectLater(
            futureStore.open(),
            throwsA(isA<UnsupportedDatabaseVersionException>()),
          );
        } finally {
          await futureStore.close();
        }

        // File remains intact
        expect(File(ctx.dbPath).existsSync(), isTrue);
      });
    });

    test('corrupt_payload_byte_hash_or_canonical_drift_detected', () async {
      await runWithStore((ctx) async {
        final payload = createValidPayload();
        await ctx.store.saveDraftRevision(
          draftId: 'draft-corrupt',
          payload: payload,
        );

        // Tamper payload JSON without updating digest
        await ctx.store.rawDb.update(
          'guest_draft_revisions',
          {'payload_json': '{"schemaVersion": 1, "metadata": {}}'},
          where: 'draft_id = ?',
          whereArgs: ['draft-corrupt'],
        );

        await expectLater(
          ctx.store.getLatestDraft(draftId: 'draft-corrupt'),
          throwsA(isA<CorruptDatabaseException>()),
        );
      });
    });
  });

  group('G15: Harness Safety & Cleanup Verification', () {
    test('test_temp_directory_cleaned_up_safely', () async {
      String? recordedTempPath;
      await runWithStore((ctx) async {
        recordedTempPath = ctx.tempDir.path;
        expect(Directory(recordedTempPath!).existsSync(), isTrue);
      });

      // After runWithStore exits, tempDir is deleted
      expect(Directory(recordedTempPath!).existsSync(), isFalse);
    });

    test(
      'dispose_rejects_mutated_or_unowned_target_path_without_deletion',
      () async {
        final ownedDir = Directory.systemTemp.createTempSync('b2_test_owned_');
        final unownedDir = Directory.systemTemp.createTempSync(
          'b2_test_unowned_',
        );
        final dbPath = p.join(
          ownedDir.path,
          LocalTripStore.defaultDatabaseName,
        );
        final store = LocalTripStore(
          databaseFactory: databaseFactoryFfi,
          databasePath: dbPath,
        );

        final ctx = TestStoreContext(
          tempDir: ownedDir,
          dbPath: dbPath,
          store: store,
        );

        // Mutate tempDir to point to unowned directory
        final mutatedCtx = TestStoreContext._(
          tempDir: unownedDir,
          dbPath: dbPath,
          store: store,
          canonicalOwnedPath: ownedDir.resolveSymbolicLinksSync(),
          canonicalTempRoot: Directory.systemTemp.resolveSymbolicLinksSync(),
        );

        await expectLater(mutatedCtx.dispose(), throwsA(isA<StateError>()));

        // Crucial: unownedDir was NOT deleted!
        expect(unownedDir.existsSync(), isTrue);

        // Clean up safely
        TestStoreContext.deleteOwnedDirectory(
          unownedDir,
          unownedDir.resolveSymbolicLinksSync(),
          Directory.systemTemp.resolveSymbolicLinksSync(),
        );
        await ctx.dispose();
        expect(ownedDir.existsSync(), isFalse);
      },
    );

    test('dispose_reports_close_failure_independently', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'b2_test_close_fail_',
      );
      final dbPath = p.join(tempDir.path, LocalTripStore.defaultDatabaseName);
      final store = _FailingCloseStore(
        databaseFactory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      await store.open();

      final ctx = TestStoreContext(
        tempDir: tempDir,
        dbPath: dbPath,
        store: store,
      );

      await expectLater(ctx.dispose(), throwsA(isA<SocketException>()));

      // Despite close failure, owned tempDir was still deleted!
      expect(tempDir.existsSync(), isFalse);
    });

    test('runWithStore_preserves_primary_error_when_cleanup_fails', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'b2_test_primary_err_',
      );
      final dbPath = p.join(tempDir.path, LocalTripStore.defaultDatabaseName);
      final store = _FailingCloseStore(
        databaseFactory: databaseFactoryFfi,
        databasePath: dbPath,
      );

      TestStoreContext? ctx;
      dynamic caughtError;

      try {
        await store.open();
        ctx = TestStoreContext(tempDir: tempDir, dbPath: dbPath, store: store);
        try {
          throw const FormatException('Primary body error');
        } catch (e, st) {
          // Emulate runWithStore error preservation
          try {
            await ctx.dispose();
          } catch (_) {
            // Secondary cleanup failure swallowed in favor of primary error
          }
          Error.throwWithStackTrace(e, st);
        }
      } catch (e) {
        caughtError = e;
      }

      expect(caughtError, isA<FormatException>());
      expect(
        (caughtError as FormatException).message,
        equals('Primary body error'),
      );
      expect(tempDir.existsSync(), isFalse);
    });
  });
}

class _FailingCloseStore extends LocalTripStore {
  _FailingCloseStore({required super.databasePath, super.databaseFactory});

  @override
  Future<void> close() async {
    await super.close();
    throw const SocketException('Simulated close failure');
  }
}

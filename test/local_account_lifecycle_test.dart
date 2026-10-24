import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

import 'local_trip_store_test.dart' as fixtures;

const ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const ownerC = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
Session sessionFor(String owner) => Session.fromJson({
  'access_token': 'fixture-$owner',
  'refresh_token': 'fixture-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': owner,
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
    'aud': 'authenticated',
    'created_at': '2026-10-13T00:00:00Z',
  },
})!..expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final outcome in [
    'verified',
    'offline',
    'wrong-owner',
    'late-owner',
    'late-expiry',
    'late-invalidation',
    'no-verifier',
    'revoked',
  ]) {
    test(
      'AUTH_RESUME pending operation $outcome revalidates online without offline grant',
      () async {
        await fixtures.runWithStore((ctx) async {
          var session = sessionFor(ownerA);
          var returning = false;
          var verifications = 0;
          late final LocalAccountLifecycleService service;
          final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
          service = LocalAccountLifecycleService(
            storeLoader: () async => ctx.store,
            sessionReader: () => session,
            registryPath: path,
            verifySubject: outcome == 'no-verifier'
                ? null
                : (_) async {
                    verifications++;
                    if (!returning) return ownerA;
                    if (outcome == 'offline') {
                      throw StateError('Controlled verifier outage');
                    }
                    if (outcome == 'wrong-owner') return ownerB;
                    if (outcome == 'late-owner') session = sessionFor(ownerB);
                    if (outcome == 'late-expiry') {
                      session.expiresAt =
                          DateTime.now().millisecondsSinceEpoch ~/ 1000;
                    }
                    if (outcome == 'late-invalidation') {
                      service.invalidateAccountContext();
                    }
                    return ownerA;
                  },
          );
          void Function()? finish;
          try {
            final handle = await service.establishAccount(
              freshAuthentication: true,
            );
            expect(handle, isNotNull);
            await ctx.store.saveDraftRevision(
              draftId: 'Guest-resume',
              payload: fixtures.createValidPayload(),
            );
            final proof = service.captureProof();
            finish = service.beginAccountOperation(proof);
            await service.suspendForegroundContext();
            expect(service.handle, isNull);
            expect(service.isCurrentProof(proof), isFalse);
            expect(await service.sealForPause(), isFalse);
            expect(
              jsonDecode(await File(path).readAsString())['state'],
              'active',
            );
            returning = true;
            final resumed = service.resumeForegroundContext();
            await Future<void>.delayed(Duration.zero);
            expect(service.handle, isNull);
            expect(verifications, outcome == 'no-verifier' ? 0 : 1);
            final revocation = outcome == 'revoked'
                ? service.revokeAccount()
                : Future.value(false);
            finish();
            finish = null;
            final restored = await resumed;
            await revocation;
            expect(service.isCurrentProof(proof), isFalse);
            if (outcome == 'verified') {
              expect(restored, isNotNull);
              expect(restored!.ownerId, ownerA);
              expect(verifications, 2);
              expect(service.isCurrentProof(service.captureProof()), isTrue);
            } else {
              expect(restored, isNull);
              expect(service.handle, isNull);
            }
            expect(await ctx.store.listGuestDrafts(), hasLength(1));
          } finally {
            finish?.call();
            await service.close();
          }
        });
      },
    );
  }
  for (final outcome in [
    'verified',
    'offline',
    'wrong-owner',
    'late-owner',
    'late-expiry',
    'late-invalidation',
  ]) {
    test(
      'PHONE03 active cold restart $outcome requires live authorization',
      () async {
        await fixtures.runWithStore((ctx) async {
          var session = sessionFor(ownerA);
          final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
          final first = LocalAccountLifecycleService(
            storeLoader: () async => ctx.store,
            sessionReader: () => session,
            registryPath: path,
          );
          try {
            final handle = await first.establishAccount(
              freshAuthentication: true,
            );
            await ctx.store.replaceSnapshot(
              handle: handle!,
              tripId: 'cold-A',
              payload: fixtures.createValidPayload(),
              fetchedAt: DateTime.now().toUtc(),
            );
            await ctx.store.saveDraftRevision(
              draftId: 'Guest',
              payload: fixtures.createValidPayload(),
            );
          } finally {
            await first.close();
          }
          expect(
            jsonDecode(await File(path).readAsString())['state'],
            'active',
          );
          final entered = Completer<void>(), release = Completer<void>();
          var checks = 0;
          final second = LocalAccountLifecycleService(
            storeLoader: () async => ctx.store,
            sessionReader: () => session,
            registryPath: path,
            verifySubject: (_) async {
              checks++;
              entered.complete();
              if (outcome.startsWith('late-')) await release.future;
              if (outcome == 'offline') throw StateError('Controlled offline');
              return outcome == 'wrong-owner' ? ownerB : ownerA;
            },
          );
          try {
            final pending = second.resumeAccount();
            if (outcome.startsWith('late-')) {
              // Bound the diagnostic wait so pre-fix denial fails, not hangs.
              await Future.any([entered.future, pending.then((_) {})]);
              if (outcome == 'late-owner') session = sessionFor(ownerB);
              if (outcome == 'late-expiry') session.expiresAt = 1;
              if (outcome == 'late-invalidation') {
                second.invalidateAccountContext();
              }
              release.complete();
            }
            final restored = await pending;
            expect(checks, 1);
            if (outcome == 'verified') {
              expect(restored, isNotNull);
              expect(restored!.ownerId, ownerA);
              expect(
                (await ctx.store.listSnapshots(handle: restored)).single.tripId,
                'cold-A',
              );
            } else {
              expect(restored, isNull);
              expect(second.handle, isNull);
            }
            expect(await ctx.store.listGuestDrafts(), hasLength(1));
          } finally {
            if (!release.isCompleted) release.complete();
            await second.close();
          }
        });
      },
    );
  }
  test('L07 another blocked owner denies seal and deadline revokes without SDK event', () async {
    await fixtures.runWithStore((ctx) async {
      var now = DateTime.now().toUtc();
      final session = sessionFor(ownerA);
      final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
      final service = LocalAccountLifecycleService(
        storeLoader: () async => ctx.store,
        sessionReader: () => session,
        registryPath: path,
        clock: () => now,
      );
      try {
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNotNull,
        );
        ctx.store.onPurgeStepForTesting = (step) async {
          if (step == 'before_marker_txn') throw StateError('B marker fault');
        };
        await expectLater(
          ctx.store.purgeAccountData(targetOwnerId: ownerB, reason: 'test'),
          throwsA(isA<CleanupMarkerPersistenceException>()),
        );
        expect(await service.sealForPause(), isFalse);
        ctx.store.onPurgeStepForTesting = null;
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNotNull,
        );
        final proof = service.captureProof();
        now = DateTime.fromMillisecondsSinceEpoch(
          session.expiresAt! * 1000,
          isUtc: true,
        );
        expect(service.isCurrentProof(proof), isFalse);
        expect(service.handle, isNull);
      } finally {
        await service.close();
      }
    });
  });

  test('L06 late consumer unregister cancels async publication', () async {
    await fixtures.runWithStore((ctx) async {
      final session = sessionFor(ownerA);
      final service = LocalAccountLifecycleService(
        storeLoader: () async => ctx.store,
        sessionReader: () => session,
        registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      SessionHandle? displayed;
      try {
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNotNull,
        );
        final unregister = service.registerConsumer(
          invalidate: () {
            displayed = null;
          },
          bind: (handle) async {
            entered.complete();
            await release.future;
            displayed = handle;
          },
        );
        await entered.future;
        unregister();
        release.complete();
        await service.close();
        expect(displayed, isNull);
        // Coordinator disposal never closes the shared Guest store.
        await ctx.store.saveDraftRevision(
          draftId: 'after-close',
          payload: fixtures.createValidPayload(),
        );
        expect(await ctx.store.listGuestDrafts(), hasLength(1));
      } finally {
        if (!release.isCompleted) release.complete();
        await service.close();
      }
    });
  });

  test('L04 failed authentication preflight preserves seal and forbids SDK mutation', () async {
    await fixtures.runWithStore((ctx) async {
      final session = sessionFor(ownerA);
      final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
      var fault = false;
      final service = LocalAccountLifecycleService(
        storeLoader: () async => ctx.store,
        sessionReader: () => session,
        registryPath: path,
        registryFile: LifecycleRegistryFile(
          path,
          onStep: (step) async {
            if (fault && step == 'replace') {
              throw FileSystemException('Intent fault');
            }
          },
        ),
      );
      try {
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNotNull,
        );
        expect(await service.sealForPause(), isTrue);
        final sealedBytes = await File(path).readAsString();
        fault = true;
        await expectLater(
          service.prepareAuthenticationMutation(),
          throwsStateError,
        );
        expect(service.handle, isNull);
        expect(await File(path).readAsString(), sealedBytes);
        expect(await service.revokeAccount(), isFalse);
        fault = false;
        expect(await service.revokeAccount(), isTrue);
        expect(
          jsonDecode(await File(path).readAsString())['state'],
          'signedOut',
        );
      } finally {
        await service.close();
      }
    });
  });

  test(
    'Neutral cleanup queued read is canceled by intervening activation',
    () async {
      await fixtures.runWithStore((ctx) async {
        final entered = Completer<void>();
        final release = Completer<void>();
        ctx.store.onSaveDraftStepForTesting = (step) async {
          if (!entered.isCompleted) {
            entered.complete();
            await release.future;
          }
        };
        final save = ctx.store.saveDraftRevision(
          draftId: 'Guest',
          payload: fixtures.createValidPayload(),
        );
        await entered.future;
        final inspection = ctx.store.listAccountOwnersForCleanup();
        final assertion = expectLater(
          inspection,
          throwsA(isA<StaleSessionEpochException>()),
        );
        final activation = ctx.store.activateSession(
          ownerId: ownerA,
          coordinatorEpoch: 1,
        );
        release.complete();
        await save;
        await assertion;
        expect(await activation, isNotNull);
      });
    },
  );
  test(
    'L01 fresh -> sealed restart -> active, private proof expires',
    () async {
      await fixtures.runWithStore((ctx) async {
        final session = sessionFor(ownerA);
        final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
        LocalAccountLifecycleService makeService() =>
            LocalAccountLifecycleService(
              storeLoader: () async => ctx.store,
              sessionReader: () => session,
              registryPath: path,
            );
        final first = makeService();
        try {
          expect(
            await first.establishAccount(freshAuthentication: true),
            isNotNull,
          );
          await ctx.store.replaceSnapshot(
            handle: first.handle!,
            tripId: 'keep-A',
            payload: fixtures.createValidPayload(),
            fetchedAt: DateTime.now().toUtc(),
          );
          final proof = first.captureProof();
          expect(first.isCurrentProof(proof), isTrue);
          expect(await first.sealForPause(), isTrue);
          expect(first.isCurrentProof(proof), isFalse);
          expect(
            jsonDecode(await File(path).readAsString())['state'],
            'sealed',
          );
        } finally {
          await first.close();
        }
        final second = makeService();
        try {
          expect(await second.resumeAccount(), isNotNull);
          expect(
            (await ctx.store.listSnapshots(handle: second.handle!))
                .single
                .tripId,
            'keep-A',
          );
          final text = await File(path).readAsString();
          expect(jsonDecode(text)['state'], 'active');
          expect(text, isNot(contains(session.accessToken)));
        } finally {
          await second.close();
        }
      });
    },
  );

  for (final kind in [
    'null',
    'expired',
    'demo',
    'blank',
    'unknown-expiry',
    'anonymous',
    'subject-verifier',
  ]) {
    test(
      'Checked SDK authority rejects $kind even with freshAuthentication',
      () async {
        await fixtures.runWithStore((ctx) async {
          Session? session = sessionFor(ownerA);
          switch (kind) {
            case 'null':
              session = null;
            case 'expired':
              session.expiresAt = 1;
            case 'demo':
              session = sessionFor('demo-user');
            case 'blank':
              session = sessionFor(ownerA).copyWith(accessToken: ' ');
            case 'unknown-expiry':
              session.expiresAt = null;
            case 'anonymous':
              session = session.copyWith(
                user: User.fromJson({
                  ...session.user.toJson(),
                  'is_anonymous': true,
                }),
              );
              session.expiresAt =
                  DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
          }
          final service = LocalAccountLifecycleService(
            storeLoader: () async => ctx.store,
            sessionReader: () => session,
            registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
            verifySubject: kind == 'subject-verifier'
                ? (_) async => ownerB
                : null,
          );
          try {
            expect(
              await service.establishAccount(freshAuthentication: true),
              isNull,
            );
            expect(service.handle, isNull);
          } finally {
            await service.close();
          }
        });
      },
    );
  }

  test('L07 consumer bind completion after pause is invalidated and cannot earn a seal', () async {
    await fixtures.runWithStore((ctx) async {
      final session = sessionFor(ownerA);
      final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
      final service = LocalAccountLifecycleService(
        storeLoader: () async => ctx.store,
        sessionReader: () => session,
        registryPath: path,
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      SessionHandle? displayed;
      service.registerConsumer(
        invalidate: () {
          displayed = null;
        },
        bind: (handle) async {
          entered.complete();
          await release.future;
          displayed = handle;
        },
      );
      try {
        final activation = service.establishAccount(freshAuthentication: true);
        await entered.future;
        final pause = service.sealForPause();
        release.complete();
        expect(await activation, isNull);
        expect(await pause, isFalse);
        expect(displayed, isNull);
        expect(service.handle, isNull);
        expect(jsonDecode(await File(path).readAsString())['state'], 'active');
      } finally {
        if (!release.isCompleted) release.complete();
        await service.close();
      }
    });
  });

  test('L06 consumer failure and failed purge deny publication, queue still permits retry', () async {
    await fixtures.runWithStore((ctx) async {
      final session = sessionFor(ownerA);
      final service = LocalAccountLifecycleService(
        storeLoader: () async => ctx.store,
        sessionReader: () => session,
        registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
      );
      final unregister = service.registerConsumer(
        invalidate: () {},
        bind: (_) async {
          throw StateError('Controlled bind failure');
        },
      );
      try {
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNull,
        );
        expect(service.handle, isNull);
        unregister();
        final handle = (await service.establishAccount(
          freshAuthentication: true,
        ))!;
        await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'A',
          payload: fixtures.createValidPayload(),
          fetchedAt: DateTime.now().toUtc(),
        );
        ctx.store.onPurgeStepForTesting = (step) async {
          if (step == 'inside_purge_txn') {
            throw StateError('Controlled rollback');
          }
        };
        expect(await service.revokeAccount(), isFalse);
        expect(
          await ctx.store.rawDb.query('account_trip_snapshots'),
          hasLength(1),
        );
        ctx.store.onPurgeStepForTesting = null;
        expect(await service.revokeAccount(), isTrue);
        expect(await ctx.store.rawDb.query('account_trip_snapshots'), isEmpty);
      } finally {
        await service.close();
      }
    });
  });

  test(
    'L07 blocked SQL namespace prevents seal while Guest remains available',
    () async {
      await fixtures.runWithStore((ctx) async {
        final session = sessionFor(ownerA);
        final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
        final service = LocalAccountLifecycleService(
          storeLoader: () async => ctx.store,
          sessionReader: () => session,
          registryPath: path,
        );
        try {
          expect(
            await service.establishAccount(freshAuthentication: true),
            isNotNull,
          );
          ctx.store.onPurgeStepForTesting = (step) async {
            if (step == 'before_marker_txn') throw StateError('Marker failure');
          };
          await expectLater(
            ctx.store.purgeAccountData(targetOwnerId: ownerA, reason: 'test'),
            throwsA(isA<CleanupMarkerPersistenceException>()),
          );
          expect(await service.sealForPause(), isFalse);
          expect(
            jsonDecode(await File(path).readAsString())['state'],
            'active',
          );
          await ctx.store.saveDraftRevision(
            draftId: 'Guest',
            payload: fixtures.createValidPayload(),
          );
          expect(await ctx.store.listGuestDrafts(), hasLength(1));
        } finally {
          await service.close();
        }
      });
    },
  );

  test(
    'L04 consumer cannot bind before active file replacement finishes',
    () async {
      await fixtures.runWithStore((ctx) async {
        final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
        final session = sessionFor(ownerA);
        final entered = Completer<void>();
        final release = Completer<void>();
        final bound = <SessionHandle>[];
        final service = LocalAccountLifecycleService(
          storeLoader: () async => ctx.store,
          sessionReader: () => session,
          registryPath: path,
          registryFile: LifecycleRegistryFile(
            path,
            onStep: (step) async {
              if (step == 'replace' && !entered.isCompleted) {
                entered.complete();
                await release.future;
              }
            },
          ),
        );
        service.registerConsumer(
          invalidate: bound.clear,
          bind: (handle) async {
            bound.add(handle);
          },
        );
        try {
          final activation = service.establishAccount(
            freshAuthentication: true,
          );
          await entered.future;
          expect(service.handle, isNull);
          expect(bound, isEmpty);
          release.complete();
          expect(await activation, isNotNull);
          expect(bound, hasLength(1));
          final proof = service.captureProof();
          final foreign = LocalAccountLifecycleService(
            storeLoader: () async => ctx.store,
            sessionReader: () => session,
            registryPath: path,
          );
          try {
            expect(foreign.isCurrentProof(proof), isFalse);
          } finally {
            await foreign.close();
          }
        } finally {
          if (!release.isCompleted) release.complete();
          await service.close();
        }
      });
    },
  );

  for (final mutation in [
    'missing',
    'partial',
    'version',
    'extra',
    'epoch',
    'fingerprint',
    'owner',
    'expiry',
    'active',
    'revoking',
    'signedOut',
    'time',
  ]) {
    test(
      'L02 unsafe registry $mutation denies restart and preserves Guest',
      () async {
        await fixtures.runWithStore((ctx) async {
          final session = sessionFor(ownerA);
          final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
          final first = LocalAccountLifecycleService(
            storeLoader: () async => ctx.store,
            sessionReader: () => session,
            registryPath: path,
          );
          try {
            final handle = (await first.establishAccount(
              freshAuthentication: true,
            ))!;
            await ctx.store.replaceSnapshot(
              handle: handle,
              tripId: 'remote-A',
              payload: fixtures.createValidPayload(),
              fetchedAt: DateTime.now().toUtc(),
            );
            await ctx.store.saveDraftRevision(
              draftId: 'Guest',
              payload: fixtures.createValidPayload(),
            );
            expect(await first.sealForPause(), isTrue);
          } finally {
            await first.close();
          }
          final file = File(path);
          final map =
              jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          switch (mutation) {
            case 'missing':
              await file.delete();
            case 'partial':
              await file.writeAsString('{"state":');
            default:
              switch (mutation) {
                case 'version':
                  map['schemaVersion'] = 2;
                case 'extra':
                  map['accessToken'] = 'forbidden';
                case 'epoch':
                  map['epoch'] = 1.0;
                case 'fingerprint':
                  map['sessionFingerprint'] = '0' * 64;
                case 'owner':
                  map['ownerId'] = ownerB;
                case 'expiry':
                  map['expiresAt'] = (session.expiresAt ?? 0) + 1;
                case 'time':
                  map['updatedAt'] = 'not-a-dateZ';
                default:
                  map['state'] = mutation;
              }
              await file.writeAsString(jsonEncode(map));
          }
          final second = LocalAccountLifecycleService(
            storeLoader: () async => ctx.store,
            sessionReader: () => session,
            registryPath: path,
          );
          try {
            expect(await second.resumeAccount(), isNull);
            expect(second.handle, isNull);
            expect(
              await ctx.store.rawDb.query('account_trip_snapshots'),
              isEmpty,
            );
            expect(await ctx.store.listGuestDrafts(), hasLength(1));
            expect(
              await second.establishAccount(freshAuthentication: true),
              isNotNull,
            );
          } finally {
            await second.close();
          }
        });
      },
    );
  }

  for (final stage in ['write', 'flush', 'replace']) {
    test(
      'L04 real file $stage fault preserves previous bytes and denies binding',
      () async {
        await fixtures.runWithStore((ctx) async {
          final session = sessionFor(ownerA);
          final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
          final file = File(path);
          await file.writeAsString('prior-record');
          final service = LocalAccountLifecycleService(
            storeLoader: () async => ctx.store,
            sessionReader: () => session,
            registryPath: path,
            registryFile: LifecycleRegistryFile(
              path,
              onStep: (step) async {
                if (stage == step) {
                  throw FileSystemException('Controlled IO fault');
                }
              },
            ),
          );
          try {
            expect(
              await service.establishAccount(freshAuthentication: true),
              isNull,
            );
            expect(service.handle, isNull);
            expect(await file.readAsString(), 'prior-record');
            expect(
              ctx.tempDir.listSync().whereType<File>().where(
                (f) => f.path.endsWith('.tmp'),
              ),
              isEmpty,
            );
          } finally {
            await service.close();
          }
        });
      },
    );
  }

  for (final stage in ['write', 'flush', 'replace', 'after_replace']) {
    for (final interrupt in ['logout', 'expiry', 'switch']) {
      test(
        'L05 $interrupt during seal $stage cannot leave a valid stale seal',
        () async {
          await fixtures.runWithStore((ctx) async {
            Session? session = sessionFor(ownerA);
            final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
            final entered = Completer<void>();
            final release = Completer<void>();
            var sealing = false;
            var waited = false;
            final service = LocalAccountLifecycleService(
              storeLoader: () async => ctx.store,
              sessionReader: () => session,
              registryPath: path,
              registryFile: LifecycleRegistryFile(
                path,
                onStep: (step) async {
                  if (sealing && !waited && step == stage) {
                    waited = true;
                    entered.complete();
                    await release.future;
                  }
                },
              ),
            );
            try {
              expect(
                await service.establishAccount(freshAuthentication: true),
                isNotNull,
              );
              sealing = true;
              final pause = service.sealForPause();
              await entered.future;
              Future<bool>? revoke;
              if (interrupt == 'logout') revoke = service.revokeAccount();
              if (interrupt == 'expiry') session.expiresAt = 1;
              if (interrupt == 'switch') session = sessionFor(ownerB);
              release.complete();
              expect(await pause, isFalse);
              if (revoke != null) expect(await revoke, isTrue);
              expect(service.handle, isNull);
              expect(
                jsonDecode(await File(path).readAsString())['state'],
                isNot('sealed'),
              );
              expect(await service.resumeAccount(), isNull);
            } finally {
              if (!release.isCompleted) release.complete();
              await service.close();
            }
          });
        },
      );
    }
  }

  test(
    'L03 failed SQLite marker + process restart cannot restore old account',
    () async {
      await fixtures.runWithStore((ctx) async {
        final session = sessionFor(ownerA);
        final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
        final service = LocalAccountLifecycleService(
          storeLoader: () async => ctx.store,
          sessionReader: () => session,
          registryPath: path,
        );
        final handle = (await service.establishAccount(
          freshAuthentication: true,
        ))!;
        await ctx.store.replaceSnapshot(
          handle: handle,
          tripId: 'A',
          payload: fixtures.createValidPayload(),
          fetchedAt: DateTime.now().toUtc(),
        );
        ctx.store.onPurgeStepForTesting = (step) async {
          if (step == 'before_marker_txn') {
            throw StateError('Controlled SQL failure');
          }
        };
        try {
          expect(await service.revokeAccount(), isFalse);
          expect(
            await ctx.store.checkAccountCleanupComplete(ownerId: ownerA),
            isFalse,
          );
          expect(
            await ctx.store.rawDb.query('account_trip_snapshots'),
            hasLength(1),
          );
        } finally {
          await service.close();
          await ctx.store.close();
        }
        ctx.store = LocalTripStore(
          databaseFactory: databaseFactoryFfi,
          databasePath: ctx.dbPath,
        );
        await ctx.store.open();
        final restarted = LocalAccountLifecycleService(
          storeLoader: () async => ctx.store,
          sessionReader: () => session,
          registryPath: path,
        );
        try {
          expect(await restarted.resumeAccount(), isNull);
          expect(
            await ctx.store.rawDb.query('account_trip_snapshots'),
            isEmpty,
          );
        } finally {
          await restarted.close();
        }
      });
    },
  );

  test(
    'L06 A activation held, B then C: only C binds and old proof is fenced',
    () async {
      await fixtures.runWithStore((ctx) async {
        Session? session = sessionFor(ownerA);
        final service = LocalAccountLifecycleService(
          storeLoader: () async => ctx.store,
          sessionReader: () => session,
          registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
        );
        final entered = Completer<void>();
        final release = Completer<void>();
        var held = false;
        ctx.store.onActivationStepForTesting = (step) async {
          if (!held && step == 'after_marker_read') {
            held = true;
            entered.complete();
            await release.future;
          }
        };
        final bound = <String>[];
        var invalidations = 0;
        service.registerConsumer(
          invalidate: () {
            invalidations++;
          },
          bind: (handle) async {
            bound.add(handle.ownerId);
          },
        );
        try {
          final a = service.establishAccount(freshAuthentication: true);
          await entered.future;
          session = sessionFor(ownerB);
          final b = service.establishAccount(freshAuthentication: true);
          session = sessionFor(ownerC);
          final c = service.establishAccount(freshAuthentication: true);
          release.complete();
          expect(await a, isNull);
          expect(await b, isNull);
          expect((await c)?.ownerId, ownerC);
          expect(bound, [ownerC]);
          expect(invalidations, greaterThanOrEqualTo(3));
          final proof = service.captureProof();
          expect(proof.toString(), isNot(contains(proof.accessToken)));
          session = sessionFor(ownerA);
          expect(service.isCurrentProof(proof), isFalse);
          expect(service.handle, isNull);
        } finally {
          if (!release.isCompleted) release.complete();
          await service.close();
        }
      });
    },
  );

  test('L07 unresolved import/cache prevents seal; SDK mutation bracket also prevents it', () async {
    await fixtures.runWithStore((ctx) async {
      final session = sessionFor(ownerA);
      final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
      final service = LocalAccountLifecycleService(
        storeLoader: () async => ctx.store,
        sessionReader: () => session,
        registryPath: path,
      );
      try {
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNotNull,
        );
        final done = service.beginAccountOperation(service.captureProof());
        expect(await service.sealForPause(), isFalse);
        done();
        done();
        expect(jsonDecode(await File(path).readAsString())['state'], 'active');
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNotNull,
        );
        await service.prepareAuthenticationMutation();
        expect(await service.sealForPause(), isFalse);
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNull,
        );
        service.completeAuthenticationMutation();
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNotNull,
        );
      } finally {
        await service.close();
      }
    });
  });

  test('L08 cleanup consumes committed records, quarantines pending, retains Guest counter', () async {
    await fixtures.runWithStore((ctx) async {
      final session = sessionFor(ownerA);
      final service = LocalAccountLifecycleService(
        storeLoader: () async => ctx.store,
        sessionReader: () => session,
        registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
      );
      try {
        final handle = (await service.establishAccount(
          freshAuthentication: true,
        ))!;
        final payload = fixtures.createValidPayload();
        final source = await ctx.store.saveDraftRevision(
          draftId: 'committed',
          payload: payload,
        );
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'committed',
          sourceRevision: 1,
          requestKey: 'key1',
        );
        await ctx.store.commitImportAck(
          handle: handle,
          receipt: fixtures.createValidReceipt(
            targetOwner: ownerA,
            draftId: 'committed',
            requestKey: 'key1',
            contentDigest: source.digest,
          ),
          payload: payload,
        );
        await ctx.store.saveDraftRevision(draftId: 'pending', payload: payload);
        await ctx.store.prepareImportJournal(
          handle: handle,
          draftId: 'pending',
          sourceRevision: 1,
          requestKey: 'key2',
        );
        await ctx.store.markJournalPendingAck(
          handle: handle,
          draftId: 'pending',
          sourceRevision: 1,
        );
        expect(await service.revokeAccount(), isTrue);
        expect(await ctx.store.rawDb.query('account_trip_snapshots'), isEmpty);
        final journals = await ctx.store.rawDb.query('local_import_journal');
        expect(journals, hasLength(1));
        expect(journals.single['state'], 'quarantined');
        expect(journals.single['receipt_payload'], isNull);
        expect((await ctx.store.listGuestDrafts()).single.draftId, 'pending');
        final next = await ctx.store.saveDraftRevision(
          draftId: 'committed',
          payload: payload,
        );
        expect(next.revision, 2);
      } finally {
        await service.close();
      }
    });
  });

  test('Neutral store reads require readiness, unbound state and include markers/journals', () async {
    await fixtures.runWithStore((ctx) async {
      final handle = await ctx.store.activateSession(
        ownerId: ownerA,
        coordinatorEpoch: 1,
      );
      await expectLater(
        ctx.store.listAccountOwnersForCleanup(),
        throwsA(isA<StaleSessionEpochException>()),
      );
      await expectLater(
        ctx.store.checkAccountCleanupComplete(ownerId: ownerA),
        throwsA(isA<StaleSessionEpochException>()),
      );
      await ctx.store.replaceSnapshot(
        handle: handle,
        tripId: 'A',
        payload: fixtures.createValidPayload(),
        fetchedAt: DateTime.now().toUtc(),
      );
      ctx.store.unbindSession();
      expect(await ctx.store.listAccountOwnersForCleanup(), [ownerA]);
      await ctx.store.rawDb.insert('local_cleanup_state', {
        'namespace': 'account:$ownerB',
        'is_blocked': 1,
        'purge_pending': 1,
        'reason': 'test',
        'created_at': '2026-10-13T00:00:00Z',
        'updated_at': '2026-10-13T00:00:00Z',
      });
      expect(await ctx.store.listAccountOwnersForCleanup(), [ownerA, ownerB]);
      expect(
        await ctx.store.checkAccountCleanupComplete(ownerId: ownerB),
        isFalse,
      );
      await ctx.store.close();
      await expectLater(
        ctx.store.listAccountOwnersForCleanup(),
        throwsA(isA<StoreUnavailableException>()),
      );
    });
  });
}

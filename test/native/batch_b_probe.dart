// Standalone Android probe: flutter build apk --debug -t test/native/batch_b_probe.dart.
// Uses an isolated app-private database and synthetic session. No server calls.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

const _ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _kind = 'B9_NATIVE_V1';

void _require(bool valid, String reason) {
  if (!valid) throw StateError(reason);
}

Session _session(String owner, int expiry) => Session.fromJson({
  'access_token': 'b9-synthetic-$owner',
  'refresh_token': 'b9-synthetic-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': owner,
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
    'aud': 'authenticated',
    'created_at': '2026-10-13T00:00:00Z',
  },
})!..expiresAt = expiry;

CanonicalTripPayloadV1 _payload() => CanonicalTripPayloadV1(
  metadata: TripMetadataV1(title: 'B9 synthetic draft', destinationName: 'Huế'),
  request: PlanTripRequest(
    origin: 'TP. Hồ Chí Minh',
    numDays: 2,
    numPeople: 1,
    budgetVnd: 2000000,
    preferences: ['văn hóa'],
    priority: 'balanced',
  ),
);

Future<String> _runProbe() async {
  final root = p.normalize(await getDatabasesPath());
  final directory = Directory(p.join(root, 'b9_native_probe_v1'));
  _require(p.isWithin(root, directory.path), 'Unowned probe directory');
  final marker = File(p.join(directory.path, 'owned_probe.json'));
  Map<String, dynamic> state;
  if (await marker.exists()) {
    state = jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
    _require(
      state['kind'] == _kind && state['schemaVersion'] == 1,
      'Unknown probe marker',
    );
  } else {
    _require(!await directory.exists(), 'Existing unowned directory');
    await directory.create();
    state = {
      'kind': _kind,
      'schemaVersion': 1,
      'stage': 0,
      'expiry': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    };
    await marker.writeAsString(jsonEncode(state), flush: true);
  }
  final stage = state['stage'];
  final expiry = state['expiry'];
  _require(stage is int && expiry is int, 'Malformed probe state');
  final store = LocalTripStore(
    databasePath: p.join(directory.path, 'probe.db'),
  );
  Session session = _session(_ownerA, expiry as int);
  final registryPath = p.join(directory.path, 'registry.json');
  final lifecycle = LocalAccountLifecycleService(
    storeLoader: () async => store,
    sessionReader: () => session,
    registryPath: registryPath,
  );
  try {
    await store.open();
    if (stage == 0) {
      await store.saveDraftRevision(
        draftId: 'native-guest',
        payload: _payload(),
      );
      final handle = await lifecycle.establishAccount(
        freshAuthentication: true,
      );
      _require(handle != null, 'Cannot establish synthetic A');
      await store.replaceSnapshot(
        handle: handle!,
        tripId: 'native-owned',
        payload: _payload(),
        fetchedAt: DateTime.now().toUtc(),
      );
      _require(await lifecycle.sealForPause(), 'Cannot seal native registry');
      state['stage'] = 1;
      await marker.writeAsString(jsonEncode(state), flush: true);
      return 'B9_NATIVE_STAGE1_PASS';
    }
    if (stage == 1) {
      final handle = await lifecycle.resumeAccount();
      _require(handle != null, 'Safe sealed restart denied');
      _require(
        (await store.listSnapshots(handle: handle!)).length == 1,
        'Snapshot lost on restart',
      );
      final guest = await store.getDraftRevision(
        draftId: 'native-guest',
        revision: 1,
      );
      _require(
        guest?.cachedPayload.request?.budgetVnd == 2000000,
        'Guest payload lost on restart',
      );
      store.onPurgeStepForTesting = (step) async {
        if (step == 'before_marker_txn') {
          throw StateError('Synthetic marker fault');
        }
      };
      _require(
        !await lifecycle.revokeAccount(),
        'Purge fault falsely reported success',
      );
      _require(lifecycle.handle == null, 'Fault exposed account handle');
      state['stage'] = 2;
      await marker.writeAsString(jsonEncode(state), flush: true);
      return 'B9_NATIVE_STAGE2_PASS';
    }
    _require(stage == 2, 'Unexpected native probe stage');
    _require(
      await lifecycle.resumeAccount() == null,
      'Unsafe restart restored A',
    );
    _require(
      (await store.rawDb.query('account_trip_snapshots')).isEmpty,
      'Startup did not purge A',
    );
    _require(
      (await store.listGuestDrafts()).length == 1,
      'Startup deleted Guest',
    );
    session = _session(_ownerB, expiry);
    final handleB = await lifecycle.establishAccount(freshAuthentication: true);
    _require(handleB != null, 'Synthetic B blocked after cleanup');
    _require(
      (await store.listSnapshots(handle: handleB!)).isEmpty,
      'B exposed A',
    );
    _require(await lifecycle.revokeAccount(), 'Final cleanup failed');
  } finally {
    await lifecycle.close();
    await store.close();
  }
  // Remove only this probe's named files after the database is closed.
  for (final name in [
    'probe.db',
    'probe.db-wal',
    'probe.db-shm',
    'probe.db-journal',
    'registry.json',
    'owned_probe.json',
  ]) {
    final file = File(p.join(directory.path, name));
    if (await file.exists()) await file.delete();
  }
  _require(
    (await directory.list().toList()).isEmpty,
    'Unexpected probe files; refuse recursive cleanup',
  );
  await directory.delete();
  return 'B9_NATIVE_STAGE3_AND_OWNED_CLEANUP_PASS';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('B9 native persistence probe'))),
    ),
  );
  try {
    final result = await _runProbe();
    debugPrint(result);
  } catch (error) {
    // Fixture-only status; never print credentials or payloads.
    debugPrint('B9_NATIVE_FAIL ${error.runtimeType}');
  }
}

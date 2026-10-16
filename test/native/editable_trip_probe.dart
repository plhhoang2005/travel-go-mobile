// Standalone Android target, synthetic owned directory only. No server calls.
// Build separately with -t test/native/editable_trip_probe.dart; launch twice.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

const _ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _trip = '00000000-0000-4000-8000-000000000801';
const _draft = '00000000-0000-4000-8000-000000000802';
const _day = '00000000-0000-4000-8000-000000000803';
const _item = '00000000-0000-4000-8000-000000000804';
EditableTripDocumentV2 probeDocument() {
  final provenance = FieldProvenance(
    quality: 'user_provided',
    sourceRefs: [],
    observedAt: null,
  );
  return EditableTripDocumentV2(
    input: TripInput(
      title: 'Synthetic native P3.2',
      destinationId: 'hue',
      destinationName: 'Huế',
      startDate: '2026-10-16',
      endDate: '2026-10-16',
      timezone: 'Asia/Ho_Chi_Minh',
      origin: 'Hà Nội',
      travelerCount: 1,
      totalBudgetVnd: 500000,
      interests: [],
      priority: 'balanced',
    ),
    days: [TripDay(id: _day, ordinal: 1, date: '2026-10-16', notes: '')],
    items: [
      TripItem(
        id: _item,
        dayId: _day,
        position: 0,
        title: 'Synthetic visit',
        placeId: null,
        startMinute: 540,
        endMinute: 600,
        notes: '',
        provenance: provenance,
      ),
    ],
    actualExpenses: [
      ActualExpense(
        id: '00000000-0000-4000-8000-000000000805',
        itemId: _item,
        amountVnd: 20000,
        category: 'food',
        paidOn: '2026-10-16',
        description: 'Synthetic actual',
        sourceItemSnapshot: ItemSnapshot(
          title: 'Synthetic visit',
          dayId: _day,
          date: '2026-10-16',
        ),
        provenance: provenance,
      ),
    ],
    source: SourceReference(kind: 'new', sourceId: null, sourceDigest: null),
  );
}

Session _session(String owner, int expiry) => Session.fromJson({
  'access_token': 'p32-native-synthetic',
  'refresh_token': 'p32-native-synthetic-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': owner,
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
    'aud': 'authenticated',
    'created_at': '2026-10-16T00:00:00Z',
  },
})!..expiresAt = expiry;
void _require(bool value, String message) {
  if (!value) {
    throw StateError(message);
  }
}

Future<String> runEditableNativeProbe() async {
  final root = p.normalize(await getDatabasesPath());
  final directory = Directory(p.join(root, 'p32_owned_native_v2'));
  _require(p.isWithin(root, directory.path), 'Invalid owned directory');
  final marker = File(p.join(directory.path, 'marker.json'));
  Map<String, Object?> state;
  if (await marker.exists()) {
    state = Map<String, Object?>.from(
      jsonDecode(await marker.readAsString()) as Map,
    );
    _require(
      state['kind'] == 'P32_NATIVE_V2' && state['stage'] is int,
      'Unknown marker',
    );
  } else {
    _require(!await directory.exists(), 'Unowned directory exists');
    await directory.create();
    state = {
      'kind': 'P32_NATIVE_V2',
      'stage': 0,
      'expiry': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    };
    await marker.writeAsString(jsonEncode(state), flush: true);
  }
  if (state['stage'] == 2) {
    return 'P32_NATIVE_ALREADY_DONE';
  }
  final expiry = state['expiry'];
  _require(expiry is int, 'Invalid expiry');
  var session = _session(_ownerA, expiry as int);
  final store = LocalTripStore(
    databasePath: p.join(directory.path, 'probe.db'),
  );
  final lifecycle = LocalAccountLifecycleService(
    storeLoader: () async => store,
    sessionReader: () => session,
    registryPath: p.join(directory.path, 'registry.json'),
  );
  try {
    await store.open();
    if (state['stage'] == 0) {
      var guest = await store.readEditableDraft(
        deviceScope: 'probe',
        draftId: _draft,
      );
      guest ??= await store.saveEditableDraft(
        deviceScope: 'probe',
        draftId: _draft,
        expectedRevision: null,
        document: probeDocument(),
      );
      _require(
        guest.contentDigest == EditableTripCodec.digest(probeDocument()),
        'Guest changed',
      );
      final handle = await lifecycle.establishAccount(
        freshAuthentication: true,
      );
      _require(handle != null, 'Cannot bind A');
      final doc = probeDocument(),
          text = EditableTripCodec.encode(probeDocument());
      await store.putEditableSnapshot(
        handle: handle!,
        head: EditableHead(
          tripId: _trip,
          ownerId: _ownerA,
          version: 1,
          payloadText: text,
          contentDigest: EditableTripCodec.digestText(text),
          fetchedAt: DateTime.now().toUtc(),
          document: doc,
        ),
      );
      _require(await lifecycle.sealForPause(), 'Cannot seal A');
      state['stage'] = 1;
      await marker.writeAsString(jsonEncode(state), flush: true);
      return 'P32_NATIVE_STAGE1_PASS_RELAUNCH_REQUIRED';
    }
    _require(state['stage'] == 1, 'Unexpected stage');
    final handle = await lifecycle.resumeAccount();
    _require(handle != null, 'Sealed restart denied');
    final cached = await store.readEditableSnapshot(
      handle: handle!,
      tripId: _trip,
    );
    _require(
      cached?.head.document.actualExpenses.single.amountVnd == 20000,
      'Actual lost on restart',
    );
    _require(await lifecycle.revokeAccount(), 'A purge failed');
    session = _session(_ownerB, expiry);
    final b = await lifecycle.establishAccount(freshAuthentication: true);
    _require(b != null, 'Cannot bind B');
    _require(
      (await store.listEditableSnapshots(handle: b!)).isEmpty,
      'B exposed A',
    );
    _require(
      (await store.listEditableAttempts(handle: b)).isEmpty,
      'B exposed A outbox',
    );
    _require(
      (await store.listEditableDrafts(deviceScope: 'probe')).length == 1,
      'Guest lost',
    );
    _require(await lifecycle.revokeAccount(), 'B cleanup failed');
    state['stage'] = 2;
    await marker.writeAsString(jsonEncode(state), flush: true);
    return 'P32_NATIVE_STAGE2_PASS';
  } finally {
    await lifecycle.close();
    await store.close();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('P3.2 synthetic native persistence probe')),
      ),
    ),
  );
  String status;
  try {
    status = await runEditableNativeProbe();
  } catch (error) {
    status = 'P32_NATIVE_FAIL: ${error.runtimeType}';
  }
  debugPrint(status);
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(child: Center(child: SelectableText(status))),
      ),
    ),
  );
}

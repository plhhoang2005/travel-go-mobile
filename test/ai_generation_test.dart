// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:travelgo_mobile/features/trip_planner/services/ai_generation_service.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/services/editable_trip_mutator.dart';

import 'editable_local_store_test.dart' as records;

Map<String, Object?> proposalJson() => {
  'contract': 'travelgo.itinerary.v1',
  'destinationId': 'hue',
  'numDays': 1,
  'summary': 'Lịch tham khảo',
  'model': 'gemini-3.5-flash-lite',
  'verification': 'unverified',
  'activities': [
    {
      'day': 1,
      'title': 'Khám phá văn hóa',
      'startMinute': null,
      'endMinute': null,
      'costVnd': null,
      'category': 'attractions',
    },
  ],
  'warnings': <String>[],
};
void main() {
  test('ai_repeat_untimed_proposal_cannot_double_budget', () {
    final base = records.doc();
    final context = AiGenerationContext.fromDocument(base);
    final raw = {
      'contract': 'travelgo.itinerary.v1',
      'destinationId': 'hue',
      'numDays': 1,
      'summary': 'Đề xuất tham khảo',
      'model': 'gemini-3.5-flash-lite',
      'verification': 'unverified',
      'activities': [
        {
          'day': 1,
          'title': 'Hoạt động trải nghiệm',
          'startMinute': null,
          'endMinute': null,
          'costVnd': 200000,
          'category': 'attractions',
        },
      ],
      'warnings': <String>[],
    };
    final proposal = AiItineraryProposal.fromJson(raw, context);

    final firstPrepared = prepareAiProposal(base, proposal, nextAiId);
    expect(firstPrepared.canApply, isTrue);
    final afterFirst = EditableTripMutator.apply(base, firstPrepared.commands);
    expect(afterFirst.items.length, base.items.length + 1);

    final secondPrepared = prepareAiProposal(afterFirst, proposal, nextAiId);
    expect(secondPrepared.canApply, isFalse);
    expect(
      secondPrepared.issues.any((i) => i.code == 'ai_duplicate_activity'),
      isTrue,
    );
  });

  test('ai_duplicate_key_is_scoped_to_day_and_time', () {
    final base = records.doc();
    final context = AiGenerationContext.fromDocument(base);

    final rawDupInternal = {
      'contract': 'travelgo.itinerary.v1',
      'destinationId': 'hue',
      'numDays': 1,
      'summary': 'Đề xuất',
      'model': 'gemini-3.5-flash-lite',
      'verification': 'unverified',
      'activities': [
        {
          'day': 1,
          'title': 'THAM   QUAN   ĐẠI   NỘI',
          'startMinute': null,
          'endMinute': null,
          'costVnd': 100000,
          'category': 'attractions',
        },
        {
          'day': 1,
          'title': 'tham quan đại nội',
          'startMinute': null,
          'endMinute': null,
          'costVnd': 100000,
          'category': 'attractions',
        },
      ],
      'warnings': <String>[],
    };
    final propDup = AiItineraryProposal.fromJson(rawDupInternal, context);
    final prepDup = prepareAiProposal(base, propDup, nextAiId);
    expect(prepDup.canApply, isFalse);
    expect(
      prepDup.issues.any((i) => i.code == 'ai_duplicate_activity'),
      isTrue,
    );

    final rawDiffTime = {
      'contract': 'travelgo.itinerary.v1',
      'destinationId': 'hue',
      'numDays': 1,
      'summary': 'Đề xuất',
      'model': 'gemini-3.5-flash-lite',
      'verification': 'unverified',
      'activities': [
        {
          'day': 1,
          'title': 'Tham quan Đại Nội',
          'startMinute': 540,
          'endMinute': 600,
          'costVnd': 100000,
          'category': 'attractions',
        },
        {
          'day': 1,
          'title': 'Tham quan Đại Nội',
          'startMinute': 840,
          'endMinute': 900,
          'costVnd': 100000,
          'category': 'attractions',
        },
      ],
      'warnings': <String>[],
    };
    final propDiffTime = AiItineraryProposal.fromJson(rawDiffTime, context);
    final prepDiffTime = prepareAiProposal(base, propDiffTime, nextAiId);
    expect(
      prepDiffTime.issues.any((i) => i.code == 'ai_duplicate_activity'),
      isFalse,
    );
  });

  testWidgets(
    'blocked_duplicate_has_explanation_and_cancel',
    (tester) async {
      final base = records.doc();
      final planner = aiPlanner()..openNew(base);
      final auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);

      final raw = {
        'contract': 'travelgo.itinerary.v1',
        'destinationId': 'hue',
        'numDays': 1,
        'summary': 'Trùng lặp',
        'model': 'gemini-3.5-flash-lite',
        'verification': 'unverified',
        'activities': [
          {
            'day': 1,
            'title': 'Hoạt động A',
            'startMinute': null,
            'endMinute': null,
            'costVnd': 100000,
            'category': 'attractions',
          },
          {
            'day': 1,
            'title': 'Hoạt động A',
            'startMinute': null,
            'endMinute': null,
            'costVnd': 100000,
            'category': 'attractions',
          },
        ],
        'warnings': <String>[],
      };
      final proposal = AiItineraryProposal.fromJson(
        raw,
        AiGenerationContext.fromDocument(base),
      );

      await tester.pumpWidget(
        aiApp(
          planner,
          auth,
          (doc, id) async => prepareAiProposal(doc, proposal, nextAiId),
        ),
      );
      await tester.tap(find.text('Trợ giúp AI'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('ai-consent')));
      await tester.tap(find.byKey(const ValueKey('ai-consent')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('ai-generate')));
      await tester.tap(find.byKey(const ValueKey('ai-generate')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('ai-apply')))
            .onPressed,
        isNull,
      );
      expect(
        find.textContaining('Đề xuất có hoạt động trùng'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('ai-cancel')));
      await tester.pumpAndSettle();
      expect(planner.document?.items.length, base.items.length);
    },
  );
  testWidgets(
    'large Vietnamese text keeps AI confirmation and Cancel reachable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final planner = aiPlanner(), auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        aiApp(
          planner,
          auth,
          (document, id) async => preparedFor(document),
          large: true,
        ),
      );
      await tester.tap(find.text('Trợ giúp AI'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('ai-consent')));
      await tester.tap(find.byKey(const ValueKey('ai-consent')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('ai-generate')));
      await tester.tap(find.byKey(const ValueKey('ai-generate')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ai-apply')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ai-cancel')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('ai-cancel')));
      await tester.pumpAndSettle();
    },
  );
  test('HTTP binds request/owner before and after credential wait; malformed binding never succeeds', () async {
    const requestId = 'a1111111-1111-4111-8111-111111111111';
    final c = AiGenerationContext.fromDocument(records.doc());
    final adapter = AiAdapter(
      (_) async => ResponseBody.fromString(
        jsonEncode({
          'status': 'succeeded',
          'requestId': requestId,
          'acceptedDay': '2026-10-19',
          'remaining': 2,
          'result': proposalJson(),
        }),
        200,
      ),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final gateway = AiGatewayClient(
      dio: dio,
      endpoint: Uri.parse('https://fixture.invalid/itinerary-proposal'),
      publicKey: 'fixture-public',
    );
    addTearDown(() => dio.close(force: true));
    final valid = await gateway.generate(
      c,
      requestId,
      credential: () async => 'fixture-only',
      isCurrent: () => true,
    );
    expect(valid.activities, hasLength(1));
    final wire = jsonDecode(adapter.calls.single.data as String) as Map;
    expect(wire['consent'], true);
    expect(wire.containsKey('title'), false);
    expect(wire['requestId'], requestId);
    var current = true;
    final held = Completer<String>();
    final pending = gateway.generate(
      c,
      requestId,
      credential: () => held.future,
      isCurrent: () => current,
    );
    current = false;
    held.complete('fixture-only');
    await expectLater(
      pending,
      throwsA(
        isA<AiGenerationFailure>().having((e) => e.code, 'reason', 'stale'),
      ),
    );
    expect(adapter.calls, hasLength(1));
    await expectLater(
      gateway.generate(
        c,
        'b2222222-2222-4222-8222-222222222222',
        credential: () async => 'fixture-only',
        isCurrent: () => true,
      ),
      throwsA(
        isA<AiGenerationFailure>().having(
          (e) => e.code,
          'reason',
          'invalid_result',
        ),
      ),
    );
  });
  test('lost HTTP outcome retries the identical request; endpoint absence/large response fail safely', () async {
    const id = 'a1111111-1111-4111-8111-111111111111';
    final adapter = AiAdapter(
      (request) async => ResponseBody.fromString(
        jsonEncode({'status': 'outcome_pending', 'requestId': id}),
        503,
      ),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final gateway = AiGatewayClient(
      dio: dio,
      endpoint: Uri.parse('https://fixture.invalid/itinerary-proposal'),
      publicKey: 'fixture-public',
    );
    addTearDown(() => dio.close(force: true));
    final c = AiGenerationContext.fromDocument(records.doc());
    for (var i = 0; i < 2; i++) {
      await expectLater(
        gateway.generate(
          c,
          id,
          credential: () async => 'fixture-only',
          isCurrent: () => true,
        ),
        throwsA(
          isA<AiGenerationFailure>().having(
            (e) => e.retrySameRequest,
            'same request',
            true,
          ),
        ),
      );
    }
    expect(adapter.calls[0].data, adapter.calls[1].data);
    adapter.reply = (_) async => ResponseBody.fromString('', 404);
    await expectLater(
      gateway.generate(
        c,
        id,
        credential: () async => 'fixture-only',
        isCurrent: () => true,
      ),
      throwsA(
        isA<AiGenerationFailure>().having(
          (e) => e.code,
          'reason',
          'deployment_blocked',
        ),
      ),
    );
    adapter.reply = (_) async => ResponseBody.fromString('x' * 32769, 200);
    await expectLater(
      gateway.generate(
        c,
        id,
        credential: () async => 'fixture-only',
        isCurrent: () => true,
      ),
      throwsA(
        isA<AiGenerationFailure>().having(
          (e) => e.code,
          'reason',
          'invalid_result',
        ),
      ),
    );
  });
  testWidgets(
    'real planner AI consent -> preview -> confirm appends once and preserves actual; no automatic save',
    (tester) async {
      final planner = aiPlanner(), auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);
      var calls = 0;
      final original = planner.document!;
      await tester.pumpWidget(
        aiApp(planner, auth, (document, id) async {
          calls++;
          return preparedFor(document);
        }),
      );
      await tester.tap(find.text('Trợ giúp AI'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('ai-generate')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('ai-consent')));
      await tester.tap(find.byKey(const ValueKey('ai-consent')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('ai-generate')));
      await tester.tap(find.byKey(const ValueKey('ai-generate')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        EditableTripCodec.encode(planner.document!),
        EditableTripCodec.encode(original),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('ai-apply')));
      await tester.tap(find.byKey(const ValueKey('ai-apply')));
      await tester.pumpAndSettle();
      expect(planner.document!.items.length, original.items.length + 1);
      expect(
        planner.document!.actualExpenses.map((e) => e.toJson()),
        original.actualExpenses.map((e) => e.toJson()),
      );
      expect(planner.hasPendingSave, false);
      expect(planner.dirty, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Cancel during pending AI ignores the late response and keeps the manual editor usable',
    (tester) async {
      final planner = aiPlanner(),
          auth = AuthProvider()..continueAsGuest(),
          held = Completer<AiPreparedProposal>();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);
      final original = EditableTripCodec.encode(planner.document!);
      await tester.pumpWidget(aiApp(planner, auth, (_, _) => held.future));
      await tester.tap(find.text('Trợ giúp AI'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('ai-consent')));
      await tester.tap(find.byKey(const ValueKey('ai-consent')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('ai-generate')));
      await tester.tap(find.byKey(const ValueKey('ai-generate')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('ai-cancel')));
      await tester.tap(find.byKey(const ValueKey('ai-cancel')));
      await tester.pumpAndSettle();
      held.complete(preparedFor(planner.document!));
      await tester.pumpAndSettle();
      expect(EditableTripCodec.encode(planner.document!), original);
      expect(find.byKey(const ValueKey('ai-apply')), findsNothing);
      expect(planner.isEditable, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pending outcome retries one ID; authority change removes preview without applying',
    (tester) async {
      final planner = aiPlanner(),
          auth = AuthProvider(trustedRoleFetcher: (_) async => 'customer')
            ..simulateSupabaseUser(
              sb.User.fromJson({
                'id': 'a1111111-1111-4111-8111-111111111111',
                'email': 'fixture@example.invalid',
                'aud': 'authenticated',
                'role': 'authenticated',
                'created_at': '2026-10-19T00:00:00Z',
                'is_anonymous': false,
                'app_metadata': <String, Object?>{},
                'user_metadata': <String, Object?>{},
              })!,
            );
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);
      final ids = <String>[];
      final held = Completer<AiPreparedProposal>();
      final original = EditableTripCodec.encode(planner.document!);
      await tester.pumpWidget(
        aiApp(planner, auth, (document, id) async {
          ids.add(id);
          if (ids.length == 1) {
            throw const AiGenerationFailure('outcome_pending');
          }
          return held.future;
        }),
      );
      await tester.tap(find.text('Trợ giúp AI'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('ai-consent')));
      await tester.tap(find.byKey(const ValueKey('ai-consent')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('ai-generate')));
      await tester.tap(find.byKey(const ValueKey('ai-generate')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('ai-generate')));
      await tester.tap(find.byKey(const ValueKey('ai-generate')));
      await tester.pump();
      expect(ids, hasLength(2));
      expect(ids[1], ids[0]);
      final epoch = auth.authEpoch;
      auth.continueAsGuest();
      expect(auth.currentUser, isNull);
      expect(
        auth.authEpoch,
        epoch,
        reason: 'standalone legacy transition must also be fenced by subject',
      );
      await tester.pumpAndSettle();
      held.complete(preparedFor(planner.document!));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-apply')), findsNothing);
      expect(EditableTripCodec.encode(planner.document!), original);
      expect(tester.takeException(), isNull);
    },
  );
  test('Guest SDK losing a known identity never signs up a replacement to reset quota', () async {
    var signups = 0;
    final client = guestClient(() => signups++);
    final identity = GuestAiIdentity(
      client: client,
      storage: MemoryAiStorage(),
    );
    addTearDown(client.dispose);
    await identity.access();
    expect(signups, 1);
    await client.auth.signOut(scope: sb.SignOutScope.local);
    await expectLater(identity.access(), throwsA(isA<AiGenerationFailure>()));
    expect(signups, 1);
  });
  test('Guest SDK persistence restores the same anonymous subject without another signup', () async {
    var signups = 0;
    final storage = MemoryAiStorage();
    final first = guestClient(() => signups++);
    addTearDown(first.dispose);
    await GuestAiIdentity(client: first, storage: storage).access();
    final owner = first.auth.currentSession!.user.id;
    final second = guestClient(() => signups++);
    addTearDown(second.dispose);
    await GuestAiIdentity(client: second, storage: storage).access();
    expect(second.auth.currentSession!.user.id, owner);
    expect(signups, 1);
  });
  test('corrupt saved Guest identity fails closed; failed persistence retries the same RAM identity', () async {
    var signups = 0;
    final client = guestClient(() => signups++);
    addTearDown(client.dispose);
    final corrupt = MemoryAiStorage()..value = 'not a session';
    await expectLater(
      GuestAiIdentity(client: client, storage: corrupt).access(),
      throwsA(isA<AiGenerationFailure>()),
    );
    expect(signups, 0);
    final storage = MemoryAiStorage()..failOnce = true;
    final identity = GuestAiIdentity(client: client, storage: storage);
    await expectLater(identity.access(), throwsA(isA<AiGenerationFailure>()));
    await identity.access();
    expect(signups, 1);
  });
  test(
    'minimal AI context excludes trip title, notes, actual and personal origin',
    () {
      final doc = records.doc();
      final c = AiGenerationContext.fromDocument(doc);
      final wire = c.toJson();
      expect(wire.keys.toSet(), {
        'destinationId',
        'originRegion',
        'numDays',
        'numPeople',
        'budgetVnd',
        'interests',
      });
      expect(wire['originRegion'], 'unknown');
      expect(wire.containsKey('actualExpenses'), false);
      expect(wire.containsKey('title'), false);
    },
  );
  test('typed proposal rejects wrong destination/day/time/negative and extra fields', () {
    final c = AiGenerationContext.fromDocument(records.doc());
    for (final extra in [
      {'destinationId': 'ha-noi'},
      {'numDays': 2},
      {'actualExpenses': []},
      {'verification': 'verified'},
    ]) {
      expect(
        () => AiItineraryProposal.fromJson({...proposalJson(), ...extra}, c),
        throwsFormatException,
      );
    }
    for (final fields in [
      {'day': 2},
      {'startMinute': 600, 'endMinute': 500},
      {'costVnd': -1},
      {'costVnd': 1.5},
    ]) {
      final activity = Map<String, Object?>.from(
        (proposalJson()['activities'] as List).single as Map,
      );
      expect(
        () => AiItineraryProposal.fromJson({
          ...proposalJson(),
          'activities': [
            {...activity, ...fields},
          ],
        }, c),
        throwsFormatException,
      );
    }
  });
  test('preparing proposal never mutates original and preserves all actual/input/items', () {
    final before = records.doc();
    final bytes = EditableTripCodec.encode(before);
    final p = AiItineraryProposal.fromJson(
      proposalJson(),
      AiGenerationContext.fromDocument(before),
    );
    var id = 200;
    final prepared = prepareAiProposal(
      before,
      p,
      () => '00000000-0000-4000-8000-${(id++).toString().padLeft(12, '0')}',
    );
    expect(EditableTripCodec.encode(before), bytes);
    expect(
      prepared.document.actualExpenses.map((x) => x.toJson()),
      before.actualExpenses.map((x) => x.toJson()),
    );
    expect(prepared.document.input.toJson(), before.input.toJson());
    expect(prepared.document.items.length, before.items.length + 1);
    expect(prepared.document.estimates.last.unitAmountVnd, isNull);
    expect(prepared.document.estimates.last.provenance.quality, 'unknown');
    expect(prepared.commands.length, 2);
  });
}

class AiAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions) reply;
  final calls = <RequestOptions>[];
  AiAdapter(this.reply);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) {
    calls.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

int aiId = 300;
String nextAiId() =>
    '00000000-0000-4000-8000-${(aiId++).toString().padLeft(12, '0')}';
AiPreparedProposal preparedFor(dynamic document) => prepareAiProposal(
  document,
  AiItineraryProposal.fromJson(
    proposalJson(),
    AiGenerationContext.fromDocument(document),
  ),
  nextAiId,
);
ManualPlannerProvider aiPlanner() => ManualPlannerProvider(
  repositoryLoader: () async =>
      throw StateError('AI must never save automatically'),
  newId: nextAiId,
)..openNew(records.doc());
Widget aiApp(
  ManualPlannerProvider planner,
  AuthProvider auth,
  Future<AiPreparedProposal> Function(dynamic, String) generate, {
  bool large = false,
}) => ChangeNotifierProvider.value(
  value: auth,
  child: MaterialApp(
    builder: large
        ? (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          )
        : null,
    home: ManualPlannerScreen(
      planner: planner,
      destinations: const [],
      enableMapNetworkTiles: false,
      generateAi: generate,
    ),
  ),
);

class MemoryAiStorage extends sb.LocalStorage {
  String? value;
  bool failOnce = false;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => value != null;
  @override
  Future<String?> accessToken() async => value;
  @override
  Future<void> removePersistedSession() async {
    value = null;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    if (failOnce) {
      failOnce = false;
      throw StateError('fixture write failure');
    }
    value = persistSessionString;
  }
}

sb.SupabaseClient guestClient(void Function() signup) => sb.SupabaseClient(
  'https://guest-fixture.invalid',
  'fixture-public',
  authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    final expires = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final encoded = base64Url
        .encode(utf8.encode(jsonEncode({'exp': expires})))
        .replaceAll('=', '');
    final user = {
      'id': 'f1111111-1111-4111-8111-111111111111',
      'aud': 'authenticated',
      'role': 'authenticated',
      'created_at': '2026-10-19T00:00:00Z',
      'is_anonymous': true,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
    };
    Object body = {};
    if (request.url.path.endsWith('/signup')) {
      signup();
      body = {
        'access_token': 'e30.$encoded.fixture',
        'refresh_token': 'fixture-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': expires,
        'user': user,
      };
    } else if (request.url.path.endsWith('/user')) {
      body = user;
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
);

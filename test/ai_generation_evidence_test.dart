// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';
import 'package:travelgo_mobile/features/trip_planner/models/ai_grounded_proposal.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/ai_generation_preview.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/ai_generation_service.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_evidence_codec.dart';

import 'editable_local_store_test.dart' as records;
import 'trip_evidence_repository_test.dart' as evidence;

class MockAiAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions) reply;
  final calls = <RequestOptions>[];
  MockAiAdapter(this.reply);

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

int _aiId = 1;
String nextAiId() =>
    '00000000-0000-4000-8000-${(_aiId++).toString().padLeft(12, '0')}';

PublicCatalogueSnapshot testSnapshot() {
  final text = File('test/fixtures/catalogue_evidence_vectors.json')
      .readAsStringSync();
  final bytes = utf8.encode(text);
  return PublicCatalogueParser.parse(
    payloadText: text,
    manifest: DiscoveryManifest(
      contract: 'travelgo.discovery.manifest.v2',
      schemaVersion: 2,
      version: 7,
      objectKey: 'releases/v2/7.json',
      sha256: sha256.convert(bytes).toString(),
      byteLength: bytes.length,
      publishedAt: DateTime.utc(2026, 10, 27),
    ),
    now: DateTime.utc(2026, 10, 27),
    origin: 'storage',
  );
}

EditableTripDocumentV2 testDoc() {
  final d = records.doc();
  return d.copyWith(
    input: TripInput.fromJson({
      ...d.input.toJson(),
      'destinationId': 'new-city',
      'destinationName': 'New City',
    }),
  );
}

Map<String, Object?> groundedReceiptJson({
  required String baseDigest,
  String destinationId = 'new-city',
}) => {
  'contract': 'travelgo.itinerary.evidence.v1',
  'proposal': {
    'contract': 'travelgo.itinerary.v1',
    'destinationId': destinationId,
    'numDays': 1,
    'summary': 'Lịch trình có căn cứ',
    'model': 'gemini-3.5-flash-lite',
    'verification': 'unverified',
    'activities': [
      {
        'day': 1,
        'title': 'Museum',
        'startMinute': 540,
        'endMinute': 660,
        'costVnd': 200000,
        'category': 'attractions',
      },
    ],
    'warnings': <String>[],
  },
  'catalogueVersion': '7',
  'catalogueDigest': '0000000000000000000000000000000000000000000000000000000000000007',
  'baseDigest': baseDigest,
  'evidence': [
    {
      'id': 'rec-1',
      'origin': 'catalogue',
      'url': 'https://example.org/museum',
      'title': 'Museum official',
      'publisher': 'Museum',
      'factKey': 'new-city/museum:admission',
      'factValue': '200000 VND',
      'retrievedAt': '2026-10-27T01:00:00Z',
      'checkedAt': '2026-10-20T00:00:00Z',
      'publishedAt': null,
      'effectiveFrom': null,
      'effectiveTo': null,
      'reviewed': true,
      'evidenceRequestId': 'a1111111-1111-4111-8111-111111111111',
    },
  ],
  'claims': [
    {
      'id': 'fact_rec-1',
      'kind': 'fact',
      'text': 'new-city/museum:admission: 200000 VND',
      'evidenceIds': ['rec-1'],
    },
  ],
};

void main() {
  test('canGenerateWholeTrip only allows empty document', () {
    final emptyDoc = testDoc();
    expect(emptyDoc.items, isEmpty);
    expect(canGenerateWholeTrip(emptyDoc), isTrue);

    final nonEmptyDoc = emptyDoc.copyWith(
      items: [
        TripItem(
          id: '00000000-0000-4000-8000-000000000010',
          dayId: emptyDoc.days.first.id,
          position: 0,
          title: 'Hoạt động có sẵn',
          placeId: null,
          startMinute: 480,
          endMinute: 540,
          notes: '',
          provenance: FieldProvenance(quality: 'unknown', sourceRefs: [], observedAt: null),
        ),
      ],
    );
    expect(nonEmptyDoc.items, isNotEmpty);
    expect(canGenerateWholeTrip(nonEmptyDoc), isFalse);
  });

  test('whole_trip_generation_rejects_nonempty_document immediately without network', () async {
    final emptyDoc = testDoc();
    final nonEmptyDoc = emptyDoc.copyWith(
      items: [
        TripItem(
          id: '00000000-0000-4000-8000-000000000010',
          dayId: emptyDoc.days.first.id,
          position: 0,
          title: 'Hoạt động có sẵn',
          placeId: null,
          startMinute: 480,
          endMinute: 540,
          notes: '',
          provenance: FieldProvenance(quality: 'unknown', sourceRefs: [], observedAt: null),
        ),
      ],
    );

    final adapter = MockAiAdapter((_) async => throw StateError('Should not be called'));
    final dio = Dio()..httpClientAdapter = adapter;
    final gateway = AiGatewayClient(
      dio: dio,
      endpoint: Uri.parse('https://fixture.invalid/itinerary-proposal'),
      publicKey: 'fixture-key',
    );
    addTearDown(() => dio.close(force: true));

    final auth = AuthProvider()..continueAsGuest();
    addTearDown(auth.dispose);

    await expectLater(
      generateAiWithEvidence(
        auth: auth,
        document: nonEmptyDoc,
        snapshot: testSnapshot(),
        requestId: 'a1111111-1111-4111-8111-111111111111',
        newId: nextAiId,
        workspaceCurrent: () => true,
        gateway: gateway,
      ),
      throwsA(isA<AiGenerationFailure>().having((e) => e.code, 'code', 'nonempty_document_blocked')),
    );

    expect(adapter.calls, isEmpty);
  });

  test('generateAiWithEvidence sends travelgo.itinerary.evidence.v1 and parses AiGroundedProposal', () async {
    final doc = testDoc();
    final snapshot = testSnapshot();
    final baseDigest = EditableTripCodec.digest(doc);
    const requestId = 'a1111111-1111-4111-8111-111111111111';

    final adapter = MockAiAdapter((options) async {
      final payload = jsonDecode(options.data as String) as Map;
      expect(payload['contract'], 'travelgo.itinerary.evidence.v1');
      expect(payload['intent'], 'generate');
      expect(payload['requestId'], requestId);
      expect((payload['context'] as Map)['catalogueVersion'], '7');
      expect((payload['context'] as Map)['baseDigest'], baseDigest);

      return ResponseBody.fromString(
        jsonEncode({
          'status': 'succeeded',
          'requestId': requestId,
          'acceptedDay': '2026-10-27',
          'remaining': 2,
          'result': groundedReceiptJson(baseDigest: baseDigest),
        }),
        200,
      );
    });

    final dio = Dio()..httpClientAdapter = adapter;
    final gateway = AiGatewayClient(
      dio: dio,
      endpoint: Uri.parse('https://fixture.invalid/itinerary-proposal'),
      publicKey: 'fixture-key',
    );
    addTearDown(() => dio.close(force: true));

    final auth = AuthProvider(trustedRoleFetcher: (_) async => 'customer')
      ..simulateSupabaseUser(
        sb.User.fromJson({
          'id': 'a1111111-1111-4111-8111-111111111111',
          'email': 'fixture@example.invalid',
          'aud': 'authenticated',
          'created_at': '2026-10-15T00:00:00Z',
        })!,
      );
    addTearDown(auth.dispose);

    final grounded = await generateAiWithEvidence(
      auth: auth,
      document: doc,
      snapshot: snapshot,
      requestId: requestId,
      newId: nextAiId,
      workspaceCurrent: () => true,
      gateway: gateway,
      credential: () async => 'fixture-bearer',
    );

    expect(grounded.proposal.summary, 'Lịch trình có căn cứ');
    expect(grounded.proposal.activities, hasLength(1));
    expect(grounded.evidence, hasLength(1));
    expect(grounded.claims, hasLength(1));
    expect(grounded.evidence.first.reviewed, isTrue);
    expect(grounded.canApply, isTrue);
    expect(grounded.envelope.evidence, hasLength(1));
    expect(grounded.envelope.claims, hasLength(1));
  });

  test('applied_proposal_keeps_sources_after_readback in planner provider', () async {
    final emptyDoc = testDoc();
    final baseDigest = EditableTripCodec.digest(emptyDoc);
    final context = AiGenerationContext.fromDocument(emptyDoc);
    final receipt = groundedReceiptJson(baseDigest: baseDigest);

    final grounded = AiGroundedProposal.fromReceipt(
      before: emptyDoc,
      receipt: receipt,
      context: context,
      newId: nextAiId,
    );

    await evidence.withEvidenceRepository((ctx, server) async {
      final planner = ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
        newId: nextAiId,
      );
      addTearDown(planner.dispose);

      planner.openNew(emptyDoc);

      expect(planner.document!.items, isEmpty);
      expect(planner.evidenceEnvelope, isNull);

      // Apply grounded proposal atomically
      planner.dispatchAll(grounded.commands);
      planner.replaceEvidence(grounded.envelope);

      expect(planner.document!.items, hasLength(1));
      expect(planner.document!.items.first.title, 'Museum');
      expect(planner.evidenceEnvelope, isNotNull);
      expect(planner.evidenceEnvelope!.evidence, hasLength(1));
      expect(planner.evidenceEnvelope!.claims, hasLength(1));
      expect(planner.contentDigest, equals(TripEvidenceCodec.digest(grounded.envelope)));
    });
  });

  testWidgets('AiGenerationPreview shows evidence button and cancel keeps document unchanged', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final emptyDoc = testDoc();
    final baseDigest = EditableTripCodec.digest(emptyDoc);
    final context = AiGenerationContext.fromDocument(emptyDoc);
    final receipt = groundedReceiptJson(baseDigest: baseDigest);

    final grounded = AiGroundedProposal.fromReceipt(
      before: emptyDoc,
      receipt: receipt,
      context: context,
      newId: nextAiId,
    );

    final authority = ChangeNotifier();
    Object? returnedResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                returnedResult = await showDialog(
                  context: ctx,
                  builder: (_) => AiGenerationPreview(
                    input: context,
                    generate: (reqId) async => grounded,
                    authority: authority,
                    isCurrent: () => true,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Check consent and tap generate
    expect(find.byKey(const ValueKey('ai-consent')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-consent')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('ai-generate')));
    await tester.tap(find.byKey(const ValueKey('ai-generate')));
    await tester.pumpAndSettle();

    // Verify "Xem căn cứ" button is rendered
    expect(find.byKey(const ValueKey('ai-view-evidence')), findsOneWidget);
    expect(find.textContaining('Museum'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-apply')), findsOneWidget);

    // Tap Cancel -> returned result is null
    await tester.tap(find.byKey(const ValueKey('ai-cancel')));
    await tester.pumpAndSettle();

    expect(returnedResult, isNull);
  });

  test('late_owner_result_never_applies when workspace changed', () async {
    final doc = testDoc();
    final snapshot = testSnapshot();
    const requestId = 'a1111111-1111-4111-8111-111111111111';

    final adapter = MockAiAdapter((_) async => ResponseBody.fromString(
      jsonEncode({
        'status': 'succeeded',
        'requestId': requestId,
        'acceptedDay': '2026-10-27',
        'remaining': 2,
        'result': groundedReceiptJson(baseDigest: EditableTripCodec.digest(doc)),
      }),
      200,
    ));

    final dio = Dio()..httpClientAdapter = adapter;
    final gateway = AiGatewayClient(
      dio: dio,
      endpoint: Uri.parse('https://fixture.invalid/itinerary-proposal'),
      publicKey: 'fixture-key',
    );
    addTearDown(() => dio.close(force: true));

    final auth = AuthProvider(trustedRoleFetcher: (_) async => 'customer')
      ..simulateSupabaseUser(
        sb.User.fromJson({
          'id': 'a1111111-1111-4111-8111-111111111111',
          'email': 'fixture@example.invalid',
          'aud': 'authenticated',
          'created_at': '2026-10-15T00:00:00Z',
        })!,
      );
    addTearDown(auth.dispose);

    var current = true;
    final call = generateAiWithEvidence(
      auth: auth,
      document: doc,
      snapshot: snapshot,
      requestId: requestId,
      newId: nextAiId,
      workspaceCurrent: () => current,
      gateway: gateway,
      credential: () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'fixture-bearer';
      },
    );

    current = false; // Simulate user switching workspace while request in flight

    await expectLater(
      call,
      throwsA(isA<AiGenerationFailure>().having((e) => e.code, 'code', 'stale')),
    );
  });
}

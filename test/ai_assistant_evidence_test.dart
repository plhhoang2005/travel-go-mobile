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
import 'package:travelgo_mobile/features/trip_planner/models/ai_grounded_assistant.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/ai_assistant_preview.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/ai_assistant_service.dart';
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

int _assistantId = 100;
String nextAiId() =>
    '00000000-0000-4000-8000-${(_assistantId++).toString().padLeft(12, '0')}';

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

EditableTripDocumentV2 testDocWithItems() {
  final d = records.doc();
  final dayId = d.days.first.id;
  return d.copyWith(
    input: TripInput.fromJson({
      ...d.input.toJson(),
      'destinationId': 'new-city',
      'destinationName': 'New City',
    }),
    items: [
      TripItem(
        id: '00000000-0000-4000-8000-000000000001',
        dayId: dayId,
        position: 0,
        title: 'Bảo tàng buổi sáng',
        placeId: 'new-city/museum',
        startMinute: 540, // 09:00
        endMinute: 660,   // 11:00
        notes: 'Ghi chú cá nhân tuyệt mật',
        provenance: FieldProvenance(quality: 'unknown', sourceRefs: [], observedAt: null),
      ),
      TripItem(
        id: '00000000-0000-4000-8000-000000000002',
        dayId: dayId,
        position: 1,
        title: 'Công viên trưa',
        placeId: 'new-city/park',
        startMinute: 690, // 11:30
        endMinute: 780,   // 13:00
        notes: 'Hẹn bạn tại cổng',
        provenance: FieldProvenance(quality: 'unknown', sourceRefs: [], observedAt: null),
      ),
    ],
    actualExpenses: [
      ActualExpense(
        id: '00000000-0000-4000-8000-000000000099',
        itemId: '00000000-0000-4000-8000-000000000001',
        amountVnd: 50000,
        category: 'attractions',
        paidOn: '2026-10-27',
        description: 'Tiền vé gửi xe',
        sourceItemSnapshot: null,
        provenance: FieldProvenance(quality: 'user_provided', sourceRefs: [], observedAt: null),
      ),
    ],
  );
}

Map<String, Object?> assistantReceiptJson({
  required String baseDigest,
  required String intent,
  int selectedDay = 1,
  String destinationId = 'new-city',
  List<Map<String, Object?>> operations = const [],
  List<Map<String, Object?>> recommendations = const [],
  List<String> warnings = const [],
  String summary = 'Đề xuất trợ lý AI có căn cứ',
}) => {
  'contract': 'travelgo.assistant.evidence.v1',
  'proposal': {
    'contract': 'travelgo.assistant.v1',
    'intent': intent,
    'destinationId': destinationId,
    'numDays': 1,
    'selectedDay': selectedDay,
    'summary': summary,
    'recommendations': recommendations,
    'operations': operations,
    'warnings': warnings,
    'model': 'gemini-3.5-flash-lite',
    'verification': 'unverified',
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
  test('advice_with_evidence_returns_empty_operations_and_preserves_document', () async {
    final doc = testDocWithItems();
    final snapshot = testSnapshot();
    final baseDigest = EditableTripCodec.digest(doc);
    const requestId = 'a1111111-1111-4111-8111-111111111111';

    final adapter = MockAiAdapter((options) async {
      final payload = jsonDecode(options.data as String) as Map;
      expect(payload['contract'], 'travelgo.assistant.evidence.v1');
      expect(payload['intent'], 'advice');
      expect(payload['requestId'], requestId);
      expect((payload['context'] as Map)['scope'], 'day');
      expect((payload['context'] as Map)['selectedDay'], 1);

      return ResponseBody.fromString(
        jsonEncode({
          'status': 'succeeded',
          'requestId': requestId,
          'acceptedDay': '2026-10-27',
          'remaining': 2,
          'result': assistantReceiptJson(
            baseDigest: baseDigest,
            intent: 'advice',
            summary: 'Nên dành trọn buổi sáng ở bảo tàng.',
            operations: const [],
          ),
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

    final reply = await askAiWithEvidence(
      auth: auth,
      document: doc,
      snapshot: snapshot,
      intent: 'advice',
      prompt: 'Buổi sáng nên đi đâu?',
      requestId: requestId,
      newId: nextAiId,
      workspaceCurrent: () => true,
      selectedDay: 1,
      gateway: gateway,
      credential: () async => 'fixture-token',
    );

    expect(reply.result.intent, 'advice');
    expect(reply.result.operations, isEmpty);
    expect(reply.modification, isNull);
    expect(reply.commands, isEmpty);
    expect(reply.evidence, hasLength(1));
    expect(reply.claims, hasLength(1));
    expect(reply.envelope, isNotNull);
    expect(EditableTripCodec.digest(reply.envelope!.document), equals(baseDigest));
  });

  test('modify_with_evidence_preserves_notes_and_actual_expenses_and_updates_envelope', () async {
    final doc = testDocWithItems();
    final snapshot = testSnapshot();
    final baseDigest = EditableTripCodec.digest(doc);
    const requestId = 'a1111111-1111-4111-8111-111111111111';

    final adapter = MockAiAdapter((options) async {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'succeeded',
          'requestId': requestId,
          'acceptedDay': '2026-10-27',
          'remaining': 2,
          'result': assistantReceiptJson(
            baseDigest: baseDigest,
            intent: 'modify',
            summary: 'Đổi giờ bảo tàng và công viên để hợp lý hơn.',
            operations: [
              {
                'kind': 'edit',
                'itemId': '00000000-0000-4000-8000-000000000001',
                'title': 'Bảo tàng buổi sáng cập nhật',
                'placeId': 'new-city/museum',
                'startMinute': 480, // 08:00
                'endMinute': 600,   // 10:00
              },
            ],
          ),
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

    final reply = await askAiWithEvidence(
      auth: auth,
      document: doc,
      snapshot: snapshot,
      intent: 'modify',
      prompt: 'Đi sớm hơn 1 tiếng',
      requestId: requestId,
      newId: nextAiId,
      workspaceCurrent: () => true,
      selectedDay: 1,
      gateway: gateway,
      credential: () async => 'fixture-token',
    );

    expect(reply.result.intent, 'modify');
    expect(reply.modification, isNotNull);
    final mod = reply.modification!;
    expect(mod.canApply, isTrue);

    // Verify notes and actual expenses are strictly preserved
    final updatedItem = mod.after.items.firstWhere((i) => i.id == '00000000-0000-4000-8000-000000000001');
    expect(updatedItem.title, 'Bảo tàng buổi sáng cập nhật');
    expect(updatedItem.startMinute, 480);
    expect(updatedItem.notes, 'Ghi chú cá nhân tuyệt mật'); // PRESERVED!

    expect(mod.after.actualExpenses, hasLength(1));
    expect(mod.after.actualExpenses.first.amountVnd, 50000); // PRESERVED!
    expect(mod.after.actualExpenses.first.description, 'Tiền vé gửi xe'); // PRESERVED!

    // Verify evidence envelope is constructed on the modified document
    expect(reply.envelope, isNotNull);
    expect(reply.envelope!.document.items.first.title, 'Bảo tàng buổi sáng cập nhật');
    expect(reply.envelope!.evidence, hasLength(1));
    expect(reply.envelope!.claims, hasLength(1));
  });

  test('applied_modify_with_evidence_persists_in_planner_provider', () async {
    final doc = testDocWithItems();
    final baseDigest = EditableTripCodec.digest(doc);
    final receipt = assistantReceiptJson(
      baseDigest: baseDigest,
      intent: 'modify',
      operations: [
        {
          'kind': 'edit',
          'itemId': '00000000-0000-4000-8000-000000000001',
          'title': 'Bảo tàng mở cửa sớm',
          'placeId': 'new-city/museum',
          'startMinute': 480,
          'endMinute': 600,
        },
      ],
    );

    final reply = AiGroundedAssistantReply.fromReceipt(
      before: doc,
      receipt: receipt,
      intent: 'modify',
      selectedDay: 1,
      newId: nextAiId,
      assistantContext: AiAssistantContext.fromDocument(doc, selectedDay: 1),
    );

    await evidence.withEvidenceRepository((ctx, server) async {
      final planner = ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
        newId: nextAiId,
      );
      addTearDown(planner.dispose);

      planner.openNew(doc);
      expect(planner.document!.items.first.title, 'Bảo tàng buổi sáng');

      // Atomically apply modification and replace evidence envelope
      planner.dispatchAll(reply.commands);
      planner.replaceEvidence(reply.envelope!);

      expect(planner.document!.items.first.title, 'Bảo tàng mở cửa sớm');
      expect(planner.evidenceEnvelope, isNotNull);
      expect(planner.evidenceEnvelope!.evidence, hasLength(1));
      expect(planner.evidenceEnvelope!.claims, hasLength(1));
      expect(planner.contentDigest, equals(TripEvidenceCodec.digest(reply.envelope!)));
    });
  });

  testWidgets('AiAssistantPreview shows evidence button and cancel keeps document unchanged', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final doc = testDocWithItems();
    final baseDigest = EditableTripCodec.digest(doc);
    final receipt = assistantReceiptJson(
      baseDigest: baseDigest,
      intent: 'modify',
      operations: [
        {
          'kind': 'edit',
          'itemId': '00000000-0000-4000-8000-000000000001',
          'title': 'Bảo tàng mở cửa sớm',
          'placeId': 'new-city/museum',
          'startMinute': 480,
          'endMinute': 600,
        },
      ],
    );

    final reply = AiGroundedAssistantReply.fromReceipt(
      before: doc,
      receipt: receipt,
      intent: 'modify',
      selectedDay: 1,
      newId: nextAiId,
      assistantContext: AiAssistantContext.fromDocument(doc, selectedDay: 1),
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
                  builder: (_) => AiAssistantPreview(
                    input: AiAssistantContext.fromDocument(doc, selectedDay: 1),
                    generate: (intent, prompt, history, reqId) async => reply,
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

    // Select modify mode
    await tester.tap(find.byKey(const ValueKey('ai-assistant-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đề xuất chỉnh lịch').last);
    await tester.pumpAndSettle();

    // Enter prompt and consent
    await tester.enterText(find.byKey(const ValueKey('ai-assistant-prompt')), 'Đổi giờ đi');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('ai-assistant-consent')));
    await tester.tap(find.byKey(const ValueKey('ai-assistant-consent')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('ai-assistant-send')));
    await tester.tap(find.byKey(const ValueKey('ai-assistant-send')));
    await tester.pumpAndSettle();

    // Verify "Xem căn cứ" button is rendered
    expect(find.byKey(const ValueKey('ai-assistant-view-evidence')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-assistant-apply')), findsOneWidget);

    // Tap Cancel -> returnedResult is null
    await tester.tap(find.byKey(const ValueKey('ai-assistant-cancel')));
    await tester.pumpAndSettle();

    expect(returnedResult, isNull);
  });

  test('late_assistant_result_never_applies when workspace changed', () async {
    final doc = testDocWithItems();
    final snapshot = testSnapshot();
    const requestId = 'a1111111-1111-4111-8111-111111111111';

    final adapter = MockAiAdapter((_) async => ResponseBody.fromString(
      jsonEncode({
        'status': 'succeeded',
        'requestId': requestId,
        'acceptedDay': '2026-10-27',
        'remaining': 2,
        'result': assistantReceiptJson(
          baseDigest: EditableTripCodec.digest(doc),
          intent: 'advice',
        ),
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
    final call = askAiWithEvidence(
      auth: auth,
      document: doc,
      snapshot: snapshot,
      intent: 'advice',
      prompt: 'Gợi ý',
      requestId: requestId,
      newId: nextAiId,
      workspaceCurrent: () => current,
      selectedDay: 1,
      gateway: gateway,
      credential: () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'fixture-token';
      },
    );

    current = false; // Simulate user navigating away

    await expectLater(
      call,
      throwsA(isA<AiGenerationFailure>().having((e) => e.code, 'code', 'stale')),
    );
  });
}

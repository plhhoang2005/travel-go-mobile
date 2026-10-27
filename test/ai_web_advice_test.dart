import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/ai_assistant_preview.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/evidence_details_sheet.dart';
import 'package:travelgo_mobile/features/trip_planner/services/ai_assistant_service.dart';
import 'package:travelgo_mobile/features/trip_planner/services/ai_generation_service.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_evidence_envelope.dart';

class _TestHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) reply;
  final List<RequestOptions> calls = [];
  _TestHttpClientAdapter(this.reply);

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

EditableTripDocumentV2 sampleDocument() {
  final rows = jsonDecode(
    File('test/fixtures/editable_trip_v2_vectors.json').readAsStringSync(),
  ) as List;
  final base = EditableTripCodec.decode(rows.first['rawText'] as String);
  final firstItem = base.items.isNotEmpty ? base.items.first : null;
  final customItem = firstItem != null
      ? TripItem(
          id: firstItem.id,
          dayId: firstItem.dayId,
          position: firstItem.position,
          title: firstItem.title,
          placeId: firstItem.placeId,
          startMinute: firstItem.startMinute,
          endMinute: firstItem.endMinute,
          notes: 'Dữ liệu cá nhân tuyệt mật, email: test@user.com, sđt: 0901234567',
          provenance: firstItem.provenance,
        )
      : TripItem(
          id: '00000000-0000-4000-8000-000000000099',
          dayId: base.days.first.id,
          position: 0,
          title: 'Hoạt động mẫu',
          placeId: null,
          startMinute: null,
          endMinute: null,
          notes: 'Dữ liệu cá nhân tuyệt mật, email: test@user.com, sđt: 0901234567',
          provenance: FieldProvenance(
            quality: 'user_provided',
            sourceRefs: const [],
            observedAt: null,
          ),
        );

  return base.copyWith(
    input: TripInput.fromJson({
      ...base.input.toJson(),
      'destinationName': 'Hà Nội',
      'startDate': '2026-11-20',
      'endDate': '2026-11-21',
      'totalBudgetVnd': 5000000,
    }),
    items: [customItem],
  );
}

void main() {
  group('S6 — W2: AiWebAdvice tests', () {
    test('web_advice_context_builds_safe_payload_without_private_data', () {
      final doc = sampleDocument();
      final context = AiWebAdviceContext.fromDocument(doc);
      final json = context.toJson();

      // Ensure minimal necessary travel context
      expect(json['destinationName'], 'Hà Nội');
      expect(json['dates'], ['2026-11-20', '2026-11-21']);
      expect(json['budgetVnd'], 5000000);
      expect(json['baseDigest'], isA<String>());

      // Strict Privacy: Never leak personal notes, actual expenses, emails
      final jsonString = json.toString();
      expect(jsonString.contains('test@user.com'), isFalse);
      expect(jsonString.contains('0901234567'), isFalse);
      expect(jsonString.contains('Dữ liệu cá nhân'), isFalse);
      expect(jsonString.contains('notes'), isFalse);
    });

    test('web_advice_reply_parses_evidence_claims_and_warnings', () {
      final sampleResponse = {
        'contract': 'travelgo.web.advice.v1',
        'requestId': '11111111-1111-4111-8111-111111111111',
        'summary': 'Bảo tàng Lịch sử Quốc gia mở cửa các ngày trong tuần.',
        'evidence': [
          {
            'id': 'web:baotanglichsu-vn-0',
            'origin': 'web',
            'sourceUri': 'https://baotanglichsu.vn/gio-mo-cua',
            'sourceTitle': 'Giờ mở cửa - Bảo tàng Lịch sử Quốc gia',
            'retrievedAt': '2026-10-27T16:00:00.000Z',
            'reviewed': false,
          },
        ],
        'claims': [
          {
            'id': 'claim:web:0',
            'kind': 'fact',
            'field': 'advice',
            'context': 'Bảo tàng Lịch sử Quốc gia mở cửa',
            'sourceIds': ['web:baotanglichsu-vn-0'],
          },
        ],
        'searchQueries': ['giờ mở cửa Bảo tàng Lịch sử Quốc gia'],
        'searchEntryPoint': '<div class="chip">Google</div>',
        'warnings': [
          'Thông tin từ Internet, chưa được Admin kiểm duyệt: kiểm tra lại trước khi thực hiện.',
        ],
        'baseDigest': 'a' * 64,
      };

      final reply = AiWebAdviceReply.fromJson(sampleResponse);

      expect(reply.requestId, '11111111-1111-4111-8111-111111111111');
      expect(reply.summary, 'Bảo tàng Lịch sử Quốc gia mở cửa các ngày trong tuần.');
      expect(reply.evidence.length, 1);
      expect(reply.evidence.first.origin, EvidenceOrigin.web);
      expect(reply.evidence.first.reviewed, isFalse);
      expect(reply.evidence.first.url?.toString(), 'https://baotanglichsu.vn/gio-mo-cua');
      expect(reply.claims.length, 1);
      expect(reply.claims.first.kind, ClaimKind.fact);
      expect(reply.claims.first.evidenceIds, ['web:baotanglichsu-vn-0']);
      expect(reply.warnings.first, contains('chưa được Admin kiểm duyệt'));
      expect(reply.commands, isEmpty); // Law 1: Advice has zero operations
    });

    testWidgets('web_advice_widget_renders_internet_warning_and_sources', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final reply = AiWebAdviceReply(
        requestId: '22222222-2222-4222-8222-222222222222',
        summary: 'Lời khuyên từ Google Search về bảo tàng.',
        evidence: [
          EvidenceRecord(
            id: 'web:source-1',
            origin: EvidenceOrigin.web,
            url: Uri.parse('https://example.com/museum'),
            title: 'Cổng thông tin Bảo tàng',
            factKey: 'advice',
            factValue: 'Cổng thông tin Bảo tàng',
            retrievedAt: '2026-10-27T16:00:00.000Z',
            reviewed: false,
          ),
        ],
        claims: [
          EvidenceClaim(
            id: 'claim:1',
            text: 'Mở cửa từ 8h',
            kind: ClaimKind.fact,
            evidenceIds: const ['web:source-1'],
          ),
        ],
        searchQueries: const ['giờ mở cửa'],
        searchEntryPoint: null,
        warnings: const [
          'Thông tin từ Internet, chưa được Admin kiểm duyệt: kiểm tra lại trước khi thực hiện.',
        ],
        baseDigest: 'b' * 64,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebAdviceSheet(reply: reply),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verifies Internet warning badge
      expect(find.textContaining('Thông tin từ Internet'), findsWidgets);
      expect(find.textContaining('chưa được Admin kiểm duyệt'), findsWidgets);

      // 2. Verifies summary text
      expect(find.text('Lời khuyên từ Google Search về bảo tàng.'), findsOneWidget);

      // 3. Verifies "Xem căn cứ" button
      final evidenceBtn = find.text('Xem căn cứ');
      expect(evidenceBtn, findsOneWidget);

      // 4. Tap "Xem căn cứ" opens EvidenceDetailsSheet
      await tester.tap(evidenceBtn);
      await tester.pumpAndSettle();

      expect(find.byType(EvidenceDetailsSheet), findsOneWidget);
      expect(find.text('Cổng thông tin Bảo tàng'), findsWidgets);
    });

    test('requestWebAdvice dispatches proper contract and returns reply', () async {
      final doc = sampleDocument();
      final adapter = _TestHttpClientAdapter((options) async {
        final payload = jsonDecode(options.data as String) as Map<String, Object?>;
        expect(payload['contract'], 'travelgo.web.advice.v1');
        expect(payload['webConsent'], isTrue);
        final context = payload['context'] as Map<String, Object?>;
        expect(context['destinationName'], 'Hà Nội');

        final responseJson = {
          'status': 'succeeded',
          'requestId': payload['requestId'],
          'acceptedDay': '2026-10-27',
          'remaining': 2,
          'result': {
            'contract': 'travelgo.web.advice.v1',
            'requestId': payload['requestId'],
            'summary': 'Tư vấn từ internet thành công.',
            'evidence': [
              {
                'id': 'web:source-test',
                'origin': 'web',
                'sourceUri': 'https://test.vn/source',
                'sourceTitle': 'Trang thông tin',
                'retrievedAt': '2026-10-27T16:00:00.000Z',
                'reviewed': false,
              },
            ],
            'claims': [
              {
                'id': 'claim:web:0',
                'kind': 'fact',
                'field': 'advice',
                'context': 'Đoạn trích dẫn',
                'sourceIds': ['web:source-test'],
              },
            ],
            'searchQueries': ['test query'],
            'searchEntryPoint': null,
            'warnings': [
              'Thông tin từ Internet, chưa được Admin kiểm duyệt: kiểm tra lại trước khi thực hiện.',
            ],
            'baseDigest': context['baseDigest'],
          },
        };

        return ResponseBody.fromString(
          jsonEncode(responseJson),
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
            'email': 'customer@example.invalid',
            'aud': 'authenticated',
            'created_at': '2026-10-15T00:00:00Z',
          })!,
        );
      addTearDown(auth.dispose);

      final reply = await requestWebAdvice(
        auth: auth,
        document: doc,
        prompt: 'Hà Nội có gì hay?',
        requestId: '77777777-7777-4777-8777-777777777777',
        workspaceCurrent: () => true,
        gateway: gateway,
        credential: () async => 'token',
      );

      expect(reply.requestId, '77777777-7777-4777-8777-777777777777');
      expect(reply.summary, 'Tư vấn từ internet thành công.');
      expect(reply.evidence.length, 1);
      expect(reply.evidence.first.url?.toString(), 'https://test.vn/source');
      expect(reply.commands, isEmpty);
    });

    test('requestWebAdvice aborts if workspace changes while awaiting response', () async {
      final doc = sampleDocument();
      var isCurrent = true;
      final adapter = _TestHttpClientAdapter((options) async {
        isCurrent = false; // Workspace switched or document edited while waiting!
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'succeeded',
            'requestId': '88888888-8888-4888-8888-888888888888',
            'result': {
              'contract': 'travelgo.web.advice.v1',
              'requestId': '88888888-8888-4888-8888-888888888888',
              'summary': 'Late reply',
              'evidence': [],
              'claims': [],
              'searchQueries': [],
              'warnings': [],
              'baseDigest': 'c' * 64,
            },
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
            'email': 'customer@example.invalid',
            'aud': 'authenticated',
            'created_at': '2026-10-15T00:00:00Z',
          })!,
        );
      addTearDown(auth.dispose);

      expect(
        () => requestWebAdvice(
          auth: auth,
          document: doc,
          prompt: 'Late call',
          requestId: '88888888-8888-4888-8888-888888888888',
          workspaceCurrent: () => isCurrent,
          gateway: gateway,
          credential: () async => 'token',
        ),
        throwsA(isA<AiGenerationFailure>().having((f) => f.code, 'code', 'stale')),
      );
    });
  });
}

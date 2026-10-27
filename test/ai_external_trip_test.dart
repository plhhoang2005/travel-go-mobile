import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/ai_grounded_proposal.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/ai_generation_preview.dart';
import 'package:travelgo_mobile/features/trip_planner/services/ai_generation_service.dart';
import 'package:travelgo_mobile/features/trips/models/trip_evidence_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_evidence_envelope.dart';

import 'editable_local_store_test.dart' as records;

class MockExternalAiAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions) reply;
  final calls = <RequestOptions>[];
  MockExternalAiAdapter(this.reply);

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

int _externalId = 1;
String nextExternalId() =>
    '00000000-0000-4000-8000-${(_externalId++).toString().padLeft(12, '0')}';

EditableTripDocumentV2 testDoc() {
  final d = records.doc();
  return d.copyWith(
    input: TripInput.fromJson({
      ...d.input.toJson(),
      'destinationId': 'phu-yen',
      'destinationName': 'Phú Yên',
      'startDate': '2026-11-20',
      'endDate': '2026-11-21',
    }),
    days: [
      TripDay(id: '00000000-0000-4000-8000-000000000001', ordinal: 1, date: '2026-11-20', notes: ''),
      TripDay(id: '00000000-0000-4000-8000-000000000002', ordinal: 2, date: '2026-11-21', notes: ''),
    ],
    items: const [],
    estimates: const [],
  );
}

Map<String, Object?> webProposalReceiptJson({
  required String baseDigest,
}) => {
  'contract': 'travelgo.web.proposal.v1',
  'proposal': {
    'contract': 'travelgo.itinerary.v1',
    'destinationId': 'custom-phu-yen',
    'numDays': 2,
    'summary': 'Lịch trình Phú Yên 2 ngày tham quan Ghềnh Đá Đĩa và Bãi Xép.',
    'model': 'gemini-3.5-flash-lite',
    'verification': 'unverified',
    'activities': [
      {
        'day': 1,
        'title': 'Tham quan Ghềnh Đá Đĩa',
        'startMinute': 480,
        'endMinute': 660,
        'costVnd': 40000,
        'category': 'attractions',
        'externalPlaceName': 'Ghềnh Đá Đĩa',
      },
      {
        'day': 2,
        'title': 'Dạo chơi Bãi Xép',
        'startMinute': 900,
        'endMinute': 1080,
        'costVnd': null,
        'category': 'attractions',
        'externalPlaceName': 'Bãi Xép',
      },
    ],
    'warnings': <String>[
      'Thông tin từ Internet, chưa được Admin kiểm duyệt: kiểm tra lại trước khi thực hiện.',
    ],
  },
  'baseDigest': baseDigest,
  'evidence': [
    {
      'id': 'web:phuyen-gov-vn-ghenh-da-dia-0',
      'origin': 'web',
      'url': 'https://phuyen.gov.vn/ghenh-da-dia',
      'title': 'Khu danh thắng Ghềnh Đá Đĩa',
      'factKey': 'general',
      'factValue': 'Khu danh thắng Ghềnh Đá Đĩa',
      'retrievedAt': '2026-10-27T17:00:00Z',
      'reviewed': false,
    },
    {
      'id': 'web:phuyen-gov-vn-bai-xep-1',
      'origin': 'web',
      'url': 'https://phuyen.gov.vn/bai-xep',
      'title': 'Bãi Xép Phú Yên',
      'factKey': 'general',
      'factValue': 'Bãi Xép Phú Yên',
      'retrievedAt': '2026-10-27T17:00:00Z',
      'reviewed': false,
    },
  ],
  'claims': [
    {
      'id': 'claim:web:0',
      'kind': 'fact',
      'text': 'Ghềnh Đá Đĩa là điểm đến nổi tiếng',
      'evidenceIds': ['web:phuyen-gov-vn-ghenh-da-dia-0'],
    },
  ],
  'externalPlaces': [
    {
      'id': 'ext-ghenh-da-dia',
      'name': 'Ghềnh Đá Đĩa',
      'destinationName': 'Phú Yên',
      'evidenceIds': ['web:phuyen-gov-vn-ghenh-da-dia-0'],
    },
    {
      'id': 'ext-bai-xep',
      'name': 'Bãi Xép',
      'destinationName': 'Phú Yên',
      'evidenceIds': ['web:phuyen-gov-vn-bai-xep-1'],
    },
  ],
  'searchQueries': ['du lịch Phú Yên'],
  'warnings': [
    'Thông tin từ Internet, chưa được Admin kiểm duyệt: kiểm tra lại trước khi thực hiện.',
  ],
};

void main() {
  test('S7 — W3: AiGroundedProposal.fromWebReceipt binds externalPlaces and externalBindings with placeId null', () {
    final before = testDoc();
    final baseDigest = TripEvidenceCodec.digest(
      TripEvidenceEnvelope(document: before),
    );
    final receipt = webProposalReceiptJson(baseDigest: baseDigest);

    final grounded = AiGroundedProposal.fromWebReceipt(
      before: before,
      receipt: receipt,
      newId: nextExternalId,
    );

    expect(grounded.canApply, isTrue);
    expect(grounded.evidence.length, 2);
    expect(grounded.evidence.every((e) => e.origin == EvidenceOrigin.web), isTrue);
    expect(grounded.evidence.every((e) => e.reviewed == false), isTrue);

    // External places
    expect(grounded.envelope.externalPlaces.length, 2);
    expect(grounded.envelope.externalPlaces[0].id, 'ext-ghenh-da-dia');
    expect(grounded.envelope.externalPlaces[0].name, 'Ghềnh Đá Đĩa');
    expect(grounded.envelope.externalPlaces[1].id, 'ext-bai-xep');

    // External bindings
    expect(grounded.envelope.externalBindings.length, 2);
    final items = grounded.envelope.document.items;
    expect(items.length, 2);

    // Law 2 & Law 3: external activities MUST have placeId == null
    expect(items[0].placeId, isNull);
    expect(items[1].placeId, isNull);
    expect(items[0].title, 'Tham quan Ghềnh Đá Đĩa');
    expect(items[1].title, 'Dạo chơi Bãi Xép');

    // Binding item IDs match items
    expect(grounded.envelope.externalBindings[0].itemId, items[0].id);
    expect(grounded.envelope.externalBindings[0].externalPlaceId, 'ext-ghenh-da-dia');
    expect(grounded.envelope.externalBindings[1].itemId, items[1].id);
    expect(grounded.envelope.externalBindings[1].externalPlaceId, 'ext-bai-xep');

    // Notes have Internet warning
    expect(items[0].notes, contains('Thông tin từ Internet, chưa được Admin kiểm duyệt'));

    // Provenance sourceRefs points to web evidence
    expect(items[0].provenance.sourceRefs, ['web:phuyen-gov-vn-ghenh-da-dia-0']);
    expect(items[1].provenance.sourceRefs, ['web:phuyen-gov-vn-bai-xep-1']);

    // Roundtrip verification through TripEvidenceCodec
    final encoded = TripEvidenceCodec.encode(grounded.envelope);
    final decoded = TripEvidenceCodec.decode(encoded);
    expect(decoded.contract, 'travelgo.trip.evidence.v1');
    expect(decoded.externalPlaces.length, 2);
    expect(decoded.externalBindings.length, 2);
    expect(decoded.evidence.length, 2);
  });

  test('S7 — W3: unknown web activity price keeps unitAmountVnd null (never defaults to 0 VND free)', () {
    final before = testDoc();
    final baseDigest = TripEvidenceCodec.digest(
      TripEvidenceEnvelope(document: before),
    );
    final receipt = webProposalReceiptJson(baseDigest: baseDigest);

    final grounded = AiGroundedProposal.fromWebReceipt(
      before: before,
      receipt: receipt,
      newId: nextExternalId,
    );

    final estimates = grounded.envelope.document.estimates;
    expect(estimates.length, 2);

    // Activity 1 has cost 40,000 VND
    expect(estimates[0].unitAmountVnd, 40000);
    expect(estimates[0].provenance.quality, 'estimated');

    // Activity 2 has unknown cost: must remain null, NOT 0
    expect(estimates[1].unitAmountVnd, isNull);
    expect(estimates[1].provenance.quality, 'unknown');
  });

  testWidgets('S7 — W3: AiGenerationPreview renders internet warning banner and view evidence sheet for web proposal', (tester) async {
    final before = testDoc();
    final baseDigest = TripEvidenceCodec.digest(
      TripEvidenceEnvelope(document: before),
    );
    final receipt = webProposalReceiptJson(baseDigest: baseDigest);

    final grounded = AiGroundedProposal.fromWebReceipt(
      before: before,
      receipt: receipt,
      newId: nextExternalId,
    );

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final authority = ChangeNotifier();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiGenerationPreview(
            input: AiGenerationContext.fromDocument(before),
            generate: (reqId) async => grounded,
            authority: authority,
            isCurrent: () => true,
          ),
        ),
      ),
    );

    // Initial state: consent checkbox and generate button
    expect(find.text('Đồng ý gửi các thông tin trên đến Gemini'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-consent')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai-generate')));
    await tester.pumpAndSettle();

    // Verification: Internet warning banner is rendered prominently
    expect(
      find.textContaining('Thông tin từ Internet, chưa được Admin kiểm duyệt (2 nguồn)'),
      findsOneWidget,
    );

    // "Xem căn cứ" button is present
    expect(find.byKey(const ValueKey('ai-view-evidence')), findsOneWidget);

    // Activities rendered
    expect(find.textContaining('Tham quan Ghềnh Đá Đĩa'), findsOneWidget);
    expect(find.textContaining('Dạo chơi Bãi Xép'), findsOneWidget);
  });
}

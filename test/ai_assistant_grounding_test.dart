import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart'
    as catalogue;
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';
import 'package:travelgo_mobile/features/trip_planner/models/ai_context_grounding.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/services/ai_assistant_service.dart';

import 'editable_local_store_test.dart' as records;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Tạo mock PlaceVisitDetails cho Huế theo đúng dữ liệu seed thực tế
  PlaceVisitDetails createMockCitadel() {
    final jsonText = jsonEncode({
      'schemaVersion': 1,
      'version': 1,
      'publishedAt': '2026-10-20T00:00:00Z',
      'catalogueSha256':
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      'timezone': 'Asia/Ho_Chi_Minh',
      'sources': [
        {
          'id': 'src-hue',
          'title': 'Trung tâm Bảo tồn Di tích Cố đô Huế',
          'publisher': 'Bảo tồn Di tích Cố đô Huế',
          'url': 'https://hueworldheritage.org.vn',
          'publishedAt': '2026-10-15',
        }
      ],
      'packages': [
        {
          'id': 'hue-combo-4',
          'label': 'Gói 4 điểm Cố đô Huế',
          'scope': 'Tuyến 4 di tích chính',
          'included': [
            'hue/citadel',
            'hue/tu-duc',
            'hue/minh-mang',
            'hue/khai-dinh'
          ],
          'excluded': [],
          'conditions': ['Áp dụng trong 2 ngày'],
          'sourceIds': ['src-hue'],
        }
      ],
      'places': [
        {
          'placeId': 'hue/citadel',
          'visitScopeLabel': 'Đại Nội Huế',
          'price': {
            'status': 'priced',
            'options': [
              {
                'id': 'citadel-standard',
                'label': 'Vé tiêu chuẩn người lớn',
                'audience': 'Người lớn',
                'amountVnd': 200000,
                'currency': 'VND',
                'unit': 'người/lượt',
                'included': ['Đại Nội'],
                'excluded': ['Dịch vụ xe điện'],
                'conditions': [],
              }
            ],
            'evidence': {
              'reviewState': 'reviewed',
              'sourceIds': ['src-hue'],
              'checkedAt': '2026-10-20',
              'conditions': [],
              'unresolvedIssues': [],
            },
          },
          'hours': {
            'status': 'seasonal',
            'rules': [
              {
                'label': 'Giờ mùa hè',
                'weekdays': [1, 2, 3, 4, 5, 6, 7],
                'seasonStart': '03-16',
                'seasonEnd': '10-15',
                'startMinutes': 390, // 06:30
                'endMinutes': 1110, // 18:30
                'admissionCutoffMinutes': 1050, // 17:30
                'endDayOffset': 0,
              },
              {
                'label': 'Giờ mùa đông',
                'weekdays': [1, 2, 3, 4, 5, 6, 7],
                'seasonStart': '10-16',
                'seasonEnd': '03-15',
                'startMinutes': 420, // 07:00
                'endMinutes': 1080, // 18:00
                'admissionCutoffMinutes': 1020, // 17:00
                'endDayOffset': 0,
              }
            ],
            'notes': [],
            'evidence': {
              'reviewState': 'reviewed',
              'sourceIds': ['src-hue'],
              'checkedAt': '2026-10-20',
              'conditions': [],
              'unresolvedIssues': [],
            },
          },
          'notes': [],
        }
      ],
    });

    final catalogue = parseVisitCatalogue(
      jsonText,
      expectedPlaceIds: {'hue/citadel'},
      expectedCatalogueSha256:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      now: DateTime.utc(2026, 10, 24),
    );
    return catalogue.places['hue/citadel']!;
  }

  EditableTripDocumentV2 assistantDocWithDate(String date) {
    final base = records.doc();
    return base.copyWith(
      input: TripInput.fromJson({
        ...base.input.toJson(),
        'destinationId': 'hue',
        'startDate': date,
        'endDate': date,
      }),
      days: [
        TripDay.fromJson({...base.days.first.toJson(), 'date': date}),
      ],
      items: [
        TripItem(
          id: '00000000-0000-4000-8000-000000000901',
          dayId: base.days.first.id,
          position: 0,
          title: 'Tham quan Kinh thành',
          placeId: 'hue/citadel',
          startMinute: 540,
          endMinute: 600,
          notes: 'NOTE',
          provenance: FieldProvenance(
            quality: 'user_provided',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
      ],
    );
  }

  group('RAG T1: Facts Grounding & Seasonal Schedule', () {
    test('TC-T1.1: Huế Citadel summer vs winter seasonal schedule evaluation', () {
      final citadel = createMockCitadel();

      // Ngày mùa hè: 15/07/2026
      final summerDate = DateTime.utc(2026, 7, 15);
      final summerFacts = evaluatePlaceGrounding(
        placeId: 'hue/citadel',
        details: citadel,
        date: summerDate,
      );
      expect(summerFacts.availability, AvailabilityState.open);
      expect(summerFacts.openingWindows.length, 1);
      // Mùa hè cắt vé 17:30 (1050 phút)
      expect(summerFacts.openingWindows.first['startMinute'], 390);
      expect(summerFacts.openingWindows.first['endMinute'], 1050);

      // Ngày mùa đông: 15/12/2026
      final winterDate = DateTime.utc(2026, 12, 15);
      final winterFacts = evaluatePlaceGrounding(
        placeId: 'hue/citadel',
        details: citadel,
        date: winterDate,
      );
      expect(winterFacts.availability, AvailabilityState.open);
      expect(winterFacts.openingWindows.length, 1);
      // Mùa đông cắt vé 17:00 (1020 phút)
      expect(winterFacts.openingWindows.first['startMinute'], 420);
      expect(winterFacts.openingWindows.first['endMinute'], 1020);

      // Kiểm tra trong giờ mùa đông (08:00 - 10:00 -> 480 - 600)
      final winterValid = evaluatePlaceGrounding(
        placeId: 'hue/citadel',
        details: citadel,
        date: winterDate,
        startMinute: 480,
        endMinute: 600,
      );
      expect(winterValid.availability, AvailabilityState.open);

      // Kiểm tra ngoài giờ mùa đông (17:30 - 18:30 -> 1050 - 1110)
      final winterInvalid = evaluatePlaceGrounding(
        placeId: 'hue/citadel',
        details: citadel,
        date: winterDate,
        startMinute: 1050,
        endMinute: 1110,
      );
      expect(winterInvalid.availability, AvailabilityState.closed);
    });

    test('TC-T1.2: Unverified POI fallback (Law 3) maps to unknown availability', () {
      final unknownPlace = evaluatePlaceGrounding(
        placeId: 'hue/dong-ba',
        details: null,
      );
      expect(unknownPlace.availability, AvailabilityState.unknown);
      expect(unknownPlace.priceStatus, 'unverified');
      expect(unknownPlace.isOutOfDomain, isTrue);
      expect(unknownPlace.openingWindows, isEmpty);
    });

    test('TC-T1.3: Package resolution detects multi-attraction combo packages', () {
      final citadel = createMockCitadel();
      final placesMap = {'hue/citadel': citadel};

      final resolution = resolveGrounding(
        placeIds: ['hue/citadel', 'hue/tu-duc', 'hue/minh-mang'],
        visitDetails: placesMap,
      );

      expect(resolution.facts.containsKey('hue/citadel'), isTrue);
      expect(resolution.facts['hue/citadel']!.amountVnd, 200000);
      expect(resolution.facts.containsKey('hue/tu-duc'), isTrue);
      expect(resolution.facts['hue/tu-duc']!.availability, AvailabilityState.unknown);
      expect(resolution.warnings.any((w) => w.contains('hue/tu-duc')), isTrue);
    });

    test('TC-T1.4: Out-of-hours activity proposal is rejected by assistant validator', () {
      final citadel = createMockCitadel();
      const placeRef = catalogue.PlaceReference(
        id: 'hue/citadel',
        name: 'Đại Nội Huế',
        sourceId: 'src-hue',
      );

      // Chuyến đi vào mùa đông: 15/12/2026 (giờ cắt vé 17:00 tức 1020 phút)
      final doc = assistantDocWithDate('2026-12-15');

      final context = AiAssistantContext.fromDocument(
        doc,
        selectedDay: 1,
        places: const [placeRef],
        visitDetails: {'hue/citadel': citadel},
      );

      // Verify rằng openingWindows đã được nạp tự động từ visitDetails
      expect(context.toJson()['constraints'], isNotNull);
      final windows =
          (context.toJson()['constraints'] as Map)['openingWindows'] as List;
      expect(windows, isNotEmpty);
      expect(windows.first['placeId'], 'hue/citadel');
      expect(windows.first['startMinute'], 420);
      expect(windows.first['endMinute'], 1020);

      // AI đề xuất chỉnh sửa dời tham quan sang 17:30–18:30 (1050–1110)
      // Nằm ngoài giờ cắt vé 1020 của mùa đông!
      final illegalEdit = {
        'contract': aiAssistantContract,
        'intent': 'modify',
        'destinationId': 'hue',
        'numDays': 1,
        'selectedDay': 1,
        'summary': 'Dời tham quan sang chiều muộn',
        'recommendations': const [],
        'operations': [
          {
            'kind': 'edit',
            'itemId': doc.items.first.id,
            'title': 'Tham quan chiều muộn',
            'placeId': 'hue/citadel',
            'startMinute': 1050,
            'endMinute': 1110,
          }
        ],
        'warnings': const ['Lưu ý giờ tham quan'],
        'model': 'gemini-3.5-flash-lite',
        'verification': 'unverified',
      };

      // Validator bắt buộc phải ném FormatException vì vượt quá openingWindows!
      expect(
        () => AiAssistantResult.fromJson(illegalEdit, context, 'modify'),
        throwsFormatException,
      );
    });
  });

  group('RAG T1: Guardrail Hướng B kết hợp C (Smart Pivot)', () {
    test('isOutOfDomainQuery recognizes off-topic questions', () {
      // Câu hỏi của người dùng: World Cup 2030
      expect(
        isOutOfDomainQuery('lỡ trường hợp là world cup 2030 bao giờ tổ chức thì sao?'),
        isTrue,
      );
      expect(isOutOfDomainQuery('kết quả bóng đá fifa world cup hôm nay'), isTrue);
      expect(isOutOfDomainQuery('viết code python giải thuật toán'), isTrue);
      expect(isOutOfDomainQuery('giá bitcoin hôm nay bao nhiêu tiền'), isTrue);
      expect(isOutOfDomainQuery('ai là tổng thống mỹ năm 2024'), isTrue);

      // Các câu hỏi du lịch hợp lệ
      expect(isOutOfDomainQuery('thời gian tham quan Đại Nội Huế mùa này'), isFalse);
      expect(isOutOfDomainQuery('gợi ý quán bún bò ngon gần chợ Đông Ba'), isFalse);
      expect(isOutOfDomainQuery('dời lịch trình tham quan sang buổi chiều'), isFalse);
      expect(isOutOfDomainQuery('chi phí vé tham quan lăng Tự Đức'), isFalse);
    });

    test('askAiForDraft executes Smart Pivot immediately without consuming gateway', () async {
      final doc = assistantDocWithDate('2026-12-15');
      final context = AiAssistantContext.fromDocument(
        doc,
        selectedDay: 1,
        places: const [],
      );

      final auth = AuthProvider();

      // Gọi askAiForDraft với câu hỏi World Cup 2030
      final reply = await askAiForDraft(
        auth: auth,
        document: doc,
        context: context,
        intent: 'advice',
        prompt: 'lỡ trường hợp là world cup 2030 bao giờ tổ chức thì sao?',
        history: const [],
        requestId: '00000000-0000-4000-8000-000000000001',
        newId: () => 'id-1',
        workspaceCurrent: () => true,
        gateway: null, // Không truyền gateway -> Nếu gọi mạng sẽ crash!
      );

      expect(reply.result, isNotNull);
      expect(reply.result.intent, 'advice');
      // Chứa lời giải thích lịch sự và điều hướng người dùng quay lại kế hoạch chuyến đi
      expect(reply.result.summary.contains('TravelGO là trợ lý chuyên biệt'), isTrue);
      expect(reply.result.summary.contains('nằm ngoài cơ sở dữ liệu'), isTrue);
      expect(reply.result.summary.contains('tối ưu lịch trình'), isTrue);
      expect(reply.result.warnings.first, contains('Smart Pivot'));
      expect(reply.result.operations, isEmpty);
    });
  });
}

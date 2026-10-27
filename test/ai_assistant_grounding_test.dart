import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
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
            'hue/khai-dinh',
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
                'endMinutes': 1110, // 18:30 (giờ đóng cửa)
                'admissionCutoffMinutes': 1050, // 17:30 (giờ ngừng nhận khách)
                'endDayOffset': 0,
              },
              {
                'label': 'Giờ mùa đông',
                'weekdays': [1, 2, 3, 4, 5, 6, 7],
                'seasonStart': '10-16',
                'seasonEnd': '03-15',
                'startMinutes': 420, // 07:00
                'endMinutes': 1080, // 18:00 (giờ đóng cửa)
                'admissionCutoffMinutes': 1020, // 17:00 (giờ ngừng nhận khách)
                'endDayOffset': 0,
              },
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

  // Mock POI tạm đóng cửa (R1)
  PlaceVisitDetails createMockTemporarilyClosedPlace() {
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
          'title': 'Nguồn thông báo',
          'publisher': 'Bảo tồn Cố đô Huế',
          'url': 'https://hueworldheritage.org.vn',
          'publishedAt': '2026-10-20',
        }
      ],
      'packages': [],
      'places': [
        {
          'placeId': 'hue/closed-palace',
          'visitScopeLabel': 'Điện Thái Hòa (Trùng tu)',
          'price': {
            'status': 'free',
            'options': [
              {
                'id': 'free-closed',
                'label': 'Miễn phí',
                'audience': 'Mọi đối tượng',
                'amountVnd': 0,
                'currency': 'VND',
                'unit': 'người/lượt',
                'included': [],
                'excluded': [],
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
            'status': 'temporarily_closed',
            'rules': [],
            'notes': ['Đang trùng tu đến hết năm 2026.'],
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
      expectedPlaceIds: {'hue/closed-palace'},
      expectedCatalogueSha256:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      now: DateTime.utc(2026, 10, 24),
    );
    return catalogue.places['hue/closed-palace']!;
  }

  // Mock POI có lịch qua đêm (R2)
  PlaceVisitDetails createMockOvernightPlace() {
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
          'title': 'Phố đêm Hoàng Thành',
          'publisher': 'Huế Night Zone',
          'url': 'https://hueworldheritage.org.vn',
          'publishedAt': '2026-10-20',
        }
      ],
      'packages': [],
      'places': [
        {
          'placeId': 'hue/night-zone',
          'visitScopeLabel': 'Phố đêm Hoàng Thành',
          'price': {
            'status': 'free',
            'options': [
              {
                'id': 'free-closed',
                'label': 'Miễn phí',
                'audience': 'Mọi đối tượng',
                'amountVnd': 0,
                'currency': 'VND',
                'unit': 'người/lượt',
                'included': [],
                'excluded': [],
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
            'status': 'scheduled',
            'rules': [
              {
                'label': 'Phố đi bộ đêm',
                'weekdays': [1, 2, 3, 4, 5, 6, 7],
                'startMinutes': 1200, // 20:00
                'endMinutes': 120, // 02:00 sáng hôm sau
                'admissionCutoffMinutes': 60, // 01:00
                'endDayOffset': 1,
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
      expectedPlaceIds: {'hue/night-zone'},
      expectedCatalogueSha256:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      now: DateTime.utc(2026, 10, 24),
    );
    return catalogue.places['hue/night-zone']!;
  }

  EditableTripDocumentV2 assistantDocWithDate(String? date) {
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

  group('RAG T1 Findings: R1 - R7 Verifications', () {
    // R1: Closed POIs must be distinguished from unknown/open and rejected from schedule proposals
    test('R1: closed POIs are rejected from recommendations and candidate schedule', () {
      final closedPlace = createMockTemporarilyClosedPlace();
      const closedRef = catalogue.PlaceReference(
        id: 'hue/closed-palace',
        name: 'Điện Thái Hòa',
        sourceId: 'src-hue',
      );

      final date = DateTime.utc(2026, 12, 15);
      final fact = evaluatePlaceGrounding(
        placeId: 'hue/closed-palace',
        details: closedPlace,
        date: date,
      );
      expect(fact.availability, AvailabilityState.closed);
      expect(fact.openingWindows, isEmpty);

      final doc = assistantDocWithDate('2026-12-15');
      final context = AiAssistantContext.fromDocument(
        doc,
        selectedDay: 1,
        places: const [closedRef],
        visitDetails: {'hue/closed-palace': closedPlace},
      );

      expect(context.closedPlaceIds.contains('hue/closed-palace'), isTrue);

      // AI recommends closed place -> MUST throw FormatException
      final illegalRec = {
        'contract': aiAssistantContract,
        'intent': 'recommendations',
        'destinationId': 'hue',
        'numDays': 1,
        'selectedDay': 1,
        'summary': 'Gợi ý điểm đến',
        'recommendations': [
          {
            'title': 'Thăm Điện Thái Hòa',
            'reason': 'Công trình kiến trúc độc đáo',
            'placeId': 'hue/closed-palace',
          }
        ],
        'operations': const [],
        'warnings': const [],
        'model': 'gemini-3.5-flash-lite',
        'verification': 'unverified',
      };
      expect(
        () => AiAssistantResult.fromJson(illegalRec, context, 'recommendations'),
        throwsFormatException,
      );

      // AI proposes modify activity at closed place -> MUST throw FormatException
      final illegalAdd = {
        'contract': aiAssistantContract,
        'intent': 'modify',
        'destinationId': 'hue',
        'numDays': 1,
        'selectedDay': 1,
        'summary': 'Thêm hoạt động tại điểm đóng cửa',
        'recommendations': const [],
        'operations': [
          {
            'kind': 'add',
            'title': 'Thăm Điện Thái Hòa',
            'placeId': 'hue/closed-palace',
            'startMinute': 480,
            'endMinute': 540,
            'costVnd': 0,
            'category': 'sightseeing',
          }
        ],
        'warnings': const [],
        'model': 'gemini-3.5-flash-lite',
        'verification': 'unverified',
      };
      expect(
        () => AiAssistantResult.fromJson(illegalAdd, context, 'modify'),
        throwsFormatException,
      );
    });

    // R2: Overnight schedule (endDayOffset == 1) does not break context
    test('R2: overnight schedule (endDayOffset == 1) does not break context or produce endMinute <= startMinute', () {
      final nightPlace = createMockOvernightPlace();
      const nightRef = catalogue.PlaceReference(
        id: 'hue/night-zone',
        name: 'Phố đêm Hoàng Thành',
        sourceId: 'src-hue',
      );

      final date = DateTime.utc(2026, 12, 15);
      final fact = evaluatePlaceGrounding(
        placeId: 'hue/night-zone',
        details: nightPlace,
        date: date,
      );

      expect(fact.availability, AvailabilityState.open);
      expect(fact.openingWindows.isNotEmpty, isTrue);
      // Window ngày bắt đầu: 1200..1440 (20:00..24:00)
      final window = fact.openingWindows.first;
      expect(window['startMinute'], 1200);
      expect(window['endMinute'], 1440);
      expect((window['endMinute'] as int) > (window['startMinute'] as int), isTrue);

      // Verify AiAssistantContext.fromDocument does NOT throw FormatException in _validateFacts!
      final doc = assistantDocWithDate('2026-12-15');
      final context = AiAssistantContext.fromDocument(
        doc,
        selectedDay: 1,
        places: const [nightRef],
        visitDetails: {'hue/night-zone': nightPlace},
      );
      expect(context.toJson()['constraints'], isNotNull);
    });

    // R3: Admission cutoff vs closing time separation
    test('R3: admission cutoff (17:00) vs closing time (18:00) are evaluated separately', () {
      final citadel = createMockCitadel();

      final winterDate = DateTime.utc(2026, 12, 15);
      final winterFacts = evaluatePlaceGrounding(
        placeId: 'hue/citadel',
        details: citadel,
        date: winterDate,
      );
      expect(winterFacts.availability, AvailabilityState.open);
      expect(winterFacts.openingWindows.length, 1);
      // Mùa đông: đóng cửa 18:00 (1080), cutoff 17:00 (1020)
      expect(winterFacts.openingWindows.first['startMinute'], 420);
      expect(winterFacts.openingWindows.first['endMinute'], 1080);

      // Mùa hè: đóng cửa 18:30 (1110), cutoff 17:30 (1050)
      final summerDate = DateTime.utc(2026, 7, 15);
      final summerFacts = evaluatePlaceGrounding(
        placeId: 'hue/citadel',
        details: citadel,
        date: summerDate,
      );
      expect(summerFacts.openingWindows.first['startMinute'], 390);
      expect(summerFacts.openingWindows.first['endMinute'], 1110);

      // Đi 16:45 - 17:30 (1005 - 1050): vào trước 17:00 cutoff và ra trước 18:00 -> HỢP LỆ (open)
      final winterLateEntry = evaluatePlaceGrounding(
        placeId: 'hue/citadel',
        details: citadel,
        date: winterDate,
        startMinute: 1005,
        endMinute: 1050,
      );
      expect(winterLateEntry.availability, AvailabilityState.open);

      // Đi 17:15 - 18:00 (1035 - 1080): vào sau 17:00 cutoff -> KHÔNG HỢP LỆ (closed)
      final winterAfterCutoff = evaluatePlaceGrounding(
        placeId: 'hue/citadel',
        details: citadel,
        date: winterDate,
        startMinute: 1035,
        endMinute: 1080,
      );
      expect(winterAfterCutoff.availability, AvailabilityState.closed);
    });

    // R4: Smart Pivot does not block valid travel requests with keywords
    test('R4: travel requests containing war/museum/trip keywords are not blocked', () {
      // Yêu cầu du lịch hợp lệ chứa từ khóa nhạy cảm
      expect(
        isOutOfDomainQuery('Thêm Bảo tàng Chứng tích Chiến tranh vào lịch ngày 1'),
        isFalse,
      );
      expect(
        isOutOfDomainQuery('Lên lịch chuyến đi xem World Cup 2026 tại Mỹ'),
        isFalse,
      );
      expect(
        isOutOfDomainQuery('Gợi ý quán ăn gần Bảo tàng Lịch sử Quân sự'),
        isFalse,
      );
      expect(
        isOutOfDomainQuery('xếp lịch tham quan các di tích chiến tranh ở Củ Chi'),
        isFalse,
      );

      // Câu hỏi kiến thức thuần túy ngoài miền -> CHẶN cục bộ (Smart Pivot)
      expect(
        isOutOfDomainQuery('lỡ trường hợp là world cup 2030 bao giờ tổ chức thì sao?'),
        isTrue,
      );
      expect(isOutOfDomainQuery('ai là tổng thống mỹ hiện nay'), isTrue);
      expect(isOutOfDomainQuery('viết code python giải bài toán'), isTrue);
      expect(isOutOfDomainQuery('giá bitcoin hôm nay bao nhiêu'), isTrue);
    });

    // R5: Missing date (date == null) returns unknown availability and does not merge seasons
    test('R5: null date returns unknown availability and empty windows', () {
      final citadel = createMockCitadel();

      // date == null
      final nullDateFacts = evaluatePlaceGrounding(
        placeId: 'hue/citadel',
        details: citadel,
        date: null,
      );

      expect(nullDateFacts.availability, AvailabilityState.unknown);
      expect(nullDateFacts.openingWindows, isEmpty);
      expect(nullDateFacts.note, contains('Chưa có ngày đi cụ thể'));
    });

    // R6: Grounding warnings deterministically surface in result and preview
    test('R6: grounding warnings deterministically surface in AiAssistantResult and preview differences', () {
      final citadel = createMockCitadel();
      const citadelRef = catalogue.PlaceReference(
        id: 'hue/citadel',
        name: 'Đại Nội Huế',
        sourceId: 'src-hue',
      );
      const unknownRef = catalogue.PlaceReference(
        id: 'hue/unverified-spot',
        name: 'Điểm chưa xác minh',
        sourceId: 'src-hue',
      );

      final doc = assistantDocWithDate('2026-12-15');
      final context = AiAssistantContext.fromDocument(
        doc,
        selectedDay: 1,
        places: const [citadelRef, unknownRef],
        visitDetails: {'hue/citadel': citadel}, // hue/unverified-spot không có visitDetails
      );

      expect(context.grounding, isNotNull);
      expect(
        context.grounding!.warnings.any((w) => w.contains('hue/unverified-spot')),
        isTrue,
      );

      final validRec = {
        'contract': aiAssistantContract,
        'intent': 'recommendations',
        'destinationId': 'hue',
        'numDays': 1,
        'selectedDay': 1,
        'summary': 'Gợi ý hoạt động',
        'recommendations': [
          {
            'title': 'Tham quan Đại Nội',
            'reason': 'Di sản văn hóa',
            'placeId': 'hue/citadel',
          }
        ],
        'operations': const [],
        'warnings': const ['Lưu ý chung từ model'],
        'model': 'gemini-3.5-flash-lite',
        'verification': 'unverified',
      };

      final result = AiAssistantResult.fromJson(validRec, context, 'recommendations');
      // Warnings phải chứa cả grounding warning và model warning
      expect(
        result.warnings.any((w) => w.contains('hue/unverified-spot')),
        isTrue,
      );
      expect(
        result.warnings.any((w) => w.contains('Lưu ý chung từ model')),
        isTrue,
      );

      // Kiểm tra preview differences có chứa cảnh báo dữ liệu
      final modifyRaw = {
        'contract': aiAssistantContract,
        'intent': 'modify',
        'destinationId': 'hue',
        'numDays': 1,
        'selectedDay': 1,
        'summary': 'Chỉnh sửa hoạt động',
        'recommendations': const [],
        'operations': [
          {
            'kind': 'edit',
            'itemId': doc.items.first.id,
            'title': 'Đại Nội Huế buổi sáng',
            'placeId': 'hue/citadel',
            'startMinute': 480,
            'endMinute': 600,
          }
        ],
        'warnings': const [],
        'model': 'gemini-3.5-flash-lite',
        'verification': 'unverified',
      };
      final modifyResult = AiAssistantResult.fromJson(modifyRaw, context, 'modify');
      final preview = prepareAiModification(doc, modifyResult, context, () => 'id-1');
      expect(
        preview.differences.any((d) => d.contains('Lưu ý dữ liệu:')),
        isTrue,
      );
    });

    // R7: Package budget resolution deferred to Decision Engine per Law 2
    test('R7: package budget resolution is marked NOT_IMPLEMENTED on client to preserve Law 2', () {
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

      // Tuân thủ Luật 2: Client không tự ý cộng trừ gói vé hay tính ngân sách tổng
      expect(resolution.appliedPackages, isEmpty);
      expect(resolution.totalEstimatedCostVnd, 0);
    });
  });
}

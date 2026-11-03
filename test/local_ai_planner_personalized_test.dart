import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/services/ai_generation_service.dart';
import 'package:travelgo_mobile/features/trip_planner/services/local_ai_planner_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('LocalAiPlannerService & Tolerant Normalizer Tests', () {
    test('extractCleanJson removes markdown fences and extracts raw json object', () {
      const rawWithFences = '''
```json
{
  "summary": "Chuyến đi tuyệt vời",
  "activities": []
}
```
''';
      final clean = LocalAiPlannerService.extractCleanJson(rawWithFences);
      expect(clean.startsWith('{'), isTrue);
      expect(clean.endsWith('}'), isTrue);
      expect(clean.contains('```'), isFalse);
    });

    test('normalizeOllamaPlanJson correctly parses valid JSON and preserves non-overlapping times', () {
      const sampleJson = '''
{
  "summary": "Lịch trình 2N1Đ tại Đà Lạt",
  "activities": [
    {
      "day": 1,
      "title": "Check-in Quảng trường Lâm Viên",
      "category": "attractions",
      "startMinute": 540,
      "endMinute": 660,
      "costVnd": 0
    },
    {
      "day": 1,
      "title": "Ăn trưa lẩu gà lá é",
      "category": "food",
      "startMinute": 690,
      "endMinute": 780,
      "costVnd": 300000
    },
    {
      "day": 2,
      "title": "Săn mây Đồi chè Cầu Đất",
      "category": "attractions",
      "startMinute": 330,
      "endMinute": 480,
      "costVnd": 100000
    }
  ]
}
''';
      final proposal = LocalAiPlannerService.normalizeOllamaPlanJson(
        jsonText: sampleJson,
        numDays: 2,
        defaultDestinationName: 'Đà Lạt',
        targetBudgetVnd: 2000000,
      );

      expect(proposal.summary, 'Lịch trình 2N1Đ tại Đà Lạt');
      expect(proposal.activities.length, 3);
      expect(proposal.activities[0].title, 'Check-in Quảng trường Lâm Viên');
      expect(proposal.activities[0].day, 1);
      expect(proposal.activities[0].startMinute, 540);
      expect(proposal.activities[0].endMinute, 660);
      expect(proposal.activities[1].category, 'food');
      expect(proposal.activities[2].day, 2);
    });

    test('normalizeOllamaPlanJson repairs overlapping and missing times automatically', () {
      const flawedJson = '''
{
  "summary": "Lịch trình có mốc giờ lỗi",
  "activities": [
    {
      "day": 1,
      "title": "Điểm 1",
      "category": "invalid_category_xyz",
      "startMinute": 600,
      "endMinute": 700
    },
    {
      "day": 1,
      "title": "Điểm 2 trùng giờ điểm 1",
      "category": "attractions",
      "startMinute": 650,
      "endMinute": 720
    }
  ]
}
''';
      final proposal = LocalAiPlannerService.normalizeOllamaPlanJson(
        jsonText: flawedJson,
        numDays: 1,
        defaultDestinationName: 'Hà Nội',
        targetBudgetVnd: 1000000,
      );

      expect(proposal.activities.length, 2);
      final act1 = proposal.activities[0];
      final act2 = proposal.activities[1];

      // Verify no overlap: act2.startMinute must be >= act1.endMinute
      expect(act2.startMinute! >= act1.endMinute!, isTrue);
      // Verify category was normalized to an allowed category
      expect(const {'transport', 'accommodation', 'food', 'attractions', 'shopping', 'other'}.contains(act1.category), isTrue);
    });

    test('prepareAiProposal creates valid EditableTripDocument from local proposal', () {
      const validJson = '''
{
  "summary": "Khám phá Đà Nẵng",
  "activities": [
    {
      "day": 1,
      "title": "Tắm biển Mỹ Khê",
      "category": "attractions",
      "startMinute": 510,
      "endMinute": 630,
      "costVnd": 0
    }
  ]
}
''';
      final proposal = LocalAiPlannerService.normalizeOllamaPlanJson(
        jsonText: validJson,
        numDays: 1,
        defaultDestinationName: 'Đà Nẵng',
        targetBudgetVnd: 1500000,
      );

      final uuid = const Uuid();
      final dayId = uuid.v4();
      final before = EditableTripDocumentV2(
        input: TripInput(
          title: 'Chuyến đi Đà Nẵng',
          destinationId: 'da-nang',
          destinationName: 'Đà Nẵng',
          startDate: '2026-12-01',
          endDate: '2026-12-01',
          timezone: 'Asia/Ho_Chi_Minh',
          origin: 'Hà Nội',
          travelerCount: 2,
          totalBudgetVnd: 1500000,
          interests: ['Biển', 'Ẩm thực'],
          priority: 'balanced',
        ),
        days: [
          TripDay(
            id: dayId,
            ordinal: 1,
            date: '2026-12-01',
            notes: 'Ngày 1: Biển Mỹ Khê',
          ),
        ],
        items: [],
        source: SourceReference(
          kind: 'new',
          sourceId: 'local-ai',
          sourceDigest: null,
        ),
      );

      final prepared = prepareAiProposal(before, proposal, () => uuid.v4());
      expect(prepared.canApply, isTrue);
      expect(prepared.commands.isNotEmpty, isTrue);
      expect(prepared.document.items.length, 1);
      expect(prepared.document.items.first.title, 'Tắm biển Mỹ Khê');
    });
  });
}

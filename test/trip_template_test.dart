import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/services/editable_trip_validator.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_template_repository.dart';

void main() {
  group('TripTemplate & Repository Tests', () {
    test('repository returns 4 curated templates with valid data', () {
      final repo = TripTemplateRepository();
      final templates = repo.getCuratedTemplates();

      expect(templates.length, 4);

      // Verify template identifiers
      final ids = templates.map((t) => t.id).toList();
      expect(ids, containsAll(['da-lat-3d', 'ha-noi-2d', 'da-nang-4d', 'sa-pa-3d']));

      for (final t in templates) {
        expect(t.title.isNotEmpty, isTrue);
        expect(t.destinationId.isNotEmpty, isTrue);
        expect(t.destinationName.isNotEmpty, isTrue);
        expect(t.numDays, greaterThanOrEqualTo(2));
        expect(t.estimatedBudgetVnd, greaterThan(1000000));
        expect(t.tagline.isNotEmpty, isTrue);
        expect(t.tags.isNotEmpty, isTrue);
        expect(t.days.length, equals(t.numDays));
      }
    });

    test('toDocument produces a valid EditableTripDocumentV2 passing validation', () {
      final repo = TripTemplateRepository();
      final templates = repo.getCuratedTemplates();

      for (final t in templates) {
        final doc = t.toDocument();

        expect(doc.input.title, t.title);
        expect(doc.input.destinationId, t.destinationId);
        expect(doc.input.destinationName, t.destinationName);
        expect(doc.days.length, t.numDays);

        // All activities must link to existing days
        final dayIds = doc.days.map((d) => d.id).toSet();
        for (final act in doc.items) {
          expect(dayIds.contains(act.dayId), isTrue);
        }

        // Validate document schema integrity
        final issues = EditableTripValidator.validate(doc);
        final blockingIssues = issues.where((i) => i.isBlocking).toList();
        expect(blockingIssues, isEmpty, reason: 'Template ${t.id} has blocking issues: $blockingIssues');
      }
    });
  });
}

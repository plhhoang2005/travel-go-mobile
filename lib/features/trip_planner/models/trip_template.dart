import 'package:uuid/uuid.dart';
import 'editable_trip_document.dart';

class TemplateActivity {
  final String title;
  final String? placeId;
  final int startMinute; // e.g. 9 * 60 = 540 (09:00)
  final int endMinute;   // e.g. 11 * 60 = 660 (11:00)
  final String notes;

  const TemplateActivity({
    required this.title,
    this.placeId,
    required this.startMinute,
    required this.endMinute,
    this.notes = '',
  });
}

class TemplateDay {
  final int dayNumber;
  final String title;
  final List<TemplateActivity> activities;

  const TemplateDay({
    required this.dayNumber,
    required this.title,
    required this.activities,
  });
}

class TripTemplate {
  final String id;
  final String title;
  final String destinationId;
  final String destinationName;
  final int numDays;
  final int estimatedBudgetVnd;
  final String tagline;
  final List<String> tags;
  final String imageUrl;
  final List<TemplateDay> days;

  const TripTemplate({
    required this.id,
    required this.title,
    required this.destinationId,
    required this.destinationName,
    required this.numDays,
    required this.estimatedBudgetVnd,
    required this.tagline,
    required this.tags,
    required this.imageUrl,
    required this.days,
  });

  EditableTripDocumentV2 toDocument({String Function()? idGenerator}) {
    final gen = idGenerator ?? const Uuid().v4;

    final tripDays = <TripDay>[];
    final tripItems = <TripItem>[];

    for (int d = 0; d < days.length; d++) {
      final tDay = days[d];
      final dayId = gen();
      tripDays.add(
        TripDay(
          id: dayId,
          ordinal: d + 1,
          date: null,
          notes: tDay.title,
        ),
      );

      for (int a = 0; a < tDay.activities.length; a++) {
        final act = tDay.activities[a];
        tripItems.add(
          TripItem(
            id: gen(),
            dayId: dayId,
            position: a,
            title: act.title,
            placeId: act.placeId,
            startMinute: act.startMinute,
            endMinute: act.endMinute,
            notes: act.notes,
            provenance: FieldProvenance(
              quality: 'estimated',
              sourceRefs: [id],
              observedAt: null,
            ),
          ),
        );
      }
    }

    return EditableTripDocumentV2(
      input: TripInput(
        title: title,
        destinationId: destinationId,
        destinationName: destinationName,
        startDate: null,
        endDate: null,
        timezone: 'Asia/Ho_Chi_Minh',
        origin: 'Hà Nội',
        travelerCount: 2,
        totalBudgetVnd: estimatedBudgetVnd,
        interests: tags,
        priority: 'balanced',
      ),
      days: tripDays,
      items: tripItems,
      source: SourceReference(
        kind: 'catalogue_reference',
        sourceId: id,
        sourceDigest: null,
      ),
    );
  }
}

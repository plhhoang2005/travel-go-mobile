import 'package:uuid/uuid.dart';

import '../../trips/models/editable_trip_codec.dart';
import '../../trips/models/trip_payload_codec.dart';
import '../models/editable_trip_document.dart';
import '../models/trip_request.dart';
import 'editable_trip_validator.dart';

/// Creates an empty manual workspace; no health check, engine or AI dependency.
class ManualTripFactory {
  final String Function() newId;
  ManualTripFactory({String Function()? newId})
    : newId = newId ?? const Uuid().v4;
  EditableTripDocumentV2 fromInput(
    PlanTripRequest request,
    TripMetadataV1 metadata,
  ) {
    if (request.numDays < 1 || request.numDays > 366) {
      throw const EditableCodecException('invalid_input', 'numDays');
    }
    var count = request.numDays;
    DateTime? first;
    if (metadata.startDate != null && metadata.endDate != null) {
      TripPayloadCodec.validateCalendarDate(metadata.startDate!);
      TripPayloadCodec.validateCalendarDate(metadata.endDate!);
      first = DateTime.parse('${metadata.startDate}T00:00:00Z');
      final last = DateTime.parse('${metadata.endDate}T00:00:00Z');
      count = last.difference(first).inDays + 1;
      if (count < 1 || count > 366) {
        throw const EditableCodecException('invalid_input', 'dates');
      }
    }
    final destId = metadata.destinationId;
    final isValidId = destId != null &&
        RegExp(r'^[a-z0-9][a-z0-9/-]{0,119}$').hasMatch(destId);
    final name = isValidId ? metadata.destinationName : null;
    final document = EditableTripDocumentV2(
      input: TripInput(
        title:
            metadata.title ??
            (name == null ? 'Chuyến đi mới' : 'Chuyến đi $name'),
        destinationId: isValidId ? destId : null,
        destinationName: name,
        startDate: metadata.startDate,
        endDate: metadata.endDate,
        timezone: 'Asia/Ho_Chi_Minh',
        origin: request.origin,
        travelerCount: request.numPeople,
        totalBudgetVnd: request.budgetVnd,
        interests: request.preferences,
        priority: request.priority,
      ),
      days: List.generate(
        count,
        (i) => TripDay(
          id: newId(),
          ordinal: i + 1,
          date: first
              ?.add(Duration(days: i))
              .toIso8601String()
              .substring(0, 10),
          notes: '',
        ),
      ),
      source: SourceReference(kind: 'new', sourceId: null, sourceDigest: null),
    );
    EditableTripCodec.encode(document);
    final issues = EditableTripValidator.validate(document);
    if (issues.any((i) => i.isBlocking)) {
      throw const EditableCodecException('invalid_input', 'input');
    }
    return document;
  }
}

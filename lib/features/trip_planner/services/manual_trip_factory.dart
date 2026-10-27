import 'package:uuid/uuid.dart';

import '../../trips/models/editable_trip_codec.dart';
import '../../trips/models/trip_payload_codec.dart';
import '../models/editable_trip_document.dart';
import '../models/trip_request.dart';
import 'editable_trip_validator.dart';
import 'trip_date_policy.dart';

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

    String? resolvedStart = metadata.startDate;
    String? resolvedEnd = metadata.endDate;

    if (request.startDate != null || request.endDate != null) {
      if (resolvedStart != null || resolvedEnd != null) {
        if (resolvedStart != request.startDate || resolvedEnd != request.endDate) {
          throw const EditableCodecException('invalid_input', 'dates');
        }
      } else {
        resolvedStart = request.startDate;
        resolvedEnd = request.endDate;
      }
    }

    var count = request.numDays;
    DateTime? first;
    if (resolvedStart != null || resolvedEnd != null) {
      try {
        final range = TripDatePolicy.validate(
          resolvedStart,
          resolvedEnd,
          expectedDays: request.numDays,
          maxDays: 366,
        );
        if (range != null) {
          count = range.numDays;
          first = TripDatePolicy.parseCalendarDate(range.startDate);
        }
      } catch (_) {
        throw const EditableCodecException('invalid_input', 'dates');
      }
    }

    final destId = metadata.destinationId;
    final isValidId = destId != null &&
        RegExp(r'^[a-z0-9][a-z0-9/-]{0,119}$').hasMatch(destId);
    if (destId != null && !isValidId) {
      throw const EditableCodecException('invalid_input', 'destinationId');
    }
    final enteredName = metadata.destinationName?.trim();
    final name = enteredName == null || enteredName.isEmpty ? null : enteredName;
    final document = EditableTripDocumentV2(
      input: TripInput(
        title:
            metadata.title ??
            (name == null ? 'Chuyến đi mới' : 'Chuyến đi $name'),
        destinationId: isValidId ? destId : null,
        destinationName: name,
        startDate: resolvedStart,
        endDate: resolvedEnd,
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
          date: first == null
              ? null
              : TripDatePolicy.calculateEndDate(resolvedStart!, i + 1),
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

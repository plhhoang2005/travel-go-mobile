import '../../trip_planner/models/editable_trip_document.dart';

class SourceBinding {
  final String kind;
  final String? deviceScope;
  final String? draftId;
  final int? sourceRevision;
  final String? sourceTripId;
  final String? sourceDigest;
  const SourceBinding.guest({
    required this.deviceScope,
    required this.draftId,
    required this.sourceRevision,
  }) : kind = 'guest_import',
       sourceTripId = null,
       sourceDigest = null;
  const SourceBinding.copy({
    required this.sourceTripId,
    required this.sourceDigest,
  }) : kind = 'v1_copy',
       deviceScope = null,
       draftId = null,
       sourceRevision = null;
  Map<String, Object?> toJson() => kind == 'guest_import'
      ? {
          'kind': kind,
          'deviceScope': deviceScope,
          'draftId': draftId,
          'sourceRevision': sourceRevision,
        }
      : {
          'kind': kind,
          'sourceTripId': sourceTripId,
          'sourceDigest': sourceDigest,
        };
}

class EditableHead {
  final String tripId, ownerId, payloadText, contentDigest;
  final int version;
  final DateTime fetchedAt;
  final EditableTripDocumentV2 document;
  const EditableHead({
    required this.tripId,
    required this.ownerId,
    required this.version,
    required this.payloadText,
    required this.contentDigest,
    required this.fetchedAt,
    required this.document,
  });
}

class EditableReceipt {
  final String requestId, ownerId, tripId, operation, requestDigest;
  final String? contentDigest;
  final int resultVersion;
  final DateTime committedAt;
  final SourceBinding? sourceBinding;
  const EditableReceipt({
    required this.requestId,
    required this.ownerId,
    required this.tripId,
    required this.operation,
    required this.requestDigest,
    required this.contentDigest,
    required this.resultVersion,
    required this.committedAt,
    required this.sourceBinding,
  });
}

enum EditableMutationStatus { committed, deleted, notFound }

class EditableMutationReply {
  final EditableMutationStatus status;
  final EditableReceipt? receipt;
  final EditableHead? head;
  const EditableMutationReply({required this.status, this.receipt, this.head});
}

class EditablePendingAttempt {
  final String requestId, ownerId, operation, requestText, requestDigest;
  final String? tripId, contentDigest;
  final int? expectedVersion;
  final SourceBinding? sourceBinding;
  const EditablePendingAttempt({
    required this.requestId,
    required this.ownerId,
    required this.operation,
    required this.requestText,
    required this.requestDigest,
    this.tripId,
    this.contentDigest,
    this.expectedVersion,
    this.sourceBinding,
  });
}

class OwnedTripCursor {
  final DateTime createdAt;
  final String id;
  const OwnedTripCursor(this.createdAt, this.id);
}

enum OwnedTripKind { legacyV1, editableV2 }

class OwnedTripSummary {
  final OwnedTripKind kind;
  final String tripId, ownerId, title, destinationName;
  final DateTime createdAt;
  final int? version;
  const OwnedTripSummary({
    required this.kind,
    required this.tripId,
    required this.ownerId,
    required this.title,
    required this.destinationName,
    required this.createdAt,
    required this.version,
  });
}

class OwnedTripPage {
  final List<OwnedTripSummary> items;
  final OwnedTripCursor? nextCursor;
  OwnedTripPage({required List<OwnedTripSummary> items, this.nextCursor})
    : items = List.unmodifiable(items);
}

enum EditableTripViewState { online, cachedReadOnly, unavailable }

class EditableTripView {
  final EditableTripViewState state;
  final EditableHead? head;
  const EditableTripView(this.state, [this.head]);
}

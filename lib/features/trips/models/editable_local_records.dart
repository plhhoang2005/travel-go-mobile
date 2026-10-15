import '../../trip_planner/models/editable_trip_command.dart';
import '../../trip_planner/models/editable_trip_document.dart';
import '../../trip_planner/services/editable_trip_validator.dart';
import 'editable_remote_records.dart';
import 'editable_trip_codec.dart';
import 'local_trip_records.dart';
import 'trip_payload_codec.dart';

class EditableDraftConflictException extends LocalTripStoreException {
  const EditableDraftConflictException(super.message);
}

class EditableDraftRecord {
  final String deviceScope, draftId, payloadText, contentDigest;
  final int revision;
  final EditableTripDocumentV2 document;
  final DateTime savedAt;
  const EditableDraftRecord({
    required this.deviceScope,
    required this.draftId,
    required this.revision,
    required this.document,
    required this.payloadText,
    required this.contentDigest,
    required this.savedAt,
  });
}

class EditableSnapshotRecord {
  final EditableHead head;
  const EditableSnapshotRecord(this.head);
}

class EditableAttemptRecord {
  final EditablePendingAttempt attempt;
  final String state;
  final EditableReceipt? receipt;
  const EditableAttemptRecord({
    required this.attempt,
    required this.state,
    this.receipt,
  });
}

/// Shared strict wire/storage decoding. No session or database connection here.
class EditableRecordCodec {
  static Never bad() =>
      throw const CorruptDatabaseException('Invalid editable record.');
  static Map<String, Object?> object(Object? value) {
    if (value is! Map<String, Object?>) {
      bad();
    }
    return value;
  }

  static void keys(Map<String, Object?> map, String fields) {
    final expected = fields.split(' ');
    if (map.length != expected.length ||
        map.keys.any((k) => !expected.contains(k))) {
      bad();
    }
  }

  static String text(Object? value, {int max = 128}) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.trim() != value ||
        value.runes.length > max) {
      bad();
    }
    TripPayloadCodec.validateUnicode(value);
    return value;
  }

  static String id(Object? value) {
    final result = text(value);
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    ).hasMatch(result)) {
      bad();
    }
    return result;
  }

  static int positive(Object? value) {
    if (value is! int || value < 1 || value > EditableTripCodec.maxMoney) {
      bad();
    }
    return value;
  }

  static String digest(Object? value) {
    if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      bad();
    }
    return value;
  }

  static DateTime utc(Object? value) {
    if (value is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$')
            .hasMatch(value)) {
      bad();
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null ||
        !parsed.isUtc ||
        parsed.toIso8601String().substring(0, 19) != value.substring(0, 19)) {
      bad();
    }
    return parsed;
  }

  static SourceBinding? source(Object? raw) {
    if (raw == null) {
      return null;
    }
    final map = object(raw);
    if (map['kind'] == 'guest_import') {
      keys(map, 'kind deviceScope draftId sourceRevision');
      return SourceBinding.guest(
        deviceScope: text(map['deviceScope']),
        draftId: text(map['draftId']),
        sourceRevision: positive(map['sourceRevision']),
      );
    }
    if (map['kind'] == 'v1_copy') {
      keys(map, 'kind sourceTripId sourceDigest');
      return SourceBinding.copy(
        sourceTripId: id(map['sourceTripId']),
        sourceDigest: digest(map['sourceDigest']),
      );
    }
    bad();
  }

  static EditableTripDocumentV2 accountDocument(
    String raw,
    String expectedDigest,
  ) {
    if (EditableTripCodec.digestText(raw) != expectedDigest) {
      bad();
    }
    final document = EditableTripCodec.decode(raw);
    if (EditableTripValidator.validate(
      document,
      mode: ValidationMode.accountSave,
    ).any((i) => i.isBlocking)) {
      bad();
    }
    return document;
  }

  static EditableHead head(Map<String, Object?> json) {
    keys(json, 'tripId ownerId version payloadText contentDigest fetchedAt');
    final raw = json['payloadText'];
    if (raw is! String) {
      bad();
    }
    final hash = digest(json['contentDigest']);
    return EditableHead(
      tripId: id(json['tripId']),
      ownerId: id(json['ownerId']),
      version: positive(json['version']),
      payloadText: raw,
      contentDigest: hash,
      fetchedAt: utc(json['fetchedAt']),
      document: accountDocument(raw, hash),
    );
  }

  static Map<String, Object?> headJson(EditableHead value) => {
    'tripId': value.tripId,
    'ownerId': value.ownerId,
    'version': value.version,
    'payloadText': value.payloadText,
    'contentDigest': value.contentDigest,
    'fetchedAt': value.fetchedAt.toIso8601String(),
  };
  static EditableReceipt receipt(Map<String, Object?> json) {
    keys(
      json,
      'requestId ownerId tripId operation requestDigest contentDigest resultVersion committedAt sourceBinding',
    );
    final op = text(json['operation']);
    if (!{'create', 'update', 'delete'}.contains(op)) {
      bad();
    }
    final version = positive(json['resultVersion']);
    if (op == 'create' && version != 1 || op != 'create' && version < 2) {
      bad();
    }
    final hash = json['contentDigest'] == null
        ? null
        : digest(json['contentDigest']);
    if (op == 'delete' && hash != null || op != 'delete' && hash == null) {
      bad();
    }
    return EditableReceipt(
      requestId: id(json['requestId']),
      ownerId: id(json['ownerId']),
      tripId: id(json['tripId']),
      operation: op,
      requestDigest: digest(json['requestDigest']),
      contentDigest: hash,
      resultVersion: version,
      committedAt: utc(json['committedAt']),
      sourceBinding: source(json['sourceBinding']),
    );
  }

  static Map<String, Object?> receiptJson(EditableReceipt value) => {
    'requestId': value.requestId,
    'ownerId': value.ownerId,
    'tripId': value.tripId,
    'operation': value.operation,
    'requestDigest': value.requestDigest,
    'contentDigest': value.contentDigest,
    'resultVersion': value.resultVersion,
    'committedAt': value.committedAt.toIso8601String(),
    'sourceBinding': value.sourceBinding?.toJson(),
  };
  static Map<String, Object?> attemptJson(EditablePendingAttempt value) => {
    'requestId': value.requestId,
    'ownerId': value.ownerId,
    'operation': value.operation,
    'requestText': value.requestText,
    'requestDigest': value.requestDigest,
    'tripId': value.tripId,
    'contentDigest': value.contentDigest,
    'expectedVersion': value.expectedVersion,
    'sourceBinding': value.sourceBinding?.toJson(),
  };
  static EditablePendingAttempt attempt(Map<String, Object?> json) {
    keys(
      json,
      'requestId ownerId operation requestText requestDigest tripId contentDigest expectedVersion sourceBinding',
    );
    final raw = json['requestText'];
    if (raw is! String) {
      bad();
    }
    final value = EditablePendingAttempt(
      requestId: id(json['requestId']),
      ownerId: id(json['ownerId']),
      operation: text(json['operation']),
      requestText: raw,
      requestDigest: digest(json['requestDigest']),
      tripId: json['tripId'] == null ? null : id(json['tripId']),
      expectedVersion: json['expectedVersion'] == null
          ? null
          : positive(json['expectedVersion']),
      contentDigest: json['contentDigest'] == null
          ? null
          : digest(json['contentDigest']),
      sourceBinding: source(json['sourceBinding']),
    );
    validateAttempt(value);
    return value;
  }

  static void validateAttempt(EditablePendingAttempt value) {
    id(value.requestId);
    id(value.ownerId);
    digest(value.requestDigest);
    if (EditableTripCodec.digestText(value.requestText) !=
        value.requestDigest) {
      bad();
    }
    final body = object(
      EditableTripCodec.parseStrict(value.requestText, limit: 3 * 1024 * 1024),
    );
    if (value.operation == 'delete') {
      keys(body, 'op tripId expectedVersion');
      if (body['op'] != 'delete' ||
          body['tripId'] != value.tripId ||
          body['expectedVersion'] != value.expectedVersion ||
          value.contentDigest != null ||
          value.sourceBinding != null) {
        bad();
      }
      id(value.tripId);
      positive(value.expectedVersion);
      return;
    }
    if (value.operation != 'create' && value.operation != 'update') {
      bad();
    }
    keys(
      body,
      value.operation == 'create'
          ? 'payloadText contentDigest sourceBinding'
          : 'payloadText contentDigest commands',
    );
    final payload = body['payloadText'];
    if (payload is! String || body['contentDigest'] != value.contentDigest) {
      bad();
    }
    accountDocument(payload, digest(value.contentDigest));
    if (value.operation == 'create') {
      if (value.tripId != null ||
          value.expectedVersion != null ||
          EditableTripCodec.canonicalJson(
                source(body['sourceBinding'])?.toJson(),
              ) !=
              EditableTripCodec.canonicalJson(value.sourceBinding?.toJson())) {
        bad();
      }
    } else {
      id(value.tripId);
      positive(value.expectedVersion);
      if (value.sourceBinding != null) {
        bad();
      }
      final commands = body['commands'];
      if (commands is! List || commands.length > 4000) {
        bad();
      }
      for (final command in commands) {
        EditableCommand.fromJson(object(command));
      }
    }
  }
}

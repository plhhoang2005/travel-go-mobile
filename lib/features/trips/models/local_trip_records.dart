import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';

/// Base exception for all local trip store errors.
abstract class LocalTripStoreException implements Exception {
  final String message;
  const LocalTripStoreException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class UnsupportedDatabaseVersionException extends LocalTripStoreException {
  const UnsupportedDatabaseVersionException(super.message);
}

class CorruptDatabaseException extends LocalTripStoreException {
  const CorruptDatabaseException(super.message);
}

class AccountNamespaceBlockedException extends LocalTripStoreException {
  const AccountNamespaceBlockedException(super.message);
}

class UnauthorizedAccountAccessException extends LocalTripStoreException {
  const UnauthorizedAccountAccessException(super.message);
}

class StaleSessionEpochException extends LocalTripStoreException {
  const StaleSessionEpochException(super.message);
}

class DraftImportPendingException extends LocalTripStoreException {
  const DraftImportPendingException(super.message);
}

class ImportAttemptConflictException extends LocalTripStoreException {
  const ImportAttemptConflictException(super.message);
}

class DuplicateRequestKeyException extends LocalTripStoreException {
  const DuplicateRequestKeyException(super.message);
}

class ImportJournalNotFoundException extends LocalTripStoreException {
  const ImportJournalNotFoundException(super.message);
}

class ReceiptBindingMismatchException extends LocalTripStoreException {
  const ReceiptBindingMismatchException(super.message);
}

class ImportAttemptQuarantinedException extends LocalTripStoreException {
  const ImportAttemptQuarantinedException(super.message);
}

class SnapshotStaleVersionException extends LocalTripStoreException {
  const SnapshotStaleVersionException(super.message);
}

class SnapshotConflictException extends LocalTripStoreException {
  const SnapshotConflictException(super.message);
}

class CleanupMarkerPersistenceException extends LocalTripStoreException {
  const CleanupMarkerPersistenceException(super.message);
}

class DraftRevisionPinnedException extends LocalTripStoreException {
  const DraftRevisionPinnedException(super.message);
}

class StoreUnavailableException extends LocalTripStoreException {
  const StoreUnavailableException(super.message);
}

/// Store-owned monotonic session handle binding trusted auth context to local operations.
class SessionHandle {
  final String ownerId;
  final int coordinatorEpoch;
  final int storeGeneration;
  final bool isDemoSession;

  const SessionHandle({
    required this.ownerId,
    required this.coordinatorEpoch,
    required this.storeGeneration,
    required this.isDemoSession,
  });

  void validate() {
    if (ownerId.trim().isEmpty) {
      throw const UnauthorizedAccountAccessException('ownerId cannot be blank.');
    }
    if (isDemoSession) {
      throw const UnauthorizedAccountAccessException(
        'Demo sessions cannot access persistent account store.',
      );
    }
    if (storeGeneration < 1) {
      throw const UnauthorizedAccountAccessException('Invalid store generation.');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionHandle &&
          runtimeType == other.runtimeType &&
          ownerId == other.ownerId &&
          coordinatorEpoch == other.coordinatorEpoch &&
          storeGeneration == other.storeGeneration &&
          isDemoSession == other.isDemoSession;

  @override
  int get hashCode =>
      ownerId.hashCode ^
      coordinatorEpoch.hashCode ^
      storeGeneration.hashCode ^
      isDemoSession.hashCode;
}

/// Strict validated representation of an import receipt from the remote server.
class LocalImportReceipt {
  static const Set<String> permittedKeys = {
    'deviceScope',
    'targetOwner',
    'draftId',
    'sourceRevision',
    'requestKey',
    'contentDigest',
    'receiptId',
    'tripId',
    'remoteVersion',
    'committedAt',
  };

  final String deviceScope;
  final String targetOwner;
  final String draftId;
  final int sourceRevision;
  final String requestKey;
  final String contentDigest;
  final String receiptId;
  final String tripId;
  final int remoteVersion;
  final DateTime committedAt;

  LocalImportReceipt({
    required this.deviceScope,
    required this.targetOwner,
    required this.draftId,
    required this.sourceRevision,
    required this.requestKey,
    required this.contentDigest,
    required this.receiptId,
    required this.tripId,
    required this.remoteVersion,
    required this.committedAt,
  }) {
    if (deviceScope.trim().isEmpty) throw ArgumentError('deviceScope cannot be blank');
    if (targetOwner.trim().isEmpty) throw ArgumentError('targetOwner cannot be blank');
    if (draftId.trim().isEmpty) throw ArgumentError('draftId cannot be blank');
    if (sourceRevision < 1) throw ArgumentError('sourceRevision must be >= 1');
    if (requestKey.trim().isEmpty) throw ArgumentError('requestKey cannot be blank');
    if (contentDigest.length != 64 || !RegExp(r'^[0-9a-f]{64}$').hasMatch(contentDigest)) {
      throw ArgumentError('contentDigest must be 64 lowercase hex characters');
    }
    if (receiptId.trim().isEmpty) throw ArgumentError('receiptId cannot be blank');
    if (tripId.trim().isEmpty) throw ArgumentError('tripId cannot be blank');
    if (remoteVersion < 1) throw ArgumentError('remoteVersion must be >= 1');
    if (!committedAt.isUtc) throw ArgumentError('committedAt must be in UTC');
  }

  Map<String, dynamic> toWhitelistedMap() => {
    'deviceScope': deviceScope,
    'targetOwner': targetOwner,
    'draftId': draftId,
    'sourceRevision': sourceRevision,
    'requestKey': requestKey,
    'contentDigest': contentDigest,
    'receiptId': receiptId,
    'tripId': tripId,
    'remoteVersion': remoteVersion,
    'committedAt': committedAt.toIso8601String(),
  };

  factory LocalImportReceipt.fromMap(Map<String, dynamic> map) {
    // 1. Strict key check: disallow extra or missing keys
    final keys = map.keys.toSet();
    if (keys.length != permittedKeys.length || !keys.containsAll(permittedKeys)) {
      throw const CorruptDatabaseException('Receipt JSON contains invalid or extra keys.');
    }

    // 2. Strict integer type check: NO .toInt() rounding/truncation
    final rawSourceRev = map['sourceRevision'];
    if (rawSourceRev is! int) {
      throw const CorruptDatabaseException(
        'Receipt sourceRevision must be strict integer, got fractional or non-int.',
      );
    }

    final rawRemoteVer = map['remoteVersion'];
    if (rawRemoteVer is! int) {
      throw const CorruptDatabaseException(
        'Receipt remoteVersion must be strict integer, got fractional or non-int.',
      );
    }

    // 3. Strict UTC string validation (must end with Z, no arbitrary offsets)
    final rawCommittedAt = map['committedAt'];
    if (rawCommittedAt is! String || !rawCommittedAt.endsWith('Z')) {
      throw const CorruptDatabaseException(
        'Receipt committedAt must be strict ISO-8601 UTC string ending with Z.',
      );
    }

    DateTime committedAt;
    try {
      committedAt = DateTime.parse(rawCommittedAt);
      if (!committedAt.isUtc) throw const FormatException();
    } catch (_) {
      throw const CorruptDatabaseException('Malformed receipt committedAt timestamp.');
    }

    try {
      return LocalImportReceipt(
        deviceScope: map['deviceScope'] as String,
        targetOwner: map['targetOwner'] as String,
        draftId: map['draftId'] as String,
        sourceRevision: rawSourceRev,
        requestKey: map['requestKey'] as String,
        contentDigest: map['contentDigest'] as String,
        receiptId: map['receiptId'] as String,
        tripId: map['tripId'] as String,
        remoteVersion: rawRemoteVer,
        committedAt: committedAt,
      );
    } catch (e) {
      throw CorruptDatabaseException('Malformed receipt structure: $e');
    }
  }

  /// Single equality helper comparing all 10 fields (C05)
  static bool areReceiptsEqual(LocalImportReceipt a, LocalImportReceipt b) {
    return a.deviceScope == b.deviceScope &&
        a.targetOwner == b.targetOwner &&
        a.draftId == b.draftId &&
        a.sourceRevision == b.sourceRevision &&
        a.requestKey == b.requestKey &&
        a.contentDigest == b.contentDigest &&
        a.receiptId == b.receiptId &&
        a.tripId == b.tripId &&
        a.remoteVersion == b.remoteVersion &&
        a.committedAt == b.committedAt;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalImportReceipt &&
          runtimeType == other.runtimeType &&
          areReceiptsEqual(this, other);

  @override
  int get hashCode =>
      deviceScope.hashCode ^
      targetOwner.hashCode ^
      draftId.hashCode ^
      sourceRevision.hashCode ^
      requestKey.hashCode ^
      contentDigest.hashCode ^
      receiptId.hashCode ^
      tripId.hashCode ^
      remoteVersion.hashCode ^
      committedAt.hashCode;
}

class ImportCommitResult {
  final LocalImportReceipt receipt;
  final AccountTripSnapshotRecord snapshot;

  const ImportCommitResult({
    required this.receipt,
    required this.snapshot,
  });
}

/// Immutable record of a single guest draft revision.
class GuestDraftRevisionRecord {
  final String deviceScope;
  final String draftId;
  final int revision;
  final String payloadJson;
  final int schemaVersion;
  final String digest;
  final DateTime createdAt;
  final String state;
  final CanonicalTripPayloadV1 cachedPayload;

  const GuestDraftRevisionRecord({
    required this.deviceScope,
    required this.draftId,
    required this.revision,
    required this.payloadJson,
    required this.schemaVersion,
    required this.digest,
    required this.createdAt,
    required this.state,
    required this.cachedPayload,
  });
}

/// Summary record of a guest draft header pointing to its active revision.
class GuestDraftSummaryRecord {
  final String deviceScope;
  final String draftId;
  final int currentRevision;
  final int highestAllocatedRevision;
  final String? title;
  final String? destinationName;
  final DateTime updatedAt;

  const GuestDraftSummaryRecord({
    required this.deviceScope,
    required this.draftId,
    required this.currentRevision,
    required this.highestAllocatedRevision,
    this.title,
    this.destinationName,
    required this.updatedAt,
  });
}

/// Cached trip record owned by an authenticated account.
class AccountTripSnapshotRecord {
  final String ownerId;
  final String tripId;
  final int? remoteVersion;
  final int schemaVersion;
  final DateTime fetchedAt;
  final String payloadJson;
  final String digest;
  final String title;
  final String destinationName;
  final String? startDate;
  final String? endDate;
  final DateTime updatedAt;
  final CanonicalTripPayloadV1 cachedPayload;

  const AccountTripSnapshotRecord({
    required this.ownerId,
    required this.tripId,
    required this.remoteVersion,
    required this.schemaVersion,
    required this.fetchedAt,
    required this.payloadJson,
    required this.digest,
    required this.title,
    required this.destinationName,
    this.startDate,
    this.endDate,
    required this.updatedAt,
    required this.cachedPayload,
  });
}

/// Record representing an import journal entry tracking draft-to-account progression.
class LocalImportJournalRecord {
  final String deviceScope;
  final String targetOwner;
  final String draftId;
  final int sourceRevision;
  final String requestKey;
  final String contentDigest;
  final String state;
  final String? receiptPayload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LocalImportReceipt? cachedReceipt;

  const LocalImportJournalRecord({
    required this.deviceScope,
    required this.targetOwner,
    required this.draftId,
    required this.sourceRevision,
    required this.requestKey,
    required this.contentDigest,
    required this.state,
    this.receiptPayload,
    required this.createdAt,
    required this.updatedAt,
    this.cachedReceipt,
  });
}

/// Durable marker record for namespace purges.
class LocalCleanupStateRecord {
  final String namespace;
  final bool isBlocked;
  final bool purgePending;
  final String reason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalCleanupStateRecord({
    required this.namespace,
    required this.isBlocked,
    required this.purgePending,
    required this.reason,
    required this.createdAt,
    required this.updatedAt,
  });
}

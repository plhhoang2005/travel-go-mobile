import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/local_trip_records.dart';
import '../models/trip_payload_codec.dart';
import 'local_account_lifecycle_service.dart';

enum SnapshotLookupStatus {
  ready,
  deleted,
  unavailable,
  deploymentBlocked,
  rejected,
}

class RemoteTripSnapshot {
  final String ownerId;
  final String tripId;
  final CanonicalTripPayloadV1 payload;
  final int? remoteVersion;
  final DateTime fetchedAt;
  final LegacyTripRowContext headers;

  const RemoteTripSnapshot({
    required this.ownerId,
    required this.tripId,
    required this.payload,
    required this.remoteVersion,
    required this.fetchedAt,
    required this.headers,
  });

  RemoteTripSnapshot withHeaders(LegacyTripRowContext value) =>
      RemoteTripSnapshot(
        ownerId: ownerId,
        tripId: tripId,
        payload: payload,
        remoteVersion: remoteVersion,
        fetchedAt: fetchedAt,
        headers: value,
      );
}

class SnapshotLookup {
  final SnapshotLookupStatus status;
  final RemoteTripSnapshot? snapshot;
  const SnapshotLookup(this.status, [this.snapshot]);
}

class SnapshotFetchBatch {
  final List<RemoteTripSnapshot> snapshots;
  final DateTime fetchedAt;
  final bool complete;

  SnapshotFetchBatch(List<RemoteTripSnapshot> snapshots, this.fetchedAt)
    : snapshots = List.unmodifiable(snapshots),
      complete = false;
}

class SnapshotRejectedException implements Exception {
  final String reason;
  const SnapshotRejectedException(this.reason);
  @override
  String toString() => 'Snapshot rejected: $reason';
}

/// Reads raw owned rows and B3 receipts without using an SDK-wide mutable token.
class TripSnapshotService {
  final Dio _dio;
  final Uri _origin;
  final String _publicKey;
  final bool Function(AccountSessionProof) isCurrentProof;
  final DateTime Function() _clock;
  DateTime? _lastFetchedAt;

  TripSnapshotService({
    required String projectUrl,
    required String publicKey,
    required this.isCurrentProof,
    HttpClientAdapter? adapter,
    DateTime Function()? clock,
  }) : _origin = _validatedOrigin(projectUrl),
       _publicKey = publicKey,
       _clock = clock ?? DateTime.now,
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 30),
         ),
       ) {
    if (publicKey.trim().isEmpty) {
      throw ArgumentError('Public key is required.');
    }
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  static Uri _validatedOrigin(String value) {
    final uri = Uri.parse(value);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError('A fixed HTTPS project origin is required.');
    }
    return uri;
  }

  DateTime _fetchedAt() {
    var current = _clock().toUtc();
    final previous = _lastFetchedAt;
    if (previous != null && !current.isAfter(previous)) {
      current = previous.add(const Duration(microseconds: 1));
    }
    _lastFetchedAt = current;
    return current;
  }

  void _check(AccountSessionProof proof) {
    if (!isCurrentProof(proof) ||
        proof.ownerId.trim().isEmpty ||
        proof.accessToken.trim().isEmpty ||
        proof.expiresAt <= _clock().millisecondsSinceEpoch ~/ 1000 + 10) {
      throw StateError('Account snapshot authority is stale.');
    }
  }

  Future<dynamic> _get(
    AccountSessionProof proof,
    String path, [
    Map<String, String>? query,
  ]) async {
    _check(proof);
    final uri = _origin.replace(path: path, queryParameters: query);
    final response = await _dio.getUri<dynamic>(
      uri,
      options: Options(
        followRedirects: false,
        headers: {
          'Authorization': 'Bearer ${proof.accessToken}',
          'apikey': _publicKey,
          'Accept': 'application/json',
        },
      ),
    );
    _check(proof);
    final data = response.data;
    return data is String ? jsonDecode(data) : data;
  }

  Future<dynamic> _postRead(
    AccountSessionProof proof,
    String path,
    Map<String, dynamic> parameters,
  ) async {
    _check(proof);
    final response = await _dio.postUri<dynamic>(
      _origin.replace(path: path),
      data: parameters,
      options: Options(
        followRedirects: false,
        headers: {
          'Authorization': 'Bearer ${proof.accessToken}',
          'apikey': _publicKey,
          'Content-Type': 'application/json',
        },
      ),
    );
    _check(proof);
    final data = response.data;
    return data is String ? jsonDecode(data) : data;
  }

  /// IDs must come from the authoritative mixed-list discriminator.
  Future<SnapshotFetchBatch> fetchLegacySnapshots({
    required AccountSessionProof proof,
    required List<String> tripIds,
  }) async {
    _check(proof);
    if (tripIds.length > 100 ||
        tripIds.toSet().length != tripIds.length ||
        tripIds.any((id) => id.trim().isEmpty)) {
      throw const SnapshotRejectedException('Invalid legacy ID batch.');
    }
    final snapshots = <RemoteTripSnapshot>[];
    for (final id in tripIds) {
      final result = await readOwnedSnapshot(proof: proof, tripId: id);
      _check(proof);
      if (result.status == SnapshotLookupStatus.deleted ||
          result.status == SnapshotLookupStatus.unavailable ||
          result.status == SnapshotLookupStatus.rejected) {
        continue;
      }
      if (result.status != SnapshotLookupStatus.ready ||
          result.snapshot?.tripId != id) {
        continue;
      }
      snapshots.add(result.snapshot!);
    }
    return SnapshotFetchBatch(snapshots, _fetchedAt());
  }

  Future<SnapshotFetchBatch> fetchSnapshots({
    required AccountSessionProof proof,
  }) async {
    final fetchedAt = _fetchedAt();
    final raw = await _get(proof, '/rest/v1/trips', {
      'select': '*',
      'user_id': 'eq.${proof.ownerId}',
      'order': 'created_at.desc',
      'limit': '100',
    });
    if (raw is! List) {
      throw const SnapshotRejectedException('Trip list is not an array.');
    }
    final snapshots = <RemoteTripSnapshot>[];
    for (final value in raw) {
      _check(proof);
      if (value is! Map) {
        throw const SnapshotRejectedException('Trip row is not an object.');
      }
      final row = Map<String, dynamic>.from(value);
      final headers = _headers(row, proof.ownerId);
      final tripId = headers.id!;
      final text = row['canonical_payload_text'];
      if (text == null) {
        final legacy = TripPayloadCodec.decodeLegacyRow(row);
        snapshots.add(
          RemoteTripSnapshot(
            ownerId: proof.ownerId,
            tripId: tripId,
            payload: legacy.payload,
            remoteVersion: null,
            fetchedAt: fetchedAt,
            headers: headers,
          ),
        );
      } else if (text is String && text.isNotEmpty) {
        final lookup = await _readImported(proof, tripId, fetchedAt);
        if (lookup.status != SnapshotLookupStatus.ready ||
            lookup.snapshot == null ||
            TripPayloadCodec.encode(lookup.snapshot!.payload) != text) {
          throw const SnapshotRejectedException(
            'Imported list row is inconsistent.',
          );
        }
        snapshots.add(lookup.snapshot!.withHeaders(headers));
      } else {
        throw const SnapshotRejectedException(
          'Invalid canonical payload text.',
        );
      }
    }
    _check(proof);
    return SnapshotFetchBatch(snapshots, fetchedAt);
  }

  Future<SnapshotLookup> readImportedSnapshot({
    required AccountSessionProof proof,
    required String tripId,
  }) => _readImported(proof, tripId, _fetchedAt());

  Future<SnapshotLookup> _readImported(
    AccountSessionProof proof,
    String tripId,
    DateTime fetchedAt,
  ) async {
    if (tripId.trim().isEmpty) {
      return const SnapshotLookup(SnapshotLookupStatus.rejected);
    }
    dynamic raw;
    try {
      raw = await _postRead(proof, '/rest/v1/rpc/get_import_trip_snapshot_v1', {
        'p_trip_id': tripId,
      });
    } on DioException catch (error) {
      _check(proof);
      final data = error.response?.data;
      final code = data is Map ? data['code'] : null;
      if (error.response?.statusCode == 404 || code == 'PGRST202') {
        return const SnapshotLookup(SnapshotLookupStatus.deploymentBlocked);
      }
      // Preserve authentication failures for the lifecycle owner. Treating
      // them as malformed rows would leave previously displayed account data.
      rethrow;
    }
    _check(proof);
    try {
      if (raw is! Map ||
          raw.length != 3 ||
          !raw.keys.toSet().containsAll({'status', 'receipt', 'payloadText'})) {
        throw const FormatException();
      }
      final status = raw['status'];
      if (status == 'unavailable' &&
          raw['receipt'] == null &&
          raw['payloadText'] == null) {
        return const SnapshotLookup(SnapshotLookupStatus.unavailable);
      }
      if (raw['receipt'] is! Map) throw const FormatException();
      final receipt = LocalImportReceipt.fromMap(
        Map<String, dynamic>.from(raw['receipt'] as Map),
      );
      if (receipt.targetOwner != proof.ownerId || receipt.tripId != tripId) {
        throw const FormatException();
      }
      if (status == 'deleted' && raw['payloadText'] == null) {
        return const SnapshotLookup(SnapshotLookupStatus.deleted);
      }
      if (status != 'committed' || raw['payloadText'] is! String) {
        throw const FormatException();
      }
      final text = raw['payloadText'] as String;
      final payload = TripPayloadCodec.decode(jsonDecode(text));
      if (TripPayloadCodec.encode(payload) != text ||
          TripPayloadCodec.computeDigest(payload) != receipt.contentDigest) {
        throw const FormatException();
      }
      return SnapshotLookup(
        SnapshotLookupStatus.ready,
        RemoteTripSnapshot(
          ownerId: proof.ownerId,
          tripId: tripId,
          payload: payload,
          remoteVersion: receipt.remoteVersion,
          fetchedAt: fetchedAt,
          headers: LegacyTripRowContext(id: tripId, userId: proof.ownerId),
        ),
      );
    } catch (_) {
      return const SnapshotLookup(SnapshotLookupStatus.rejected);
    }
  }

  Future<SnapshotLookup> readOwnedSnapshot({
    required AccountSessionProof proof,
    required String tripId,
  }) async {
    final imported = await readImportedSnapshot(proof: proof, tripId: tripId);
    if (imported.status != SnapshotLookupStatus.unavailable) return imported;
    final fetchedAt = _fetchedAt();
    final raw = await _get(proof, '/rest/v1/trips', {
      'select': '*',
      'id': 'eq.$tripId',
      'user_id': 'eq.${proof.ownerId}',
      'limit': '2',
    });
    if (raw is! List || raw.length > 1) {
      return const SnapshotLookup(SnapshotLookupStatus.rejected);
    }
    if (raw.isEmpty) {
      return const SnapshotLookup(SnapshotLookupStatus.unavailable);
    }
    try {
      final row = Map<String, dynamic>.from(raw.single as Map);
      final headers = _headers(row, proof.ownerId);
      if (headers.id != tripId || row['canonical_payload_text'] != null) {
        throw const FormatException();
      }
      final legacy = TripPayloadCodec.decodeLegacyRow(row);
      _check(proof);
      return SnapshotLookup(
        SnapshotLookupStatus.ready,
        RemoteTripSnapshot(
          ownerId: proof.ownerId,
          tripId: tripId,
          payload: legacy.payload,
          remoteVersion: null,
          fetchedAt: fetchedAt,
          headers: headers,
        ),
      );
    } catch (_) {
      _check(proof);
      return const SnapshotLookup(SnapshotLookupStatus.rejected);
    }
  }

  static LegacyTripRowContext _headers(Map<String, dynamic> row, String owner) {
    final id = row['id'];
    if (id is! String || id.trim().isEmpty || row['user_id'] != owner) {
      throw const SnapshotRejectedException('Trip identity does not match.');
    }
    final days = row['num_days'];
    final budget = row['budget_total'];
    if ((days != null && (days is! int || days < 1)) ||
        (budget != null &&
            (budget is! num || !budget.isFinite || budget < 0))) {
      throw const SnapshotRejectedException('Invalid trip numeric header.');
    }
    for (final key in [
      'title',
      'destination_name',
      'status',
      'start_date',
      'end_date',
      'created_at',
    ]) {
      final value = row[key];
      if (value != null && value is! String) {
        throw const SnapshotRejectedException('Invalid trip text header.');
      }
    }
    for (final key in ['start_date', 'end_date', 'created_at']) {
      final value = row[key];
      if (value is String && DateTime.tryParse(value) == null) {
        throw const SnapshotRejectedException('Invalid trip time header.');
      }
    }
    return LegacyTripRowContext(
      id: id,
      userId: owner,
      title: row['title'] as String?,
      destinationName: row['destination_name'] as String?,
      numDays: days as int?,
      budgetTotal: budget as num?,
      status: row['status'] as String?,
      startDate: row['start_date'] as String?,
      endDate: row['end_date'] as String?,
      createdAt: row['created_at'] as String?,
    );
  }

  void close() => _dio.close(force: true);
}

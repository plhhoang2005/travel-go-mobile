import 'package:dio/dio.dart';

import '../models/editable_local_records.dart';
import '../models/editable_remote_records.dart';
import '../models/editable_trip_codec.dart';
import 'local_account_lifecycle_service.dart';

enum EditableRemoteFailure { deploymentBlocked, uncertain, rejected, protocol }

class EditableRemoteException implements Exception {
  final EditableRemoteFailure kind;
  final String code;
  const EditableRemoteException(this.kind, this.code);
  @override
  String toString() => 'Editable trip request: ${kind.name}/$code';
}

/// Tokens belong to individual requests; neither the SDK nor disk receives them.
class EditableTripService {
  final Dio _dio;
  final Uri _origin;
  final String _publicKey;
  final bool Function(AccountSessionProof) isCurrentProof;
  final DateTime Function() _clock;
  String? _capabilityOwner;
  int? _capabilityEpoch;
  bool? _evidenceSupported;

  Future<bool> supportsEvidence({required AccountSessionProof proof}) async {
    _check(proof);
    if (_capabilityOwner == proof.ownerId &&
        _capabilityEpoch == proof.epoch &&
        _evidenceSupported != null) {
      return _evidenceSupported!;
    }
    bool supported;
    try {
      final reply = await _rpc(proof, 'get_trip_capabilities_v1', {});
      supported = _decode(() {
        EditableRecordCodec.keys(reply, 'evidenceV1 ownedListV3');
        if (reply['evidenceV1'] is! bool || reply['ownedListV3'] is! bool) {
          _bad();
        }
        return reply['evidenceV1'] == true && reply['ownedListV3'] == true;
      });
    } on EditableRemoteException catch (e) {
      if (e.kind != EditableRemoteFailure.deploymentBlocked ||
          e.code != 'rpc_missing') {
        rethrow;
      }
      supported = false;
    }
    _check(proof);
    _capabilityOwner = proof.ownerId;
    _capabilityEpoch = proof.epoch;
    _evidenceSupported = supported;
    return supported;
  }

  EditableTripService({
    required String projectUrl,
    required String publicKey,
    required this.isCurrentProof,
    HttpClientAdapter? adapter,
    DateTime Function()? clock,
  }) : _origin = _validateOrigin(projectUrl),
       _publicKey = publicKey,
       _clock = clock ?? DateTime.now,
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 30),
           sendTimeout: const Duration(seconds: 30),
         ),
       ) {
    if (publicKey.trim().isEmpty) {
      throw ArgumentError('Public key is required.');
    }
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  static Uri _validateOrigin(String value) {
    final uri = Uri.parse(value);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError('A fixed HTTPS project origin is required.');
    }
    return uri;
  }

  void _check(AccountSessionProof proof) {
    if (!isCurrentProof(proof) ||
        proof.ownerId.trim().isEmpty ||
        proof.accessToken.trim().isEmpty ||
        proof.expiresAt <= _clock().millisecondsSinceEpoch ~/ 1000 + 10) {
      throw StateError('Editable trip authority is stale.');
    }
  }

  static Never _bad() => throw const EditableRemoteException(
    EditableRemoteFailure.protocol,
    'invalid_reply',
  );

  static T _decode<T>(T Function() body) {
    try {
      return body();
    } catch (_) {
      _bad();
    }
  }

  Future<Map<String, Object?>> _rpc(
    AccountSessionProof proof,
    String name,
    Map<String, Object?> parameters,
  ) async {
    _check(proof);
    try {
      final response = await _dio.postUri<String>(
        _origin.replace(path: '/rest/v1/rpc/$name'),
        data: parameters,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          headers: {
            'Authorization': 'Bearer ${proof.accessToken}',
            'apikey': _publicKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      _check(proof);
      final Map<String, Object?> decoded = _decode(
        () => EditableRecordCodec.object(
          EditableTripCodec.parseStrict(
            response.data ?? '',
            limit: 3 * 1024 * 1024,
          ),
        ),
      );
      return decoded;
    } on DioException catch (error) {
      _check(proof);
      final status = error.response?.statusCode;
      if (status == null || status >= 500 || status == 408 || status == 429) {
        throw const EditableRemoteException(
          EditableRemoteFailure.uncertain,
          'outcome_unknown',
        );
      }
      String? code;
      String? message;
      final raw = error.response?.data;
      if (raw is String) {
        try {
          final body = EditableRecordCodec.object(
            EditableTripCodec.parseStrict(raw, limit: 16384),
          );
          code = body['code'] as String?;
          message = body['message'] as String?;
        } catch (_) {
          // Invalid error text is never used as an outcome or shown to the UI.
        }
      }
      if ({'PGRST202', '42883', '42P01', 'PGRST205'}.contains(code)) {
        throw EditableRemoteException(
          EditableRemoteFailure.deploymentBlocked,
          {'PGRST202', '42883'}.contains(code)
              ? 'rpc_missing'
              : 'editable_schema_unavailable',
        );
      }
      const safeCodes = {
        'version_conflict',
        'request_identity_conflict',
        'source_identity_conflict',
        'invalid_document',
        'invalid_request',
        'source_unavailable',
        'trip_unavailable',
        'unauthorized',
        'evidence_expired',
        'evidence_untrusted',
        'evidence_immutable',
        'evidence_stale_citation',
        'unsupported_schema',
      };
      final safe = safeCodes.contains(message)
          ? message!
          : safeCodes.contains(code)
          ? code!
          : status == 401 || status == 403
          ? 'unauthorized'
          : 'request_rejected';
      throw EditableRemoteException(EditableRemoteFailure.rejected, safe);
    }
  }

  EditableMutationReply _reply(
    Map<String, Object?> json,
    AccountSessionProof proof,
    String requestId, {
    EditablePendingAttempt? attempt,
    bool allowMissing = false,
  }) {
    return _decode(() {
      EditableRecordCodec.keys(json, 'status receipt head');
      if (json['status'] == 'not_found') {
        if (!allowMissing || json['receipt'] != null || json['head'] != null) {
          _bad();
        }
        return const EditableMutationReply(
          status: EditableMutationStatus.notFound,
        );
      }
      final status = switch (json['status']) {
        'committed' => EditableMutationStatus.committed,
        'deleted' => EditableMutationStatus.deleted,
        _ => _bad(),
      };
      final receipt = EditableRecordCodec.receipt(
        EditableRecordCodec.object(json['receipt']),
      );
      if (receipt.ownerId != proof.ownerId ||
          receipt.requestId != requestId ||
          (receipt.operation != 'create' && receipt.sourceBinding != null)) {
        _bad();
      }
      EditableHead? head;
      if (status == EditableMutationStatus.deleted) {
        if (json['head'] != null) _bad();
      } else {
        head = EditableRecordCodec.head(
          EditableRecordCodec.object(json['head']),
        );
        if (receipt.operation == 'delete' ||
            head.ownerId != proof.ownerId ||
            head.tripId != receipt.tripId ||
            head.version < receipt.resultVersion ||
            (head.version == receipt.resultVersion &&
                head.contentDigest != receipt.contentDigest)) {
          _bad();
        }
      }
      if (attempt != null &&
          (receipt.operation != attempt.operation ||
              receipt.requestDigest != attempt.requestDigest ||
              receipt.contentDigest != attempt.contentDigest ||
              receipt.resultVersion != (attempt.expectedVersion ?? 0) + 1 ||
              (attempt.tripId != null && receipt.tripId != attempt.tripId) ||
              EditableTripCodec.canonicalJson(
                    receipt.sourceBinding?.toJson(),
                  ) !=
                  EditableTripCodec.canonicalJson(
                    attempt.sourceBinding?.toJson(),
                  ))) {
        _bad();
      }
      return EditableMutationReply(
        status: status,
        receipt: receipt,
        head: head,
      );
    });
  }

  Future<EditableMutationReply> _mutate(
    String operation,
    AccountSessionProof proof,
    EditablePendingAttempt attempt,
  ) async {
    _check(proof);
    _decode(() => EditableRecordCodec.validateAttempt(attempt));
    if (attempt.ownerId != proof.ownerId || attempt.operation != operation) {
      _bad();
    }
    final json = await _rpc(
      proof,
      attempt.isEvidence
          ? '${operation}_evidence_trip_v1'
          : '${operation}_editable_trip_v2',
      {
        if (operation != 'create') 'p_trip_id': attempt.tripId,
        if (operation != 'create')
          'p_expected_version': attempt.expectedVersion,
        'p_request_id': attempt.requestId,
        if (operation != 'delete') 'p_request_text': attempt.requestText,
        if (operation != 'delete') 'p_request_digest': attempt.requestDigest,
      },
    );
    _check(proof);
    final reply = _reply(json, proof, attempt.requestId, attempt: attempt);
    if (attempt.isEvidence &&
        reply.head != null &&
        reply.head!.evidenceEnvelope == null) {
      _bad();
    }
    return reply;
  }

  Future<EditableMutationReply> create({
    required AccountSessionProof proof,
    required EditablePendingAttempt attempt,
  }) => _mutate('create', proof, attempt);
  Future<EditableMutationReply> update({
    required AccountSessionProof proof,
    required EditablePendingAttempt attempt,
  }) => _mutate('update', proof, attempt);
  Future<EditableMutationReply> delete({
    required AccountSessionProof proof,
    required EditablePendingAttempt attempt,
  }) => _mutate('delete', proof, attempt);

  Future<EditableHead?> read({
    required AccountSessionProof proof,
    required String tripId,
    bool evidence = false,
  }) async {
    _check(proof);
    _decode(() => EditableRecordCodec.id(tripId));
    final json = await _rpc(
      proof,
      evidence ? 'get_evidence_trip_v1' : 'get_editable_trip_v2',
      {'p_trip_id': tripId},
    );
    _check(proof);
    return _decode(() {
      EditableRecordCodec.keys(json, 'status head');
      if (json['status'] == 'unavailable' && json['head'] == null) return null;
      if (json['status'] != 'ready') _bad();
      final head = EditableRecordCodec.head(
        EditableRecordCodec.object(json['head']),
      );
      if (head.tripId != tripId ||
          head.ownerId != proof.ownerId ||
          (evidence && head.evidenceEnvelope == null)) {
        _bad();
      }
      return head;
    });
  }

  Future<EditableMutationReply> lookup({
    required AccountSessionProof proof,
    required String requestId,
    bool evidence = false,
  }) async {
    _check(proof);
    _decode(() => EditableRecordCodec.id(requestId));
    final json = await _rpc(
      proof,
      evidence ? 'get_evidence_mutation_v1' : 'get_editable_mutation_v2',
      {'p_request_id': requestId},
    );
    _check(proof);
    final reply = _reply(json, proof, requestId, allowMissing: true);
    if (evidence &&
        reply.head != null &&
        reply.head!.evidenceEnvelope == null) {
      _bad();
    }
    return reply;
  }

  static bool _older(OwnedTripCursor a, OwnedTripCursor b) =>
      a.createdAt.isBefore(b.createdAt) ||
      (a.createdAt == b.createdAt && a.id.compareTo(b.id) < 0);

  Future<OwnedTripPage> list({
    required AccountSessionProof proof,
    OwnedTripCursor? cursor,
    int limit = 25,
  }) async {
    _check(proof);
    if (limit < 1 || limit > 50) {
      throw ArgumentError('Page limit must be 1..50.');
    }
    if (cursor != null) _decode(() => EditableRecordCodec.id(cursor.id));
    final evidence =
        _capabilityOwner == proof.ownerId &&
        _capabilityEpoch == proof.epoch &&
        _evidenceSupported == true;
    final json = await _rpc(
      proof,
      evidence ? 'list_owned_trips_v3' : 'list_owned_trips_v2',
      {
        'p_before_created_at': cursor?.createdAt.toUtc().toIso8601String(),
        'p_before_id': cursor?.id,
        'p_limit': limit,
      },
    );
    _check(proof);
    return _decode(() {
      EditableRecordCodec.keys(json, 'items nextCursor');
      final rows = json['items'];
      if (rows is! List || rows.length > limit) _bad();
      final items = <OwnedTripSummary>[];
      final ids = <String>{};
      OwnedTripCursor? previous = cursor;
      for (final raw in rows) {
        final row = EditableRecordCodec.object(raw);
        EditableRecordCodec.keys(
          row,
          'kind tripId ownerId title destinationName createdAt version',
        );
        final kind = switch (row['kind']) {
          'legacy_v1' => OwnedTripKind.legacyV1,
          'editable_v2' => OwnedTripKind.editableV2,
          'evidence_v1' when evidence => OwnedTripKind.evidenceV1,
          _ => _bad(),
        };
        final id = EditableRecordCodec.id(row['tripId']);
        final owner = EditableRecordCodec.id(row['ownerId']);
        final date = EditableRecordCodec.utc(row['createdAt']);
        final version = kind != OwnedTripKind.legacyV1
            ? EditableRecordCodec.positive(row['version'])
            : null;
        if (owner != proof.ownerId ||
            !ids.add(id) ||
            (kind == OwnedTripKind.legacyV1 && row['version'] != null)) {
          _bad();
        }
        final next = OwnedTripCursor(date, id);
        if (previous != null && !_older(next, previous)) _bad();
        previous = next;
        items.add(
          OwnedTripSummary(
            kind: kind,
            tripId: id,
            ownerId: owner,
            title: EditableRecordCodec.text(row['title'], max: 200),
            destinationName: EditableRecordCodec.text(
              row['destinationName'],
              max: 200,
            ),
            createdAt: date,
            version: version,
          ),
        );
      }
      OwnedTripCursor? nextCursor;
      if (json['nextCursor'] != null) {
        final raw = EditableRecordCodec.object(json['nextCursor']);
        EditableRecordCodec.keys(raw, 'createdAt id');
        nextCursor = OwnedTripCursor(
          EditableRecordCodec.utc(raw['createdAt']),
          EditableRecordCodec.id(raw['id']),
        );
        if (items.length != limit ||
            previous == null ||
            previous.id != nextCursor.id ||
            previous.createdAt != nextCursor.createdAt) {
          _bad();
        }
      }
      return OwnedTripPage(items: items, nextCursor: nextCursor);
    });
  }

  void close() => _dio.close(force: true);

  Future<EditableHead?> readEvidence({
    required AccountSessionProof proof,
    required String tripId,
  }) => read(proof: proof, tripId: tripId, evidence: true);
  Future<EditableMutationReply> lookupEvidence({
    required AccountSessionProof proof,
    required String requestId,
  }) => lookup(proof: proof, requestId: requestId, evidence: true);
  Future<EditableMutationReply> createEvidence({
    required AccountSessionProof proof,
    required EditablePendingAttempt attempt,
  }) => _evidenceMutation('create', proof, attempt);
  Future<EditableMutationReply> updateEvidence({
    required AccountSessionProof proof,
    required EditablePendingAttempt attempt,
  }) => _evidenceMutation('update', proof, attempt);
  Future<EditableMutationReply> deleteEvidence({
    required AccountSessionProof proof,
    required EditablePendingAttempt attempt,
  }) => _evidenceMutation('delete', proof, attempt);
  Future<EditableMutationReply> _evidenceMutation(
    String op,
    AccountSessionProof proof,
    EditablePendingAttempt attempt,
  ) {
    if (!attempt.isEvidence) _bad();
    return _mutate(op, proof, attempt);
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/local_trip_records.dart';
import '../models/trip_payload_codec.dart';
import 'local_trip_store.dart';

class ImportSource {
  final String deviceScope;
  final String draftId;
  final int revision;
  final String digest;

  const ImportSource({
    required this.deviceScope,
    required this.draftId,
    required this.revision,
    required this.digest,
  });

  @override
  bool operator ==(Object other) =>
      other is ImportSource &&
      deviceScope == other.deviceScope &&
      draftId == other.draftId &&
      revision == other.revision &&
      digest == other.digest;
  @override
  int get hashCode => Object.hash(deviceScope, draftId, revision, digest);
}

class ImportConfirmation {
  final Object _issuer;
  final int _generation;
  final SessionHandle _handle;
  final List<ImportSource> sources;
  ImportConfirmation._(
    this._issuer,
    this._generation,
    this._handle,
    List<ImportSource> sources,
  ) : sources = List.unmodifiable(sources);
}

enum GuestImportStatus {
  committed,
  alreadyCommitted,
  pendingRetry,
  deletedNeedsAttention,
  rejected,
  deploymentBlocked,
  sessionInvalidated,
}

class GuestImportOutcome {
  final ImportSource source;
  final GuestImportStatus status;
  final ImportCommitResult? result;
  final String? reason;
  const GuestImportOutcome(
    this.source,
    this.status, {
    this.result,
    this.reason,
  });
}

/// Credentials are ephemeral; default Object.toString never prints their contents.
class GuestImportCredentials {
  final String ownerId;
  final String accessToken;
  final int expiresAt;
  const GuestImportCredentials({
    required this.ownerId,
    required this.accessToken,
    required this.expiresAt,
  });
}

class GuestImportAuthContext {
  final Session? Function() _reader;
  GuestImportAuthContext(this._reader);
  factory GuestImportAuthContext.supabase(SupabaseClient client) =>
      GuestImportAuthContext(() => client.auth.currentSession);

  GuestImportCredentials capture(String owner) {
    final session = _reader();
    final expiry = session?.expiresAt;
    if (session == null ||
        session.user.id != owner ||
        session.accessToken.trim().isEmpty ||
        session.tokenType.toLowerCase() != 'bearer' ||
        expiry == null ||
        session.isExpired) {
      throw const _ImportRejected('Phiên đăng nhập không hợp lệ.');
    }
    return GuestImportCredentials(
      ownerId: owner,
      accessToken: session.accessToken,
      expiresAt: expiry,
    );
  }
}

abstract interface class GuestImportTransport {
  Future<dynamic> importDraft({
    required GuestImportCredentials credentials,
    required Map<String, dynamic> parameters,
  });
}

/// Dedicated Dio instance avoids shared auth interceptors or automatic retry.
class DioGuestImportTransport implements GuestImportTransport {
  final Dio _dio;
  final String _endpoint;
  final String _publicKey;

  DioGuestImportTransport({
    required String projectUrl,
    required String publicKey,
    HttpClientAdapter? adapter,
  }) : _endpoint = _rpcEndpoint(projectUrl),
       _publicKey = publicKey,
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 15),
           sendTimeout: const Duration(seconds: 30),
           receiveTimeout: const Duration(seconds: 30),
         ),
       ) {
    if (publicKey.trim().isEmpty) {
      throw ArgumentError('Public key is required.');
    }
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  static String _rpcEndpoint(String url) {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError('A fixed HTTPS project origin is required.');
    }
    return uri.replace(path: '/rest/v1/rpc/import_guest_draft_v1').toString();
  }

  @override
  Future<dynamic> importDraft({
    required GuestImportCredentials credentials,
    required Map<String, dynamic> parameters,
  }) async {
    if (credentials.expiresAt <=
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10) {
      throw const _ImportRejected('Phiên đăng nhập đã hết hạn.');
    }
    final response = await _dio.post<dynamic>(
      _endpoint,
      data: parameters,
      options: Options(
        followRedirects: false,
        headers: {
          'Authorization': 'Bearer ${credentials.accessToken}',
          'apikey': _publicKey,
          'Content-Type': 'application/json',
        },
      ),
    );
    return response.data;
  }

  void close() => _dio.close(force: true);
}

class _ImportRejected implements Exception {
  final String reason;
  const _ImportRejected(this.reason);
}

class _SessionInvalidated implements Exception {
  const _SessionInvalidated();
}

class _Flight {
  final ImportSource source;
  final Future<GuestImportOutcome> future;
  _Flight(this.source, this.future);
}

class GuestImportService {
  final LocalTripStore store;
  final GuestImportAuthContext auth;
  final GuestImportTransport transport;
  final String Function() _requestKeyFactory;
  final Object _issuer = Object();
  final Map<String, _Flight> _flights = {};
  SessionHandle? _handle;
  int _generation = 0;
  bool _disposed = false;

  GuestImportService({
    required this.store,
    required this.auth,
    required this.transport,
    String Function()? requestKeyFactory,
  }) : _requestKeyFactory = requestKeyFactory ?? (() => const Uuid().v4());

  void bindSession(SessionHandle handle) {
    unbindSession();
    if (_disposed) throw StateError('Import service is disposed.');
    handle.validate();
    auth.capture(handle.ownerId);
    _handle = handle;
  }

  void unbindSession() {
    _generation++;
    _handle = null;
    _flights.clear();
  }

  void dispose() {
    unbindSession();
    _disposed = true;
  }

  void _check(SessionHandle handle, int generation) {
    if (_disposed || _generation != generation || _handle != handle) {
      throw const _SessionInvalidated();
    }
    try {
      auth.capture(handle.ownerId);
    } catch (_) {
      throw const _SessionInvalidated();
    }
  }

  ImportConfirmation confirmSelection(List<ImportSource> sources) {
    final handle = _handle;
    if (handle == null) throw StateError('An active real account is required.');
    _check(handle, _generation);
    final unique = sources.toSet();
    if (unique.length != sources.length) {
      throw ArgumentError('Duplicate selection.');
    }
    for (final source in sources) {
      _validateSource(source);
    }
    return ImportConfirmation._(_issuer, _generation, handle, sources);
  }

  Future<List<GuestImportOutcome>> importConfirmed(
    ImportConfirmation confirmation,
  ) async {
    if (!identical(confirmation._issuer, _issuer)) {
      throw ArgumentError('Foreign confirmation.');
    }
    final results = <GuestImportOutcome>[];
    for (final source in confirmation.sources) {
      final result = await _singleFlight(
        source,
        confirmation._handle,
        confirmation._generation,
        retryOnly: false,
      );
      try {
        _check(confirmation._handle, confirmation._generation);
      } catch (_) {
        return [
          GuestImportOutcome(source, GuestImportStatus.sessionInvalidated),
        ];
      }
      results.add(result);
      if (result.status == GuestImportStatus.sessionInvalidated) {
        return [
          GuestImportOutcome(source, GuestImportStatus.sessionInvalidated),
        ];
      }
    }
    return List.unmodifiable(results);
  }

  Future<GuestImportOutcome> retry(ImportSource source) {
    final handle = _handle;
    if (handle == null) {
      return Future.value(
        GuestImportOutcome(source, GuestImportStatus.sessionInvalidated),
      );
    }
    return _singleFlight(source, handle, _generation, retryOnly: true);
  }

  Future<GuestImportOutcome> _singleFlight(
    ImportSource source,
    SessionHandle handle,
    int generation, {
    required bool retryOnly,
  }) {
    final key = jsonEncode([
      handle.ownerId,
      handle.storeGeneration,
      generation,
      source.deviceScope,
      source.draftId,
      source.revision,
    ]);
    final existing = _flights[key];
    if (existing != null) {
      if (existing.source != source) {
        return Future.value(
          GuestImportOutcome(
            source,
            GuestImportStatus.rejected,
            reason: 'Nội dung xác nhận không khớp.',
          ),
        );
      }
      return existing.future;
    }
    final future = _run(source, handle, generation, retryOnly: retryOnly);
    final flight = _Flight(source, future);
    _flights[key] = flight;
    unawaited(
      future.then((_) {
        if (identical(_flights[key], flight)) _flights.remove(key);
      }),
    );
    return future;
  }

  static void _identity(String value, int limit) {
    TripPayloadCodec.validateUnicode(value);
    if (value.trim().isEmpty || value.runes.length > limit) {
      throw const _ImportRejected('Định danh bản nháp không hợp lệ.');
    }
  }

  static void _validateSource(ImportSource source) {
    _identity(source.deviceScope, 128);
    _identity(source.draftId, 128);
    if (source.revision < 1 ||
        source.revision > 9007199254740991 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(source.digest)) {
      throw const _ImportRejected('Revision hoặc digest không hợp lệ.');
    }
  }

  static void _bounds(dynamic value, int depth) {
    if (depth > 32) {
      throw const _ImportRejected('Nội dung vượt giới hạn độ sâu.');
    }
    if (value is Map) {
      if (value.length > 256) {
        throw const _ImportRejected('Nội dung vượt giới hạn object.');
      }
      for (final child in value.values) {
        _bounds(child, depth + 1);
      }
    } else if (value is List) {
      if (value.length > 1000) {
        throw const _ImportRejected('Nội dung vượt giới hạn array.');
      }
      for (final child in value) {
        _bounds(child, depth + 1);
      }
    }
  }

  static CanonicalTripPayloadV1 _payload(String text, String digest) {
    final bytes = utf8.encode(text);
    if (bytes.length > 1048576 || sha256.convert(bytes).toString() != digest) {
      throw const _ImportRejected('Nội dung hoặc digest không khớp.');
    }
    final raw = jsonDecode(text);
    _bounds(raw, 1);
    if (raw is! Map ||
        raw['schemaVersion'] is! int ||
        raw['schemaVersion'] != 1) {
      throw const _ImportRejected('Schema không được hỗ trợ.');
    }
    final payload = TripPayloadCodec.decode(raw);
    _numericLimits(raw);
    if (TripPayloadCodec.encode(payload) != text ||
        TripPayloadCodec.computeDigest(payload) != digest) {
      throw const _ImportRejected('Nội dung không ở định dạng canonical.');
    }
    return payload;
  }

  static void _integerLimit(
    dynamic value, {
    int min = 0,
    int max = 9007199254740991,
  }) {
    if (value is! int || value < min || value > max) {
      throw const _ImportRejected('Giá trị số vượt giới hạn server.');
    }
  }

  static void _numericLimits(Map raw) {
    final request = raw['request'];
    if (request is Map) {
      _integerLimit(request['numDays'], min: 1, max: 2147483647);
      _integerLimit(request['numPeople'], min: 1, max: 2147483647);
      _integerLimit(request['budgetVnd']);
    }
    final plan = raw['plan'];
    if (plan is! Map) return;
    final budget = plan['budgetBreakdown'];
    if (budget is Map) {
      for (final value in budget.values) {
        _integerLimit(value);
      }
    }
    for (final destination in plan['topDestinations'] as List) {
      _integerLimit((destination as Map)['estimatedCostVnd']);
    }
    for (final option in plan['transportOptions'] as List) {
      _integerLimit((option as Map)['priceTotalVnd']);
    }
    for (final day in plan['itineraryDays'] as List) {
      _integerLimit((day as Map)['day'], min: 1);
      for (final activity in day['activities'] as List) {
        _integerLimit((activity as Map)['costVnd']);
      }
    }
  }

  static void _receipt(
    LocalImportReceipt receipt,
    LocalImportJournalRecord journal,
  ) {
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (receipt.targetOwner != journal.targetOwner ||
        receipt.deviceScope != journal.deviceScope ||
        receipt.draftId != journal.draftId ||
        receipt.sourceRevision != journal.sourceRevision ||
        receipt.requestKey != journal.requestKey ||
        receipt.contentDigest != journal.contentDigest ||
        receipt.remoteVersion != 1 ||
        !uuid.hasMatch(receipt.receiptId) ||
        !uuid.hasMatch(receipt.tripId) ||
        (journal.cachedReceipt != null &&
            !LocalImportReceipt.areReceiptsEqual(
              journal.cachedReceipt!,
              receipt,
            ))) {
      throw const _ImportRejected('Receipt không khớp yêu cầu chuyển.');
    }
  }

  Future<GuestImportOutcome> _run(
    ImportSource source,
    SessionHandle handle,
    int generation, {
    required bool retryOnly,
  }) async {
    var committing = false;
    try {
      _check(handle, generation);
      _validateSource(source);
      var journal = await store.getJournalEntry(
        handle: handle,
        draftId: source.draftId,
        sourceRevision: source.revision,
        deviceScope: source.deviceScope,
      );
      _check(handle, generation);
      if (journal != null && journal.contentDigest != source.digest) {
        throw const _ImportRejected('Nguồn không khớp journal.');
      }
      if (journal?.state == 'committed') {
        final receipt = journal!.cachedReceipt;
        if (receipt == null) {
          throw const _ImportRejected('Thiếu receipt đã lưu.');
        }
        _receipt(receipt, journal);
        final snapshot = await store.getSnapshot(
          handle: handle,
          tripId: receipt.tripId,
        );
        _check(handle, generation);
        if (snapshot == null) {
          throw const _ImportRejected('Thiếu snapshot đã lưu.');
        }
        final payload = _payload(snapshot.payloadJson, source.digest);
        final result = await store.commitImportAck(
          handle: handle,
          receipt: receipt,
          payload: payload,
        );
        _check(handle, generation);
        return GuestImportOutcome(
          source,
          GuestImportStatus.alreadyCommitted,
          result: result,
        );
      }
      if (retryOnly && journal == null) {
        throw const _ImportRejected('Không có lần chuyển để retry.');
      }
      final row = await store.getDraftRevision(
        draftId: source.draftId,
        revision: source.revision,
        deviceScope: source.deviceScope,
      );
      _check(handle, generation);
      if (row == null || row.digest != source.digest) {
        throw const _ImportRejected('Nguồn đã thay đổi.');
      }
      _payload(row.payloadJson, source.digest);
      final requestKey = journal?.requestKey ?? _requestKeyFactory();
      _identity(requestKey, 256);
      journal = await store.prepareImportJournal(
        handle: handle,
        draftId: source.draftId,
        sourceRevision: source.revision,
        requestKey: requestKey,
        deviceScope: source.deviceScope,
      );
      _check(handle, generation);
      if (journal.state == 'quarantined') {
        if (!retryOnly) {
          throw const _ImportRejected(
            'Cần retry chủ đích cho lần chuyển cách ly.',
          );
        }
        journal = await store.reconcileQuarantinedAttempt(
          handle: handle,
          draftId: source.draftId,
          sourceRevision: source.revision,
          deviceScope: source.deviceScope,
        );
        _check(handle, generation);
      }
      await store.markJournalPendingAck(
        handle: handle,
        draftId: source.draftId,
        sourceRevision: source.revision,
        deviceScope: source.deviceScope,
      );
      _check(handle, generation);
      final credentials = auth.capture(handle.ownerId);
      final raw = await transport
          .importDraft(
            credentials: credentials,
            parameters: {
              'p_device_scope': source.deviceScope,
              'p_draft_id': source.draftId,
              'p_source_revision': source.revision,
              'p_request_key': journal.requestKey,
              'p_payload_text': row.payloadJson,
              'p_content_digest': source.digest,
            },
          )
          .timeout(const Duration(seconds: 45));
      _check(handle, generation);
      if (raw is! Map ||
          raw.length != 3 ||
          !raw.keys.toSet().containsAll({'status', 'receipt', 'payloadText'}) ||
          raw['receipt'] is! Map ||
          !{'committed', 'deleted'}.contains(raw['status'])) {
        throw const _ImportRejected('Phản hồi import không hợp lệ.');
      }
      final receipt = LocalImportReceipt.fromMap(
        Map<String, dynamic>.from(raw['receipt'] as Map),
      );
      _receipt(receipt, journal);
      if (raw['status'] == 'deleted') {
        if (raw['payloadText'] != null) {
          throw const _ImportRejected('Phản hồi deleted không hợp lệ.');
        }
        return GuestImportOutcome(
          source,
          GuestImportStatus.deletedNeedsAttention,
          reason: 'Chuyến đi đã bị xóa; bản nháp vẫn được giữ và cần xử lý.',
        );
      }
      if (raw['payloadText'] is! String ||
          raw['payloadText'] != row.payloadJson) {
        throw const _ImportRejected('Nội dung phản hồi khác bản nháp đã gửi.');
      }
      final payload = _payload(raw['payloadText'] as String, source.digest);
      _check(handle, generation);
      committing = true;
      final result = await store.commitImportAck(
        handle: handle,
        receipt: receipt,
        payload: payload,
      );
      _check(handle, generation);
      return GuestImportOutcome(
        source,
        GuestImportStatus.committed,
        result: result,
      );
    } catch (error) {
      try {
        _check(handle, generation);
      } catch (_) {
        return GuestImportOutcome(source, GuestImportStatus.sessionInvalidated);
      }
      if (error is _SessionInvalidated || error is StaleSessionEpochException) {
        return GuestImportOutcome(source, GuestImportStatus.sessionInvalidated);
      }
      if (error is _ImportRejected) {
        return GuestImportOutcome(
          source,
          GuestImportStatus.rejected,
          reason: error.reason,
        );
      }
      if (error is DioException) {
        final status = error.response?.statusCode;
        final data = error.response?.data;
        final code = data is Map ? data['code'] : null;
        final blocked = status == 404 || code == 'PGRST202';
        final rejected = {400, 401, 403, 409, 422}.contains(status);
        return GuestImportOutcome(
          source,
          blocked
              ? GuestImportStatus.deploymentBlocked
              : rejected
              ? GuestImportStatus.rejected
              : GuestImportStatus.pendingRetry,
          reason: blocked
              ? 'Server chưa hỗ trợ import.'
              : 'Chưa thể xác nhận chuyển; bản nháp vẫn được giữ.',
        );
      }
      if (error is TimeoutException) {
        return GuestImportOutcome(
          source,
          GuestImportStatus.pendingRetry,
          reason: 'Chưa nhận được xác nhận từ server.',
        );
      }
      final invalidData =
          error is CorruptDatabaseException ||
          error is ReceiptBindingMismatchException ||
          error is TripPayloadException ||
          error is FormatException ||
          error is TypeError;
      return GuestImportOutcome(
        source,
        committing && !invalidData
            ? GuestImportStatus.pendingRetry
            : GuestImportStatus.rejected,
        reason: 'Chưa thể hoàn tất chuyển; bản nháp vẫn được giữ.',
      );
    }
  }
}

// Publication service and immutable transport models for TravelGO Discovery V2.
// Implements guarded preview, confirmed publication, and operation tracking.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';

@immutable
class FieldIssue {
  final String code;
  final String path;
  final String message;

  const FieldIssue({
    required this.code,
    required this.path,
    required this.message,
  });

  factory FieldIssue.fromJson(Map<String, dynamic> json) {
    return FieldIssue(
      code: json['code'] as String? ?? 'unknown_issue',
      path: json['path'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

@immutable
class PublicationSummary {
  final int added;
  final int changed;
  final int hidden;

  const PublicationSummary({
    required this.added,
    required this.changed,
    required this.hidden,
  });

  factory PublicationSummary.fromJson(Map<String, dynamic> json) {
    return PublicationSummary(
      added: json['added'] as int? ?? 0,
      changed: json['changed'] as int? ?? 0,
      hidden: json['hidden'] as int? ?? 0,
    );
  }
}

@immutable
class PublicationPreview {
  final String previewId;
  final int sourceRevision;
  final int expectedActiveVersion;
  final String previewDigest;
  final PublicationSummary summary;
  final List<FieldIssue> warnings;
  final List<FieldIssue> blockers;
  final DateTime expiresAt;

  const PublicationPreview({
    required this.previewId,
    required this.sourceRevision,
    required this.expectedActiveVersion,
    required this.previewDigest,
    required this.summary,
    required this.warnings,
    required this.blockers,
    required this.expiresAt,
  });

  bool get hasBlockers => blockers.isNotEmpty;

  factory PublicationPreview.fromJson(Map<String, dynamic> json) {
    final warningsRaw = json['warnings'] as List? ?? const [];
    final blockersRaw = json['blockers'] as List? ?? const [];
    final summaryRaw = json['summary'] as Map<String, dynamic>? ?? const {};

    return PublicationPreview(
      previewId: json['previewId'] as String? ?? '',
      sourceRevision: json['sourceRevision'] as int? ?? 1,
      expectedActiveVersion: json['expectedActiveVersion'] as int? ?? 0,
      previewDigest: json['previewDigest'] as String? ?? '',
      summary: PublicationSummary.fromJson(summaryRaw),
      warnings: warningsRaw.map((w) => FieldIssue.fromJson(w as Map<String, dynamic>)).toList(growable: false),
      blockers: blockersRaw.map((b) => FieldIssue.fromJson(b as Map<String, dynamic>)).toList(growable: false),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

@immutable
class PublicationOperation {
  final String id;
  final String state; // pending, completed, needs_retry, conflict
  final int? version;
  final int? sourceRevision;

  const PublicationOperation({
    required this.id,
    required this.state,
    this.version,
    this.sourceRevision,
  });

  bool get isCompleted => state == 'completed';
  bool get needsRetry => state == 'needs_retry';
  bool get isConflict => state == 'conflict';

  factory PublicationOperation.fromJson(Map<String, dynamic> json) {
    return PublicationOperation(
      id: json['id'] as String? ?? '',
      state: json['state'] as String? ?? 'pending',
      version: json['version'] as int?,
      sourceRevision: json['sourceRevision'] as int?,
    );
  }
}

class AdminPublicationService {
  final Dio dio;
  final Uri projectOrigin;
  final String publicKey;
  final Future<LocalAccountLifecycleService> Function() lifecycleLoader;

  AdminPublicationService({
    required this.dio,
    required this.projectOrigin,
    required this.publicKey,
    required this.lifecycleLoader,
  });

  Uri get _endpoint => projectOrigin.replace(path: '/functions/v1/admin-publication');

  Future<PublicationPreview> preview({
    required String requestId,
    required int draftRevision,
  }) async {
    final lifecycle = await lifecycleLoader();
    final proof = lifecycle.captureProof();

    try {
      final response = await dio.postUri(
        _endpoint,
        data: {
          'contract': 'travelgo.admin.publication.v1',
          'action': 'preview',
          'request': {
            'requestId': requestId,
            'draftRevision': draftRevision,
          },
        },
        options: Options(
          headers: {
            'apikey': publicKey,
            'Authorization': 'Bearer ${proof.accessToken}',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      if (!lifecycle.isCurrentProof(proof)) {
        throw const AdminFailure(code: 'stale_session', message: 'Phiên đã thay đổi trong quá trình xử lý');
      }

      final data = response.data as Map<String, dynamic>;
      final previewData = data['preview'] as Map<String, dynamic>? ?? const {};
      return PublicationPreview.fromJson(previewData);
    } on DioException catch (e) {
      if (!lifecycle.isCurrentProof(proof)) {
        throw const AdminFailure(code: 'stale_session', message: 'Phiên đã thay đổi');
      }
      throw _mapDioError(e);
    }
  }

  Future<PublicationOperation> publish({
    required String requestId,
    required PublicationPreview preview,
    required int expectedDraftRevision,
    required int expectedActiveVersion,
  }) async {
    final lifecycle = await lifecycleLoader();
    final proof = lifecycle.captureProof();

    try {
      final response = await dio.postUri(
        _endpoint,
        data: {
          'contract': 'travelgo.admin.publication.v1',
          'action': 'publish',
          'request': {
            'requestId': requestId,
            'previewId': preview.previewId,
            'previewDigest': preview.previewDigest,
            'expectedDraftRevision': expectedDraftRevision,
            'expectedActiveVersion': expectedActiveVersion,
          },
        },
        options: Options(
          headers: {
            'apikey': publicKey,
            'Authorization': 'Bearer ${proof.accessToken}',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (!lifecycle.isCurrentProof(proof)) {
        throw const AdminFailure(code: 'stale_session', message: 'Phiên đã thay đổi');
      }

      final data = response.data as Map<String, dynamic>;
      final opData = data['operation'] as Map<String, dynamic>? ?? const {};
      return PublicationOperation.fromJson(opData);
    } on DioException catch (e) {
      if (!lifecycle.isCurrentProof(proof)) {
        throw const AdminFailure(code: 'stale_session', message: 'Phiên đã thay đổi');
      }
      throw _mapDioError(e);
    }
  }

  Future<PublicationOperation> operation(String operationId) async {
    final lifecycle = await lifecycleLoader();
    final proof = lifecycle.captureProof();

    try {
      final response = await dio.postUri(
        _endpoint,
        data: {
          'contract': 'travelgo.admin.publication.v1',
          'action': 'operation',
          'request': {
            'operationId': operationId,
          },
        },
        options: Options(
          headers: {
            'apikey': publicKey,
            'Authorization': 'Bearer ${proof.accessToken}',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final opData = data['operation'] as Map<String, dynamic>? ?? const {};
      return PublicationOperation.fromJson(opData);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  AdminFailure _mapDioError(DioException e) {
    if (e.response != null) {
      final status = e.response!.statusCode ?? 500;
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        return AdminFailure(
          code: data['code'] as String? ?? 'http_$status',
          message: data['message'] as String? ?? 'Lỗi máy chủ ($status)',
          outcomeUncertain: status >= 500,
        );
      }
      return AdminFailure(
        code: 'http_$status',
        message: 'Lỗi máy chủ ($status)',
        outcomeUncertain: status >= 500,
      );
    }
    return AdminFailure(
      code: 'network_error',
      message: e.message ?? 'Lỗi kết nối mạng',
      outcomeUncertain: true,
    );
  }
}

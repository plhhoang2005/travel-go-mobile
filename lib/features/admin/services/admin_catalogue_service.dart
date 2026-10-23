// Catalogue Service for TravelGO mobile administration.
// Consumes PostgreSQL RPC endpoints /rest/v1/rpc/admin_discovery and /admin_discovery_command.

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';

class AdminCatalogueService {
  final Dio dio;
  final Uri projectOrigin;
  final String publicKey;
  final Future<LocalAccountLifecycleService> Function() lifecycleLoader;

  AdminCatalogueService({
    required this.dio,
    required this.projectOrigin,
    required this.publicKey,
    required this.lifecycleLoader,
  });

  Future<T> _callRpc<T>({
    required String rpcName,
    required Map<String, dynamic> body,
    required T Function(dynamic data) mapper,
    bool isMutation = false,
  }) async {
    final lifecycle = await lifecycleLoader();
    final proof = lifecycle.captureProof();
    final releaseOp = lifecycle.beginAccountOperation(proof);

    try {
      final endpoint = projectOrigin.resolve('/rest/v1/rpc/$rpcName');
      final response = await dio.postUri(
        endpoint,
        data: body,
        options: Options(
          followRedirects: false,
          headers: {
            'Authorization': 'Bearer ${proof.accessToken}',
            'apikey': publicKey,
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );

      if (!lifecycle.isCurrentProof(proof)) {
        throw const AdminFailure(
          code: 'stale_session',
          message: 'Account session changed during catalogue request',
        );
      }

      return mapper(response.data);
    } on DioException catch (dioErr) {
      if (!lifecycle.isCurrentProof(proof)) {
        throw const AdminFailure(
          code: 'stale_session',
          message: 'Account session changed during catalogue error',
        );
      }

      final statusCode = dioErr.response?.statusCode;
      final respData = dioErr.response?.data;
      String errorCode = 'rpc_error';
      String message = 'Catalogue RPC failed';

      if (respData is Map<String, dynamic>) {
        errorCode = respData['code'] as String? ?? errorCode;
        message = respData['message'] as String? ?? message;
      }

      if (statusCode == 401) {
        throw const AdminFailure(code: 'unauthorized', message: 'Unauthorized');
      } else if (statusCode == 403) {
        throw AdminFailure(code: 'admin_required', message: message);
      } else if (statusCode == 409 || errorCode == '40001' || message.contains('conflict')) {
        throw AdminFailure(code: 'conflict', message: message);
      } else if (statusCode == 503 ||
          dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout ||
          dioErr.type == DioExceptionType.sendTimeout ||
          dioErr.type == DioExceptionType.unknown) {
        throw AdminFailure(
          code: 'upstream_unavailable',
          outcomeUncertain: isMutation,
          message: isMutation
              ? 'Catalogue command outcome uncertain due to network timeout'
              : 'Network failure communicating with catalogue',
        );
      }

      throw AdminFailure(
        code: errorCode,
        message: message,
      );
    } finally {
      releaseOp();
    }
  }

  Future<AdminCatalogueSnapshot> read() {
    return _callRpc(
      rpcName: 'admin_discovery',
      body: {},
      mapper: (data) => AdminCatalogueSnapshot.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<AdminCatalogueSnapshot> version(int revision) {
    return _callRpc(
      rpcName: 'admin_discovery',
      body: {'p_version': revision},
      mapper: (data) => AdminCatalogueSnapshot.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<AdminCatalogueSnapshot> command({
    required String requestId,
    required int expectedRevision,
    required Map<String, Object?> command,
    required String reason,
  }) {
    return _callRpc(
      rpcName: 'admin_discovery_command',
      body: {
        'p_request_id': requestId,
        'p_expected_revision': expectedRevision,
        'p_command': command,
        'p_reason': reason,
      },
      isMutation: true,
      mapper: (data) => AdminCatalogueSnapshot.fromJson(data as Map<String, dynamic>),
    );
  }
}

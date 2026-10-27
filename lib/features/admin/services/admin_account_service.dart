// Administration Service for TravelGO mobile client.
// Consumes POST /functions/v1/admin-control under contract travelgo.admin.v1.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';

class AdminAccountService {
  final Dio dio;
  final Uri projectOrigin;
  final String publicKey;
  final Future<LocalAccountLifecycleService> Function() lifecycleLoader;
  final ({String? ownerId, int epoch}) Function()? callerContext;

  AdminAccountService({
    required this.dio,
    required this.projectOrigin,
    required this.publicKey,
    required this.lifecycleLoader,
    this.callerContext,
  });

  Uri get _endpoint => projectOrigin.resolve('/functions/v1/admin-control');

  Future<T> _execute<T>({
    required String action,
    required Map<String, dynamic> requestData,
    required T Function(dynamic data) mapper,
    bool isMutation = false,
  }) async {
    final caller = callerContext?.call();
    final lifecycle = await lifecycleLoader();
    if (caller != null &&
        (caller != callerContext?.call() || caller.ownerId == null)) {
      throw const AdminFailure(
        code: 'stale_session',
        message: 'Caller changed before dispatch',
      );
    }
    final proof = lifecycle.captureProof();
    if (caller != null && proof.ownerId != caller.ownerId) {
      throw const AdminFailure(
        code: 'stale_session',
        message: 'Wrong caller proof',
      );
    }
    final releaseOp = lifecycle.beginAccountOperation(proof);

    try {
      final payload = {
        'contract': 'travelgo.admin.v1',
        'action': action,
        'request': requestData,
      };

      final response = await dio.postUri(
        _endpoint,
        data: payload,
        options: Options(
          followRedirects: false,
          headers: {
            'Authorization': 'Bearer ${proof.accessToken}',
            'apikey': publicKey,
            'Content-Type': 'application/json',
          },
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      if (!lifecycle.isCurrentProof(proof)) {
        throw const AdminFailure(
          code: 'stale_session',
          message: 'Account session epoch changed during admin request',
        );
      }

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const AdminFailure(
          code: 'invalid_response',
          message: 'Malformed response structure from admin server',
        );
      }

      final status = body['status'];
      if (status != 'ok' && status != 'pending') {
        final code = body['code'] as String? ?? 'protocol_error';
        final field = body['field'] as String?;
        throw AdminFailure(
          code: code,
          field: field,
          message: 'Admin command failed with status: $status',
        );
      }

      final result = mapper(body['data']);
      if (result is AdminAccess && result.subjectId != proof.ownerId) {
        throw const FormatException('Wrong access subject');
      }
      return result;
    } on DioException catch (dioErr) {
      if (!lifecycle.isCurrentProof(proof)) {
        throw const AdminFailure(
          code: 'stale_session',
          message: 'Account session changed during failed admin request',
        );
      }

      final statusCode = dioErr.response?.statusCode;
      final respData = dioErr.response?.data;
      String errorCode = 'network_error';
      String? errorField;

      if (respData is Map<String, dynamic>) {
        errorCode = respData['code'] as String? ?? errorCode;
        errorField = respData['field'] as String?;
      }

      if (statusCode == 401) {
        throw const AdminFailure(
          code: 'unauthorized',
          message: 'Unauthorized caller session',
        );
      } else if (statusCode == 403) {
        if (errorCode == 'account_locked') {
          throw const AdminFailure(
            code: 'account_locked',
            message: 'Caller account is locked',
          );
        }
        throw AdminFailure(
          code: errorCode == 'admin_required' ? 'admin_required' : 'forbidden',
          field: errorField,
          message: 'Forbidden admin action',
        );
      } else if (statusCode == 409) {
        throw AdminFailure(
          code: errorCode,
          field: errorField,
          message: 'Conflict in admin mutation or revision',
        );
      } else if (statusCode == 422) {
        throw AdminFailure(
          code: errorCode,
          field: errorField,
          message: 'Invalid admin request field',
        );
      } else if ((statusCode != null && statusCode >= 500) ||
          dioErr.type == DioExceptionType.connectionError ||
          dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout ||
          dioErr.type == DioExceptionType.sendTimeout ||
          dioErr.type == DioExceptionType.unknown) {
        throw AdminFailure(
          code: statusCode != null && statusCode >= 500
              ? 'upstream_unavailable'
              : 'network_error',
          field: errorField,
          outcomeUncertain: isMutation,
          message: isMutation
              ? 'Request outcome uncertain due to network/server timeout'
              : 'Network failure communicating with admin control',
        );
      }

      throw AdminFailure(
        code: errorCode,
        field: errorField,
        message: 'Admin request failed with HTTP $statusCode',
      );
    } on FormatException {
      throw AdminFailure(
        code: 'invalid_response',
        outcomeUncertain: isMutation,
        message: 'Invalid admin response',
      );
    } on TypeError {
      throw AdminFailure(
        code: 'invalid_response',
        outcomeUncertain: isMutation,
        message: 'Invalid admin response',
      );
    } finally {
      releaseOp();
    }
  }

  Future<AdminAccess> access() {
    return _execute(
      action: 'access',
      requestData: {},
      mapper: (data) => AdminAccess.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<UserPage> listUsers({
    String query = '',
    String? role,
    String? state,
    UserCursor? cursor,
  }) {
    final req = <String, dynamic>{'query': query, 'limit': 25};
    if (role != null) req['role'] = role;
    if (state != null) req['state'] = state;
    if (cursor != null) req['cursor'] = cursor.toJson();

    return _execute(
      action: 'users',
      requestData: req,
      mapper: (data) => UserPage.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<UserDetail> getUser(String targetId) {
    return _execute(
      action: 'user',
      requestData: {'targetId': targetId},
      mapper: (data) {
        final detail = UserDetail.fromJson(data as Map<String, dynamic>);
        if (detail.id != targetId) throw const FormatException('Wrong user');
        return detail;
      },
    );
  }

  Future<DashboardSnapshot> dashboard({required int days}) {
    return _execute(
      action: 'dashboard',
      requestData: {'days': days},
      mapper: (data) =>
          DashboardSnapshot.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<AccountOperation> mutate({
    required String requestId,
    required String targetId,
    required int expectedRevision,
    required String action,
    required String reason,
  }) {
    return _execute(
      action: 'mutate',
      requestData: {
        'requestId': requestId,
        'targetId': targetId,
        'expectedRevision': expectedRevision,
        'action': action,
        'reason': reason,
      },
      isMutation: true,
      mapper: (data) {
        final op = AccountOperation.fromJson(data as Map<String, dynamic>);
        if (op.id != requestId ||
            op.targetId != targetId ||
            op.action != action ||
            op.targetRevision != expectedRevision + 1) {
          throw const FormatException('Wrong operation');
        }
        return op;
      },
    );
  }

  Future<AccountOperation> operation(String operationId) {
    return _execute(
      action: 'operation',
      requestData: {'operationId': operationId},
      mapper: (data) {
        final operation = AccountOperation.fromJson(
          data as Map<String, dynamic>,
        );
        if (operation.id != operationId) {
          throw const FormatException('Wrong receipt');
        }
        return operation;
      },
    );
  }

  Future<AccountOperation> reconcile({
    required String requestId,
    required String operationId,
    required int expectedRevision,
    required String reason,
  }) {
    return _execute(
      action: 'reconcile',
      requestData: {
        'requestId': requestId,
        'operationId': operationId,
        'expectedRevision': expectedRevision,
        'reason': reason,
      },
      isMutation: true,
      mapper: (data) {
        final operation = AccountOperation.fromJson(
          data as Map<String, dynamic>,
        );
        if (operation.id != operationId ||
            operation.targetRevision != expectedRevision) {
          throw const FormatException('Wrong reconcile receipt');
        }
        return operation;
      },
    );
  }
}

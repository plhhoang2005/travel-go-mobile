import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

/// QA-only transport wrapper for the P3.2 main-UI lost-reply case.
///
/// Enabled only by `TRAVELGO_P32_DROP_UI_REPLY=true` at build time. It drops the
/// first successful UPDATE response whose payload contains a P32 lost-reply
/// title, after the real server has committed it. Normal builds never install
/// this adapter.
class P32DropCommittedReplyAdapter implements HttpClientAdapter {
  static const targetTitle = 'P32_UI_1810_A';
  final HttpClientAdapter _delegate = IOHttpClientAdapter();
  bool dropped = false;
  int matchedRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isUpdate = options.uri.path.endsWith('/update_editable_trip_v2');
    var target = false;
    if (isUpdate) {
      try {
        final data = options.data;
        target = data is Map && jsonEncode(data).contains(targetTitle);
      } catch (_) {
        target = false;
      }
    }
    if (target) matchedRequests++;
    final response = await _delegate.fetch(
      options,
      requestStream,
      cancelFuture,
    );
    if (target && !dropped && response.statusCode == 200) {
      await response.stream.drain<void>();
      dropped = true;
      debugPrint('[P32 UI reply] committed_response_dropped=true');
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return response;
  }

  @override
  void close({bool force = false}) => _delegate.close(force: force);
}

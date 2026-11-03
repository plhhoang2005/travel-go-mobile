import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_models.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_settings.dart';
import 'package:travelgo_mobile/features/trip_planner/services/local_ai_service.dart';

class OllamaTestAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handle;
  final requests = <RequestOptions>[];
  OllamaTestAdapter(this.handle);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handle(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody ollamaJson(Object? data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );

Map<String, Object?> ollamaAnswer([String content = 'Xin chào từ Ollama']) => {
  'done': true,
  'message': {'role': 'assistant', 'content': content},
};

Matcher failureCode(LocalAiFailureCode code) =>
    isA<LocalAiFailure>().having((f) => f.code, 'code', code);

void main() {
  test('request uses selected settings and bounded local generation', () async {
    final adapter = OllamaTestAdapter((_) async => ollamaJson(ollamaAnswer()));
    final service = LocalAiService(dio: Dio()..httpClientAdapter = adapter);
    final reply = await service.requestReply(
      'Du lịch Huế',
      settings: LocalAiSettings(
        baseUrl: 'http://10.0.2.2:11434',
        systemPrompt: 'Chỉ tư vấn du lịch.',
        temperature: 0.2,
      ),
    );
    expect(reply, 'Xin chào từ Ollama');
    expect(adapter.requests, hasLength(1));
    final request = adapter.requests.single;
    expect(request.uri.toString(), 'http://10.0.2.2:11434/api/chat');
    expect(request.data['model'], 'qwen3:4b-instruct-2507-q4_K_M');
    expect(request.data['messages'], [
      {'role': 'system', 'content': 'Chỉ tư vấn du lịch.'},
      {'role': 'user', 'content': 'Du lịch Huế'},
    ]);
    expect(request.data['stream'], false);
    expect(request.data['think'], false);
    expect(request.data['options'], {
      'temperature': 0.2,
      'num_ctx': 2048,
      'num_predict': 256,
    });
    expect(request.connectTimeout, const Duration(seconds: 5));
    expect(request.sendTimeout, const Duration(seconds: 15));
    expect(request.receiveTimeout, const Duration(seconds: 120));
  });

  for (final item in [
    (
      404,
      {'error': 'model qwen3:4b-instruct-2507-q4_K_M not found'},
      LocalAiFailureCode.modelMissing,
    ),
    (404, {'error': 'unknown endpoint'}, LocalAiFailureCode.server),
    (500, {'error': 'private server details'}, LocalAiFailureCode.server),
    (
      200,
      {
        'done': false,
        'message': {'role': 'assistant', 'content': 'partial'},
      },
      LocalAiFailureCode.invalidResponse,
    ),
    (
      200,
      {
        'done': true,
        'done_reason': 'length',
        'message': {'role': 'assistant', 'content': 'truncated'},
      },
      LocalAiFailureCode.invalidResponse,
    ),
    (
      200,
      {
        'done': true,
        'message': {'role': 'assistant', 'content': '   '},
      },
      LocalAiFailureCode.invalidResponse,
    ),
    (
      200,
      {
        'done': true,
        'message': {'role': 'user', 'content': 'echo'},
      },
      LocalAiFailureCode.invalidResponse,
    ),
    (200, {'unexpected': true}, LocalAiFailureCode.invalidResponse),
  ]) {
    test('HTTP ${item.$1} ${item.$2} fails transparently', () async {
      final adapter = OllamaTestAdapter(
        (_) async => ollamaJson(item.$2, item.$1),
      );
      final service = LocalAiService(dio: Dio()..httpClientAdapter = adapter);
      await expectLater(
        service.requestReply('Huế', settings: LocalAiSettings()),
        throwsA(failureCode(item.$3)),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.cancel,
  ]) {
    test('maps $type to typed failure', () async {
      final adapter = OllamaTestAdapter(
        (o) async => throw DioException(requestOptions: o, type: type),
      );
      final service = LocalAiService(dio: Dio()..httpClientAdapter = adapter);
      final expected = type == DioExceptionType.cancel
          ? LocalAiFailureCode.cancelled
          : type == DioExceptionType.connectionError
          ? LocalAiFailureCode.connection
          : LocalAiFailureCode.timeout;
      await expectLater(
        service.requestReply('Huế', settings: LocalAiSettings()),
        throwsA(failureCode(expected)),
      );
    });
  }

  test(
    'connection check verifies selected model and genuine generation',
    () async {
      final adapter = OllamaTestAdapter(
        (o) async => ollamaJson(
          o.method == 'GET'
              ? {
                  'models': [
                    {'name': 'qwen3:4b-instruct-2507-q4_K_M'},
                  ],
                }
              : ollamaAnswer(),
        ),
      );
      final service = LocalAiService(dio: Dio()..httpClientAdapter = adapter);
      final check = await service.checkConnection(LocalAiSettings());
      expect(check.modelName, 'qwen3:4b-instruct-2507-q4_K_M');
      expect(check.elapsed, isA<Duration>());
      expect(adapter.requests.map((o) => o.uri.path), [
        '/api/tags',
        '/api/chat',
      ]);
    },
  );

  test('missing model never makes a generation request', () async {
    final adapter = OllamaTestAdapter(
      (_) async => ollamaJson({
        'models': [
          {'name': 'other:4b'},
        ],
      }),
    );
    final service = LocalAiService(dio: Dio()..httpClientAdapter = adapter);
    await expectLater(
      service.checkConnection(LocalAiSettings()),
      throwsA(failureCode(LocalAiFailureCode.modelMissing)),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('model list alone cannot report successful connection', () async {
    final adapter = OllamaTestAdapter(
      (o) async => ollamaJson(
        o.method == 'GET'
            ? {
                'models': [
                  {'name': 'qwen3:4b-instruct-2507-q4_K_M'},
                ],
              }
            : ollamaAnswer(''),
      ),
    );
    final service = LocalAiService(dio: Dio()..httpClientAdapter = adapter);
    await expectLater(
      service.checkConnection(LocalAiSettings()),
      throwsA(failureCode(LocalAiFailureCode.invalidResponse)),
    );
  });

  test('legacy chat preserves history and custom host model', () async {
    final adapter = OllamaTestAdapter((_) async => ollamaJson(ollamaAnswer()));
    final service = LocalAiService(
      dio: Dio()..httpClientAdapter = adapter,
      ollamaBaseUrl: 'http://localhost:11435',
      modelName: 'custom:small',
    );
    await service.sendChatMessage(
      'Ngày hai?',
      history: [
        LocalChatMessage(
          text: 'Tôi đi Huế',
          isUser: true,
          timestamp: DateTime(2026),
        ),
      ],
    );
    expect(adapter.requests.single.uri.host, 'localhost');
    expect(adapter.requests.single.data['model'], 'custom:small');
    expect(adapter.requests.single.data['messages'][1], {
      'role': 'user',
      'content': 'Tôi đi Huế',
    });
  });
}

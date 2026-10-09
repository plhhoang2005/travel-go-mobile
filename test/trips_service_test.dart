// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';
import 'package:travelgo_mobile/features/trips/services/trips_service.dart';

const String testUserId = '11111111-1111-4111-8111-111111111111';
const String testTripId = '22222222-2222-4222-8222-222222222222';

void main() {
  group('TripsService Real SDK Security & Exact Acknowledgement (Task 2)', () {
    int authCalls = 0;
    int restCalls = 0;

    String createToken({required String userId, bool expired = false}) {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final exp = expired ? nowSec - 3600 : nowSec + 3600;
      final tokenPayload = base64Url
          .encode(
            utf8.encode(
              jsonEncode({'sub': userId, 'exp': exp, 'role': 'authenticated'}),
            ),
          )
          .replaceAll('=', '');
      return 'eyJhbGciOiJIUzI1NiJ9.$tokenPayload.synthetic';
    }

    SupabaseClient createRealClient({
      required Future<http.Response> Function(http.Request req) restHandler,
      String userId = testUserId,
      bool expired = false,
    }) {
      authCalls = 0;
      restCalls = 0;

      final token = createToken(userId: userId, expired: expired);

      return SupabaseClient(
        'https://test-project.supabase.co',
        'synthetic-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((req) async {
          if (req.url.path == '/auth/v1/token') {
            authCalls++;
            return http.Response(
              jsonEncode({
                'access_token': token,
                'token_type': 'bearer',
                'expires_in': expired ? -3600 : 3600,
                'refresh_token': 'synthetic-refresh',
                'user': {
                  'id': userId,
                  'aud': 'authenticated',
                  'role': 'authenticated',
                  'email': 'user@example.com',
                  'app_metadata': {},
                  'user_metadata': {},
                  'created_at': '2026-10-08T00:00:00Z',
                },
              }),
              200,
              request: req,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }

          restCalls++;
          return restHandler(req);
        }),
      );
    }

    test('delete_rejects_multiple_ack_rows (REV-003 Red Probe)', () async {
      final client = createRealClient(
        restHandler: (req) async {
          expect(req.method, 'DELETE');
          expect(req.url.path, '/rest/v1/trips');
          expect(req.url.queryParameters['id'], 'eq.$testTripId');
          expect(req.url.queryParameters['user_id'], 'eq.$testUserId');
          expect(req.url.queryParameters['select'], 'id,user_id');

          return http.Response(
            jsonEncode([
              {'id': testTripId, 'user_id': testUserId},
              {'id': 'unexpected-extra-row', 'user_id': testUserId},
            ]),
            200,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );

      try {
        await client.auth.signInWithPassword(
          email: 'user@example.com',
          password: 'secret',
        );
        expect(client.auth.currentSession, isNotNull);
        expect(authCalls, 1);

        final service = TripsService(client: client);
        final result = await service.deleteTrip(
          tripId: testTripId,
          userId: testUserId,
        );

        expect(restCalls, 1);
        expect(
          result,
          isFalse,
          reason: 'Response containing multiple rows must NOT be acknowledged as valid single delete',
        );
      } finally {
        await client.dispose();
      }
    });

    test('delete_acknowledges_exactly_one_matching_row', () async {
      final client = createRealClient(
        restHandler: (req) async {
          expect(req.headers['authorization'], startsWith('Bearer eyJ'));
          return http.Response(
            jsonEncode([
              {'id': testTripId, 'user_id': testUserId},
            ]),
            200,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );

      try {
        await client.auth.signInWithPassword(
          email: 'user@example.com',
          password: 'secret',
        );
        final service = TripsService(client: client);
        final result = await service.deleteTrip(
          tripId: testTripId,
          userId: testUserId,
        );

        expect(restCalls, 1);
        expect(result, isTrue);
      } finally {
        await client.dispose();
      }
    });

    test('delete_rejects_zero_rows_response', () async {
      final client = createRealClient(
        restHandler: (req) async => http.Response(
          '[]',
          200,
          request: req,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      try {
        await client.auth.signInWithPassword(
          email: 'user@example.com',
          password: 'secret',
        );
        final service = TripsService(client: client);
        final result = await service.deleteTrip(
          tripId: testTripId,
          userId: testUserId,
        );

        expect(restCalls, 1);
        expect(result, isFalse);
      } finally {
        await client.dispose();
      }
    });

    test('delete_rejects_mismatched_id_or_owner', () async {
      final client = createRealClient(
        restHandler: (req) async => http.Response(
          jsonEncode([
            {'id': 'different-id', 'user_id': testUserId},
          ]),
          200,
          request: req,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      try {
        await client.auth.signInWithPassword(
          email: 'user@example.com',
          password: 'secret',
        );
        final service = TripsService(client: client);
        final result = await service.deleteTrip(
          tripId: testTripId,
          userId: testUserId,
        );

        expect(result, isFalse);
      } finally {
        await client.dispose();
      }
    });

    test('fetchTrips fails closed synchronously when session is null, mismatched, or expired', () async {
      // 1. Session null
      final clientNoAuth = createRealClient(
        restHandler: (req) async => http.Response('[]', 200, request: req),
      );
      try {
        final service = TripsService(client: clientNoAuth);
        expect(
          () => service.fetchTrips(testUserId),
          throwsA(isA<StateError>()),
        );
        expect(restCalls, 0);
      } finally {
        await clientNoAuth.dispose();
      }

      // 2. Mismatched userId
      final clientMismatch = createRealClient(
        restHandler: (req) async => http.Response('[]', 200, request: req),
      );
      try {
        await clientMismatch.auth.signInWithPassword(
          email: 'user@example.com',
          password: 'secret',
        );
        final service = TripsService(client: clientMismatch);
        expect(
          () => service.fetchTrips('different-user-id'),
          throwsA(isA<StateError>()),
        );
        expect(restCalls, 0);
      } finally {
        await clientMismatch.dispose();
      }

      // 3. Expired session
      final clientExpired = createRealClient(
        restHandler: (req) async => http.Response('[]', 200, request: req),
        expired: true,
      );
      try {
        await clientExpired.auth.signInWithPassword(
          email: 'user@example.com',
          password: 'secret',
        );
        expect(clientExpired.auth.currentSession?.isExpired, isTrue);
        final service = TripsService(client: clientExpired);
        expect(
          () => service.fetchTrips(testUserId),
          throwsA(isA<StateError>()),
        );
        expect(restCalls, 0);
      } finally {
        await clientExpired.dispose();
      }
    });

    test('saveTrip validates required fields and verifies server ID & owner acknowledgement', () async {
      final client = createRealClient(
        restHandler: (req) async {
          expect(req.method, 'POST');
          expect(req.url.path, '/rest/v1/trips');
          final decodedBody = jsonDecode(req.body) as Map<String, dynamic>;
          // Verification: ai_plan_data exists in payload, NOT legacy trip_plan_data
          expect(decodedBody['ai_plan_data'], isNotNull);
          expect(decodedBody['trip_plan_data'], isNull);

          return http.Response(
            jsonEncode({
              'id': testTripId,
              'user_id': testUserId,
              'title': 'Chuyến đi Phú Quốc',
              'destination_name': 'Phú Quốc',
              'num_days': 4,
              'budget_total': 8000000,
              'ai_plan_data': {'hotel': 'Resort'},
              'created_at': '2026-10-08T00:00:00Z',
            }),
            201,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );

      try {
        await client.auth.signInWithPassword(
          email: 'user@example.com',
          password: 'secret',
        );
        final service = TripsService(client: client);

        final validTrip = SavedTrip(
          id: '',
          userId: testUserId,
          title: 'Chuyến đi Phú Quốc',
          destinationName: 'Phú Quốc',
          numDays: 4,
          budgetTotal: 8000000,
          tripPlanData: {'hotel': 'Resort'},
          createdAt: DateTime.now(),
        );

        final saved = await service.saveTrip(validTrip);
        expect(saved.id, testTripId);
        expect(saved.userId, testUserId);
        expect(restCalls, 1);
      } finally {
        await client.dispose();
      }
    });

    test(
      'deleteTrip propagates PostgrestException when server returns 401/403',
      () async {
        final client = createRealClient(
          restHandler: (req) async => http.Response(
            jsonEncode({
              'code': '42501',
              'message': 'permission denied for table trips',
            }),
            403,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        );

        try {
          await client.auth.signInWithPassword(
            email: 'user@example.com',
            password: 'secret',
          );
          final service = TripsService(client: client);

          expect(
            () => service.deleteTrip(tripId: testTripId, userId: testUserId),
            throwsA(isA<PostgrestException>()),
          );
        } finally {
          await client.dispose();
        }
      },
    );
  });
}

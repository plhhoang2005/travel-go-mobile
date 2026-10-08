// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';
import 'package:travelgo_mobile/features/trips/services/trips_service.dart';

class _FakeAuthClient extends GoTrueClient {
  Session? _mockSession;

  _FakeAuthClient({Session? initialSession}) : _mockSession = initialSession, super();

  void updateMockSession(Session? session) {
    _mockSession = session;
  }

  @override
  Session? get currentSession => _mockSession;

  @override
  User? get currentUser => _mockSession?.user;
}

class _FakeSupabaseClient extends SupabaseClient {
  final _FakeAuthClient mockAuthClient;

  _FakeSupabaseClient({
    required this.mockAuthClient,
    required http.Client httpClient,
  }) : super(
          'https://test-project.supabase.co',
          'anon-key-test',
          httpClient: httpClient,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );

  @override
  GoTrueClient get auth => mockAuthClient;
}

void main() {
  group('TripsService Security & Acknowledgement (REV-003, REV-004)', () {
    late int httpCalls;
    late _FakeAuthClient fakeAuth;
    late _FakeSupabaseClient client;

    Session createSession({
      required String userId,
      bool expired = false,
    }) {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = expired ? nowSec - 3600 : nowSec + 3600;

      final header = base64Url
          .encode(utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})))
          .replaceAll('=', '');
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({
            'sub': userId,
            'exp': expiresAt,
            'role': 'authenticated',
          })))
          .replaceAll('=', '');
      final token = '$header.$payload.mock-signature';

      return Session(
        accessToken: token,
        tokenType: 'bearer',
        expiresIn: expired ? -3600 : 3600,
        refreshToken: 'mock-refresh-$userId',
        user: User(
          id: userId,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00.000Z',
        ),
      );
    }

    TripsService setupService({
      required Future<http.Response> Function(http.Request request) handler,
      Session? initialSession,
    }) {
      httpCalls = 0;
      fakeAuth = _FakeAuthClient(initialSession: initialSession);

      final mockHttp = MockClient((request) async {
        httpCalls++;
        return handler(request);
      });

      client = _FakeSupabaseClient(
        mockAuthClient: fakeAuth,
        httpClient: mockHttp,
      );

      return TripsService(client: client);
    }

    test('fetchTrips fails closed synchronously when currentSession is null (no HTTP call)', () async {
      final service = setupService(
        handler: (req) async => http.Response('[]', 200, request: req),
        initialSession: null,
      );

      expect(
        () => service.fetchTrips('user-alice'),
        throwsA(isA<StateError>()),
      );
      expect(httpCalls, 0, reason: 'Zero HTTP requests should be dispatched when session is null');
    });

    test('fetchTrips fails closed synchronously when currentUser.id does not match requested userId', () async {
      final aliceSession = createSession(userId: 'user-alice');
      final service = setupService(
        handler: (req) async => http.Response('[]', 200, request: req),
        initialSession: aliceSession,
      );

      expect(
        () => service.fetchTrips('user-bob'),
        throwsA(isA<StateError>()),
      );
      expect(httpCalls, 0, reason: 'Zero HTTP requests should be dispatched when userId mismatches session');
    });

    test('fetchTrips fails closed synchronously when SDK session is expired', () async {
      final expiredSession = createSession(userId: 'user-alice', expired: true);
      final service = setupService(
        handler: (req) async => http.Response('[]', 200, request: req),
        initialSession: expiredSession,
      );

      expect(
        () => service.fetchTrips('user-alice'),
        throwsA(isA<StateError>()),
      );
      expect(httpCalls, 0, reason: 'Zero HTTP requests should be dispatched when session is expired');
    });

    test('saveTrip and deleteTrip fail closed synchronously when SDK session is missing or mismatched', () async {
      final service = setupService(
        handler: (req) async => http.Response('[]', 200, request: req),
        initialSession: null,
      );

      final dummyTrip = SavedTrip(
        id: 't-1',
        userId: 'user-alice',
        title: 'Trip 1',
        destinationName: 'Đà Nẵng',
        tripPlanData: {},
        createdAt: DateTime.now(),
      );

      expect(
        () => service.saveTrip(dummyTrip),
        throwsA(isA<StateError>()),
      );
      expect(
        () => service.deleteTrip(tripId: 't-1', userId: 'user-alice'),
        throwsA(isA<StateError>()),
      );
      expect(httpCalls, 0, reason: 'Zero REST requests when session is null');
    });

    test('deleteTrip returns true only when server acknowledges deleted row matching tripId and userId', () async {
      final aliceSession = createSession(userId: 'user-alice');
      final service = setupService(
        initialSession: aliceSession,
        handler: (req) async {
          expect(req.method, 'DELETE');
          expect(req.url.path, contains('/trips'));
          expect(req.url.queryParameters['id'], 'eq.trip-101');
          expect(req.url.queryParameters['user_id'], 'eq.user-alice');
          expect(req.url.queryParameters['select'], 'id,user_id');

          return http.Response(
            jsonEncode([
              {'id': 'trip-101', 'user_id': 'user-alice'}
            ]),
            200,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );

      final result = await service.deleteTrip(tripId: 'trip-101', userId: 'user-alice');
      expect(result, isTrue);
      expect(httpCalls, 1);
    });

    test('deleteTrip returns false when server returns empty array (zero rows affected / wrong owner / not found)', () async {
      final aliceSession = createSession(userId: 'user-alice');
      final service = setupService(
        initialSession: aliceSession,
        handler: (req) async {
          return http.Response(
            jsonEncode([]),
            200,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );

      final result = await service.deleteTrip(tripId: 'trip-999', userId: 'user-alice');
      expect(result, isFalse, reason: 'Deleting nonexistent or unowned trip must return false, NOT true');
      expect(httpCalls, 1);
    });

    test('deleteTrip returns false when server returns mismatched row data', () async {
      final aliceSession = createSession(userId: 'user-alice');
      final service = setupService(
        initialSession: aliceSession,
        handler: (req) async {
          return http.Response(
            jsonEncode([
              {'id': 'different-trip-id', 'user_id': 'user-alice'}
            ]),
            200,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );

      final result = await service.deleteTrip(tripId: 'trip-101', userId: 'user-alice');
      expect(result, isFalse);
    });

    test('deleteTrip propagates PostgrestException when server returns error (e.g. 401 / 403)', () async {
      final aliceSession = createSession(userId: 'user-alice');
      final service = setupService(
        initialSession: aliceSession,
        handler: (req) async {
          return http.Response(
            jsonEncode({
              'code': '42501',
              'message': 'permission denied for table trips',
            }),
            403,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );

      expect(
        () => service.deleteTrip(tripId: 'trip-101', userId: 'user-alice'),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('saveTrip validates required fields and parses server response with ID', () async {
      final aliceSession = createSession(userId: 'user-alice');
      final service = setupService(
        initialSession: aliceSession,
        handler: (req) async {
          expect(req.method, 'POST');
          return http.Response(
            jsonEncode({
              'id': 'server-gen-uuid-456',
              'user_id': 'user-alice',
              'title': 'Chuyến đi Hà Nội',
              'destination_name': 'Hà Nội',
              'num_days': 2,
              'budget_total': 3000000,
              'trip_plan_data': {'test': true},
              'created_at': '2026-10-08T12:00:00.000Z',
            }),
            201,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );

      final validTrip = SavedTrip(
        id: '',
        userId: 'user-alice',
        title: 'Chuyến đi Hà Nội',
        destinationName: 'Hà Nội',
        numDays: 2,
        budgetTotal: 3000000,
        tripPlanData: {'test': true},
        createdAt: DateTime.now(),
      );

      final saved = await service.saveTrip(validTrip);
      expect(saved.id, 'server-gen-uuid-456');
      expect(saved.title, 'Chuyến đi Hà Nội');

      // Empty title should fail synchronously
      final invalidTrip = SavedTrip(
        id: '',
        userId: 'user-alice',
        title: '   ',
        destinationName: 'Hà Nội',
        tripPlanData: {},
        createdAt: DateTime.now(),
      );
      expect(() => service.saveTrip(invalidTrip), throwsA(isA<ArgumentError>()));
    });
  });
}

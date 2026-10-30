// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/community/models/community_trip.dart';
import 'package:travelgo_mobile/features/community/models/trip_review.dart';
import 'package:travelgo_mobile/features/community/services/community_service.dart';

const String testUserIdA = '11111111-1111-4111-8111-111111111111';
const String testUserIdB = '22222222-2222-4222-8222-222222222222';
const String testTripId = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';

String createSyntheticToken({required String userId, bool expired = false}) {
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = expired ? nowSec - 3600 : nowSec + 3600;
  final tokenPayload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': userId,
            'exp': exp,
            'role': 'authenticated',
            'user_metadata': {'full_name': 'Người Dùng Test'},
          }),
        ),
      )
      .replaceAll('=', '');
  return 'eyJhbGciOiJIUzI1NiJ9.$tokenPayload.synthetic';
}

SupabaseClient createMockSupabaseClient({
  required Future<http.Response> Function(http.Request req) restHandler,
  String userId = testUserIdB,
  bool expired = false,
  bool unauthenticated = false,
}) {
  final token = createSyntheticToken(userId: userId, expired: expired);

  return SupabaseClient(
    'https://test-project.supabase.co',
    'synthetic-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((req) async {
      if (req.url.path == '/auth/v1/token') {
        if (unauthenticated) {
          return http.Response(
            jsonEncode({'error': 'invalid_grant', 'error_description': 'Invalid login'}),
            400,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
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
              'email': 'tester@example.com',
              'user_metadata': {'full_name': 'Người Dùng Test'},
              'app_metadata': {},
            },
          }),
          200,
          request: req,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return restHandler(req);
    }),
  );
}

void main() {
  group('Community Models Unit Tests', () {
    test('CommunityTrip parses JSON with full fields and nullables correctly', () {
      final json = {
        'id': 'trip-001',
        'title': 'Khám phá Hà Nội',
        'destination_name': 'Hà Nội',
        'num_days': 3,
        'budget_total': 5000000,
        'user_id': testUserIdA,
        'author_name': 'Tuấn Anh',
        'is_public': true,
        'like_count': 15,
        'average_rating': 4.75,
        'review_count': 8,
        'start_date': '2026-11-01T08:00:00.000Z',
        'end_date': '2026-11-03T18:00:00.000Z',
        'status': 'planning',
        'ai_plan_data': {
          'days': [
            {'day': 1, 'activities': ['Hồ Gươm', 'Phố Cổ']},
          ],
        },
        'created_at': '2026-10-29T10:00:00.000Z',
      };

      final trip = CommunityTrip.fromJson(json);

      expect(trip.id, 'trip-001');
      expect(trip.title, 'Khám phá Hà Nội');
      expect(trip.destination, 'Hà Nội');
      expect(trip.destinationName, 'Hà Nội');
      expect(trip.daysCount, 3);
      expect(trip.numDays, 3);
      expect(trip.estimatedCostVnd, 5000000.0);
      expect(trip.budgetTotal, 5000000.0);
      expect(trip.authorId, testUserIdA);
      expect(trip.userId, testUserIdA);
      expect(trip.authorName, 'Tuấn Anh');
      expect(trip.isPublic, isTrue);
      expect(trip.likeCount, 15);
      expect(trip.averageRating, 4.75);
      expect(trip.reviewCount, 8);
      expect(trip.tripData['days'], isNotEmpty);
      expect(trip.aiPlanData['days'], isNotEmpty);

      final outputJson = trip.toJson(includeId: true);
      expect(outputJson['id'], 'trip-001');
      expect(outputJson['user_id'], testUserIdA);
      expect(outputJson['destination_name'], 'Hà Nội');
      expect(outputJson['is_public'], isTrue);
    });

    test('CommunityTrip handles missing optional fields gracefully', () {
      final json = <String, dynamic>{
        'id': 'trip-minimal',
        'title': 'Chuyến đi ngắn',
        'destination_name': 'Đà Nẵng',
        'user_id': testUserIdA,
      };

      final trip = CommunityTrip.fromJson(json);
      expect(trip.id, 'trip-minimal');
      expect(trip.daysCount, isNull);
      expect(trip.estimatedCostVnd, isNull);
      expect(trip.authorName, isNull);
      expect(trip.isPublic, isFalse);
      expect(trip.likeCount, 0);
      expect(trip.averageRating, 0.0);
      expect(trip.reviewCount, 0);
      expect(trip.tripData, isEmpty);
    });

    test('TripReview parses JSON and enforces rating bounds', () {
      final json = {
        'id': 'rev-01',
        'trip_id': testTripId,
        'user_id': testUserIdB,
        'user_name': 'Hải Nam',
        'rating': 5,
        'comment': 'Lịch trình rất hợp lý!',
        'created_at': '2026-10-29T12:00:00.000Z',
      };

      final review = TripReview.fromJson(json);
      expect(review.id, 'rev-01');
      expect(review.tripId, testTripId);
      expect(review.userId, testUserIdB);
      expect(review.userName, 'Hải Nam');
      expect(review.rating, 5);
      expect(review.comment, 'Lịch trình rất hợp lý!');

      final output = review.toJson();
      expect(output['rating'], 5);
      expect(output['trip_id'], testTripId);

      // Thử tạo review ngoài khoảng 1..5 phải throw assertion
      expect(
        () => TripReview(
          id: '1',
          tripId: '1',
          userId: '1',
          userName: 'A',
          rating: 6,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('CommunityService Logic & Clone Trip Unit Tests', () {
    test('buildClonedTripPayload generates private copy with new user ID and resets stats', () {
      final original = CommunityTrip(
        id: testTripId,
        title: 'Hành trình Đà Lạt',
        destination: 'Đà Lạt',
        daysCount: 3,
        estimatedCostVnd: 3000000,
        authorId: testUserIdA,
        authorName: 'Tuấn',
        isPublic: true,
        likeCount: 25,
        averageRating: 4.9,
        reviewCount: 14,
        tripData: {
          'activities': [
            {'title': 'Thung lũng Tình Yêu', 'cost': 150000},
          ],
        },
      );

      final payload = CommunityService.buildClonedTripPayload(
        original: original,
        newUserId: testUserIdB,
      );

      // 1. Phải sinh ID mới khác ID gốc
      expect(payload['id'], isNotEmpty);
      expect(payload['id'], isNot(equals(testTripId)));

      // 2. Chủ sở hữu mới phải là user B
      expect(payload['user_id'], testUserIdB);

      // 3. Tiêu đề có tiền tố "Bản sao - "
      expect(payload['title'], 'Bản sao - Hành trình Đà Lạt');

      // 4. Mặc định phải là private
      expect(payload['is_public'], isFalse);

      // 5. Thống kê rating và like phải bị reset về 0
      expect(payload['like_count'], 0);
      expect(payload['average_rating'], 0.0);
      expect(payload['review_count'], 0);
      expect(payload['author_name'], isNull);

      // 6. Dữ liệu lịch trình phải được giữ nguyên vẹn
      final clonedPlan = payload['ai_plan_data'] as Map<String, dynamic>;
      expect(clonedPlan['activities'], isNotEmpty);

      // 7. Sửa đổi trên clonedPlan không được làm ảnh hưởng bản gốc (Deep copy)
      (clonedPlan['activities'] as List).clear();
      expect(original.tripData['activities'], isNotEmpty);
    });

    test('cloneTrip fails if user is not authenticated', () async {
      final client = createMockSupabaseClient(
        restHandler: (req) async => http.Response('[]', 200, request: req),
        unauthenticated: true,
      );

      final service = CommunityService(client: client);
      final trip = CommunityTrip(
        id: testTripId,
        title: 'Đà Nẵng',
        destination: 'Đà Nẵng',
        authorId: testUserIdA,
        isPublic: true,
      );

      expect(
        () => service.cloneTrip(sourceTrip: trip),
        throwsA(isA<StateError>()),
      );
    });

    test('cloneTrip rejects cloning private trip of another user', () async {
      final client = createMockSupabaseClient(
        restHandler: (req) async => http.Response('[]', 200, request: req),
        userId: testUserIdB,
      );
      await client.auth.signInWithPassword(email: 'b@example.com', password: 'pass');

      final service = CommunityService(client: client);
      final privateTripOfA = CommunityTrip(
        id: testTripId,
        title: 'Chuyến đi bí mật của A',
        destination: 'Phú Quốc',
        authorId: testUserIdA,
        isPublic: false, // Chuyến đi riêng tư
      );

      expect(
        () => service.cloneTrip(sourceTrip: privateTripOfA),
        throwsA(isA<StateError>()),
      );
    });

    test('cloneTrip succeeds with valid public trip and returns new CommunityTrip', () async {
      String? sentPath;
      String? sentBody;
      String? sentMethod;

      final client = createMockSupabaseClient(
        userId: testUserIdB,
        restHandler: (req) async {
          sentMethod = req.method;
          sentPath = req.url.path;
          sentBody = req.body;

          final decoded = jsonDecode(req.body) as Map<String, dynamic>;
          // Trả về bản ghi vừa tạo
          return http.Response(
            jsonEncode({
              ...decoded,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            }),
            201,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );
      await client.auth.signInWithPassword(email: 'b@example.com', password: 'pass');

      final service = CommunityService(client: client);
      final publicTrip = CommunityTrip(
        id: testTripId,
        title: 'Hạ Long 2 ngày',
        destination: 'Hạ Long',
        daysCount: 2,
        estimatedCostVnd: 2500000,
        authorId: testUserIdA,
        isPublic: true,
        tripData: {'hotel': 'Sun World Resort'},
      );

      final cloned = await service.cloneTrip(sourceTrip: publicTrip);

      expect(sentMethod, 'POST');
      expect(sentPath, '/rest/v1/trips');
      expect(sentBody, contains('Bản sao - Hạ Long 2 ngày'));
      expect(cloned.authorId, testUserIdB);
      expect(cloned.title, 'Bản sao - Hạ Long 2 ngày');
      expect(cloned.isPublic, isFalse);
      expect(cloned.tripData['hotel'], 'Sun World Resort');
    });

    test('fetchPublicTrips queries is_public = true and orders descending', () async {
      final client = createMockSupabaseClient(
        restHandler: (req) async {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/trips');
          expect(req.url.queryParameters['is_public'], 'eq.true');
          expect(req.url.queryParameters['order'], startsWith('created_at.desc'));

          return http.Response(
            jsonEncode([
              {
                'id': 'trip-pub-1',
                'title': 'Chuyến đi 1',
                'destination_name': 'Nha Trang',
                'user_id': testUserIdA,
                'is_public': true,
                'average_rating': 5.0,
                'review_count': 1,
              },
            ]),
            200,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );

      final service = CommunityService(client: client);
      final results = await service.fetchPublicTrips();

      expect(results.length, 1);
      expect(results.first.id, 'trip-pub-1');
      expect(results.first.isPublic, isTrue);
    });

    test('submitTripReview validates rating and upserts with onConflict', () async {
      String? sentMethod;
      String? sentBody;
      String? preferHeader;

      final client = createMockSupabaseClient(
        userId: testUserIdB,
        restHandler: (req) async {
          sentMethod = req.method;
          sentBody = req.body;
          preferHeader = req.headers['prefer'];

          final decoded = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 'rev-new-1',
              ...decoded,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            }),
            201,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );
      await client.auth.signInWithPassword(email: 'b@example.com', password: 'pass');

      final service = CommunityService(client: client);

      // Validate invalid rating (0 sao hoặc 6 sao)
      expect(
        () => service.submitTripReview(tripId: testTripId, rating: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.submitTripReview(tripId: testTripId, rating: 6),
        throwsA(isA<ArgumentError>()),
      );

      // Gửi review hợp lệ
      final review = await service.submitTripReview(
        tripId: testTripId,
        rating: 5,
        comment: 'Rất đáng thử!',
        userName: 'Hải Bùi',
      );

      expect(sentMethod, 'POST');
      expect(preferHeader, contains('resolution=merge-duplicates'));
      expect(sentBody, contains('Hải Bùi'));
      expect(sentBody, contains('"rating":5'));
      expect(review.rating, 5);
      expect(review.userName, 'Hải Bùi');
    });

    test('fetchTripReviews queries reviews for specific trip', () async {
      final client = createMockSupabaseClient(
        restHandler: (req) async {
          expect(req.method, 'GET');
          expect(req.url.path, '/rest/v1/trip_reviews');
          expect(req.url.queryParameters['trip_id'], 'eq.$testTripId');

          return http.Response(
            jsonEncode([
              {
                'id': 'rev-01',
                'trip_id': testTripId,
                'user_id': testUserIdB,
                'user_name': 'Tuấn',
                'rating': 4,
                'comment': 'Hay lắm',
                'created_at': '2026-10-29T10:00:00.000Z',
              },
            ]),
            200,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );

      final service = CommunityService(client: client);
      final reviews = await service.fetchTripReviews(testTripId);

      expect(reviews.length, 1);
      expect(reviews.first.tripId, testTripId);
      expect(reviews.first.rating, 4);
    });

    test('toggleTripPublic updates is_public with authenticated ownership check', () async {
      String? sentBody;
      String? sentMethod;

      final client = createMockSupabaseClient(
        userId: testUserIdA,
        restHandler: (req) async {
          sentMethod = req.method;
          sentBody = req.body;
          expect(req.url.queryParameters['id'], 'eq.$testTripId');
          expect(req.url.queryParameters['user_id'], 'eq.$testUserIdA');

          return http.Response(
            jsonEncode({
              'id': testTripId,
              'title': 'Chuyến đi của A',
              'destination_name': 'Huế',
              'user_id': testUserIdA,
              'is_public': true,
              'author_name': 'Tác giả A',
            }),
            200,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );
      await client.auth.signInWithPassword(email: 'a@example.com', password: 'pass');

      final service = CommunityService(client: client);
      final updated = await service.toggleTripPublic(
        tripId: testTripId,
        isPublic: true,
        authorName: 'Tác giả A',
      );

      expect(sentMethod, 'PATCH');
      expect(sentBody, contains('"is_public":true'));
      expect(sentBody, contains('"author_name":"Tác giả A"'));
      expect(updated.isPublic, isTrue);
      expect(updated.authorName, 'Tác giả A');
    });

    test('handles backend/network error gracefully without false success', () async {
      final client = createMockSupabaseClient(
        userId: testUserIdB,
        restHandler: (req) async => http.Response(
          'Internal Server Error',
          500,
          request: req,
          headers: {'content-type': 'text/plain'},
        ),
      );
      await client.auth.signInWithPassword(email: 'b@example.com', password: 'pass');

      final service = CommunityService(client: client);
      final trip = CommunityTrip(
        id: testTripId,
        title: 'Đà Nẵng',
        destination: 'Đà Nẵng',
        authorId: testUserIdA,
        isPublic: true,
      );

      // Khi server 500, cloneTrip phải throw error, không được nuốt lỗi hoặc giả lập thành công
      expect(
        () => service.cloneTrip(sourceTrip: trip),
        throwsA(anything),
      );
    });
  });
}

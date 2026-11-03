import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/community/models/community_trip.dart';
import 'package:travelgo_mobile/features/community/presentation/screens/shared_trip_detail_screen.dart';
import 'package:travelgo_mobile/features/community/services/community_service.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';
import 'package:travelgo_mobile/features/map/presentation/screens/catalogue_discovery_map_screen.dart';
import 'package:travelgo_mobile/features/navigation/presentation/screens/main_navigation_shell.dart';
import 'package:travelgo_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:travelgo_mobile/features/reviews/models/place_review.dart';
import 'package:travelgo_mobile/features/reviews/presentation/screens/place_reviews_screen.dart';
import 'package:travelgo_mobile/features/reviews/presentation/widgets/rating_stars_widget.dart';
import 'package:travelgo_mobile/features/reviews/providers/place_reviews_provider.dart';
import 'package:travelgo_mobile/features/reviews/services/place_reviews_service.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/local_ai_assistant_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/planner_input_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/local_ai_service.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';

import 'catalogue_parser_test.dart' show catalogueData;

class _MockAutomatedCommunityService extends CommunityService {
  _MockAutomatedCommunityService() : super(client: null);

  @override
  Future<List<CommunityTrip>> fetchPublicTrips({
    int limit = 20,
    int offset = 0,
    String? destinationQuery,
  }) async {
    return [
      CommunityTrip(
        id: 'shared-trip-1',
        title: 'Khám Phá Đà Lạt Mộng Mơ 3N2Đ',
        destination: 'Đà Lạt',
        daysCount: 3,
        estimatedCostVnd: 3500000,
        authorName: 'Hoàng Minh',
        authorId: 'user-minh',
        likeCount: 42,
        averageRating: 4.8,
        reviewCount: 15,
        isPublic: true,
        tripData: {
          'title': 'Khám Phá Đà Lạt Mộng Mơ 3N2Đ',
          'destinationId': 'da-lat',
          'days': [
            {
              'dayIndex': 1,
              'activities': [
                {'time': '08:00', 'title': 'Hồ Xuân Hương', 'placeId': 'p1'},
              ],
            },
          ],
        },
      ),
    ];
  }

  @override
  Future<CommunityTrip> cloneTrip({
    required CommunityTrip sourceTrip,
    String? newTitle,
  }) async {
    return CommunityTrip(
      id: 'cloned-trip-new',
      title: newTitle ?? 'Bản sao - Khám Phá Đà Lạt Mộng Mơ 3N2Đ',
      destination: sourceTrip.destination,
      daysCount: sourceTrip.daysCount,
      estimatedCostVnd: sourceTrip.estimatedCostVnd,
      authorName: 'Bản thân',
      authorId: 'test-user',
      likeCount: 0,
      averageRating: 0.0,
      reviewCount: 0,
    );
  }
}

class _MockReviewsRepository implements PlaceReviewsRepository {
  final List<PlaceReview> reviews;
  _MockReviewsRepository(this.reviews);

  @override
  Future<List<PlaceReview>> fetchForPlace(String placeId) async => reviews;

  @override
  Future<PlaceReview> create({
    required String placeId,
    required int rating,
    required String content,
  }) async {
    return PlaceReview(
      id: 'new-review',
      placeId: placeId,
      reviewerId: 'user-me',
      reviewerDisplayName: 'Người dùng thử nghiệm',
      rating: rating,
      content: content,
      createdAt: DateTime.now().toUtc(),
    );
  }
}

void main() {
  group('TravelGO All-Feature Automated End-to-End Test Suite', () {
    testWidgets('Complete Multi-Member Flow: Navigation Shell -> Profile -> AI Local -> Map -> Reviews -> Community & Clone -> My Trips', (
      tester,
    ) async {
      // 1. Khởi tạo Providers và Môi trường Giả lập Đồng bộ
      final authProvider = AuthProvider();
      await tester.runAsync(() => authProvider.quickDemoLogin(UserRole.customer));

      final catalogueRepo = CatalogueRepository(
        loader: () async => jsonEncode(catalogueData()),
      );
      final discoveryProvider = DiscoveryProvider(repository: catalogueRepo);
      await discoveryProvider.load();

      final tripProvider = TripProvider();
      final plannerInputProvider = PlannerInputProvider();
      final savedTripsProvider = SavedTripsProvider();
      final localAiService = LocalAiService(dio: Dio());
      final mockCommunityService = _MockAutomatedCommunityService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<DiscoveryProvider>.value(value: discoveryProvider),
            ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
            ChangeNotifierProvider<PlannerInputProvider>.value(value: plannerInputProvider),
            ChangeNotifierProvider<SavedTripsProvider>.value(value: savedTripsProvider),
            Provider<LocalAiService>.value(value: localAiService),
            Provider<CommunityService>.value(value: mockCommunityService),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MainNavigationShell(
              enableMapTab: true,
              enableCommunityTab: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // =========================================================================
      // GIAI ĐOẠN 1: KIỂM TRA THANH ĐIỀU HƯỚNG 5 NÚT CHUẨN CÔNG THÁI HỌC
      // =========================================================================
      final navBarFinder = find.byType(NavigationBar);
      expect(navBarFinder, findsOneWidget);

      final destinations = find.descendant(
        of: navBarFinder,
        matching: find.byType(NavigationDestination),
      );
      expect(destinations, findsNWidgets(5));
      expect(find.text('Trang chủ'), findsOneWidget);
      expect(find.text('Khám phá'), findsOneWidget);
      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Cộng đồng'), findsOneWidget);
      expect(find.text('Chuyến đi'), findsOneWidget);

      // =========================================================================
      // GIAI ĐOẠN 2: KIỂM TRA TRANG CHỦ & HỒ SƠ AVATAR (MEMBER 1)
      // =========================================================================
      expect(find.text('TravelGO'), findsOneWidget);
      expect(find.text('Khám phá theo sở thích'), findsOneWidget);

      // Nhấn vào Avatar góc trên AppBar để mở trang Hồ Sơ Cá Nhân
      final profileAvatarFinder = find.byType(CircleAvatar);
      expect(profileAvatarFinder, findsOneWidget);
      await tester.tap(profileAvatarFinder);
      await tester.pumpAndSettle();

      // Xác nhận đã mở CustomerProfileScreen an toàn
      expect(find.byType(CustomerProfileScreen), findsOneWidget);
      expect(find.text('Tài Khoản'), findsOneWidget);

      // Quay lại Trang chủ
      Navigator.of(tester.element(find.byType(CustomerProfileScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CustomerProfileScreen), findsNothing);

      // =========================================================================
      // GIAI ĐOẠN 3: KIỂM TRA TRỢ LÝ AI LOCAL 3-IN-1 (MEMBER 1)
      // =========================================================================
      final aiAssistantContext = tester.element(find.byType(MainNavigationShell));
      Navigator.of(aiAssistantContext).push(
        MaterialPageRoute<void>(
          builder: (_) => LocalAiAssistantScreen(service: localAiService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LocalAiAssistantScreen), findsOneWidget);
      expect(find.text('Trợ Lý AI TravelGO'), findsOneWidget);
      expect(find.text('Trò Chuyện 💬'), findsOneWidget);
      expect(find.text('Tra Cứu 🔍'), findsOneWidget);
      expect(find.text('Gợi Ý 💡'), findsOneWidget);

      // Thử chuyển sang Tab Tra Cứu Hybrid (Catalogue First)
      await tester.tap(find.text('Tra Cứu 🔍'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập tên địa danh cần tra cứu...'), findsOneWidget);

      // Thử chuyển sang Tab Gợi Ý Đánh Giá Cao >= 4.5 sao
      await tester.tap(find.text('Gợi Ý 💡'));
      await tester.pumpAndSettle();
      expect(find.text('Gợi ý địa điểm ≥ 4.5⭐'), findsOneWidget);

      // Đóng màn hình AI để quay lại thanh điều hướng chính
      Navigator.of(tester.element(find.byType(LocalAiAssistantScreen))).pop();
      await tester.pumpAndSettle();

      // =========================================================================
      // GIAI ĐOẠN 4: KIỂM TRA BẢN ĐỒ KHÁM PHÁ & LỚP CHỦ QUYỀN BIỂN ĐẢO (MEMBER 2)
      // =========================================================================
      await tester.tap(find.text('Bản đồ'));
      await tester.pumpAndSettle();

      expect(find.byType(CatalogueDiscoveryMapScreen), findsOneWidget);
      expect(find.text('Bản Đồ Khám Phá'), findsOneWidget);
      expect(find.text('Hoàng Sa (VN)'), findsOneWidget);
      expect(find.text('Trường Sa (VN)'), findsOneWidget);

      // =========================================================================
      // GIAI ĐOẠN 5: KIỂM TRA ĐÁNH GIÁ ĐỊA ĐIỂM & RATING STARS WIDGET (MEMBER 3)
      // =========================================================================
      final reviewsRepo = _MockReviewsRepository([
        PlaceReview(
          id: 'rev-1',
          placeId: 'p-ho-xuan-huong',
          reviewerId: 'user-minh',
          reviewerDisplayName: 'Hoàng Minh',
          rating: 5,
          content: 'Không gian thơ mộng, không khí trong lành tuyệt vời!',
          createdAt: DateTime.utc(2026, 10, 20),
        ),
      ]);
      final reviewsProvider = PlaceReviewsProvider(
        repository: reviewsRepo,
        placeId: 'p-ho-xuan-huong',
      );
      await reviewsProvider.load();

      final mapContext = tester.element(find.byType(CatalogueDiscoveryMapScreen));
      Navigator.of(mapContext).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaceReviewsScreen(
            placeName: 'Hồ Xuân Hương',
            provider: reviewsProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlaceReviewsScreen), findsOneWidget);
      expect(find.text('Đánh giá · Hồ Xuân Hương'), findsOneWidget);
      expect(find.text('Không gian thơ mộng, không khí trong lành tuyệt vời!'), findsOneWidget);
      expect(find.byType(RatingStarsWidget), findsWidgets);

      Navigator.of(tester.element(find.byType(PlaceReviewsScreen))).pop();
      await tester.pumpAndSettle();

      // =========================================================================
      // GIAI ĐOẠN 6: KIỂM TRA BẢNG TIN CỘNG ĐỒNG & SAO CHÉP CHUYẾN ĐI (MEMBER 4)
      // =========================================================================
      await tester.tap(find.text('Cộng đồng'));
      await tester.pumpAndSettle();

      expect(find.text('Cộng Đồng Xê Dịch'), findsOneWidget);
      expect(find.text('Khám Phá Đà Lạt Mộng Mơ 3N2Đ'), findsOneWidget);
      expect(find.text('Bởi Hoàng Minh'), findsOneWidget);

      // Chạm vào thẻ chuyến đi để xem chi tiết
      await tester.tap(find.text('Khám Phá Đà Lạt Mộng Mơ 3N2Đ'));
      await tester.pumpAndSettle();

      expect(find.byType(SharedTripDetailScreen), findsOneWidget);
      final cloneButton = find.byKey(const ValueKey('clone-trip-cta-button'));
      expect(cloneButton, findsOneWidget);

      await tester.tap(cloneButton);
      await tester.pumpAndSettle();

      // Đóng màn hình Chi Tiết Chuyến Đi để quay lại Shell
      Navigator.of(tester.element(find.byType(SharedTripDetailScreen))).pop();
      await tester.pumpAndSettle();

      // =========================================================================
      // GIAI ĐOẠN 7: KIỂM TRA CHUYẾN ĐI CỦA TÔI (MEMBER 1 & 4)
      // =========================================================================
      await tester.tap(find.text('Chuyến đi'));
      await tester.pumpAndSettle();

      expect(find.byType(MyTripsScreen), findsOneWidget);
      expect(find.text('Chuyến Đi Của Tôi'), findsOneWidget);

      reviewsProvider.dispose();
      authProvider.dispose();
      discoveryProvider.dispose();
      savedTripsProvider.dispose();
      tripProvider.dispose();
      plannerInputProvider.dispose();
    });
  });
}

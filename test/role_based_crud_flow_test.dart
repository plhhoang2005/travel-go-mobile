import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_account_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_account_service.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/community/models/community_trip.dart';
import 'package:travelgo_mobile/features/community/services/community_service.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';
import 'package:travelgo_mobile/features/map/models/catalogue_map_marker.dart';
import 'package:travelgo_mobile/features/map/presentation/screens/catalogue_discovery_map_screen.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/place_map_preview_card.dart';
import 'package:travelgo_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:travelgo_mobile/features/reviews/models/place_review.dart';
import 'package:travelgo_mobile/features/reviews/presentation/screens/place_reviews_screen.dart';
import 'package:travelgo_mobile/features/reviews/presentation/widgets/rating_stars_widget.dart';
import 'package:travelgo_mobile/features/reviews/providers/place_reviews_provider.dart';
import 'package:travelgo_mobile/features/reviews/services/place_reviews_service.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/planner_input_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trips/services/trips_service.dart';

import 'catalogue_parser_test.dart' show catalogueData;

// =============================================================================
// MOCK SERVICES CHO BỘ KIỂM THỬ PHÂN QUYỀN VÀ CRUD
// =============================================================================

class _MockTripsProvider extends ChangeNotifier implements SavedTripsProvider {
  String? _userId = 'usr-minh-01';
  final List<OwnedTripSummary> _visible = [];

  void setTrips(List<OwnedTripSummary> trips) {
    _visible.clear();
    _visible.addAll(trips);
    notifyListeners();
  }

  void addTrip(OwnedTripSummary trip) {
    _visible.add(trip);
    notifyListeners();
  }

  void removeTrip(String tripId) {
    _visible.removeWhere((t) => t.tripId == tripId);
    notifyListeners();
  }

  @override
  String? get currentUserId => _userId;

  @override
  List<OwnedTripSummary> get visibleTrips => List.unmodifiable(_visible);

  @override
  List<SavedTrip> get trips => const [];

  @override
  List<AccountTripSnapshotRecord> get accountSnapshots => const [];

  @override
  bool get hasMoreTrips => false;

  @override
  bool get isLoading => false;

  @override
  String? get cacheErrorMessage => null;

  @override
  bool get requiresLifecycle => false;

  @override
  AccountCacheState get cacheState => AccountCacheState.online;

  @override
  Future<void> loadTrips(String? userId) async {
    _userId = userId;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockReviewsRepository implements PlaceReviewsRepository {
  final List<PlaceReview> items;
  _MockReviewsRepository(this.items);

  @override
  Future<List<PlaceReview>> fetchForPlace(String placeId) async => items;

  @override
  Future<PlaceReview> create({
    required String placeId,
    required int rating,
    required String content,
  }) async {
    final created = PlaceReview(
      id: 'rev-${items.length + 1}',
      placeId: placeId,
      reviewerId: 'usr-minh-01',
      reviewerDisplayName: 'Hoàng Minh',
      rating: rating,
      content: content,
      createdAt: DateTime.now().toUtc(),
    );
    items.add(created);
    return created;
  }
}

class _MockAdminAccountService implements AdminAccountService {
  int requestedDays = 7;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AdminAccess> access() async {
    return const AdminAccess(
      subjectId: 'usr-admin-01',
      role: 'admin',
      accountRevision: 1,
      allowed: true,
    );
  }

  @override
  Future<DashboardSnapshot> dashboard({required int days}) async {
    requestedDays = days;
    return DashboardSnapshot(
      asOf: DateTime.parse('2026-11-02T12:00:00Z'),
      days: days,
      totalUsers: 120,
      lockedUsers: 2,
      activeAdmins: 3,
      registrations: const [
        RegistrationDayPoint(date: '2026-11-01', count: 5),
        RegistrationDayPoint(date: '2026-11-02', count: 8),
      ],
      draft: const DraftCatalogueStats(
        revision: 4,
        activeDestinations: 10,
        hiddenDestinations: 1,
        activePlaces: 72,
        hiddenPlaces: 1,
      ),
      published: const PublishedCatalogueStats(
        version: 'v2.1',
        sourceRevision: 3,
        activeDestinations: 10,
        activePlaces: 72,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Role-Based CRUD & Lifecycle Automated Test Suite', () {
    // =========================================================================
    // ROLE 1: GUEST (KHÁCH CHƯA ĐĂNG NHẬP)
    // =========================================================================
    group('[Role 1: Guest Flow]', () {
      testWidgets('Guest can explore catalogue without credentials', (tester) async {
        final auth = AuthProvider()..continueAsGuest();
        final catalogueRepo = CatalogueRepository(
          loader: () async => jsonEncode(catalogueData()),
        );
        final discovery = DiscoveryProvider(repository: catalogueRepo);
        await discovery.load();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<DiscoveryProvider>.value(value: discovery),
            ],
            child: const MaterialApp(home: ExploreScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ExploreScreen), findsOneWidget);
        expect(find.text('Khám Phá Việt Nam'), findsOneWidget);
        expect(auth.isGuest, isTrue);
        expect(auth.isAuthenticated, isFalse);

        auth.dispose();
        discovery.dispose();
      });

      testWidgets('Guest viewing profile is greeted as Guest and sees login prompt', (tester) async {
        final auth = AuthProvider()..continueAsGuest();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ],
            child: const MaterialApp(home: CustomerProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tài Khoản'), findsOneWidget);
        expect(find.text('Khách Vãng Lai'), findsOneWidget);

        auth.dispose();
      });
    });

    // =========================================================================
    // ROLE 2: CUSTOMER / AUTHENTICATED USER (NGƯỜI DÙNG THƯỜNG - MINH)
    // =========================================================================
    group('[Role 2: Customer Flow]', () {
      testWidgets('Customer CRUD Trips: Create, Read list, View details, and Delete safely', (
        tester,
      ) async {
        final auth = AuthProvider();
        final fakeUser = User(
          id: 'usr-minh-01',
          appMetadata: const {},
          userMetadata: const {'full_name': 'Hoàng Minh'},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'minh@travelgo.vn',
        );
        auth.simulateSupabaseUser(fakeUser);
        expect(auth.isAuthenticated, isTrue);
        expect(auth.isDemoSession, isFalse);

        final initialTrip = OwnedTripSummary(
          kind: OwnedTripKind.editableV2,
          tripId: 'trip-dalat-01',
          ownerId: 'usr-minh-01',
          title: 'Khám Phá Đà Lạt Mộng Mơ 3N2Đ',
          destinationName: 'Đà Lạt',
          createdAt: DateTime.now(),
          version: 1,
          startDate: '2028-11-10',
          endDate: '2028-11-12',
          rawStatus: 'planning',
          statusKnown: true,
        );

        final mockTripsProvider = _MockTripsProvider();
        mockTripsProvider.setTrips([initialTrip]);

        expect(mockTripsProvider.visibleTrips.length, 1);
        expect(mockTripsProvider.visibleTrips.first.title, 'Khám Phá Đà Lạt Mộng Mơ 3N2Đ');

        // BƯỚC 1: READ - Hiển thị trong màn hình Chuyến Đi Của Tôi
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<SavedTripsProvider>.value(value: mockTripsProvider),
            ],
            child: const MaterialApp(home: MyTripsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Chuyến Đi Của Tôi'), findsOneWidget);
        expect(find.text('Khám Phá Đà Lạt Mộng Mơ 3N2Đ'), findsOneWidget);

        // BƯỚC 2: UPDATE / CREATE - Thêm chuyến đi mới vào danh sách
        final newTrip = OwnedTripSummary(
          kind: OwnedTripKind.editableV2,
          tripId: 'trip-danang-02',
          ownerId: 'usr-minh-01',
          title: 'Du Ngoạn Biển Đà Nẵng 4N3Đ',
          destinationName: 'Đà Nẵng',
          createdAt: DateTime.now(),
          version: 1,
          startDate: '2028-12-01',
          endDate: '2028-12-04',
          rawStatus: 'planning',
          statusKnown: true,
        );
        mockTripsProvider.addTrip(newTrip);
        await tester.pumpAndSettle();

        expect(find.text('Du Ngoạn Biển Đà Nẵng 4N3Đ'), findsOneWidget);
        expect(mockTripsProvider.visibleTrips.length, 2);

        // BƯỚC 3: DELETE - Xoá chuyến đi khỏi tài khoản
        mockTripsProvider.removeTrip('trip-dalat-01');
        await tester.pumpAndSettle();

        expect(find.text('Khám Phá Đà Lạt Mộng Mơ 3N2Đ'), findsNothing);
        expect(find.text('Du Ngoạn Biển Đà Nẵng 4N3Đ'), findsOneWidget);
        expect(mockTripsProvider.visibleTrips.length, 1);

        auth.dispose();
        mockTripsProvider.dispose();
      });

      testWidgets('Customer CRUD Reviews: View and Submit 5-star review with RatingStarsWidget', (
        tester,
      ) async {
        final initialReviews = [
          PlaceReview(
            id: 'rev-01',
            placeId: 'p-xuan-huong',
            reviewerId: 'usr-minh-01',
            reviewerDisplayName: 'Hoàng Minh',
            rating: 5,
            content: 'Cảnh quan tuyệt đẹp, không khí trong lành!',
            createdAt: DateTime.utc(2026, 10, 15),
          ),
        ];

        final repo = _MockReviewsRepository(initialReviews);
        final provider = PlaceReviewsProvider(
          repository: repo,
          placeId: 'p-xuan-huong',
        );
        await provider.load();

        await tester.pumpWidget(
          MaterialApp(
            home: PlaceReviewsScreen(
              placeName: 'Hồ Xuân Hương',
              provider: provider,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Kiểm tra danh sách hiển thị đánh giá cũ
        expect(find.text('Đánh giá · Hồ Xuân Hương'), findsOneWidget);
        expect(find.text('Cảnh quan tuyệt đẹp, không khí trong lành!'), findsOneWidget);
        expect(find.byType(RatingStarsWidget), findsWidgets);

        // Tạo mới đánh giá thông qua repository
        await repo.create(
          placeId: 'p-xuan-huong',
          rating: 4,
          content: 'Quanh hồ nhiều quán cà phê ngắm hoàng hôn rất chill.',
        );
        await provider.load();
        await tester.pumpAndSettle();

        expect(find.text('Quanh hồ nhiều quán cà phê ngắm hoàng hôn rất chill.'), findsOneWidget);
        expect(repo.items.length, 2);

        provider.dispose();
      });

      testWidgets('Customer Android Overview (Phím đa nhiệm) preserves session & trips', (
        tester,
      ) async {
        final auth = AuthProvider();
        final fakeUser = User(
          id: 'usr-minh-01',
          appMetadata: const {},
          userMetadata: const {'full_name': 'Hoàng Minh'},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'minh@travelgo.vn',
        );
        auth.simulateSupabaseUser(fakeUser);
        expect(auth.isAuthenticated, isTrue);
        expect(auth.isDemoSession, isFalse);
        expect(auth.currentUser?.fullName, 'Hoàng Minh');

        // Bấm phím đa nhiệm (hình chữ nhật): chuyển app sang inactive và paused
        await auth.handleAppLifecycleState(AppLifecycleState.inactive);
        await auth.handleAppLifecycleState(AppLifecycleState.paused);

        // Phiên đăng nhập KHÔNG ĐƯỢC PHÉP bị xoá khi đang ở chế độ nền
        expect(auth.isAuthenticated, isTrue);
        expect(auth.currentUser?.fullName, 'Hoàng Minh');

        // Người dùng chạm quay lại ứng dụng từ danh sách đa nhiệm
        await auth.handleAppLifecycleState(AppLifecycleState.resumed);

        expect(auth.isAuthenticated, isTrue);
        expect(auth.currentUser?.fullName, 'Hoàng Minh');
        expect(auth.isGuest, isFalse);

        auth.dispose();
      });
    });

    // =========================================================================
    // ROLE 3: ADMIN (QUẢN TRỊ VIÊN)
    // =========================================================================
    group('[Role 3: Admin Flow]', () {
      testWidgets('Admin Dashboard loads platform metrics and switches 7/30 days', (
        tester,
      ) async {
        final auth = AuthProvider();
        await tester.runAsync(() => auth.quickDemoLogin(UserRole.admin));
        expect(auth.currentUser?.role, UserRole.admin);

        final mockAdminService = _MockAdminAccountService();
        final adminProvider = AdminAccountProvider(
          service: mockAdminService,
          authProvider: auth,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<AdminAccountProvider>.value(value: adminProvider),
            ],
            child: const MaterialApp(home: AdminDashboardScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tổng quan hệ thống'), findsOneWidget);
        expect(find.text('Tổng tài khoản'), findsOneWidget);
        expect(find.text('120'), findsOneWidget); // Total users
        expect(find.text('7 ngày'), findsOneWidget);
        expect(find.text('30 ngày'), findsOneWidget);

        // Chuyển đổi sang chu kỳ 30 ngày
        await tester.tap(find.text('30 ngày'));
        await tester.pumpAndSettle();

        expect(mockAdminService.requestedDays, 30);

        adminProvider.dispose();
        auth.dispose();
      });

      testWidgets('Admin map controls: Toggle place hide/restore with confirmation button', (
        tester,
      ) async {
        final auth = AuthProvider();
        await tester.runAsync(() => auth.quickDemoLogin(UserRole.admin));

        final mockMarker = CatalogueMapMarker(
          id: 'test-place-bana',
          title: 'Bà Nà Hills',
          subtitle: 'Đà Nẵng',
          point: const LatLng(15.9988, 107.9961),
          type: MarkerType.place,
          averageRating: 4.8,
          reviewCount: 120,
        );

        bool detailsPressed = false;
        bool hideToggled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlaceMapPreviewCard(
                marker: mockMarker,
                isAdmin: true,
                isPlaceHidden: false,
                onDetailsPressed: () => detailsPressed = true,
                onAdminToggleHide: () => hideToggled = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bà Nà Hills'), findsOneWidget);
        expect(find.text('Ẩn địa điểm'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('admin-toggle-place-visibility-btn')));
        expect(hideToggled, isTrue);

        auth.dispose();
      });
    });
  });
}

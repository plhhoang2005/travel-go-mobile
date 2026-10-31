import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/community/models/community_trip.dart';
import 'package:travelgo_mobile/features/community/models/trip_review.dart';
import 'package:travelgo_mobile/features/community/presentation/screens/community_feed_screen.dart';
import 'package:travelgo_mobile/features/community/presentation/screens/shared_trip_detail_screen.dart';
import 'package:travelgo_mobile/features/community/presentation/widgets/community_trip_card.dart';
import 'package:travelgo_mobile/features/community/presentation/widgets/rating_stars_widget.dart';
import 'package:travelgo_mobile/features/community/services/community_service.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';
import 'package:travelgo_mobile/features/navigation/presentation/screens/main_navigation_shell.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/planner_input_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'catalogue_parser_test.dart' show catalogueData;

/// Fake CommunityService phục vụ widget tests độc lập và không cần mạng
class FakeCommunityService extends CommunityService {
  List<CommunityTrip> publicTrips;
  List<TripReview> reviews;
  int cloneCalls = 0;
  int submitReviewCalls = 0;
  int fetchPublicCalls = 0;
  String? lastClonedTripId;
  int? lastSubmittedRating;
  String? lastSubmittedComment;

  FakeCommunityService({
    this.publicTrips = const [],
    this.reviews = const [],
  });

  @override
  Future<List<CommunityTrip>> fetchPublicTrips({
    int limit = 20,
    int offset = 0,
    String? destinationQuery,
  }) async {
    fetchPublicCalls++;
    return publicTrips;
  }

  @override
  Future<List<TripReview>> fetchTripReviews(String tripId) async {
    return reviews;
  }

  @override
  Future<TripReview> submitTripReview({
    required String tripId,
    required int rating,
    String? comment,
    String? userName,
  }) async {
    submitReviewCalls++;
    lastSubmittedRating = rating;
    lastSubmittedComment = comment;
    final newReview = TripReview(
      id: 'rev-${DateTime.now().millisecondsSinceEpoch}',
      tripId: tripId,
      userId: 'test-user-id',
      userName: userName ?? 'Người dùng thử nghiệm',
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );
    reviews = [newReview, ...reviews];
    return newReview;
  }

  @override
  Future<CommunityTrip> cloneTrip({
    required CommunityTrip sourceTrip,
    String? newTitle,
  }) async {
    cloneCalls++;
    lastClonedTripId = sourceTrip.id;
    return sourceTrip.copyWith(
      id: 'cloned-123',
      title: newTitle ?? 'Bản sao - ${sourceTrip.title}',
      isPublic: false,
    );
  }
}

final sampleTrip = CommunityTrip(
  id: 'trip-1',
  title: 'Khám Phá Đà Nẵng 4 Ngày 3 Đêm',
  destination: 'Đà Nẵng',
  daysCount: 4,
  estimatedCostVnd: 4500000,
  authorId: 'u-1',
  authorName: 'Nguyễn Văn Minh',
  isPublic: true,
  likeCount: 24,
  averageRating: 4.8,
  reviewCount: 5,
  tripData: {
    'itineraryDays': [
      {
        'day': 1,
        'title': 'Bán đảo Sơn Trà & Biển Mỹ Khê',
        'activities': [
          {
            'time': '08:00',
            'title': 'Viếng Chùa Linh Ứng',
            'costVnd': 0,
            'durationHours': 2.0,
          },
          {
            'time': '12:00',
            'title': 'Thưởng thức bánh tráng cuốn thịt heo',
            'costVnd': 150000,
            'durationHours': 1.5,
          },
        ],
      },
      {
        'day': 2,
        'title': 'Bà Nà Hills đường lên tiên cảnh',
        'activities': [
          {
            'time': '08:30',
            'title': 'Cáp treo Bà Nà & Cầu Vàng',
            'costVnd': 900000,
            'durationHours': 5.0,
          },
        ],
      },
    ],
  },
);

void main() {
  group('Community Widgets & Screens Tests (Member 4)', () {
    testWidgets(
      'RatingStarsWidget displays correct stars and triggers callback in interactive mode',
      (tester) async {
        int selected = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RatingStarsWidget(
                rating: 3.5,
                interactive: true,
                onRatingChanged: (val) => selected = val,
              ),
            ),
          ),
        );

        expect(find.byType(RatingStarsWidget), findsOneWidget);
        expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
        expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
        expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);

        // Chạm vào ngôi sao thứ 5
        final fifthStar = find.bySemanticsLabel('5 sao');
        expect(fifthStar, findsOneWidget);
        await tester.tap(fifthStar);
        await tester.pumpAndSettle();

        expect(selected, 5);
      },
    );

    testWidgets(
      'CommunityTripCard renders title, author, rating, destination, duration and read-only like count',
      (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: CommunityTripCard(
                trip: sampleTrip,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        // Kiểm tra thông tin hiển thị
        expect(find.text('Khám Phá Đà Nẵng 4 Ngày 3 Đêm'), findsOneWidget);
        expect(find.text('Đà Nẵng'), findsOneWidget);
        expect(find.text('Bởi Nguyễn Văn Minh'), findsOneWidget);
        expect(find.text('4.8'), findsOneWidget);
        expect(find.text('(5)'), findsOneWidget);
        expect(find.text('4 ngày'), findsOneWidget);
        expect(find.text('24'), findsOneWidget); // like count (thống kê hiển thị)
        expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

        // Chạm vào thẻ
        await tester.tap(find.byType(CommunityTripCard));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'CommunityFeedScreen renders empty state when no trips exist',
      (tester) async {
        final fakeService = FakeCommunityService(publicTrips: []);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: CommunityFeedScreen(service: fakeService),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Cộng Đồng Xê Dịch'), findsOneWidget);
        expect(find.text('Chưa có chuyến đi công khai nào'), findsOneWidget);
        expect(fakeService.fetchPublicCalls, 1);
      },
    );

    testWidgets(
      'CommunityFeedScreen renders list of trips and supports refresh',
      (tester) async {
        final fakeService = FakeCommunityService(publicTrips: [sampleTrip]);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: CommunityFeedScreen(service: fakeService),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(CommunityTripCard), findsOneWidget);
        expect(find.text('Khám Phá Đà Nẵng 4 Ngày 3 Đêm'), findsOneWidget);

        // Nhấn nút làm mới trên AppBar
        await tester.tap(find.byIcon(Icons.refresh_rounded));
        await tester.pumpAndSettle();

        expect(fakeService.fetchPublicCalls, 2);
      },
    );

    testWidgets(
      'SharedTripDetailScreen renders itinerary days, review section and yellow clone button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final sampleReview = TripReview(
          id: 'r-1',
          tripId: sampleTrip.id,
          userId: 'u-2',
          userName: 'Trần Thị Mai',
          rating: 5,
          comment: 'Lịch trình rất chi tiết và hợp lý!',
          createdAt: DateTime(2026, 10, 29),
        );
        final fakeService = FakeCommunityService(
          publicTrips: [sampleTrip],
          reviews: [sampleReview],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: SharedTripDetailScreen(
              trip: sampleTrip,
              service: fakeService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Kiểm tra tiêu đề và thông tin tổng quan
        expect(find.text('Khám Phá Đà Nẵng 4 Ngày 3 Đêm'), findsWidgets);
        expect(find.text('Tác giả: Nguyễn Văn Minh'), findsOneWidget);
        expect(find.text('Thời lượng: 4 ngày'), findsOneWidget);

        // 2. Kiểm tra lịch trình các ngày từ ai_plan_data
        expect(find.text('Ngày 1'), findsOneWidget);
        expect(find.text('Bán đảo Sơn Trà & Biển Mỹ Khê'), findsOneWidget);
        expect(find.text('Viếng Chùa Linh Ứng'), findsOneWidget);
        expect(find.text('Ngày 2'), findsOneWidget);
        expect(find.text('Bà Nà Hills đường lên tiên cảnh'), findsOneWidget);

        // 3. Kiểm tra danh sách nhận xét
        expect(find.text('Lịch trình rất chi tiết và hợp lý!'), findsOneWidget);

        // 4. Kiểm tra nút vàng CTA Clone Trip
        final cloneBtnFinder = find.byKey(const ValueKey('clone-trip-cta-button'));
        expect(cloneBtnFinder, findsOneWidget);
        expect(find.text('Sao chép về chuyến đi của tôi'), findsOneWidget);

        // Bấm nút vàng Clone Trip
        await tester.tap(cloneBtnFinder);
        await tester.pumpAndSettle();

        expect(fakeService.cloneCalls, 1);
        expect(fakeService.lastClonedTripId, sampleTrip.id);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('Đã sao chép'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'SharedTripDetailScreen on narrow 360-wide screen does not overflow RenderFlex',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0; // 360 logical width
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final bigTrip = sampleTrip.copyWith(
          title: 'Chuyến đi mới với tiêu đề dài tại Đà Nẵng',
          destination: 'Thành phố Đà Nẵng',
          daysCount: 14,
          estimatedCostVnd: 50000000.0,
        );
        final fakeService = FakeCommunityService(publicTrips: [bigTrip]);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: SharedTripDetailScreen(
              trip: bigTrip,
              service: fakeService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Thời lượng: 14 ngày'), findsOneWidget);
        expect(find.text('Sao chép về chuyến đi của tôi'), findsOneWidget);
      },
    );

    testWidgets(
      'SharedTripDetailScreen submits review with rating and comment',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeService = FakeCommunityService(
          publicTrips: [sampleTrip],
          reviews: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: SharedTripDetailScreen(
              trip: sampleTrip,
              service: fakeService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Nhập nhận xét vào TextField
        final inputFinder = find.byType(TextField);
        expect(inputFinder, findsOneWidget);
        await tester.enterText(inputFinder, 'Chuyến đi tuyệt vời!');

        // Bấm gửi nhận xét
        final submitBtn = find.widgetWithText(FilledButton, 'Gửi nhận xét');
        expect(submitBtn, findsOneWidget);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(fakeService.submitReviewCalls, 1);
        expect(fakeService.lastSubmittedRating, 5);
        expect(fakeService.lastSubmittedComment, 'Chuyến đi tuyệt vời!');
        expect(find.text('Đã gửi đánh giá thành công! Cảm ơn bạn.'), findsOneWidget);
      },
    );

    testWidgets(
      'MainNavigationShell preserves 4 destinations by default and expands to 5 when enableCommunityTab is true',
      (tester) async {
        final auth = AuthProvider()..continueAsGuest();
        final trip = TripProvider();
        final discovery = DiscoveryProvider(
          repository: CatalogueRepository(
            loader: () async => jsonEncode(catalogueData()),
          ),
        );

        Widget buildShell({bool enableCommunityTab = false}) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<PlannerInputProvider>(
                create: (_) => PlannerInputProvider(),
              ),
              ChangeNotifierProvider<TripProvider>.value(value: trip),
              ChangeNotifierProvider<DiscoveryProvider>.value(value: discovery),
              ChangeNotifierProvider<SavedTripsProvider>(
                create: (_) => SavedTripsProvider(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: MainNavigationShell(enableCommunityTab: enableCommunityTab),
            ),
          );
        }

        // Mặc định: 4 tab (bảo toàn 100% cho bài test coursework cũ)
        await tester.pumpWidget(buildShell());
        await tester.pumpAndSettle();

        final navBarDefault = find.byType(NavigationBar);
        expect(navBarDefault, findsOneWidget);
        expect(
          find.descendant(
            of: navBarDefault,
            matching: find.byType(NavigationDestination),
          ),
          findsNWidgets(4),
        );
        expect(find.text('Cộng đồng'), findsNothing);

        // Khi bật enableCommunityTab: true -> hiển thị 5 tab có Cộng đồng
        await tester.pumpWidget(buildShell(enableCommunityTab: true));
        await tester.pumpAndSettle();

        final navBarWithCommunity = find.byType(NavigationBar);
        expect(
          find.descendant(
            of: navBarWithCommunity,
            matching: find.byType(NavigationDestination),
          ),
          findsNWidgets(5),
        );
        expect(find.text('Cộng đồng'), findsOneWidget);

        // Đảm bảo chữ "Cộng đồng" nằm trên đúng 1 hàng ngang, không bị ngắt thành 2 dòng dọc (chiều cao <= 18px)
        final renderParagraph = tester.renderObject<RenderParagraph>(find.text('Cộng đồng'));
        expect(renderParagraph.size.height, lessThanOrEqualTo(18.0));

        auth.dispose();
        trip.dispose();
        discovery.dispose();
      },
    );
  });
}

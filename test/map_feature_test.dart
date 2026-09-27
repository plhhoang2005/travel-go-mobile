import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelgo_mobile/features/map/models/map_models.dart';
import 'package:travelgo_mobile/features/map/services/location_service.dart';
import 'package:travelgo_mobile/features/map/services/map_api_service.dart';
import 'package:travelgo_mobile/features/map/providers/map_provider.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/member_radar_sheet.dart';

class FakeMapApiService extends MapApiService {
  @override
  Future<RouteData> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<RouteWaypoint> waypoints = const [],
  }) async {
    return RouteData(
      points: [origin, destination],
      distanceKm: 300.0,
      durationMinutes: 360,
      isFallback: false,
      summary: 'Tuyến đường thử nghiệm OSRM',
      waypoints: waypoints,
    );
  }
}

class FakeLocationService extends LocationService {
  @override
  Future<LocationResult> getCurrentUserLocation() async {
    return const LocationResult(
      position: LocationService.defaultUniversityOrigin,
      isMock: true,
      locationName: LocationService.defaultOriginName,
    );
  }
}

void main() {
  group('Map Models & Radar Status Unit Tests', () {
    test('MemberSafetyStatus returns correct labels and colors', () {
      expect(MemberSafetyStatus.safe.label, 'Khoảng cách an toàn');
      expect(MemberSafetyStatus.warning.label, 'Cảnh báo tách đoàn');
      expect(MemberSafetyStatus.danger.label, 'Cảnh báo đi lạc');

      expect(MemberSafetyStatus.safe.color, const Color(0xFF10B981));
      expect(MemberSafetyStatus.warning.color, const Color(0xFFF59E0B));
      expect(MemberSafetyStatus.danger.color, const Color(0xFFEF4444));
    });

    test('GroupMember status classifies distances accurately', () {
      final now = DateTime.now();

      final leader = GroupMember(
        id: '1',
        name: 'Minh',
        avatarText: 'M',
        avatarColor: Colors.teal,
        position: const LatLng(10.7725, 106.6578),
        isLeader: true,
        distanceToLeaderMeters: 0,
        lastUpdated: now,
      );
      expect(leader.status, MemberSafetyStatus.safe);
      expect(leader.formattedDistance, contains('Trưởng nhóm'));

      final safeMember = GroupMember(
        id: '2',
        name: 'Hoàng',
        avatarText: 'H',
        avatarColor: Colors.green,
        position: const LatLng(10.7735, 106.6585),
        isLeader: false,
        distanceToLeaderMeters: 130,
        lastUpdated: now,
      );
      expect(safeMember.status, MemberSafetyStatus.safe);
      expect(safeMember.formattedDistance, '130 m');

      final warningMember = GroupMember(
        id: '3',
        name: 'Lan',
        avatarText: 'L',
        avatarColor: Colors.amber,
        position: const LatLng(10.7760, 106.6610),
        isLeader: false,
        distanceToLeaderMeters: 550,
        lastUpdated: now,
      );
      expect(warningMember.status, MemberSafetyStatus.warning);
      expect(warningMember.formattedDistance, '550 m');

      final dangerMember = GroupMember(
        id: '4',
        name: 'Tuấn',
        avatarText: 'T',
        avatarColor: Colors.red,
        position: const LatLng(10.7840, 106.6700),
        isLeader: false,
        distanceToLeaderMeters: 1650,
        lastUpdated: now,
      );
      expect(dangerMember.status, MemberSafetyStatus.danger);
      expect(dangerMember.formattedDistance, '1.65 km');
    });

    test('RouteData formats duration and distance correctly', () {
      const route1 = RouteData(
        points: [LatLng(10.7725, 106.6578), LatLng(11.9404, 108.4583)],
        distanceKm: 305.4,
        durationMinutes: 380, // 6h 20m
        isFallback: false,
        summary: 'QL20',
      );
      expect(route1.formattedDistance, '305 km');
      expect(route1.formattedDuration, '6 giờ 20 phút');

      const route2 = RouteData(
        points: [LatLng(10.7725, 106.6578), LatLng(10.7800, 106.6600)],
        distanceKm: 2.34,
        durationMinutes: 12,
        isFallback: true,
        summary: 'Dự phòng',
      );
      expect(route2.formattedDistance, '2.3 km');
      expect(route2.formattedDuration, '12 phút');
    });
  });

  group('Location Service Unit Tests', () {
    final locationService = LocationService();

    test('calculateDistanceMeters computes reasonable Haversine distances', () {
      const p1 = LatLng(10.7725, 106.6578);
      const p2 = LatLng(10.7735, 106.6578);
      final dist = locationService.calculateDistanceMeters(p1, p2);
      expect(dist, greaterThan(100));
      expect(dist, lessThan(125));
    });

    test('generateInitialGroupMembers generates leader and 3 members', () {
      const leaderPos = LatLng(10.7725, 106.6578);
      final members = locationService.generateInitialGroupMembers(leaderPos);

      expect(members.length, 4);
      expect(members.first.isLeader, isTrue);
      expect(members.first.name, contains('Minh'));

      // Check distance spectrum
      expect(members[1].status, MemberSafetyStatus.safe);
      expect(members[2].status, MemberSafetyStatus.warning);
      expect(members[3].status, MemberSafetyStatus.danger);
    });
  });

  group('MapProvider Unit Tests', () {
    test('MapProvider manages modes and routeBackToLeader correctly with FakeMapApiService', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(apiService: fakeRouting, locationService: fakeLocation);
      await provider.init();

      expect(provider.currentMode, MapMode.routing);
      expect(provider.groupMembers.length, 4);

      provider.setMode(MapMode.radar);
      expect(provider.currentMode, MapMode.radar);

      final lostMember = provider.groupMembers.firstWhere((m) => m.status == MemberSafetyStatus.danger);
      expect(lostMember.name, 'Tuấn');

      await provider.routeBackToLeader(lostMember);
      expect(provider.currentMode, MapMode.routing);
      expect(provider.origin, lostMember.position);
      expect(provider.destination, provider.leader!.position);
    });
  });

  group('MemberRadarSheet Widget Tests', () {
    testWidgets('MemberRadarSheet renders all members, badges, and directions button', (tester) async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(apiService: fakeRouting, locationService: fakeLocation);
      await provider.init();
      provider.setMode(MapMode.radar);

      bool memberSelectedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemberRadarSheet(
                provider: provider,
                onMemberSelected: () {
                  memberSelectedCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify Header
      expect(find.text('Radar Thành Viên Nhóm'), findsOneWidget);
      expect(find.textContaining('4 thành viên'), findsOneWidget);

      // Verify Members listed
      expect(find.text('Minh (Bạn / Leader)'), findsOneWidget);
      expect(find.text('Trưởng nhóm'), findsOneWidget);
      expect(find.text('Hoàng'), findsOneWidget);
      expect(find.text('Khoảng cách an toàn'), findsNWidgets(2)); // Leader and Hoàng
      expect(find.text('Lan'), findsOneWidget);
      expect(find.text('Cảnh báo tách đoàn'), findsOneWidget);
      expect(find.text('Tuấn'), findsOneWidget);
      expect(find.text('Cảnh báo đi lạc'), findsOneWidget);

      // Verify "Chỉ đường về nhóm" button appears for danger member
      expect(find.text('Chỉ đường về nhóm'), findsOneWidget);

      // Tap on Hoàng
      await tester.tap(find.text('Hoàng'));
      await tester.pump();
      expect(memberSelectedCalled, isTrue);
      expect(provider.selectedMember?.name, 'Hoàng');

      // Tap "Chỉ đường về nhóm" for Tuấn
      await tester.tap(find.text('Chỉ đường về nhóm'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3)); // Let SnackBar animation complete
      expect(provider.currentMode, MapMode.routing);
    });
  });
}

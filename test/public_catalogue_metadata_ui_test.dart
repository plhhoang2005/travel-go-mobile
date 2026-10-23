import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/destination_detail_screen.dart';
import 'package:travelgo_mobile/features/explore/presentation/widgets/destination_reference_list_tile.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';
import 'package:travelgo_mobile/features/favorites/models/favorite_item_model.dart';
import 'package:travelgo_mobile/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:travelgo_mobile/features/favorites/providers/favorites_provider.dart';
import 'package:travelgo_mobile/features/map/services/manual_place_locations.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';

PublicCatalogueSnapshot createSnapshot({
  int version = 1,
  List<Map<String, dynamic>> destinations = const [],
}) {
  final bundle = {
    'contract': 'travelgo.discovery.release.v2',
    'schemaVersion': 2,
    'version': version,
    'preparedAt': '2026-10-20T10:00:00.000Z',
    'catalogue': {
      'sources': [
        {
          'id': 'src-01',
          'title': 'Cổng du lịch',
          'publisher': 'Tổng cục Du lịch',
          'url': 'https://vietnam.travel',
          'checkedAt': '2026-10-20T08:00:00Z',
        }
      ],
      'destinations': destinations,
    },
    'visitDetails': {
      'sources': [],
      'packages': [],
      'places': [],
    },
  };

  final payloadText = jsonEncode(bundle);
  final rawBytes = utf8.encode(payloadText);
  final sha = sha256.convert(rawBytes).toString();

  final manifest = DiscoveryManifest(
    contract: 'travelgo.discovery.manifest.v2',
    schemaVersion: 2,
    version: version,
    objectKey: 'releases/v2/$version.json',
    sha256: sha,
    byteLength: rawBytes.length,
    publishedAt: DateTime.parse('2026-10-20T10:00:00Z'),
  );

  return PublicCatalogueParser.parse(
    payloadText: payloadText,
    manifest: manifest,
    now: DateTime.parse('2026-10-20T12:00:00Z'),
    origin: 'storage',
  );
}

class FakeFavoritesProvider extends ChangeNotifier implements FavoritesProvider {
  final List<FavoriteItem> _items;
  int deleteFavoriteCalls = 0;

  FakeFavoritesProvider(this._items);

  @override
  List<FavoriteItem> get items => _items;

  @override
  bool get isLoading => false;

  @override
  bool isFavorite(String itemId) => _items.any((i) => i.itemId == itemId);

  @override
  Future<bool> toggleFavorite(FavoriteItem item) async {
    deleteFavoriteCalls++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isGuest => false;

  @override
  UserEntity? get currentUser => UserEntity.demoMinh();

  @override
  int get authEpoch => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('ManualPlaceLocations.find returns runtime coordinates and falls back to static', () {
    final snapshot = createSnapshot(
      version: 1,
      destinations: [
        {
          'id': 'da-nang',
          'name': 'Đà Nẵng',
          'slug': 'da-nang',
          'region': 'Miền Trung',
          'places': [
            {
              'id': 'da-nang/cau-vang',
              'destinationId': 'da-nang',
              'name': 'Cầu Vàng',
              'slug': 'cau-vang',
              'latitude': 15.9988,
              'longitude': 108.0011,
              'sourceRefs': ['src-01'],
            }
          ],
        }
      ],
    );

    // Dynamic place with runtime coordinates in snapshot
    final loc = ManualPlaceLocations.find('da-nang/cau-vang', snapshot: snapshot);
    expect(loc, isNotNull);
    expect(loc!.position.latitude, 15.9988);
    expect(loc.position.longitude, 108.0011);
    expect(loc.sourceUrl, 'https://vietnam.travel');

    // Static fallback place for existing ID
    final staticLoc = ManualPlaceLocations.find('ha-noi/hoan-kiem', snapshot: snapshot);
    expect(staticLoc, isNotNull);
    expect(staticLoc!.position.latitude, closeTo(21.028, 0.01));

    // Unknown place returns null
    expect(ManualPlaceLocations.find('unknown/place', snapshot: snapshot), isNull);
  });

  testWidgets('unavailable_favorite_keeps_saved_label: pin invariant', (tester) async {
    final fakeFavorites = FakeFavoritesProvider([
      FavoriteItem(
        id: 'fav-01',
        userId: 'usr-minh-01',
        itemId: 'old-destination-hidden',
        itemType: 'destination',
        title: 'Điểm Đến Cũ Đã Ẩn',
        location: 'Miền Tây',
        createdAt: DateTime.now(),
      ),
      FavoriteItem(
        id: 'fav-02',
        userId: 'usr-minh-01',
        itemId: 'hotel-01',
        itemType: 'hotel',
        title: 'Khách sạn Biển Đẹp',
        location: 'Đà Nẵng',
        createdAt: DateTime.now(),
      ),
    ]);

    final discovery = DiscoveryProvider();
    final snapshot = createSnapshot(
      version: 2,
      destinations: [
        {
          'id': 'da-nang',
          'name': 'Đà Nẵng',
          'slug': 'da-nang',
          'region': 'Miền Trung',
          'places': [],
        }
      ],
    );
    discovery.bindPublicSnapshot(snapshot);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
          ChangeNotifierProvider<FavoritesProvider>.value(value: fakeFavorites),
          ChangeNotifierProvider<DiscoveryProvider>.value(value: discovery),
        ],
        child: const MaterialApp(home: FavoritesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Saved name is visible
    expect(find.text('Điểm Đến Cũ Đã Ẩn'), findsOneWidget);
    // Unavailable label is shown for catalogue item
    expect(find.text('Mục không còn trong danh mục phát hành'), findsOneWidget);

    // Hotel does not show the label
    expect(find.text('Khách sạn Biển Đẹp'), findsOneWidget);

    // Pin: Zero delete favorite calls made
    expect(fakeFavorites.deleteFavoriteCalls, 0);
  });

  testWidgets('DestinationReferenceListTile and DetailScreen render published metadata and image', (tester) async {
    final destination = DestinationReference(
      id: 'da-nang-v2',
      name: 'Đà Nẵng Siêu Đẹp',
      region: 'Miền Trung',
      description: 'Thành phố với những cây cầu nổi tiếng',
      imageUrl: 'https://example.com/da-nang.jpg',
      imageRights: {
        'sourceUrl': 'https://example.com/source',
        'permission': 'owned',
        'credit': 'Nhiếp ảnh gia Hoàng',
        'licenseUrl': null,
      },
      places: const [],
      sample: SampleReference.unavailable(),
    );

    // Test list tile
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DestinationReferenceListTile(
            destination: destination,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đà Nẵng Siêu Đẹp'), findsOneWidget);

    // Test detail screen
    final catalogue = CatalogueReference(
      checkedAt: '2026-10-20',
      sources: const [],
      destinations: [destination],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TripProvider()),
        ],
        child: MaterialApp(
          home: DestinationDetailScreen(
            catalogue: catalogue,
            destination: destination,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đà Nẵng Siêu Đẹp'), findsWidgets);
    expect(find.text('Thành phố với những cây cầu nổi tiếng'), findsOneWidget);
    expect(find.text('Ví dụ đang được rà soát'), findsOneWidget);
  });
}

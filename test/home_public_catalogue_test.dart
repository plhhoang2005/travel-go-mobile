import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';
import 'package:travelgo_mobile/features/home/models/destination_model.dart';
import 'package:travelgo_mobile/features/home/models/service_model.dart';
import 'package:travelgo_mobile/features/home/models/voucher_model.dart';
import 'package:travelgo_mobile/features/home/providers/home_catalog_provider.dart';
import 'package:travelgo_mobile/features/home/services/home_catalog_service.dart';

class FailingHomeCatalogService extends HomeCatalogService {
  int fetchDestinationsCalls = 0;

  @override
  Future<List<DestinationModel>> fetchDestinations() async {
    fetchDestinationsCalls++;
    throw Exception('Simulated network failure on destinations');
  }

  @override
  Future<List<ServiceModel>> fetchFeaturedHotels() async => [];

  @override
  Future<List<ServiceModel>> fetchPopularTours() async => [];

  @override
  Future<List<VoucherModel>> fetchActiveVouchers() async => [];
}

class SuccessHomeCatalogService extends HomeCatalogService {
  @override
  Future<List<DestinationModel>> fetchDestinations() async => [];

  @override
  Future<List<ServiceModel>> fetchFeaturedHotels() async {
    return [
      const ServiceModel(
        id: 'hotel-01',
        destinationId: 'da-nang',
        serviceType: 'hotel',
        title: 'Khách sạn Mường Thanh',
        basePrice: 1200000,
        rating: 4.8,
      ),
    ];
  }

  @override
  Future<List<ServiceModel>> fetchPopularTours() async => [];

  @override
  Future<List<VoucherModel>> fetchActiveVouchers() async {
    return [
      VoucherModel(
        id: 'voucher-01',
        title: 'Giảm 100k',
        discountAmount: 100000,
        minOrderValue: 500000,
        expiryDate: DateTime.parse('2026-12-31T23:59:59Z'),
        isActive: true,
      ),
    ];
  }
}

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

void main() {
  test('home_failure_does_not_resurrect_hidden_destination: pin invariant', () async {
    final failingService = FailingHomeCatalogService();
    final provider = HomeCatalogProvider(
      service: failingService,
      autoLoad: false,
    );

    // Initial snapshot has da-nang only, nha-trang is hidden
    final snapshot = createSnapshot(
      version: 1,
      destinations: [
        {
          'id': 'da-nang',
          'name': 'Đà Nẵng',
          'slug': 'da-nang',
          'region': 'Miền Trung',
          'description': 'Thành phố biển',
          'imageUrl': 'https://example.com/da-nang.jpg',
          'places': [],
        }
      ],
    );

    provider.bindPublicSnapshot(snapshot);

    const hiddenId = 'nha-trang';
    // Nha Trang is not in the published snapshot
    expect(provider.destinations.where((d) => d.id == hiddenId), isEmpty);
    expect(provider.destinations.length, 1);
    expect(provider.destinations.first.id, 'da-nang');

    // Trigger loadCatalog which encounters failures/refresh
    await provider.loadCatalog(forceRefresh: true);

    // Pin: Hidden destination must NOT be resurrected by network failure or fallback!
    expect(provider.destinations.where((d) => d.id == hiddenId), isEmpty);
    expect(provider.destinations.length, 1);
    expect(provider.destinations.first.id, 'da-nang');
    expect(failingService.fetchDestinationsCalls, 0); // V2 bound does not fetch legacy table
  });

  test('all-hidden catalogue leaves home destinations empty without preset fallback', () async {
    final provider = HomeCatalogProvider(autoLoad: false);

    final emptySnapshot = createSnapshot(
      version: 1,
      destinations: [],
    );

    provider.bindPublicSnapshot(emptySnapshot);

    expect(provider.isBoundToV2, isTrue);
    expect(provider.destinations, isEmpty);

    // loadCatalog failure also preserves empty list
    await provider.loadCatalog(forceRefresh: true);
    expect(provider.destinations, isEmpty);
  });

  test('V2 destination metadata maps correctly with null dynamic weather', () async {
    final provider = HomeCatalogProvider(autoLoad: false);

    final snapshot = createSnapshot(
      version: 2,
      destinations: [
        {
          'id': 'phu-quoc-v2',
          'name': 'Phú Quốc Đảo Ngọc Mới',
          'slug': 'phu-quoc',
          'region': 'Miền Nam',
          'description': 'Bãi biển cát trắng tinh khôi',
          'imageUrl': 'https://example.com/phu-quoc.jpg',
          'places': [],
        }
      ],
    );

    provider.bindPublicSnapshot(snapshot);

    expect(provider.destinations.length, 1);
    final item = provider.destinations.first;
    expect(item.id, 'phu-quoc-v2');
    expect(item.name, 'Phú Quốc Đảo Ngọc Mới');
    expect(item.description, 'Bãi biển cát trắng tinh khôi');
    expect(item.imageUrl, 'https://example.com/phu-quoc.jpg');
    // Dynamic entry has no assumed 26.0 forecast
    expect(item.weatherCachedTemp, isNull);
    expect(item.hasWeather, isFalse);
  });

  test('catalogue bind retains existing featured hotels and vouchers', () async {
    final service = SuccessHomeCatalogService();
    final provider = HomeCatalogProvider(
      service: service,
      autoLoad: false,
    );

    // Initial load fetches hotels and vouchers
    await provider.loadCatalog();
    expect(provider.featuredHotels.length, 1);
    expect(provider.vouchers.length, 1);

    // Bind new catalogue snapshot
    final snapshot = createSnapshot(
      version: 3,
      destinations: [
        {
          'id': 'quy-nhon',
          'name': 'Quy Nhơn',
          'slug': 'quy-nhon',
          'region': 'Miền Trung',
          'places': [],
        }
      ],
    );

    provider.bindPublicSnapshot(snapshot);

    // Hotels and vouchers are intact
    expect(provider.featuredHotels.length, 1);
    expect(provider.vouchers.length, 1);
    expect(provider.featuredHotels.first.id, 'hotel-01');
    expect(provider.vouchers.first.title, 'Giảm 100k');
  });
}

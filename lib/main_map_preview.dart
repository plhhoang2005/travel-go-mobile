import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/explore/models/catalogue_reference.dart';
import 'features/explore/providers/discovery_provider.dart';
import 'features/explore/services/catalogue_repository.dart';
import 'features/map/presentation/screens/catalogue_discovery_map_screen.dart';

/// Test Entry Point for Android Studio:
/// Direct interactive test runner for Member 2's Catalogue Discovery Map feature.
/// Can be launched directly via Android Studio Run Configuration:
/// 'flutter run -t lib/main_map_preview.dart'
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MapTestPreviewApp());
}

class MapTestPreviewApp extends StatefulWidget {
  const MapTestPreviewApp({super.key});

  @override
  State<MapTestPreviewApp> createState() => _MapTestPreviewAppState();
}

class _MapTestPreviewAppState extends State<MapTestPreviewApp> {
  late CatalogueReference _currentCatalogue;
  bool _isAdminSimulatedHidden = false;

  @override
  void initState() {
    super.initState();
    _currentCatalogue = _createMockCatalogue(hidePlace: false);
  }

  void _toggleAdminHidePlace(BuildContext scaffoldContext) {
    setState(() {
      _isAdminSimulatedHidden = !_isAdminSimulatedHidden;
      _currentCatalogue = _createMockCatalogue(hidePlace: _isAdminSimulatedHidden);
    });

    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
      SnackBar(
        content: Text(
          _isAdminSimulatedHidden
              ? 'Admin đã ẩn "Chợ Đà Lạt" khỏi danh mục!'
              : 'Admin đã khôi phục "Chợ Đà Lạt" trên bản đồ!',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor:
            _isAdminSimulatedHidden ? Colors.red.shade700 : Colors.teal.shade700,
      ),
    );
  }

  static CatalogueReference _createMockCatalogue({required bool hidePlace}) {
    final daLatPlaces = <PlaceReference>[
      const PlaceReference(
        id: 'place-xuan-huong',
        name: 'Hồ Xuân Hương',
        sourceId: 's1',
        latitude: 11.9404,
        longitude: 108.4583,
        description: 'Trái tim thơ mộng của Đà Lạt với cung đường ven hồ tuyệt đẹp.',
      ),
      const PlaceReference(
        id: 'place-linh-phuoc',
        name: 'Chùa Linh Phước (Chùa Ve Chai)',
        sourceId: 's1',
        latitude: 11.9442,
        longitude: 108.4988,
        description: 'Ngôi chùa độc đáo khảm từ hàng triệu mảnh sành sứ tinh xảo.',
      ),
      if (!hidePlace)
        const PlaceReference(
          id: 'place-cho-da-lat',
          name: 'Chợ Đà Lạt & Chợ Đêm',
          sourceId: 's1',
          latitude: 11.9425,
          longitude: 108.4365,
          description: 'Thiên đường ẩm thực đêm và nông sản xứ lạnh.',
        ),
      const PlaceReference(
        id: 'place-tinh-yeu',
        name: 'Thung Lũng Tình Yêu',
        sourceId: 's1',
        latitude: 11.9792,
        longitude: 108.4503,
        description: 'Thắng cảnh nổi tiếng bao quanh bởi đồi thông xanh ngát.',
      ),
      const PlaceReference(
        id: 'place-checkin-moi',
        name: 'Điểm Check-in Mới (Chưa có sao)',
        sourceId: 's1',
        latitude: 11.9280,
        longitude: 108.4200,
        description: 'Địa điểm mới mở cửa thử nghiệm đón khách du lịch.',
      ),
    ];

    final daNangPlaces = <PlaceReference>[
      const PlaceReference(
        id: 'place-ba-na-hills',
        name: 'Bà Nà Hills & Cầu Vàng',
        sourceId: 's1',
        latitude: 15.9988,
        longitude: 107.9961,
        description: 'Kỳ quan Cầu Vàng trên mây và làng Pháp tuyệt đẹp.',
      ),
      const PlaceReference(
        id: 'place-cau-rong',
        name: 'Cầu Rồng Sông Hàn',
        sourceId: 's1',
        latitude: 16.0611,
        longitude: 108.2272,
        description: 'Biểu tượng hiện đại với màn trình diễn phun lửa & nước cuối tuần.',
      ),
      const PlaceReference(
        id: 'place-my-khe',
        name: 'Bãi Biển Mỹ Khê',
        sourceId: 's1',
        latitude: 16.0592,
        longitude: 108.2465,
        description: 'Một trong những bãi biển quyến rũ nhất hành tinh.',
      ),
    ];

    final haNoiPlaces = <PlaceReference>[
      const PlaceReference(
        id: 'place-hoan-kiem',
        name: 'Hồ Hoàn Kiếm & Đền Ngọc Sơn',
        sourceId: 's1',
        latitude: 21.0285,
        longitude: 105.8542,
        description: 'Trái tim lịch sử nghìn năm văn hiến của thủ đô.',
      ),
      const PlaceReference(
        id: 'place-van-mieu',
        name: 'Văn Miếu - Quốc Tử Giám',
        sourceId: 's1',
        latitude: 21.0293,
        longitude: 105.8360,
        description: 'Trường đại học đầu tiên của Việt Nam.',
      ),
    ];

    final phuQuocPlaces = <PlaceReference>[
      const PlaceReference(
        id: 'place-bai-sao',
        name: 'Bãi Sao Phú Quốc',
        sourceId: 's1',
        latitude: 10.0528,
        longitude: 104.0322,
        description: 'Bờ cát trắng mịn như kem và làn nước trong vắt.',
      ),
      const PlaceReference(
        id: 'place-grand-world',
        name: 'Grand World Phú Quốc',
        sourceId: 's1',
        latitude: 10.3275,
        longitude: 103.8569,
        description: 'Thành phố không ngủ sôi động bên bờ biển bắc đảo.',
      ),
    ];

    return CatalogueReference(
      checkedAt: DateTime.now().toIso8601String(),
      sources: const [
        SourceReference(
          id: 's1',
          title: 'Tổng cục Du lịch Việt Nam',
          url: 'https://vietnamtourism.gov.vn',
          publisher: 'VNAT',
          checkedAt: '2026-10-30',
        ),
      ],
      destinations: [
        DestinationReference(
          id: 'da-lat',
          name: 'Đà Lạt',
          region: 'Tây Nguyên',
          sample: SampleReference.unavailable(),
          places: daLatPlaces,
          description: 'Thành phố ngàn hoa với khí hậu se lạnh quanh năm.',
        ),
        DestinationReference(
          id: 'da-nang',
          name: 'Đà Nẵng',
          region: 'Duyên hải Nam Trung Bộ',
          sample: SampleReference.unavailable(),
          places: daNangPlaces,
          description: 'Thành phố đáng sống với biển xanh và cầu biểu tượng.',
        ),
        DestinationReference(
          id: 'ha-noi',
          name: 'Hà Nội',
          region: 'Đồng bằng sông Hồng',
          sample: SampleReference.unavailable(),
          places: haNoiPlaces,
          description: 'Thủ đô ngàn năm văn hiến cổ kính và rực rỡ.',
        ),
        DestinationReference(
          id: 'phu-quoc',
          name: 'Phú Quốc',
          region: 'Đồng bằng sông Cửu Long',
          sample: SampleReference.unavailable(),
          places: phuQuocPlaces,
          description: 'Đảo ngọc thiên đường nghỉ dưỡng nhiệt đới.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DiscoveryProvider>(
          create: (_) => DiscoveryProvider(
            repository: CatalogueRepository(
              snapshotLoader: () async => _currentCatalogue,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'TravelGO - Map Test Preview',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (screenContext) {
            return Scaffold(
              body: CatalogueDiscoveryMapScreen(
                initialCatalogue: _currentCatalogue,
                enableNetworkTiles: true,
              ),
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor:
                    _isAdminSimulatedHidden ? Colors.teal : Colors.deepOrange,
                foregroundColor: Colors.white,
                icon: Icon(
                  _isAdminSimulatedHidden ? Icons.visibility : Icons.visibility_off,
                ),
                label: Text(
                  _isAdminSimulatedHidden
                      ? 'Admin: Hiện lại Chợ Đà Lạt'
                      : 'Admin: Ẩn Chợ Đà Lạt',
                ),
                onPressed: () => _toggleAdminHidePlace(screenContext),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/models/destination_model.dart';
import '../../../home/providers/home_catalog_provider.dart';
import '../../../map/presentation/screens/trip_map_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _selectedRegion = 'Tất cả';

  final List<String> _regions = [
    'Tất cả',
    'Miền Bắc',
    'Miền Trung',
    'Miền Nam',
    'Tây Nguyên',
  ];

  Color _getRegionColor(String region) {
    if (region.contains('Bắc')) return const Color(0xFF0284C7);
    if (region.contains('Trung')) return const Color(0xFF0D9488);
    if (region.contains('Nam')) return const Color(0xFFF97316);
    if (region.contains('Tây Nguyên')) return const Color(0xFF8B5CF6);
    return AppTheme.primaryColor;
  }

  String _formatRegionLabel(String region) {
    if (region == 'Bắc') return 'Miền Bắc';
    if (region == 'Trung') return 'Miền Trung';
    if (region == 'Nam') return 'Miền Nam';
    return region;
  }

  bool _matchesRegion(String destRegion, String filter) {
    if (filter == 'Tất cả') return true;
    if (filter == 'Miền Bắc') return destRegion == 'Bắc' || destRegion == 'Miền Bắc';
    if (filter == 'Miền Trung') return destRegion == 'Trung' || destRegion == 'Miền Trung';
    if (filter == 'Miền Nam') return destRegion == 'Nam' || destRegion == 'Miền Nam';
    if (filter == 'Tây Nguyên') return destRegion == 'Tây Nguyên';
    return destRegion == filter;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<HomeCatalogProvider>();
    final List<DestinationModel> allDestinations = catalog.destinations;
    final filtered = allDestinations.where((d) => _matchesRegion(d.region, _selectedRegion)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Khám Phá Việt Nam', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Bản Đồ OpenStreetMap & Radar',
            icon: const Icon(Icons.map_outlined, color: AppTheme.primaryColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TripMapScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh, color: AppTheme.slate600),
            onPressed: () => catalog.fetchCatalog(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _regions.map((region) {
                  final isSelected = _selectedRegion == region;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(region),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.primaryColor : AppTheme.slate600,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedRegion = region);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Offline fallback banner (Law 3: Zero Silent Fallbacks)
          if (catalog.isFallback)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '[Dữ liệu ngoại tuyến] Hiển thị danh mục điểm đến cục bộ.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Destinations List with Pull-to-refresh
          Expanded(
            child: catalog.isLoading && allDestinations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off_outlined, size: 64, color: AppTheme.slate300),
                            const SizedBox(height: 12),
                            const Text(
                              'Không có điểm đến nào trong khu vực này',
                              style: TextStyle(fontSize: 14, color: AppTheme.slate600),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => catalog.fetchCatalog(forceRefresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final dest = filtered[index];
                            final color = _getRegionColor(dest.region);
                            final regionLabel = _formatRegionLabel(dest.region);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              clipBehavior: Clip.antiAlias,
                              elevation: 1,
                              color: Colors.white,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Destination Image Header with badging
                                  if (dest.imageUrl != null)
                                    Stack(
                                      children: [
                                        Image.network(
                                          dest.imageUrl!,
                                          height: 140,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            height: 140,
                                            color: color.withValues(alpha: 0.1),
                                            child: Center(
                                              child: Icon(Icons.photo_size_select_actual_outlined, color: color, size: 40),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.65),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  catalog.getWeather(dest.id)?.weatherIcon ?? Icons.wb_sunny_rounded,
                                                  color: Colors.amber,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${(catalog.getWeather(dest.id)?.temperature ?? dest.weatherCachedTemp).toStringAsFixed(0)}°C',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 12,
                                          left: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: color,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              regionLabel,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                  // Body
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                dest.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.slate900,
                                                ),
                                              ),
                                            ),
                                            if (dest.isPopular)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'Phổ biến',
                                                  style: TextStyle(
                                                    color: Colors.red.shade700,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (dest.description != null && dest.description!.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            dest.description!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.slate600,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                        Builder(
                                          builder: (context) {
                                            final liveWeather = catalog.getWeather(dest.id);
                                            if (liveWeather == null) return const SizedBox.shrink();
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Row(
                                                children: [
                                                  Icon(liveWeather.weatherIcon, size: 14, color: liveWeather.weatherColor),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      '${liveWeather.temperature.toStringAsFixed(1)}°C • ${liveWeather.weatherDescription} (Độ ẩm ${liveWeather.relativeHumidity}%)',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme.slate700,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                        const Divider(height: 24, color: AppTheme.slate100),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.explore_outlined, size: 16, color: color),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Khu vực $regionLabel',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: color,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  'Lên kế hoạch',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.primaryColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primaryColor),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}


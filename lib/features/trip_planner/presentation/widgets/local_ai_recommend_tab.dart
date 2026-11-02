import 'package:flutter/material.dart';
import '../../models/local_ai_models.dart';
import '../../services/local_ai_service.dart';

class LocalAiRecommendTab extends StatefulWidget {
  final LocalAiService service;
  final List<Map<String, dynamic>> ratedPlaces;
  final void Function(AiRecommendationItem item)? onAddPlace;

  const LocalAiRecommendTab({
    super.key,
    required this.service,
    this.ratedPlaces = const [],
    this.onAddPlace,
  });

  @override
  State<LocalAiRecommendTab> createState() => _LocalAiRecommendTabState();
}

class _LocalAiRecommendTabState extends State<LocalAiRecommendTab> {
  final List<String> _destinations = [
    'Đà Lạt',
    'Đà Nẵng',
    'Hà Nội',
    'TP. Hồ Chí Minh',
    'Huế',
    'Nha Trang',
    'Phú Quốc',
    'Hội An',
  ];

  late String _selectedDestination;
  List<AiRecommendationItem> _recommendations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDestination = _destinations.first;
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);

    final results = await widget.service.getRecommendationsWithRatings(
      destination: _selectedDestination,
      budgetVnd: 5000000,
      ratedPlaces: widget.ratedPlaces.isNotEmpty ? widget.ratedPlaces : _defaultRatedPlaces(),
    );

    if (mounted) {
      setState(() {
        _recommendations = results;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _defaultRatedPlaces() {
    return [
      {
        'id': 'dalat-1',
        'name': 'Hồ Tuyền Lâm & Thiền Viện Trúc Lâm',
        'destination': 'Đà Lạt',
        'description': 'Khu hồ nước rộng lớn bao quanh bởi rừng thông bạt ngàn.',
        'estimatedCostVnd': 50000,
        'averageRating': 4.8,
        'reviewCount': 210,
        'tags': ['Thiên nhiên', 'Tĩnh lặng'],
      },
      {
        'id': 'dalat-2',
        'name': 'Quảng Trường Lâm Viên',
        'destination': 'Đà Lạt',
        'description': 'Biểu tượng hoa Dã Quỳ và nụ hoa Atiso khổng lồ.',
        'estimatedCostVnd': 0,
        'averageRating': 4.6,
        'reviewCount': 340,
        'tags': ['Check-in', 'Miễn phí'],
      },
      {
        'id': 'danang-1',
        'name': 'Bà Nà Hills & Cầu Vàng',
        'destination': 'Đà Nẵng',
        'description': 'Cây cầu được nâng đỡ bởi đôi bàn tay khổng lồ giữa mây trời.',
        'estimatedCostVnd': 950000,
        'averageRating': 4.9,
        'reviewCount': 520,
        'tags': ['Kỳ quan', 'Sống ảo'],
      },
      {
        'id': 'danang-2',
        'name': 'Cầu Rồng Phun Lửa',
        'destination': 'Đà Nẵng',
        'description': 'Màn trình diễn phun lửa và nước ấn tượng vào mỗi tối cuối tuần.',
        'estimatedCostVnd': 0,
        'averageRating': 4.7,
        'reviewCount': 415,
        'tags': ['Miễn phí', 'Đêm'],
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Điểm đến yêu thích:',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedDestination,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _destinations.map((dest) {
                    return DropdownMenuItem(value: dest, child: Text(dest));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedDestination = val);
                      _loadRecommendations();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gợi ý địa điểm ≥ 4.5⭐',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${_recommendations.length} địa điểm',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_recommendations.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Chưa có địa điểm nào đạt tiêu chuẩn ≥ 4.5 sao tại $_selectedDestination.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recommendations.length,
              itemBuilder: (context, index) {
                final item = _recommendations[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.placeName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.averageRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.brown,
                                    ),
                                  ),
                                  if (item.reviewCount > 0)
                                    Text(
                                      ' (${item.reviewCount})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.brown.shade400,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.estimatedCostVnd > 0
                                  ? '${item.estimatedCostVnd} đ'
                                  : 'Miễn phí',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                                fontSize: 13,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                if (widget.onAddPlace != null) {
                                  widget.onAddPlace!(item);
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã thêm ${item.placeName} vào danh sách dự định!'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Thêm vào chuyến đi'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

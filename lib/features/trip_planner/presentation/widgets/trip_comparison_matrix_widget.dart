import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';

class TripOptionData {
  final String title;
  final String badgeText;
  final bool isRecommended;
  final int costVnd;
  final String accommodation;
  final String transport;
  final String highlights;
  final String flexibility;
  final String targetAudience;

  const TripOptionData({
    required this.title,
    required this.badgeText,
    required this.isRecommended,
    required this.costVnd,
    required this.accommodation,
    required this.transport,
    required this.highlights,
    required this.flexibility,
    required this.targetAudience,
  });
}

class TripComparisonMatrixWidget extends StatefulWidget {
  final int baseBudgetVnd;

  const TripComparisonMatrixWidget({
    super.key,
    required this.baseBudgetVnd,
  });

  @override
  State<TripComparisonMatrixWidget> createState() => _TripComparisonMatrixWidgetState();
}

class _TripComparisonMatrixWidgetState extends State<TripComparisonMatrixWidget> {
  int _selectedIndex = 0;

  List<TripOptionData> _buildOptions() {
    return [
      const TripOptionData(
        title: 'Cân Bằng',
        badgeText: 'MCDA Đề Xuất',
        isRecommended: true,
        costVnd: 4200000,
        accommodation: 'Resort Biển 4★ (Deluxe View)',
        transport: 'Máy bay VietJet Air (Khứ hồi)',
        highlights: 'Cáp treo Bà Nà Hills & Cầu Vàng',
        flexibility: 'Miễn phí hủy phòng trước 48h',
        targetAudience: 'Nhóm bạn / Lần đầu khám phá',
      ),
      const TripOptionData(
        title: 'Tiết Kiệm',
        badgeText: 'Ngân Sách Tối Thiểu',
        isRecommended: false,
        costVnd: 3450000,
        accommodation: 'Khách sạn Trung tâm 3★',
        transport: 'Xe khách Limousine giường nằm',
        highlights: 'City Tour, Chợ Đêm & Biển Mỹ Khê',
        flexibility: 'Đổi ngày có phí linh hoạt',
        targetAudience: 'Ưu tiên tối ưu chi tiêu',
      ),
      const TripOptionData(
        title: 'Trải Nghiệm',
        badgeText: 'Nghỉ Dưỡng Cao Cấp',
        isRecommended: false,
        costVnd: 4850000,
        accommodation: 'Resort Biển 5★ & Spa',
        transport: 'Vé máy bay giờ đẹp + Xe riêng',
        highlights: 'Tour riêng Sơn Trà & Tiệc tối hải sản',
        flexibility: 'Miễn phí hủy & Đổi lịch trình 24h',
        targetAudience: 'Cặp đôi & Nghỉ dưỡng thư giãn',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0);
    final theme = Theme.of(context);
    final options = _buildOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ma Trận So Sánh Phương Án',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dựa trên ngân sách ${currencyFmt.format(widget.baseBudgetVnd)} của bạn',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.slate700),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '3 Kịch Bản',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tabs to toggle options
        Row(
          children: List.generate(options.length, (index) {
            final opt = options[index];
            final isSelected = _selectedIndex == index;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < options.length - 1 ? 8.0 : 0),
                child: InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : Colors.white,
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : AppTheme.slate200,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        if (opt.isRecommended)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : AppTheme.accentOrange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ĐỀ XUẤT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? theme.colorScheme.primary : Colors.white,
                              ),
                            ),
                          ),
                        Text(
                          opt.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currencyFmt.format(opt.costVnd),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white70 : AppTheme.accentOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        // Detail Card for selected option
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chi Tiết Phương Án: ${options[_selectedIndex].title}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      currencyFmt.format(options[_selectedIndex].costVnd),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildCriterionRow(
                  Icons.hotel_outlined,
                  'Chỗ ở',
                  options[_selectedIndex].accommodation,
                ),
                const SizedBox(height: 12),
                _buildCriterionRow(
                  Icons.flight_takeoff_outlined,
                  'Di chuyển',
                  options[_selectedIndex].transport,
                ),
                const SizedBox(height: 12),
                _buildCriterionRow(
                  Icons.attractions_outlined,
                  'Trải nghiệm',
                  options[_selectedIndex].highlights,
                ),
                const SizedBox(height: 12),
                _buildCriterionRow(
                  Icons.event_available_outlined,
                  'Chính sách',
                  options[_selectedIndex].flexibility,
                ),
                const SizedBox(height: 12),
                _buildCriterionRow(
                  Icons.group_outlined,
                  'Phù hợp với',
                  options[_selectedIndex].targetAudience,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCriterionRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.slate700, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slate900),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/travel_image.dart';
import '../../../../core/presentation/travel_media.dart';
import '../../models/editable_trip_document.dart';

class TripLivePreview extends StatelessWidget {
  final TripInput input;
  final int dayCount;
  final bool compact;
  const TripLivePreview({
    super.key,
    required this.input,
    required this.dayCount,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destination = input.destinationName?.trim();
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          TravelImage(
            media: TravelMediaCatalog.forDestination(input.destinationId),
            semanticLabel:
                'Ảnh ${destination?.isNotEmpty == true ? destination : 'điểm đến'}',
            height: 160,
          ),
          const SizedBox(height: 16),
        ],
        Text(
          destination?.isNotEmpty == true ? destination! : 'Chọn điểm đến',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _PreviewMetric(
              icon: Icons.calendar_today_outlined,
              label: '$dayCount ngày',
            ),
            _PreviewMetric(
              icon: Icons.people_outline,
              label: '${input.travelerCount} người',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Ngân sách ${money.format(input.totalBudgetVnd)}',
          style: theme.textTheme.titleMedium,
        ),
        if (input.travelerCount > 0)
          Text(
            'Khoảng ${money.format(input.totalBudgetVnd ~/ input.travelerCount)}/người',
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PreviewMetric({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
}

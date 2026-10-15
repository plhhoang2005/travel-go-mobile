import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/trip_provider.dart';
import 'planner_workspace_actions.dart';

class SelectedDestinationControls extends StatelessWidget {
  final VoidCallback? onManualPlanner;
  const SelectedDestinationControls({super.key, this.onManualPlanner});
  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>();
    if (!trip.hasSelectedDestination && !trip.isAccountWorkspace) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trip.hasSelectedDestination) ...[
            Text(
              'Điểm đến đã chọn',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              trip.currentMetadata.destinationName ??
                  trip.currentMetadata.destinationId!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Tính năng tự động chưa hỗ trợ điểm đến đã chọn. Bạn có thể tự lập lịch trình.',
            ),
            const SizedBox(height: 8),
            if (onManualPlanner != null) ...[
              FilledButton.icon(
                onPressed: trip.canReplaceWorkspace ? onManualPlanner : null,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Tự lập lịch trình'),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton(
              onPressed: trip.canReplaceWorkspace
                  ? () => replacePlannerWorkspace(context)
                  : null,
              child: const Text('Để app gợi ý điểm đến'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đây là thông tin đầu vào. Bạn có thể điều chỉnh các giá trị bên dưới.',
            ),
          ],
          if (trip.isAccountWorkspace) ...[
            const SizedBox(height: 8),
            const Text(
              'Thông tin này chưa được lưu',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text(
              'Nội dung hiện chỉ được giữ trong phiên làm việc của ứng dụng.',
            ),
          ],
        ],
      ),
    );
  }
}

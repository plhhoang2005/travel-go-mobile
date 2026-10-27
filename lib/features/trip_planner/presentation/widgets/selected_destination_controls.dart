import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../explore/providers/public_catalogue_provider.dart';
import '../../../trips/models/trip_payload_codec.dart';
import '../../models/trip_request.dart';
import '../../providers/planner_input_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/editable_trip_document.dart';
import 'planner_workspace_actions.dart';
import 'trip_live_preview.dart';

class SelectedDestinationControls extends StatelessWidget {
  final VoidCallback? onManualPlanner;
  const SelectedDestinationControls({super.key, this.onManualPlanner});
  @override
  Widget build(BuildContext context) {
    PlannerInputProvider? inputProvider;
    try {
      inputProvider = context.watch<PlannerInputProvider>();
    } catch (_) {}
    TripProvider? legacyTrip;
    if (inputProvider == null) {
      try {
        legacyTrip = context.watch<TripProvider>();
      } catch (_) {}
    }

    final request = inputProvider?.currentRequest ?? legacyTrip?.currentRequest ?? PlanTripRequest.presetMinh();
    final metadata = inputProvider?.currentMetadata ?? legacyTrip?.currentMetadata ?? TripMetadataV1();
    final canReplace = inputProvider?.canReplaceWorkspace ?? legacyTrip?.canReplaceWorkspace ?? true;
    final hasSelectedDestination = inputProvider?.hasSelectedDestination ?? legacyTrip?.hasSelectedDestination ?? false;
    final supportsAi = inputProvider?.supportsSelectedDestinationAi ?? legacyTrip?.supportsSelectedDestinationAi ?? false;

    AuthProvider? auth;
    try {
      auth = context.watch<AuthProvider>();
    } catch (_) {}
    final isAccountWorkspace =
        (auth != null && !auth.isGuest && !auth.isDemoSession && auth.isAuthenticated) ||
        (legacyTrip != null && legacyTrip.isAccountWorkspace);
    final input = TripInput(
      title: metadata.title ?? 'Chuyến đi mới',
      destinationId: metadata.destinationId,
      destinationName: metadata.destinationName,
      startDate: metadata.startDate,
      endDate: metadata.endDate,
      timezone: 'Asia/Ho_Chi_Minh',
      origin: request.origin,
      travelerCount: request.numPeople,
      totalBudgetVnd: request.budgetVnd,
      interests: request.preferences,
      priority: request.priority,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TripLivePreview(
            input: input,
            dayCount: request.numDays,
            compact: MediaQuery.textScalerOf(context).scale(16) > 21,
          ),
          const SizedBox(height: 16),
          if (onManualPlanner != null) ...[
            FilledButton.icon(
              onPressed: canReplace ? onManualPlanner : null,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Tự lập lịch trình'),
            ),
            const SizedBox(height: 16),
          ],
          if (hasSelectedDestination) ...[
            Text(
              'Điểm đến đã chọn',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                PublicCatalogueProvider? pub;
                try {
                  pub = context.watch<PublicCatalogueProvider>();
                } catch (_) {}
                final snapshot = pub?.snapshot;
                final isSupported = metadata.destinationId == null ||
                    (snapshot != null
                        ? PlannerInputProvider.isAiEligibleDestination(metadata.destinationId, snapshot)
                        : supportsAi);
                return Text(
                  isSupported
                      ? 'Hệ thống sẽ đồng hành cùng bạn khi lập lịch trình cho ${metadata.destinationName ?? "điểm đến này"}.'
                      : 'Tính năng tự động và AI chưa hỗ trợ điểm đến này. Bạn có thể tự lập lịch trình.',
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: canReplace
                  ? () => replacePlannerWorkspace(context)
                  : null,
              child: const Text('Để app gợi ý điểm đến'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đây là thông tin đầu vào. Bạn có thể điều chỉnh các giá trị bên dưới.',
            ),
          ],
          if (isAccountWorkspace) ...[
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

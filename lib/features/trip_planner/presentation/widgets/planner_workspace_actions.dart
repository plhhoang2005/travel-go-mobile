import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/manual_planner_provider.dart';
import '../../providers/planner_input_provider.dart';
import '../../providers/trip_provider.dart';

Future<bool> replacePlannerWorkspace(
  BuildContext context, {
  String? destinationId,
  String? destinationName,
}) async {
  PlannerInputProvider? input;
  try {
    input = context.read<PlannerInputProvider>();
  } catch (_) {}

  TripProvider? trip;
  if (input == null) {
    try {
      trip = context.read<TripProvider>();
    } catch (_) {}
  }

  ManualPlannerProvider? manualPlanner;
  try {
    manualPlanner = context.read<ManualPlannerProvider>();
  } catch (_) {}

  if (manualPlanner != null && (manualPlanner.isSaving || manualPlanner.hasPendingSave)) {
    return false;
  }

  final canReplace = input?.canReplaceWorkspace ?? trip?.canReplaceWorkspace ?? true;
  if (!canReplace) return false;

  final isManualDirty = (manualPlanner != null && manualPlanner.document != null && manualPlanner.dirty);
  final isLegacyDirty = (input == null && (trip?.isDraftDirty ?? false));
  final dirty = isManualDirty || isLegacyDirty;

  final generation = trip?.workspaceGeneration;
  final revision = trip?.activeDraftRevision;
  final metadata = trip?.currentMetadata;
  final draftId = trip?.activeDraftId;

  if (dirty) {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Tạo chuyến đi mới?'),
        content: const Text(
          'Nội dung đang sửa sẽ được thay thế. Các bản nháp đã lưu vẫn còn trên máy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Tạo mới'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return false;
  }
  if (!context.mounted) return false;

  if (input != null) {
    if (destinationId == null) {
      input.useSuggestedDestination();
    } else {
      input.prepareDestinationWorkspace(
        destinationId: destinationId,
        destinationName: destinationName ?? '',
      );
    }
    return true;
  }

  bool accepted = true;
  if (trip != null) {
    final unchanged =
        generation == trip.workspaceGeneration &&
        identical(metadata, trip.currentMetadata) &&
        draftId == trip.activeDraftId &&
        revision == trip.activeDraftRevision;
    accepted = unchanged &&
        (destinationId == null
            ? trip.useSuggestedDestination(
                expectedWorkspaceGeneration: generation!,
                replaceDirty: dirty,
              )
            : trip.prepareDestinationWorkspace(
                destinationId: destinationId,
                destinationName: destinationName ?? '',
                expectedWorkspaceGeneration: generation!,
                replaceDirty: dirty,
              ));
    if (!accepted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nội dung hoặc phiên đã thay đổi; vui lòng chọn lại'),
        ),
      );
    }
  }
  return accepted;
}

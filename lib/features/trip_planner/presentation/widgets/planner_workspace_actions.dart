import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/trip_provider.dart';

Future<bool> replacePlannerWorkspace(
  BuildContext context, {
  String? destinationId,
  String? destinationName,
}) async {
  final trip = context.read<TripProvider>();
  if (!trip.canReplaceWorkspace) return false;
  final generation = trip.workspaceGeneration,
      revision = trip.activeDraftRevision;
  final metadata = trip.currentMetadata;
  final draftId = trip.activeDraftId;
  final dirty = trip.isDraftDirty;
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
  // A save may change identity/metadata without changing generation.
  final unchanged =
      generation == trip.workspaceGeneration &&
      identical(metadata, trip.currentMetadata) &&
      draftId == trip.activeDraftId &&
      revision == trip.activeDraftRevision;
  final accepted =
      unchanged &&
      (destinationId == null
          ? trip.useSuggestedDestination(
              expectedWorkspaceGeneration: generation,
              replaceDirty: dirty,
            )
          : trip.prepareDestinationWorkspace(
              destinationId: destinationId,
              destinationName: destinationName ?? '',
              expectedWorkspaceGeneration: generation,
              replaceDirty: dirty,
            ));
  if (!accepted && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nội dung hoặc phiên đã thay đổi; vui lòng chọn lại'),
      ),
    );
  }
  return accepted;
}

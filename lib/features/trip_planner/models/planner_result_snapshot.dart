import 'package:flutter/foundation.dart';

import '../../trips/models/trip_payload_codec.dart';
import 'trip_request.dart';
import 'trip_response.dart';

/// Immutable snapshot of the result context produced by the planner engine.
/// Carries the original user request, metadata, and engine plan response.
@immutable
class PlannerResultSnapshot {
  final PlanTripRequest request;
  final TripMetadataV1 metadata;
  final PlanTripResponse plan;
  final int workspaceGeneration;

  const PlannerResultSnapshot({
    required this.request,
    required this.metadata,
    required this.plan,
    required this.workspaceGeneration,
  });

  /// Finds the winning destination card matching [plan.winnerId].
  /// Returns null if winnerId is not found or topDestinations is empty.
  DestinationCard? get winner {
    final winnerId = plan.winnerId;
    if (winnerId.isEmpty) return null;
    try {
      return plan.topDestinations.firstWhere(
        (d) => d.id == winnerId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Converts this snapshot into a canonical envelope payload for cloud or guest persistence.
  CanonicalTripPayloadV1 toPayload({required String title}) {
    final winnerCard = winner;
    final destId = winnerCard?.id ?? metadata.destinationId ?? request.destinationId;
    final destName = winnerCard?.name ?? metadata.destinationName ?? request.destinationName;
    final start = request.startDate ?? metadata.startDate;
    final end = request.endDate ?? metadata.endDate;

    final updatedMetadata = metadata.copyWith(
      title: title,
      destinationId: destId,
      destinationName: destName,
      startDate: start,
      endDate: end,
    );

    return CanonicalTripPayloadV1(
      schemaVersion: 1,
      metadata: updatedMetadata,
      request: request,
      plan: plan,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannerResultSnapshot &&
          runtimeType == other.runtimeType &&
          workspaceGeneration == other.workspaceGeneration &&
          identical(request, other.request) &&
          identical(metadata, other.metadata) &&
          identical(plan, other.plan);

  @override
  int get hashCode => Object.hash(request, metadata, plan, workspaceGeneration);
}

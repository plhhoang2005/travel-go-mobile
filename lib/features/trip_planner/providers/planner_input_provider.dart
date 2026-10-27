import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../explore/models/public_catalogue_snapshot.dart';
import '../../trips/models/trip_payload_codec.dart';
import '../models/trip_request.dart';
import '../services/trip_date_policy.dart';

/// Provider managing planner input state, independent of Decision Engine,
/// remote persistence, or map dependencies.
class PlannerInputProvider extends ChangeNotifier {
  static final RegExp destinationIdRegex = RegExp(r'^[a-z0-9][a-z0-9/-]{0,119}$');
  static const Set<String> supportedAiDestinationIds = {'hue'};

  PlanTripRequest _currentRequest;
  TripMetadataV1 _currentMetadata;
  int _workspaceGeneration = 0;
  bool _disposed = false;

  PlannerInputProvider({
    PlanTripRequest? initialRequest,
    TripMetadataV1? initialMetadata,
  })  : _currentRequest = TripPayloadCodec.deepFreezeRequest(
          initialRequest ?? PlanTripRequest.presetMinh(),
        ),
        _currentMetadata = initialMetadata ?? TripMetadataV1();

  PlanTripRequest get currentRequest => _currentRequest;
  TripMetadataV1 get currentMetadata => _currentMetadata;
  int get workspaceGeneration => _workspaceGeneration;
  bool get canReplaceWorkspace => !_disposed;
  bool get hasPlannerInput => true;
  bool get hasSelectedDestination =>
      _currentMetadata.destinationId != null ||
      (_currentMetadata.destinationName != null &&
          _currentMetadata.destinationName!.trim().isNotEmpty);

  bool get supportsSelectedDestinationAi {
    final id = _currentMetadata.destinationId;
    if (id == null) return true;
    return supportedAiDestinationIds.contains(id);
  }

  static bool isAiEligibleDestination(
    String? id,
    PublicCatalogueSnapshot snapshot,
  ) {
    if (id == null || !destinationIdRegex.hasMatch(id)) return false;
    return snapshot.catalogue.destinations.any((d) => d.id == id);
  }

  bool prepareDestinationWorkspace({
    required String destinationId,
    required String destinationName,
    int? expectedWorkspaceGeneration,
    bool replaceDirty = false,
  }) {
    if (_disposed) return false;
    if (expectedWorkspaceGeneration != null &&
        expectedWorkspaceGeneration != _workspaceGeneration) {
      return false;
    }
    if (!destinationIdRegex.hasMatch(destinationId) ||
        destinationName.trim().isEmpty) {
      return false;
    }
    setDestination(id: destinationId, name: destinationName);
    return true;
  }

  bool useSuggestedDestination({
    int? expectedWorkspaceGeneration,
    bool replaceDirty = false,
  }) {
    if (_disposed) return false;
    if (expectedWorkspaceGeneration != null &&
        expectedWorkspaceGeneration != _workspaceGeneration) {
      return false;
    }
    _currentMetadata = TripMetadataV1(
      title: 'Chuyến đi mới',
      destinationId: null,
      destinationName: null,
      startDate: _currentMetadata.startDate,
      endDate: _currentMetadata.endDate,
    );
    final updated = _currentRequest.copyWith(
      clearDestination: true,
    );
    _currentRequest = TripPayloadCodec.deepFreezeRequest(updated);
    _workspaceGeneration++;
    notifyListeners();
    return true;
  }

  void updateRequest(PlanTripRequest value) {
    if (_disposed) return;
    PlanTripRequest candidate = value;
    if (candidate.startDate != null || candidate.endDate != null) {
      final range = TripDatePolicy.validate(
        candidate.startDate,
        candidate.endDate,
        expectedDays: candidate.numDays,
        maxDays: 30,
      );
      if (range != null) {
        _currentMetadata = _currentMetadata.copyWith(
          startDate: range.startDate,
          endDate: range.endDate,
        );
      }
    } else {
      final existingStart = _currentMetadata.startDate;
      if (existingStart != null) {
        final newEndDate = TripDatePolicy.calculateEndDate(
          existingStart,
          candidate.numDays,
        );
        _currentMetadata = _currentMetadata.copyWith(
          startDate: existingStart,
          endDate: newEndDate,
        );
        candidate = candidate.copyWith(
          startDate: existingStart,
          endDate: newEndDate,
        );
      }
    }
    final frozen = TripPayloadCodec.deepFreezeRequest(candidate);
    if (jsonEncode(frozen.toJson()) == jsonEncode(_currentRequest.toJson())) {
      return;
    }
    _currentRequest = frozen;
    _workspaceGeneration++;
    notifyListeners();
  }

  void setCalendarRange(String startDate, String endDate) {
    if (_disposed) return;
    final range = TripDatePolicy.validate(startDate, endDate, maxDays: 30);
    if (range == null) return;
    final updated = _currentRequest.copyWith(
      startDate: range.startDate,
      endDate: range.endDate,
      numDays: range.numDays,
    );
    _currentRequest = TripPayloadCodec.deepFreezeRequest(updated);
    _currentMetadata = _currentMetadata.copyWith(
      startDate: range.startDate,
      endDate: range.endDate,
    );
    _workspaceGeneration++;
    notifyListeners();
  }

  void setDuration(int days) {
    if (_disposed) return;
    if (days < 1 || days > 30) {
      throw FormatException('Số ngày phải từ 1 đến 30 ngày (nhận được $days)');
    }
    final existingStart = _currentRequest.startDate ?? _currentMetadata.startDate;
    String? newEndDate;
    if (existingStart != null) {
      newEndDate = TripDatePolicy.calculateEndDate(existingStart, days);
      _currentMetadata = _currentMetadata.copyWith(
        startDate: existingStart,
        endDate: newEndDate,
      );
    }
    final updated = _currentRequest.copyWith(
      numDays: days,
      startDate: existingStart,
      endDate: newEndDate,
    );
    _currentRequest = TripPayloadCodec.deepFreezeRequest(updated);
    _workspaceGeneration++;
    notifyListeners();
  }

  void setDestination({required String? id, required String name}) {
    if (_disposed) return;
    final trimmedName = name.trim();
    if (id != null && !destinationIdRegex.hasMatch(id)) {
      throw ArgumentError('Invalid destination ID format: $id');
    }
    _currentMetadata = TripMetadataV1(
      title: trimmedName.isNotEmpty ? 'Chuyến đi $trimmedName' : 'Chuyến đi mới',
      destinationId: id,
      destinationName: trimmedName.isNotEmpty ? trimmedName : null,
      startDate: _currentMetadata.startDate,
      endDate: _currentMetadata.endDate,
    );
    final updated = _currentRequest.copyWith(
      destinationId: id,
      destinationName: trimmedName.isNotEmpty ? trimmedName : null,
    );
    _currentRequest = TripPayloadCodec.deepFreezeRequest(updated);
    _workspaceGeneration++;
    notifyListeners();
  }

  void applyPreset(int presetId) {
    if (_disposed) return;
    PlanTripRequest preset;
    if (presetId == 1) {
      preset = PlanTripRequest.presetMinh();
    } else if (presetId == 2) {
      preset = PlanTripRequest.presetPhuQuoc();
    } else if (presetId == 3) {
      preset = PlanTripRequest.presetVungTau();
    } else {
      return;
    }

    final destId = _currentMetadata.destinationId ?? _currentRequest.destinationId;
    final destName = _currentMetadata.destinationName ?? _currentRequest.destinationName;

    final existingStart = _currentRequest.startDate ?? _currentMetadata.startDate;
    String? newEndDate;
    if (existingStart != null) {
      newEndDate = TripDatePolicy.calculateEndDate(existingStart, preset.numDays);
      _currentMetadata = _currentMetadata.copyWith(
        startDate: existingStart,
        endDate: newEndDate,
      );
    } else {
      _currentMetadata = _currentMetadata.copyWith(
        startDate: null,
        endDate: null,
      );
    }

    final updated = preset.copyWith(
      destinationId: destId,
      destinationName: destName,
      startDate: existingStart,
      endDate: newEndDate,
    );
    _currentRequest = TripPayloadCodec.deepFreezeRequest(updated);
    _workspaceGeneration++;
    notifyListeners();
  }

  void init() {
    // No-op for decoupled planner input
  }

  void reset() {
    if (_disposed) return;
    _currentRequest = TripPayloadCodec.deepFreezeRequest(PlanTripRequest.presetMinh());
    _currentMetadata = TripMetadataV1();
    _workspaceGeneration++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import '../models/trip_request.dart';
import '../models/trip_response.dart';
import '../services/trip_api_service.dart';

class TripProvider extends ChangeNotifier {
  final TripApiService _apiService;

  TripProvider({TripApiService? apiService})
      : _apiService = apiService ?? TripApiService();

  PlanTripRequest _currentRequest = PlanTripRequest.presetMinh();
  PlanTripResponse? _currentResponse;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isBackendOnline = false;

  PlanTripRequest get currentRequest => _currentRequest;
  PlanTripResponse? get currentResponse => _currentResponse;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isBackendOnline => _isBackendOnline;

  Future<void> init() async {
    _isBackendOnline = await _apiService.checkHealth();
    notifyListeners();
  }

  void updateRequest(PlanTripRequest newRequest) {
    _currentRequest = newRequest;
    notifyListeners();
  }

  void applyPreset(int presetId) {
    if (presetId == 1) {
      _currentRequest = PlanTripRequest.presetMinh();
    } else if (presetId == 2) {
      _currentRequest = PlanTripRequest.presetPhuQuoc();
    } else if (presetId == 3) {
      _currentRequest = PlanTripRequest.presetVungTau();
    }
    notifyListeners();
  }

  Future<void> submitPlan() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.planTrip(_currentRequest);
      _currentResponse = response;
    } catch (e) {
      _errorMessage = 'Không thể kết nối đến máy chủ: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

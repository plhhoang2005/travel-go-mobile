import 'package:flutter/material.dart';
import '../models/saved_trip_model.dart';
import '../services/trips_service.dart';

class SavedTripsProvider extends ChangeNotifier {
  final TripsService _service = TripsService();

  List<SavedTrip> _trips = [];
  bool _isLoading = false;
  String? _currentUserId;

  List<SavedTrip> get trips => List.unmodifiable(_trips);
  bool get isLoading => _isLoading;
  int get count => _trips.length;

  List<SavedTrip> get upcomingTrips {
    final now = DateTime.now();
    return _trips.where((t) => t.startDate == null || t.startDate!.isAfter(now.subtract(const Duration(days: 1)))).toList();
  }

  Future<void> loadTrips(String? userId) async {
    if (userId == null || userId.isEmpty) {
      _trips = [];
      _currentUserId = null;
      notifyListeners();
      return;
    }

    _currentUserId = userId;
    _isLoading = true;
    notifyListeners();

    final fetched = await _service.fetchTrips(userId);
    _trips = fetched;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveTrip({
    required String title,
    required String destinationName,
    required int numDays,
    required double budgetTotal,
    DateTime? startDate,
    DateTime? endDate,
    required Map<String, dynamic> tripPlanData,
  }) async {
    if (_currentUserId == null) return false;

    _isLoading = true;
    notifyListeners();

    final newTrip = SavedTrip(
      id: '',
      userId: _currentUserId!,
      title: title,
      destinationName: destinationName,
      numDays: numDays,
      budgetTotal: budgetTotal,
      startDate: startDate,
      endDate: endDate,
      tripPlanData: tripPlanData,
      createdAt: DateTime.now(),
    );

    final saved = await _service.saveTrip(newTrip);
    _isLoading = false;

    if (saved != null) {
      _trips.insert(0, saved);
      notifyListeners();
      return true;
    } else {
      // Local optimistic fallback
      _trips.insert(0, newTrip);
      notifyListeners();
      return true;
    }
  }

  Future<bool> deleteTrip(String tripId) async {
    if (_currentUserId == null) return false;

    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index >= 0) {
      final removed = _trips.removeAt(index);
      notifyListeners();

      final success = await _service.deleteTrip(
        tripId: tripId,
        userId: _currentUserId!,
      );

      if (!success && tripId.isNotEmpty) {
        _trips.insert(index, removed);
        notifyListeners();
        return false;
      }
    }
    return true;
  }

  void clearLocal() {
    _trips = [];
    _currentUserId = null;
    notifyListeners();
  }
}

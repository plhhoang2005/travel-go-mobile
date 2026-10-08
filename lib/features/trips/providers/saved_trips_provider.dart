import 'package:flutter/material.dart';
import '../models/saved_trip_model.dart';
import '../services/trips_service.dart';

class SavedTripsProvider extends ChangeNotifier {
  final TripsService _service;

  List<SavedTrip> _trips = [];
  bool _isLoading = false;
  String? _currentUserId;
  String? _errorMessage;
  int _sessionEpoch = 0;

  List<SavedTrip> get trips => List.unmodifiable(_trips);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentUserId => _currentUserId;
  int get sessionEpoch => _sessionEpoch;
  int get count => _trips.length;

  SavedTripsProvider({TripsService? service}) : _service = service ?? TripsService();

  List<SavedTrip> get upcomingTrips {
    final now = DateTime.now();
    return _trips.where((t) => t.startDate == null || t.startDate!.isAfter(now.subtract(const Duration(days: 1)))).toList();
  }

  Future<void> loadTrips(String? userId) async {
    _sessionEpoch++;
    final targetEpoch = _sessionEpoch;

    if (userId == null || userId.isEmpty) {
      _trips = [];
      _currentUserId = null;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    final isNewUser = _currentUserId != userId;
    if (isNewUser) {
      _trips = [];
      _errorMessage = null;
    }

    _currentUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _service.fetchTrips(userId);
      // Drop late responses if epoch or user changed
      if (_sessionEpoch != targetEpoch || _currentUserId != userId) {
        return;
      }
      _trips = fetched;
      _errorMessage = null;
    } catch (e) {
      if (_sessionEpoch != targetEpoch || _currentUserId != userId) {
        return;
      }
      _errorMessage = 'Lỗi tải danh sách chuyến đi: ${e.toString()}';
    } finally {
      if (_sessionEpoch == targetEpoch && _currentUserId == userId) {
        _isLoading = false;
        notifyListeners();
      }
    }
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
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      _errorMessage = 'Vui lòng đăng nhập để lưu chuyến đi.';
      notifyListeners();
      return false;
    }

    final targetEpoch = _sessionEpoch;
    final targetUserId = _currentUserId!;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final newTrip = SavedTrip(
      id: '',
      userId: targetUserId,
      title: title,
      destinationName: destinationName,
      numDays: numDays,
      budgetTotal: budgetTotal,
      startDate: startDate,
      endDate: endDate,
      tripPlanData: tripPlanData,
      createdAt: DateTime.now(),
    );

    try {
      final saved = await _service.saveTrip(newTrip);

      // Verify epoch and session match
      if (_sessionEpoch != targetEpoch || _currentUserId != targetUserId) {
        return false;
      }

      // STRICT LAW: Success only after valid server ID acknowledgement
      if (saved.id.isNotEmpty && saved.userId == targetUserId) {
        _trips.insert(0, saved);
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Máy chủ trả về phản hồi không hợp lệ.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (_sessionEpoch != targetEpoch || _currentUserId != targetUserId) {
        return false;
      }
      _errorMessage = 'Không thể lưu chuyến đi lên máy chủ: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTrip(String tripId) async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;

    final targetEpoch = _sessionEpoch;
    final targetUserId = _currentUserId!;

    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index < 0) return false;

    final removed = _trips.removeAt(index);
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _service.deleteTrip(
        tripId: tripId,
        userId: targetUserId,
      );

      if (!success) {
        // Rollback only if still in the same user session
        if (_sessionEpoch == targetEpoch && _currentUserId == targetUserId) {
          _trips.insert(index, removed);
          _errorMessage = 'Không thể xóa chuyến đi khỏi máy chủ.';
          notifyListeners();
        }
        return false;
      }
      return true;
    } catch (e) {
      if (_sessionEpoch == targetEpoch && _currentUserId == targetUserId) {
        _trips.insert(index, removed);
        _errorMessage = 'Lỗi khi xóa chuyến đi: ${e.toString()}';
        notifyListeners();
      }
      return false;
    }
  }

  void clearLocal() {
    _sessionEpoch++;
    _trips = [];
    _currentUserId = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  bool _isDisposed = false;
  String? _pendingFetchUserId;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Synchronously align user context during ProxyProvider.update to avoid
  /// cross-account cache exposure in intermediate build frames.
  void updateAuthContext({
    required bool isAuthenticated,
    required bool isDemoSession,
    required String? userId,
  }) {
    if (isAuthenticated && !isDemoSession && userId != null && userId.isNotEmpty) {
      if (_currentUserId != userId) {
        _sessionEpoch++;
        _trips = [];
        _currentUserId = userId;
        _errorMessage = null;
        _isLoading = true;
        _pendingFetchUserId = userId;
      }
    } else {
      if (_currentUserId != null || _trips.isNotEmpty) {
        _sessionEpoch++;
        _trips = [];
        _currentUserId = null;
        _errorMessage = null;
        _isLoading = false;
        _pendingFetchUserId = null;
      }
    }
  }

  /// Trigger pending fetch deferred to post-frame safely.
  void fetchIfPending() {
    if (_isDisposed) return;
    final targetUserId = _pendingFetchUserId;
    if (targetUserId != null && targetUserId.isNotEmpty) {
      _pendingFetchUserId = null;
      loadTrips(targetUserId);
    }
  }

  /// Lifecycle synchronization hook driven by AuthProvider.
  /// Ensures account isolation, demo session containment, and prevents cross-user stale cache.
  void syncWithAuth({
    required bool isAuthenticated,
    required bool isDemoSession,
    required String? userId,
  }) {
    if (isAuthenticated && !isDemoSession && userId != null && userId.isNotEmpty) {
      if (_currentUserId != userId) {
        loadTrips(userId);
      }
    } else {
      if (_currentUserId != null || _trips.isNotEmpty) {
        clearLocal();
      }
    }
  }
}

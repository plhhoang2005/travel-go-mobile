import 'package:flutter/foundation.dart';

import '../models/place_review.dart';
import '../services/review_service.dart';

enum PlaceReviewsLoadState { idle, loading, ready, error }

class PlaceReviewsProvider extends ChangeNotifier {
  final ReviewService service;
  final bool Function(String placeId)? placeValidator;

  PlaceReviewsProvider({required this.service, this.placeValidator});

  String? _placeId;
  List<PlaceReview> _reviews = const [];
  int? _filter;
  PlaceReviewsLoadState _state = PlaceReviewsLoadState.idle;
  String? _errorMessage;
  bool _isSubmitting = false;
  int _generation = 0;
  String? _authUserId;
  int _authEpoch = 0;
  bool _disposed = false;

  String? get placeId => _placeId;
  List<PlaceReview> get reviews => List.unmodifiable(_reviews);
  List<PlaceReview> get visibleReviews => List.unmodifiable(
    _filter == null
        ? _reviews
        : _reviews.where((review) => review.rating == _filter).toList(),
  );
  ReviewSummary get summary => ReviewSummary.fromReviews(_reviews);
  int? get filter => _filter;
  PlaceReviewsLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isSubmitting => _isSubmitting;
  bool get canSubmit => service.canSubmit;

  void bindAuthContext({required String? userId, required int authEpoch}) {
    if (_disposed || (_authUserId == userId && _authEpoch == authEpoch)) return;
    _authUserId = userId;
    _authEpoch = authEpoch;
    _generation++;
    _placeId = null;
    _reviews = const [];
    _filter = null;
    _state = PlaceReviewsLoadState.idle;
    _errorMessage = null;
    _isSubmitting = false;
    notifyListeners();
  }

  Future<void> load(String nextPlaceId, {bool force = false}) async {
    if (_disposed) return;
    if (!force &&
        _placeId == nextPlaceId &&
        _state == PlaceReviewsLoadState.ready) {
      return;
    }
    if (placeValidator != null && !placeValidator!(nextPlaceId)) {
      _placeId = nextPlaceId;
      _reviews = const [];
      _state = PlaceReviewsLoadState.error;
      _errorMessage = 'Địa điểm không tồn tại trong catalogue hiện tại.';
      notifyListeners();
      return;
    }
    final generation = ++_generation;
    _placeId = nextPlaceId;
    _reviews = const [];
    _state = PlaceReviewsLoadState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await service.fetchReviews(nextPlaceId);
      if (_disposed || generation != _generation || _placeId != nextPlaceId) {
        return;
      }
      _reviews = result;
      _state = PlaceReviewsLoadState.ready;
    } catch (error) {
      if (_disposed || generation != _generation || _placeId != nextPlaceId) {
        return;
      }
      _state = PlaceReviewsLoadState.error;
      _errorMessage = error.toString();
    }
    if (!_disposed && generation == _generation) notifyListeners();
  }

  void setFilter(int? value) {
    if (_disposed ||
        value == _filter ||
        value != null && (value < 1 || value > 5)) {
      return;
    }
    _filter = value;
    notifyListeners();
  }

  Future<bool> submit({
    required String placeId,
    required int rating,
    required String comment,
  }) async {
    if (_disposed || _isSubmitting) return false;
    if (placeValidator != null && !placeValidator!(placeId)) {
      _errorMessage = 'Địa điểm không tồn tại trong catalogue hiện tại.';
      notifyListeners();
      return false;
    }
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    final generation = _generation;
    final authEpoch = _authEpoch;
    final authUserId = _authUserId;
    try {
      await service.submitReview(
        placeId: placeId,
        rating: rating,
        comment: comment,
        expectedUserId: authUserId,
      );
      if (_disposed ||
          generation != _generation ||
          authEpoch != _authEpoch ||
          authUserId != _authUserId ||
          _placeId != placeId) {
        return false;
      }
      _isSubmitting = false;
      await load(placeId, force: true);
      return true;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _isSubmitting = false;
        _errorMessage = error.toString();
        notifyListeners();
      }
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

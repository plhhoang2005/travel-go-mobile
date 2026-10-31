import 'package:flutter/foundation.dart';

import '../models/place_review.dart';
import '../services/place_reviews_service.dart';

class PlaceReviewsProvider extends ChangeNotifier {
  final PlaceReviewsRepository repository;
  final String placeId;
  List<PlaceReview> _reviews = const [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorCode;
  int? _ratingFilter;
  int _operation = 0;
  bool _disposed = false;

  PlaceReviewsProvider({required this.repository, required this.placeId});

  List<PlaceReview> get reviews => List.unmodifiable(_reviews);
  List<PlaceReview> get visibleReviews => List.unmodifiable(
    _ratingFilter == null
        ? _reviews
        : _reviews.where((review) => review.rating == _ratingFilter),
  );
  PlaceReviewSummary get summary => PlaceReviewSummary.fromReviews(_reviews);
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorCode => _errorCode;
  int? get ratingFilter => _ratingFilter;

  Future<void> load() async {
    final operation = ++_operation;
    _isLoading = true;
    _errorCode = null;
    _notify();
    try {
      final loaded = await repository.fetchForPlace(placeId);
      if (_disposed || operation != _operation) return;
      _reviews = loaded;
    } on PlaceReviewFailure catch (error) {
      if (_disposed || operation != _operation) return;
      _errorCode = error.code;
    } catch (_) {
      if (_disposed || operation != _operation) return;
      _errorCode = 'network_error';
    } finally {
      if (!_disposed && operation == _operation) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<bool> submit({required int rating, required String content}) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _errorCode = null;
    _notify();
    try {
      final review = await repository.create(
        placeId: placeId,
        rating: rating,
        content: content,
      );
      if (_disposed) return false;
      _reviews = [review, ..._reviews.where((item) => item.id != review.id)];
      return true;
    } on PlaceReviewFailure catch (error) {
      if (!_disposed) _errorCode = error.code;
      return false;
    } catch (_) {
      if (!_disposed) _errorCode = 'network_error';
      return false;
    } finally {
      if (!_disposed) {
        _isSubmitting = false;
        _notify();
      }
    }
  }

  void setRatingFilter(int? rating) {
    if (rating != null && (rating < 1 || rating > 5)) return;
    if (_ratingFilter == rating) return;
    _ratingFilter = rating;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    super.dispose();
  }
}

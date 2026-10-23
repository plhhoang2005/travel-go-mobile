import 'dart:async';
import 'package:flutter/material.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import '../models/destination_model.dart';
import '../models/destination_weather.dart';
import '../models/service_model.dart';
import '../models/voucher_model.dart';
import '../services/home_catalog_service.dart';
import '../services/open_meteo_service.dart';

class HomeCatalogProvider extends ChangeNotifier {
  final HomeCatalogService _service;
  final OpenMeteoService _weatherService;

  List<DestinationModel> _destinations = [];
  List<ServiceModel> _featuredHotels = [];
  List<ServiceModel> _popularTours = [];
  List<VoucherModel> _vouchers = [];
  Map<String, DestinationWeather> _weatherMap = {};

  bool _isLoading = false;
  bool _isOffline = false;
  bool _boundToV2 = false;
  int? _v2Version;

  List<DestinationModel> get destinations => _destinations;
  List<ServiceModel> get featuredHotels => _featuredHotels;
  List<ServiceModel> get popularTours => _popularTours;
  List<VoucherModel> get vouchers => _vouchers;
  Map<String, DestinationWeather> get weatherMap => _weatherMap;
  bool get isBoundToV2 => _boundToV2;
  int? get v2Version => _v2Version;

  DestinationWeather? getWeather(String destinationId) => _weatherMap[destinationId];

  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  bool get isFallback => _isOffline;

  HomeCatalogProvider({
    HomeCatalogService? service,
    OpenMeteoService? weatherService,
    bool autoLoad = true,
  })  : _service = service ?? HomeCatalogService(),
        _weatherService = weatherService ?? OpenMeteoService() {
    if (autoLoad) {
      loadCatalog();
    }
  }

  void bindPublicSnapshot(PublicCatalogueSnapshot snapshot) {
    _boundToV2 = true;
    _v2Version = snapshot.version;
    _destinations = snapshot.catalogue.destinations.map((d) {
      return DestinationModel(
        id: d.id,
        name: d.name,
        region: d.region,
        description: d.description,
        imageUrl: d.imageUrl,
        weatherCachedTemp: null, // missing dynamic weather renders null
        isPopular: true,
      );
    }).toList();
    _isOffline = false;
    notifyListeners();
    _loadWeatherAsync(_destinations);
  }

  Future<void> fetchCatalog({bool forceRefresh = false}) =>
      loadCatalog(forceRefresh: forceRefresh);

  Future<void> loadCatalog({bool forceRefresh = false}) async {
    if (_destinations.isNotEmpty && !forceRefresh && !_boundToV2) return;

    _isLoading = true;
    notifyListeners();

    try {
      if (!_boundToV2) {
        final results = await Future.wait([
          _service.fetchDestinations(),
          _service.fetchFeaturedHotels(),
          _service.fetchPopularTours(),
          _service.fetchActiveVouchers(),
        ]);

        _destinations = results[0] as List<DestinationModel>;
        _featuredHotels = results[1] as List<ServiceModel>;
        _popularTours = results[2] as List<ServiceModel>;
        _vouchers = results[3] as List<VoucherModel>;
      } else {
        final results = await Future.wait([
          _service.fetchFeaturedHotels(),
          _service.fetchPopularTours(),
          _service.fetchActiveVouchers(),
        ]);

        _featuredHotels = results[0] as List<ServiceModel>;
        _popularTours = results[1] as List<ServiceModel>;
        _vouchers = results[2] as List<VoucherModel>;
      }
      _isOffline = false;
    } catch (_) {
      if (!_boundToV2) {
        _destinations = DestinationModel.presetFallbackList();
      }
      _featuredHotels = ServiceModel.presetHotelsFallback();
      _popularTours = ServiceModel.presetToursFallback();
      _vouchers = VoucherModel.presetFallbackList();
      _isOffline = true;
    } finally {
      _isLoading = false;
      notifyListeners();
      _loadWeatherAsync(_destinations, forceRefresh: forceRefresh);
    }
  }

  void _loadWeatherAsync(List<DestinationModel> destinations, {bool forceRefresh = false}) {
    final ids = destinations.map((d) => d.id).toList();
    _weatherService.fetchBatchWeather(ids, forceRefresh: forceRefresh).then((batch) {
      if (batch.isNotEmpty) {
        _weatherMap = {..._weatherMap, ...batch};
        notifyListeners();
      }
    }).catchError((e) {
      debugPrint('Async weather fetch notice: $e');
    });
  }

  Future<bool> claimVoucher({
    required String? userId,
    required String voucherId,
  }) async {
    if (userId == null || userId.isEmpty) return false;
    return await _service.claimVoucher(userId: userId, voucherId: voucherId);
  }
}

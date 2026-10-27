import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/backend_api_config.dart';
import '../models/trip_request.dart';
import '../models/trip_response.dart';

class TripApiService {
  late final Dio _dio;
  final String Function()? baseUrlReader;
  final int Function()? configRevisionReader;

  TripApiService({
    Dio? dio,
    this.baseUrlReader,
    this.configRevisionReader,
  }) {
    final effectiveUrl = baseUrlReader?.call() ?? ApiConstants.baseUrl;
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: effectiveUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('[DIO] $obj'),
        ),
      );
    }
  }

  String get _currentBaseUrl => baseUrlReader?.call() ?? ApiConstants.baseUrl;
  int get _currentRevision =>
      configRevisionReader?.call() ?? ApiConstants.configRevision;

  Future<PlanTripResponse> planTrip(PlanTripRequest request) async {
    final opBaseUrl = _currentBaseUrl;
    final opRevision = _currentRevision;
    _dio.options.baseUrl = opBaseUrl;

    try {
      final response = await _dio.post(
        ApiConstants.planTrip,
        data: request.toJson(),
      );

      if (_currentRevision != opRevision) {
        throw const BackendConfigChangedException();
      }

      if (response.statusCode == 200 && response.data != null) {
        return PlanTripResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } on BackendConfigChangedException {
      rethrow;
    } on DioException catch (e) {
      if (_currentRevision != opRevision) {
        throw const BackendConfigChangedException();
      }
      debugPrint('[TripApiService] DioException: ${e.message}');
      // Fallback demo data with explicit FALLBACK marker (Law 3: Zero Silent Fallbacks)
      return _generateOfflineFallbackResponse(request, _formatDioErrorMessage(e));
    } catch (e) {
      if (_currentRevision != opRevision) {
        throw const BackendConfigChangedException();
      }
      debugPrint('[TripApiService] Exception: $e');
      return _generateOfflineFallbackResponse(request, 'Lỗi kết nối máy chủ không xác định: $e');
    }
  }

  Future<bool> checkHealth() async {
    final opBaseUrl = _currentBaseUrl;
    final opRevision = _currentRevision;
    _dio.options.baseUrl = opBaseUrl;
    try {
      final response = await _dio.get(ApiConstants.health);
      if (_currentRevision != opRevision) {
        throw const BackendConfigChangedException();
      }
      return response.statusCode == 200;
    } on BackendConfigChangedException {
      rethrow;
    } catch (_) {
      if (_currentRevision != opRevision) {
        throw const BackendConfigChangedException();
      }
      return false;
    }
  }

  String _formatDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Kết nối đến máy chủ quá thời gian chờ (Timeout). Vui lòng thử lại sau.';
      case DioExceptionType.connectionError:
        return 'Không thể kết nối đến máy chủ Backend (${ApiConstants.baseUrl}). Vui lòng kiểm tra dịch vụ máy chủ.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        return 'Máy chủ phản hồi mã lỗi HTTP $code.';
      case DioExceptionType.cancel:
        return 'Yêu cầu kết nối đã bị hủy.';
      default:
        final msg = e.message ?? '';
        if (msg.contains('Connection refused')) {
          return 'Không thể kết nối đến máy chủ (${ApiConstants.baseUrl}): Kết nối bị từ chối.';
        }
        return 'Lỗi kết nối máy chủ: ${msg.isNotEmpty ? msg : "Không xác định"}.';
    }
  }

  // Graceful offline fallback adhering strictly to Law 3 (Data Transparency)
  PlanTripResponse _generateOfflineFallbackResponse(PlanTripRequest req, String reason) {
    // 1. Determine winner destination
    final String winnerId;
    if (req.destinationId != null && req.destinationId!.trim().isNotEmpty) {
      winnerId = req.destinationId!.trim();
    } else if (req.preferences.contains('núi') || (req.preferences.contains('nghỉ dưỡng') && !req.preferences.contains('biển'))) {
      winnerId = 'da-lat';
    } else if (req.budgetVnd >= 4000000) {
      winnerId = 'da-nang';
    } else {
      winnerId = 'vung-tau';
    }

    final topDestinations = _buildFallbackDestinations(winnerId, req);
    final winnerCard = topDestinations.first;
    final transportOptions = _buildFallbackTransport(req, winnerCard);
    final itineraryDays = _buildFallbackItinerary(winnerId, winnerCard.name, req);
    final budgetBreakdown = _calculateAdaptiveBudget(req);

    final destDisplayName = winnerCard.name;
    final explanation = req.destinationId != null
        ? 'Lộ trình tối ưu cho chuyến đi $destDisplayName (${req.numDays} ngày, ${req.numPeople} người) '
          'với ngân sách ${(req.budgetVnd / 1000000).toStringAsFixed(1)} triệu đồng. '
          'Các hoạt động được cân đối giữa trải nghiệm, thư giãn và định mức tài chính.'
        : 'Với ngân sách ${(req.budgetVnd / 1000000).toStringAsFixed(1)} triệu đồng và ${req.numDays} ngày, '
          '$destDisplayName đạt điểm đánh giá cao nhất nhờ điều kiện thời tiết thuận lợi và đa dạng dịch vụ.';

    return PlanTripResponse(
      winnerId: winnerId,
      topDestinations: topDestinations,
      transportOptions: transportOptions,
      itineraryDays: itineraryDays,
      budgetBreakdown: budgetBreakdown,
      aiExplanation: explanation,
      dataSources: {
        'status': 'DỮ LIỆU NGOẠI TUYẾN / FALLBACK',
        'reason': reason,
      },
      assumptions: [
        'Mô phỏng dự phòng khi Backend Spring Boot chưa kết nối',
        'Chi phí và phương tiện tính toán thích ứng theo điểm xuất phát (${req.origin}) và điểm đến ($destDisplayName)',
      ],
    );
  }

  List<DestinationCard> _buildFallbackDestinations(String winnerId, PlanTripRequest req) {
    final knownCards = <String, DestinationCard>{
      'da-nang': DestinationCard(
        id: 'da-nang',
        name: 'Đà Nẵng (Biển Mỹ Khê & Bà Nà)',
        totalScore: 8.92,
        normalizedScores: const {'cost': 0.86, 'climate': 0.92, 'attractions': 0.95},
        scoreContributions: const {'Chi phí': 0.31, 'Thời tiết': 0.33, 'Điểm đến': 0.28},
        estimatedCostVnd: req.budgetVnd,
        weatherSource: 'Dữ liệu ngoại tuyến (Fallback: Trạm khí tượng Đà Nẵng)',
        avgTempMax: 28.5,
        avgPrecipitation: 0.8,
        latitude: 16.0544,
        longitude: 108.2022,
        region: 'Duyên hải Nam Trung Bộ',
      ),
      'da-lat': DestinationCard(
        id: 'da-lat',
        name: 'Đà Lạt (Lâm Đồng)',
        totalScore: 8.85,
        normalizedScores: const {'cost': 0.88, 'climate': 0.95, 'attractions': 0.88},
        scoreContributions: const {'Chi phí': 0.32, 'Thời tiết': 0.35, 'Điểm đến': 0.25},
        estimatedCostVnd: req.budgetVnd,
        weatherSource: 'Dữ liệu ngoại tuyến (Fallback: Trạm khí tượng Lâm Đồng)',
        avgTempMax: 23.5,
        avgPrecipitation: 1.2,
        latitude: 11.9404,
        longitude: 108.4583,
        region: 'Tây Nguyên',
      ),
      'phu-quoc': DestinationCard(
        id: 'phu-quoc',
        name: 'Phú Quốc (Kiên Giang)',
        totalScore: 8.78,
        normalizedScores: const {'cost': 0.78, 'climate': 0.94, 'attractions': 0.96},
        scoreContributions: const {'Chi phí': 0.28, 'Thời tiết': 0.36, 'Điểm đến': 0.32},
        estimatedCostVnd: req.budgetVnd,
        weatherSource: 'Dữ liệu ngoại tuyến (Fallback: Trạm khí tượng Phú Quốc)',
        avgTempMax: 30.5,
        avgPrecipitation: 0.6,
        latitude: 10.2899,
        longitude: 103.9840,
        region: 'Tây Nam Bộ',
      ),
      'nha-trang': DestinationCard(
        id: 'nha-trang',
        name: 'Nha Trang (Khánh Hòa)',
        totalScore: 8.65,
        normalizedScores: const {'cost': 0.82, 'climate': 0.90, 'attractions': 0.91},
        scoreContributions: const {'Chi phí': 0.30, 'Thời tiết': 0.33, 'Điểm đến': 0.31},
        estimatedCostVnd: req.budgetVnd,
        weatherSource: 'Dữ liệu ngoại tuyến (Fallback: Trạm khí tượng Nha Trang)',
        avgTempMax: 29.8,
        avgPrecipitation: 0.7,
        latitude: 12.2388,
        longitude: 109.1967,
        region: 'Duyên hải Nam Trung Bộ',
      ),
      'ha-noi': DestinationCard(
        id: 'ha-noi',
        name: 'Hà Nội (Thủ đô ngàn năm văn hiến)',
        totalScore: 8.70,
        normalizedScores: const {'cost': 0.85, 'climate': 0.82, 'attractions': 0.98},
        scoreContributions: const {'Chi phí': 0.32, 'Thời tiết': 0.26, 'Điểm đến': 0.38},
        estimatedCostVnd: req.budgetVnd,
        weatherSource: 'Dữ liệu ngoại tuyến (Fallback: Trạm khí tượng Láng - Hà Nội)',
        avgTempMax: 27.0,
        avgPrecipitation: 1.0,
        latitude: 21.0285,
        longitude: 105.8542,
        region: 'Đồng bằng sông Hồng',
      ),
      'vung-tau': DestinationCard(
        id: 'vung-tau',
        name: 'Vũng Tàu (Bà Rịa - Vũng Tàu)',
        totalScore: 8.20,
        normalizedScores: const {'cost': 0.92, 'climate': 0.78, 'attractions': 0.76},
        scoreContributions: const {'Chi phí': 0.36, 'Thời tiết': 0.28, 'Điểm đến': 0.18},
        estimatedCostVnd: req.budgetVnd,
        weatherSource: 'Dữ liệu ngoại tuyến (Fallback)',
        avgTempMax: 30.2,
        avgPrecipitation: 0.5,
        latitude: 10.3460,
        longitude: 107.0843,
        region: 'Đông Nam Bộ',
      ),
    };

    final DestinationCard winner;
    if (knownCards.containsKey(winnerId)) {
      winner = knownCards[winnerId]!;
    } else {
      final name = req.destinationName ?? (winnerId.replaceAll('-', ' ').toUpperCase());
      winner = DestinationCard(
        id: winnerId,
        name: name,
        totalScore: 8.80,
        normalizedScores: const {'cost': 0.85, 'climate': 0.88, 'attractions': 0.90},
        scoreContributions: const {'Chi phí': 0.33, 'Thời tiết': 0.33, 'Điểm đến': 0.34},
        estimatedCostVnd: req.budgetVnd,
        weatherSource: 'Dữ liệu ngoại tuyến (Fallback Catalogue)',
        avgTempMax: 28.0,
        avgPrecipitation: 0.8,
        latitude: 16.0,
        longitude: 107.0,
        region: 'Việt Nam',
      );
    }

    final others = knownCards.values.where((c) => c.id != winnerId).toList();
    return [winner, ...others.take(2)];
  }

  List<TransportOption> _buildFallbackTransport(PlanTripRequest req, DestinationCard winner) {
    final perPerson = req.numPeople;
    return [
      TransportOption(
        mode: 'bus',
        displayName: 'Xe khách Limousine chất lượng cao',
        priceTotalVnd: 350000 * perPerson,
        durationHours: 6.0,
        comfortScore: 8,
        isParetoOptimal: true,
        tradeoffType: 'Tiết kiệm nhất',
        recommendationReason: 'Tối ưu ngân sách từ ${req.origin} đến ${winner.name}',
      ),
      TransportOption(
        mode: 'flight',
        displayName: 'Chuyến bay khứ hồi ${req.origin} – ${winner.name}',
        priceTotalVnd: 1500000 * perPerson,
        durationHours: 1.5,
        comfortScore: 9,
        isParetoOptimal: true,
        tradeoffType: 'Nhanh nhất',
        recommendationReason: 'Rút ngắn thời gian di chuyển, tối đa thời gian khám phá',
      ),
      TransportOption(
        mode: 'private_car',
        displayName: 'Thuê xe ô tô riêng',
        priceTotalVnd: 2800000,
        durationHours: 6.5,
        comfortScore: 7,
        isParetoOptimal: false,
        tradeoffType: 'Bị lấn át (Dominated)',
        recommendationReason: 'Chi phí cao hơn xe khách và cần người lái',
      ),
    ];
  }

  List<ItineraryDay> _buildFallbackItinerary(String winnerId, String destName, PlanTripRequest req) {
    final totalDays = req.numDays.clamp(1, 30);
    final perPerson = req.numPeople;

    // Destination-specific daily activity templates
    final templates = _getDestinationTemplates(winnerId, destName, perPerson);

    return List.generate(totalDays, (index) {
      final dayNumber = index + 1;
      final templateIndex = index % templates.length;
      final template = templates[templateIndex];

      return ItineraryDay(
        day: dayNumber,
        title: totalDays == 1
            ? 'Khám phá trọn vẹn $destName'
            : (index == 0
                ? 'Ngày $dayNumber: Chạm ngõ $destName & Khởi hành'
                : (index == totalDays - 1
                    ? 'Ngày $dayNumber: Mua sắm đặc sản & Tạm biệt $destName'
                    : 'Ngày $dayNumber: ${template.title}')),
        activities: template.activities,
      );
    });
  }

  List<_DayTemplate> _getDestinationTemplates(String destinationId, String destName, int people) {
    if (destinationId == 'da-lat') {
      return [
        _DayTemplate(
          title: 'Khám phá Trung tâm & Hồ Xuân Hương',
          activities: [
            Activity(time: '08:00 - 10:00', title: 'Dạo quanh Hồ Xuân Hương & Quảng trường Lâm Viên', costVnd: 0, durationHours: 2.0),
            Activity(time: '10:30 - 12:30', title: 'Check-in Ga Đà Lạt & Cà phê view đồi thông', costVnd: 80000 * people, durationHours: 2.0),
            Activity(time: '13:00 - 14:30', title: 'Thưởng thức ẩm thực Lẩu gà lá é Tao Ngộ', costVnd: 150000 * people, durationHours: 1.5),
            Activity(time: '15:00 - 17:30', title: 'Tham quan Vườn hoa thành phố Đà Lạt', costVnd: 100000 * people, durationHours: 2.5),
            Activity(time: '18:30 - 21:00', title: 'Dạo Chợ đêm Đà Lạt & Ăn bánh tráng nướng', costVnd: 100000 * people, durationHours: 2.5),
          ],
        ),
        _DayTemplate(
          title: 'Chinh phục Đỉnh LangBiang & Đồi Robin',
          activities: [
            Activity(time: '08:00 - 11:30', title: 'Cáp treo Đồi Robin & Thiền Viện Trúc Lâm', costVnd: 120000 * people, durationHours: 3.5),
            Activity(time: '12:00 - 13:30', title: 'Ăn trưa cơm lam gà nướng đồi thông', costVnd: 180000 * people, durationHours: 1.5),
            Activity(time: '14:00 - 17:00', title: 'Chinh phục đỉnh núi LangBiang ngắm toàn cảnh hồ Dankia', costVnd: 150000 * people, durationHours: 3.0),
            Activity(time: '18:30 - 20:30', title: 'Giao lưu cồng chiêng Tây Nguyên & Uống rượu cần', costVnd: 150000 * people, durationHours: 2.0),
          ],
        ),
        _DayTemplate(
          title: 'Thác Datanla & Dinh Bảo Đại',
          activities: [
            Activity(time: '08:30 - 11:30', title: 'Trải nghiệm máng trượt xuyên rừng Thác Datanla', costVnd: 200000 * people, durationHours: 3.0),
            Activity(time: '12:00 - 13:30', title: 'Ăn trưa Lẩu bò Ba Toa quán gỗ', costVnd: 160000 * people, durationHours: 1.5),
            Activity(time: '14:00 - 16:30', title: 'Khám phá Dinh III Bảo Đại & Vườn dâu tây', costVnd: 90000 * people, durationHours: 2.5),
            Activity(time: '17:00 - 19:00', title: 'Mua sắm mứt đặc sản Lò Than & Check-out', costVnd: 200000 * people, durationHours: 2.0),
          ],
        ),
      ];
    } else if (destinationId == 'phu-quoc') {
      return [
        _DayTemplate(
          title: 'Biển Bãi Sao & Sunset Sanato',
          activities: [
            Activity(time: '08:30 - 11:30', title: 'Tắm biển Bãi Sao - cát trắng mịn như kem', costVnd: 50000 * people, durationHours: 3.0),
            Activity(time: '12:00 - 13:30', title: 'Ăn trưa gỏi cá trích & hải sản làng chài', costVnd: 250000 * people, durationHours: 1.5),
            Activity(time: '15:30 - 18:00', title: 'Ngắm hoàng hôn Bãi Trường & Sunset Sanato', costVnd: 100000 * people, durationHours: 2.5),
            Activity(time: '18:30 - 21:00', title: 'Khám phá Chợ đêm Phú Quốc & Thưởng thức kem cuộn', costVnd: 150000 * people, durationHours: 2.5),
          ],
        ),
        _DayTemplate(
          title: 'Cáp treo Hòn Thơm & Công viên nước',
          activities: [
            Activity(time: '08:30 - 12:00', title: 'Cáp treo vượt biển Hòn Thơm dài nhất thế giới', costVnd: 600000 * people, durationHours: 3.5),
            Activity(time: '12:00 - 13:30', title: 'Buffet ẩm thực 3 miền tại Hòn Thơm', costVnd: 300000 * people, durationHours: 1.5),
            Activity(time: '14:00 - 17:00', title: 'Vui chơi công viên nước Aquatopia & Tắm biển', costVnd: 0, durationHours: 3.0),
            Activity(time: '18:30 - 20:30', title: 'Dạo biển Địa Trung Hải & Xem Cầu Hôn Kiss Bridge', costVnd: 100000 * people, durationHours: 2.0),
          ],
        ),
        _DayTemplate(
          title: 'Grand World & Làng chài Rạch Vẹm',
          activities: [
            Activity(time: '08:30 - 11:30', title: 'Check-in Làng chài Rạch Vẹm mùa sao biển', costVnd: 80000 * people, durationHours: 3.0),
            Activity(time: '12:00 - 14:00', title: 'Khám phá Grand World Phú Quốc - Thành phố không ngủ', costVnd: 0, durationHours: 2.0),
            Activity(time: '14:30 - 17:00', title: 'Bảo tàng Gấu Teddy & Đi thuyền Gondola sông Venice', costVnd: 200000 * people, durationHours: 2.5),
            Activity(time: '18:00 - 20:00', title: 'Xem show nhạc nước Sắc Màu Venice & Mua ngọc trai', costVnd: 150000 * people, durationHours: 2.0),
          ],
        ),
      ];
    } else if (destinationId == 'ha-noi') {
      return [
        _DayTemplate(
          title: 'Khám phá 36 Phố Phường & Hồ Gươm',
          activities: [
            Activity(time: '08:00 - 10:00', title: 'Dạo bộ quanh Hồ Gươm & Viếng Đền Ngọc Sơn', costVnd: 50000 * people, durationHours: 2.0),
            Activity(time: '10:30 - 12:30', title: 'Khám phá Phố Cổ & Thưởng thức Phở Bát Đàn', costVnd: 100000 * people, durationHours: 2.0),
            Activity(time: '14:00 - 16:30', title: 'Tham quan Văn Miếu Quốc Tử Giám', costVnd: 70000 * people, durationHours: 2.5),
            Activity(time: '18:00 - 21:00', title: 'Ngắm Hồ Tây & Thưởng thức Kem Tràng Tiền', costVnd: 80000 * people, durationHours: 3.0),
          ],
        ),
      ];
    } else {
      // Default / Đà Nẵng / Generic templates
      return [
        _DayTemplate(
          title: 'Danh lam & Biển $destName',
          activities: [
            Activity(time: '08:00 - 10:30', title: 'Khám phá biểu tượng du lịch tại $destName', costVnd: 100000 * people, durationHours: 2.5),
            Activity(time: '11:00 - 13:00', title: 'Thưởng thức ẩm thực đặc sản địa phương $destName', costVnd: 150000 * people, durationHours: 2.0),
            Activity(time: '14:30 - 17:30', title: 'Tự do tham quan và trải nghiệm thiên nhiên $destName', costVnd: 50000 * people, durationHours: 3.0),
            Activity(time: '18:30 - 21:00', title: 'Ăn tối hải sản & Dạo phố ngắm cảnh đêm', costVnd: 200000 * people, durationHours: 2.5),
          ],
        ),
        _DayTemplate(
          title: 'Khu vui chơi & Trải nghiệm văn hóa $destName',
          activities: [
            Activity(time: '08:30 - 12:00', title: 'Tuyến cáp treo & Điểm tham quan nổi bật tại $destName', costVnd: 450000 * people, durationHours: 3.5),
            Activity(time: '12:00 - 13:30', title: 'Buffet trưa ẩm thực vùng miền', costVnd: 250000 * people, durationHours: 1.5),
            Activity(time: '14:00 - 17:00', title: 'Khám phá các công trình di sản và văn hóa độc đáo', costVnd: 100000 * people, durationHours: 3.0),
            Activity(time: '18:30 - 20:30', title: 'Thưởng thức cà phê ngắm cảnh & Mua quà lưu niệm', costVnd: 120000 * people, durationHours: 2.0),
          ],
        ),
        _DayTemplate(
          title: 'Di tích lịch sử & Chợ truyền thống $destName',
          activities: [
            Activity(time: '08:30 - 11:00', title: 'Viếng chùa tâm linh và ngắm toàn cảnh vịnh/núi $destName', costVnd: 50000 * people, durationHours: 2.5),
            Activity(time: '11:30 - 13:00', title: 'Mua sắm đặc sản làm quà tại chợ truyền thống', costVnd: 200000 * people, durationHours: 1.5),
            Activity(time: '14:00 - 16:30', title: 'Thư giãn nghỉ ngơi & Chuẩn bị chuyến trở về', costVnd: 50000 * people, durationHours: 2.5),
          ],
        ),
      ];
    }
  }

  BudgetBreakdown _calculateAdaptiveBudget(PlanTripRequest req) {
    final total = req.budgetVnd;
    final type = req.companionType;

    double transportRatio;
    double accommodationRatio;
    double foodRatio;
    double attractionsRatio;

    switch (type) {
      case 'family':
        transportRatio = 0.25;
        accommodationRatio = 0.35;
        foodRatio = 0.20;
        attractionsRatio = 0.10;
        break;
      case 'couple':
        transportRatio = 0.25;
        accommodationRatio = 0.35;
        foodRatio = 0.22;
        attractionsRatio = 0.11;
        break;
      case 'solo':
        transportRatio = 0.30;
        accommodationRatio = 0.25;
        foodRatio = 0.25;
        attractionsRatio = 0.15;
        break;
      case 'group':
      default:
        transportRatio = 0.35;
        accommodationRatio = 0.30;
        foodRatio = 0.18;
        attractionsRatio = 0.12;
        break;
    }

    final transport = (total * transportRatio).toInt();
    final accommodation = (total * accommodationRatio).toInt();
    final food = (total * foodRatio).toInt();
    final attractions = (total * attractionsRatio).toInt();
    final remainingSafetyMargin = total - (transport + accommodation + food + attractions);

    return BudgetBreakdown(
      transport: transport,
      accommodation: accommodation,
      food: food,
      attractions: attractions,
      remainingSafetyMargin: remainingSafetyMargin,
    );
  }
}

class _DayTemplate {
  final String title;
  final List<Activity> activities;
  const _DayTemplate({required this.title, required this.activities});
}

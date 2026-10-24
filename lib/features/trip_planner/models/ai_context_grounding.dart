import 'package:flutter/foundation.dart';
import '../../explore/models/place_visit_details.dart';

/// Trạng thái khả dụng được đóng băng cho RAG v1: open | closed | unknown
enum AvailabilityState { open, closed, unknown }

/// Căn cứ tính giá vé chuẩn: perPerson | tripTotal | packages
enum PricingBasis { perPerson, tripTotal, packages }

/// Dữ liệu thực tế của một địa điểm sau khi được đối chiếu với cơ sở dữ liệu
@immutable
class GroundedPlaceFacts {
  final String placeId;
  final AvailabilityState availability;
  final List<Map<String, Object?>> openingWindows;
  final String priceStatus;
  final int? amountVnd;
  final PricingBasis pricingBasis;
  final String? packageId;
  final List<String> conditions;
  final bool isReviewed;
  final bool isOutOfDomain;
  final String? note;

  const GroundedPlaceFacts({
    required this.placeId,
    required this.availability,
    required this.openingWindows,
    required this.priceStatus,
    this.amountVnd,
    required this.pricingBasis,
    this.packageId,
    this.conditions = const [],
    required this.isReviewed,
    this.isOutOfDomain = false,
    this.note,
  });

  Map<String, Object?> toJson() => {
    'placeId': placeId,
    'availability': availability.name,
    'priceStatus': priceStatus,
    if (amountVnd != null) 'amountVnd': amountVnd,
    'pricingBasis': pricingBasis.name,
    if (packageId != null) 'packageId': packageId,
    if (conditions.isNotEmpty) 'conditions': conditions,
    'isReviewed': isReviewed,
    'isOutOfDomain': isOutOfDomain,
    if (note != null) 'note': note,
  };
}

/// Kết quả phân giải tổng thể các facts thực tế cho ngữ cảnh Trợ lý AI
@immutable
class GroundingResolution {
  final Map<String, GroundedPlaceFacts> facts;
  final List<Map<String, Object?>> openingWindows;
  final List<String> appliedPackages;
  final int totalEstimatedCostVnd;
  final List<String> warnings;

  const GroundingResolution({
    required this.facts,
    required this.openingWindows,
    required this.appliedPackages,
    required this.totalEstimatedCostVnd,
    required this.warnings,
  });
}

/// Đối chiếu và thẩm định dữ liệu mở cửa/giá vé cho một địa điểm cụ thể
GroundedPlaceFacts evaluatePlaceGrounding({
  required String placeId,
  PlaceVisitDetails? details,
  DateTime? date,
  int? startMinute,
  int? endMinute,
}) {
  if (details == null) {
    return GroundedPlaceFacts(
      placeId: placeId,
      availability: AvailabilityState.unknown,
      openingWindows: const [],
      priceStatus: 'unverified',
      amountVnd: null,
      pricingBasis: PricingBasis.perPerson,
      packageId: null,
      conditions: const ['Chưa có trong danh mục xác minh TravelGO'],
      isReviewed: false,
      isOutOfDomain: true,
      note: 'Địa điểm không nằm trong danh mục xác minh của TravelGO.',
    );
  }

  // 1. Đánh giá giờ tham quan (Hours & Rules)
  final hours = details.hours;
  var availability = AvailabilityState.unknown;
  final windows = <Map<String, Object?>>[];
  String? hoursNote;

  if (!hours.evidence.isReviewed || hours.status == 'unverified') {
    availability = AvailabilityState.unknown;
    hoursNote = 'Chưa xác minh giờ tham quan chính thức.';
  } else if (hours.status == 'temporarily_closed') {
    // R1: Temporary closure -> closed rõ ràng, không có windows
    availability = AvailabilityState.closed;
    hoursNote = 'Địa điểm đang tạm đóng cửa theo nguồn chính thức.';
  } else if (hours.status == 'scheduled' || hours.status == 'seasonal') {
    // R5: Nếu thiếu ngày đi (date == null) với lịch theo mùa hoặc theo thứ,
    // phải trả về unknown; tuyệt đối không ghép union 2 mùa thành window đã xác minh!
    if (date == null) {
      availability = AvailabilityState.unknown;
      hoursNote = 'Chưa có ngày đi cụ thể để xác định lịch mở cửa theo mùa/thứ.';
    } else {
      final matchingRules = hours.rules.where((r) => r.appliesOn(date)).toList();

      if (matchingRules.isEmpty) {
        // R1: Ngày được chọn không có rule mở cửa -> closed rõ ràng
        availability = AvailabilityState.closed;
        hoursNote = 'Không có lịch mở cửa vào ngày đã chọn.';
      } else {
        availability = AvailabilityState.open;
        final sourceRef = hours.evidence.sourceIds.isNotEmpty
            ? hours.evidence.sourceIds.first
            : 'catalogue_v1';

        for (final rule in matchingRules) {
          // R2: Xử lý lịch qua đêm (endDayOffset == 1):
          // Ngày bắt đầu mở từ rule.startMinutes đến hết ngày (1440).
          // Đảm bảo effectiveEnd luôn > rule.startMinutes, không bao giờ tạo window lỗi end <= start!
          final effectiveEnd = rule.endDayOffset == 1
              ? 1440
              : rule.endMinutes;

          if (effectiveEnd > rule.startMinutes) {
            // R3: openingWindows biểu diễn toàn bộ khung giờ mở cửa (đến giờ đóng cửa rule.endMinutes hoặc 1440),
            // KHÔNG cắt ngắn ở admissionCutoffMinutes.
            windows.add({
              'placeId': placeId,
              'startMinute': rule.startMinutes,
              'endMinute': effectiveEnd,
              'sourceRef': sourceRef,
            });
          }
        }

        // R2 bổ sung: Nếu hôm trước có rule qua đêm áp dụng vào rạng sáng hôm nay
        final yesterday = date.subtract(const Duration(days: 1));
        final yesterdayOvernights = hours.rules
            .where((r) => r.endDayOffset == 1 && r.appliesOn(yesterday))
            .toList();
        for (final yRule in yesterdayOvernights) {
          if (yRule.endMinutes > 0) {
            windows.add({
              'placeId': placeId,
              'startMinute': 0,
              'endMinute': yRule.endMinutes,
              'sourceRef': sourceRef,
            });
          }
        }

        // R3: Kiểm tra riêng rẽ hạn nhận khách (admission cutoff) và giờ đóng cửa (closing)
        if (startMinute != null && endMinute != null && matchingRules.isNotEmpty) {
          final fits = matchingRules.any((r) {
            // Giờ bắt đầu phải trước hạn chót nhận khách (nếu có)
            final cutoff = r.admissionCutoffMinutes != null &&
                    r.admissionCutoffMinutes! >= r.startMinutes
                ? r.admissionCutoffMinutes!
                : (r.endDayOffset == 1 ? 1440 : r.endMinutes);
            final maxClosing = r.endDayOffset == 1 ? 1440 : r.endMinutes;

            final validStart = startMinute >= r.startMinutes && startMinute <= cutoff;
            final validEnd = endMinute <= maxClosing && endMinute > startMinute;
            return validStart && validEnd;
          });

          if (!fits) {
            availability = AvailabilityState.closed;
            hoursNote =
                'Thời gian tham quan nằm ngoài khung giờ mở cửa hoặc vào sau giờ ngừng nhận khách.';
          }
        }
      }
    }
  } else {
    // 'no_fixed_hours' hoặc 'event_based'
    availability = AvailabilityState.unknown;
    hoursNote = 'Không có khung giờ cố định hoặc theo sự kiện.';
  }

  // 2. Đánh giá giá vé (Price & Options)
  final price = details.price;
  final priceStatus = price.status;
  final isReviewed = price.evidence.isReviewed;
  int? standardAmount;
  var pricingBasis = PricingBasis.perPerson;
  String? packageId;
  final conditions = <String>[...price.evidence.conditions];

  if (priceStatus == 'free') {
    standardAmount = 0;
  } else if (priceStatus == 'priced' || priceStatus == 'bundled') {
    final standardOption = price.options.isNotEmpty ? price.options.first : null;
    if (standardOption != null) {
      standardAmount = standardOption.amountVnd;
      packageId = standardOption.packageId;
      if (standardOption.packageId != null) {
        pricingBasis = PricingBasis.packages;
      } else if (standardOption.unit.contains('xe') ||
          standardOption.unit.contains('nhóm')) {
        pricingBasis = PricingBasis.tripTotal;
      } else {
        pricingBasis = PricingBasis.perPerson;
      }
      conditions.addAll(standardOption.conditions);
    }
  }

  return GroundedPlaceFacts(
    placeId: placeId,
    availability: availability,
    openingWindows: windows,
    priceStatus: priceStatus,
    amountVnd: standardAmount,
    pricingBasis: pricingBasis,
    packageId: packageId,
    conditions: conditions,
    isReviewed: isReviewed,
    isOutOfDomain: false,
    note: hoursNote,
  );
}

/// Phân giải tổng thể Facts địa điểm cho ngữ cảnh trợ lý
GroundingResolution resolveGrounding({
  required List<String> placeIds,
  required Map<String, PlaceVisitDetails> visitDetails,
  Map<String, VisitPackage> packages = const {},
  DateTime? date,
}) {
  final factsMap = <String, GroundedPlaceFacts>{};
  final allWindows = <Map<String, Object?>>[];
  final warnings = <String>[];

  for (final id in placeIds) {
    final details = visitDetails[id];
    final fact = evaluatePlaceGrounding(
      placeId: id,
      details: details,
      date: date,
    );
    factsMap[id] = fact;
    allWindows.addAll(fact.openingWindows);

    // R1 & R6: Surface warnings rõ ràng
    if (fact.availability == AvailabilityState.closed) {
      warnings.add(
        'Địa điểm $id đang đóng cửa${date != null ? " vào ngày đã chọn" : ""}.',
      );
    } else if (!fact.isReviewed || fact.availability == AvailabilityState.unknown) {
      warnings.add(
        'Địa điểm $id chưa xác minh đầy đủ thông tin vé/giờ tham quan.',
      );
    }
  }

  // R7: Package budget resolution & auto combo discount
  // Trong seed hiện tại, pkg.included sử dụng nhãn văn bản tiếng Việt thay vì stable placeId.
  // Đồng thời, việc tính toán ngân sách tối ưu thuộc thẩm quyền của Backend/Decision Engine
  // theo Luật 2. Do đó, logic tự động trừ tiền combo ở client được đánh dấu NOT_IMPLEMENTED
  // để bảo toàn Luật 2 và tránh sai lệch ngân sách.
  const appliedPackages = <String>[];

  return GroundingResolution(
    facts: Map.unmodifiable(factsMap),
    openingWindows: List.unmodifiable(allWindows),
    appliedPackages: appliedPackages,
    totalEstimatedCostVnd: 0, // Tuân thủ Luật 2: Client không tự ý cộng trừ ngân sách
    warnings: warnings,
  );
}

/// R4: Nhận diện yêu cầu có yếu tố lịch trình / du lịch
bool isTravelOrItineraryIntent(String clean) {
  const travelIndicators = [
    // Hành động lập lịch / chuyến đi
    'thêm', 'bớt', 'xóa', 'dời', 'đổi', 'chuyển', 'xếp lịch', 'lên lịch',
    'lịch trình', 'kế hoạch', 'chuyến đi', 'ngày 1', 'ngày 2', 'ngày 3',
    'buổi sáng', 'buổi chiều', 'buổi tối', 'tham quan', 'du lịch',
    'khách sạn', 'ăn uống', 'quán', 'nhà hàng', 'địa điểm', 'điểm đến',
    'tối ưu', 'chi phí', 'ngân sách', 'giá vé', 'vé vào', 'gợi ý',
    'chuẩn bị', 'đến', 'ghé', 'xem', 'chơi gì', 'ăn gì', 'ở đâu',
    'bản nháp', 'hoạt động', 'thời gian', 'mở cửa', 'đóng cửa',

    // Địa danh / công trình / loại hình điểm đến
    'bảo tàng', 'chùa', 'nhà thờ', 'di tích', 'lăng', 'đại nội', 'kinh thành',
    'chợ', 'bãi biển', 'công viên', 'sân vận động', 'phố cổ', 'đảo', 'núi',
    'đèo', 'thác', 'hồ', 'vịnh', 'rừng', 'cố đô', 'phố đi bộ',
  ];

  return travelIndicators.any(clean.contains);
}

/// R4: Bộ lọc nhận diện câu hỏi ngoài phạm vi nghiệp vụ du lịch (Hướng B kết hợp C)
bool isOutOfDomainQuery(String prompt) {
  final clean = prompt.toLowerCase().trim();
  if (clean.isEmpty) return false;

  // Nếu câu hỏi có chứa ý định lập lịch hoặc tên/loại hình địa điểm du lịch -> KHÔNG chặn!
  if (isTravelOrItineraryIntent(clean)) {
    return false;
  }

  // Danh sách các chủ đề thuần túy ngoài miền (chỉ kích hoạt khi KHÔNG có ý định du lịch)
  const nonTravelPatterns = [
    // 1. Thể thao / giải đấu thuần túy
    'world cup',
    'fifa',
    'bóng đá',
    'premier league',
    'champions league',
    'euro 20',
    'messi',
    'ronaldo',
    'olympic',
    // 2. Lập trình / công nghệ
    'lập trình',
    'viết code',
    'python',
    'javascript',
    'typescript',
    'flutter',
    'react',
    'c++',
    'sql injection',
    // 3. Tài chính / chứng khoán / tiền số
    'chứng khoán',
    'bitcoin',
    'crypto',
    'cổ phiếu',
    'forex',
    'tiền ảo',
    'đào coin',
    // 4. Toán học / khoa học tự nhiên
    'giải toán',
    'đạo hàm',
    'tích phân',
    'phương trình',
    'hóa học',
    'vật lý',
    // 5. Chính trị / thời sự quốc tế
    'tổng thống',
    'bầu cử',
    'chiến tranh',
    'chính trị',
  ];

  return nonTravelPatterns.any(clean.contains);
}

/// Tạo phản hồi Smart Pivot điều hướng người dùng quay lại kế hoạch chuyến đi (Hướng B kết hợp C)
String formatSmartPivotSummary({
  required String prompt,
  String? destinationName,
  required int selectedDay,
}) {
  final dest = destinationName != null && destinationName.isNotEmpty
      ? destinationName
      : 'điểm đến của bạn';

  return 'TravelGO là trợ lý chuyên biệt về lịch trình và điểm đến tại $dest. '
      'Về câu hỏi của bạn ("$prompt"): thông tin này nằm ngoài cơ sở dữ liệu du lịch chính thức của TravelGO. '
      'Hãy để tôi giúp bạn tiếp tục tối ưu lịch trình và ngân sách cho Ngày $selectedDay tại $dest nhé!';
}

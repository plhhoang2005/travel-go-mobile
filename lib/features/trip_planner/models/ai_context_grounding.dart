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
    availability = AvailabilityState.closed;
    hoursNote = 'Địa điểm đang tạm đóng cửa theo nguồn chính thức.';
  } else if (hours.status == 'scheduled' || hours.status == 'seasonal') {
    final matchingRules = date == null
        ? hours.rules
        : hours.rules.where((r) => r.appliesOn(date)).toList();

    if (matchingRules.isEmpty) {
      availability = AvailabilityState.closed;
      hoursNote = 'Không có lịch mở cửa vào ngày đã chọn.';
    } else {
      availability = AvailabilityState.open;
      final sourceRef = hours.evidence.sourceIds.isNotEmpty
          ? hours.evidence.sourceIds.first
          : 'catalogue_v1';

      for (final rule in matchingRules) {
        // Hạn chót nhận khách nếu có, hoặc giờ đóng cửa
        final effectiveEnd = rule.admissionCutoffMinutes != null &&
                rule.admissionCutoffMinutes! > rule.startMinutes
            ? rule.admissionCutoffMinutes!
            : rule.endMinutes;

        windows.add({
          'placeId': placeId,
          'startMinute': rule.startMinutes,
          'endMinute': effectiveEnd,
          'sourceRef': sourceRef,
        });
      }

      // Nếu có giờ cụ thể, kiểm tra xem có nằm trọn trong khung giờ mở cửa không
      if (startMinute != null && endMinute != null && windows.isNotEmpty) {
        final fits = windows.any(
          (w) =>
              startMinute >= (w['startMinute'] as int) &&
              endMinute <= (w['endMinute'] as int),
        );
        if (!fits) {
          availability = AvailabilityState.closed;
          hoursNote = 'Thời gian tham quan nằm ngoài khung giờ mở cửa.';
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

/// Giải quyết gói combo (Package Resolution) và tổng hợp toàn bộ Facts
GroundingResolution resolveGrounding({
  required List<String> placeIds,
  required Map<String, PlaceVisitDetails> visitDetails,
  Map<String, VisitPackage> packages = const {},
  DateTime? date,
}) {
  final factsMap = <String, GroundedPlaceFacts>{};
  final allWindows = <Map<String, Object?>>[];
  final appliedPackages = <String>{};
  final warnings = <String>[];
  var totalEstimatedCost = 0;

  for (final id in placeIds) {
    final details = visitDetails[id];
    final fact = evaluatePlaceGrounding(
      placeId: id,
      details: details,
      date: date,
    );
    factsMap[id] = fact;
    allWindows.addAll(fact.openingWindows);

    if (!fact.isReviewed || fact.availability == AvailabilityState.unknown) {
      warnings.add(
        'Địa điểm $id chưa xác minh đầy đủ thông tin vé/giờ tham quan.',
      );
    }
  }

  // Thuật toán kiểm tra Combo Packages (Tránh cộng dồn vé lẻ sai lệch)
  final uniquePlaces = placeIds.toSet();
  for (final pkg in packages.values) {
    // Nếu chuyến đi ghé thăm từ 2 điểm trở lên thuộc cùng gói package
    final coveredInTrip = pkg.included.where(uniquePlaces.contains).toList();
    if (coveredInTrip.length >= 2) {
      appliedPackages.add(pkg.id);
      warnings.add(
        'Đã phát hiện gói vé combo ${pkg.label} cho các điểm: ${coveredInTrip.join(", ")}.',
      );
    }
  }

  // Tính toán sơ bộ chi phí
  for (final fact in factsMap.values) {
    if (fact.amountVnd != null && fact.amountVnd! > 0) {
      totalEstimatedCost += fact.amountVnd!;
    }
  }

  return GroundingResolution(
    facts: Map.unmodifiable(factsMap),
    openingWindows: List.unmodifiable(allWindows),
    appliedPackages: appliedPackages.toList(),
    totalEstimatedCostVnd: totalEstimatedCost,
    warnings: warnings,
  );
}

/// Bộ lọc nhận diện câu hỏi ngoài phạm vi nghiệp vụ du lịch (Hướng B kết hợp C)
bool isOutOfDomainQuery(String prompt) {
  final clean = prompt.toLowerCase().trim();
  if (clean.isEmpty) return false;

  const patterns = [
    // 1. Thể thao / giải đấu quốc tế
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
    // 5. Chính trị / chiến sự / thời sự ngoài du lịch
    'tổng thống',
    'bầu cử',
    'chiến tranh',
    'chính trị',
  ];

  return patterns.any(clean.contains);
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

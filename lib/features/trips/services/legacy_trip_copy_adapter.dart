import '../../trip_planner/models/editable_trip_document.dart';
import '../../trip_planner/models/trip_request.dart';
import '../../trip_planner/services/editable_trip_validator.dart';
import '../../trip_planner/services/manual_trip_factory.dart';
import '../models/editable_trip_codec.dart';
import '../models/trip_payload_codec.dart';

class LegacyCopyPreview {
  final EditableTripDocumentV2? document;
  final List<EditableValidationIssue> issues;
  final bool needsDestination, needsInput;
  LegacyCopyPreview({
    required this.document,
    required List<EditableValidationIssue> issues,
    required this.needsDestination,
    this.needsInput = false,
  }) : issues = List.unmodifiable(issues);
  bool get canProceed =>
      document != null &&
      !needsDestination &&
      !needsInput &&
      !issues.any((i) => i.isBlocking);
}

/// A copy, never an in-place conversion of immutable import receipts or V1 rows.
class LegacyTripCopyAdapter {
  final ManualTripFactory _factory;
  LegacyTripCopyAdapter({String Function()? newId})
    : _factory = ManualTripFactory(newId: newId);
  LegacyCopyPreview preview(
    CanonicalTripPayloadV1 source, {
    String? sourceTripId,
    required String sourceDigest,
    PlanTripRequest? inputOverride,
    TripMetadataV1? metadataOverride,
  }) {
    final issues = <EditableValidationIssue>[];
    void issue(String code, String message, {bool warning = false}) {
      issues.add(
        EditableValidationIssue(
          code: code,
          path: 'source',
          message: message,
          severity: warning
              ? EditableIssueSeverity.warning
              : EditableIssueSeverity.error,
        ),
      );
    }

    final request = inputOverride ?? source.request;
    if (request == null) {
      issue(
        'legacy_input_required',
        'Chuyến cũ chưa có đủ đầu vào. Hãy nhập đầu vào trước khi tạo bản sao.',
      );
      return LegacyCopyPreview(
        document: null,
        issues: issues,
        needsDestination: true,
        needsInput: true,
      );
    }
    final metadata = metadataOverride ?? source.metadata;
    final winner = source.plan?.winnerId;
    final conflict =
        metadataOverride == null &&
        metadata.destinationId != null &&
        winner != null &&
        winner.isNotEmpty &&
        metadata.destinationId != winner;
    final destination = conflict ? null : (metadata.destinationId ?? winner);
    String? name = metadata.destinationName;
    if (name == null && winner != null) {
      for (final card in source.plan?.topDestinations ?? []) {
        if (card.id == winner) {
          name = card.name;
          break;
        }
      }
    }
    final selected = EditableTripCodec.destinations.contains(destination);
    final needsDestination = !selected || name == null || conflict;
    if (needsDestination) {
      issue(
        'legacy_destination_required',
        'Chọn rõ điểm đến cho bản sao; app không tự đoán tên hoặc đổi nơi.',
        warning: true,
      );
    }
    if (metadata.timezone != null && metadata.timezone != 'Asia/Ho_Chi_Minh') {
      issue(
        'legacy_timezone',
        'Bản sao dùng giờ Việt Nam. Kiểm tra lại ngày và giờ của bản gốc.',
        warning: true,
      );
    }
    try {
      final seed = _factory.fromInput(
        request,
        TripMetadataV1(
          title: metadata.title,
          destinationId: selected ? destination : null,
          destinationName: selected ? name : null,
          startDate: metadata.startDate,
          endDate: metadata.endDate,
          timezone: 'Asia/Ho_Chi_Minh',
        ),
      );
      final days = seed.days.toList();
      final items = <TripItem>[];
      final estimates = <EstimatedExpense>[];
      final seenDays = <int>{};
      for (final oldDay in source.plan?.itineraryDays ?? []) {
        if (oldDay.day < 1 ||
            oldDay.day > days.length ||
            !seenDays.add(oldDay.day)) {
          issue(
            'legacy_day_out_of_range',
            'Ngày trong lịch gốc không khớp đầu vào. Cần điều chỉnh đầu vào trước khi copy; không bỏ hoạt động ngầm.',
          );
          return LegacyCopyPreview(
            document: null,
            issues: issues,
            needsDestination: needsDestination,
          );
        }
        final index = oldDay.day - 1;
        final day = days[index];
        days[index] = TripDay.fromJson({
          ...day.toJson(),
          'notes': oldDay.title,
        });
        for (
          var position = 0;
          position < oldDay.activities.length;
          position++
        ) {
          final activity = oldDay.activities[position];
          final match = RegExp(r'^([01][0-9]|2[0-3]):([0-5][0-9])$')
              .firstMatch(activity.time.trim());
          final minute = match == null
              ? null
              : int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
          final id = _factory.newId();
          final notes = [
            if (match == null && activity.time.isNotEmpty)
              'Giờ gốc: ${activity.time}',
            'Thời lượng gốc: ${activity.durationHours} giờ (tham khảo, chưa xác minh).',
          ].join('\n');
          items.add(
            TripItem(
              id: id,
              dayId: day.id,
              position: position,
              title: activity.title,
              placeId: null,
              startMinute: minute,
              endMinute: null,
              notes: notes,
              provenance: FieldProvenance(
                quality: 'estimated',
                sourceRefs: [],
                observedAt: null,
              ),
            ),
          );
          // The old DTO cannot distinguish a default 0 from a verified free price.
          final amount = activity.costVnd == 0 ? null : activity.costVnd;
          estimates.add(
            EstimatedExpense(
              id: _factory.newId(),
              itemId: id,
              category: 'other',
              unitAmountVnd: amount,
              basis: 'trip_total',
              customQuantity: null,
              active: true,
              description: amount == null
                  ? 'Giá gốc 0đ chưa xác minh; cần nhập lại.'
                  : 'Ước tính gốc, tạm tính toàn chuyến; cần rà soát đơn vị.',
              provenance: FieldProvenance(
                quality: amount == null ? 'unknown' : 'estimated',
                sourceRefs: [],
                observedAt: null,
              ),
            ),
          );
        }
      }
      final document = seed.copyWith(
        days: days,
        items: items,
        estimates: estimates,
        source: SourceReference(
          kind: 'manual_v1_copy',
          sourceId: sourceTripId,
          sourceDigest: sourceDigest,
        ),
      );
      EditableTripCodec.encode(document);
      issue(
        'legacy_review',
        'Bản sao chứa ước tính từ dữ liệu cũ. Kiểm tra giá, đơn vị và giờ; không sao chép tổng phân bổ để tránh tính trùng.',
        warning: true,
      );
      issues.addAll(EditableTripValidator.validate(document));
      return LegacyCopyPreview(
        document: document,
        issues: issues,
        needsDestination: needsDestination,
      );
    } on Object {
      issue(
        'legacy_copy_unavailable',
        'Dữ liệu cũ không thể chuyển nguyên vẹn sang bản chỉnh sửa. Bản gốc được giữ; hãy tạo lịch mới hoặc điều chỉnh đầu vào.',
      );
      return LegacyCopyPreview(
        document: null,
        issues: issues,
        needsDestination: needsDestination,
      );
    }
  }
}

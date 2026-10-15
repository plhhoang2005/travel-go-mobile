import '../../trips/models/editable_trip_codec.dart';
import '../models/editable_trip_document.dart';
import 'budget_calculator.dart';

enum ValidationMode { draft, accountSave }

enum EditableIssueSeverity { warning, error }

class EditableValidationIssue {
  final String code, path, message;
  final EditableIssueSeverity severity;
  final List<String> itemIds;
  final String? fingerprint;
  final bool acknowledged;
  EditableValidationIssue({
    required this.code,
    required this.path,
    required this.message,
    required this.severity,
    List<String> itemIds = const [],
    this.fingerprint,
    this.acknowledged = false,
  }) : itemIds = List.unmodifiable(itemIds);
  bool get isBlocking =>
      severity == EditableIssueSeverity.error && !acknowledged;
}

class EditableTripValidator {
  static DateTime _day(String date) => DateTime.parse('${date}T00:00:00Z');
  static String issueFingerprint(
    String code,
    List<TripItem> items,
    Map<String, TripDay> days,
  ) {
    final ordered = items.toList()..sort((a, b) => a.id.compareTo(b.id));
    return EditableTripCodec.digestText(
      EditableTripCodec.canonicalJson({
        'code': code,
        'itemIds': ordered.map((i) => i.id).toList(),
        'scopedFields': ordered
            .map(
              (i) => {
                'id': i.id,
                'dayId': i.dayId,
                'date': days[i.dayId]?.date,
                'position': i.position,
                'startMinute': i.startMinute,
                'endMinute': i.endMinute,
              },
            )
            .toList(),
      }),
    );
  }

  static List<EditableValidationIssue> validate(
    EditableTripDocumentV2 document, {
    ValidationMode mode = ValidationMode.draft,
  }) {
    final issues = <EditableValidationIssue>[];
    void issue(
      String code,
      String path,
      String message, {
      bool warning = false,
    }) {
      issues.add(
        EditableValidationIssue(
          code: code,
          path: path,
          message: message,
          severity: warning
              ? EditableIssueSeverity.warning
              : EditableIssueSeverity.error,
        ),
      );
    }

    try {
      EditableTripCodec.validateDocument(document);
    } on EditableCodecException catch (error) {
      issue(
        error.code,
        error.path,
        'Dữ liệu lịch trình không hợp lệ. Vui lòng kiểm tra lại.',
      );
      return List.unmodifiable(issues);
    }
    final input = document.input;
    final complete = input.startDate != null && input.endDate != null;
    if (mode == ValidationMode.accountSave) {
      if (input.title.trim().isEmpty) {
        issue('required', 'input.title', 'Nhập tên chuyến đi.');
      }
      if (input.origin.trim().isEmpty) {
        issue('required', 'input.origin', 'Nhập nơi xuất phát.');
      }
      if (input.destinationId == null || input.destinationName == null) {
        issue('required', 'input.destinationId', 'Chọn điểm đến.');
      }
      if (!complete) {
        issue(
          'required',
          'input.startDate',
          'Chọn ngày bắt đầu và kết thúc để lưu tài khoản.',
        );
      }
    }
    if (complete) {
      final start = _day(input.startDate!);
      final end = _day(input.endDate!);
      if (end.isBefore(start)) {
        issue(
          'date_range',
          'input.endDate',
          'Ngày kết thúc phải từ ngày bắt đầu trở đi.',
        );
      } else if (end.difference(start).inDays + 1 != document.days.length) {
        issue(
          'day_count',
          'input.endDate',
          'Số ngày trong lịch không khớp khoảng ngày đã chọn.',
        );
      }
      for (var i = 0; i < document.days.length; i++) {
        final expected = start
            .add(Duration(days: i))
            .toIso8601String()
            .substring(0, 10);
        if (document.days[i].date != expected) {
          issue(
            'day_date',
            'days.${document.days[i].id}.date',
            'Ngày trong lịch chưa khớp khoảng ngày chuyến đi.',
          );
        }
      }
    } else {
      issue(
        'missing_dates',
        'input.startDate',
        'Bản nháp chưa có đủ ngày đi.',
        warning: true,
      );
    }
    final days = {for (final day in document.days) day.id: day};
    void scheduledIssue(String code, List<TripItem> items, String message) {
      final fingerprint = issueFingerprint(code, items, days);
      final ids = items.map((i) => i.id).toList()..sort();
      final acknowledged = document.exceptions.any(
        (e) =>
            e.issueCode == code &&
            e.fingerprint == fingerprint &&
            e.reason.trim().isNotEmpty &&
            e.itemIds.length == ids.length &&
            e.itemIds.toSet().containsAll(ids),
      );
      issues.add(
        EditableValidationIssue(
          code: code,
          path: 'items.${items.first.id}',
          message: message,
          severity: EditableIssueSeverity.error,
          itemIds: ids,
          fingerprint: fingerprint,
          acknowledged: acknowledged,
        ),
      );
    }

    for (final day in document.days) {
      final items = document.items.where((i) => i.dayId == day.id).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      for (var i = 0; i < items.length; i++) {
        final a = items[i];
        if (a.startMinute == null || a.endMinute == null) {
          issue(
            'unknown_time',
            'items.${a.id}',
            'Hoạt động chưa có đủ giờ; chưa đánh giá được thời gian.',
            warning: true,
          );
        } else if (a.endMinute! <= a.startMinute!) {
          issue(
            'time_range',
            'items.${a.id}.endMinute',
            'Giờ kết thúc phải sau giờ bắt đầu trong cùng ngày.',
          );
        }
        if (i > 0 &&
            a.startMinute != null &&
            items[i - 1].startMinute != null &&
            a.startMinute! < items[i - 1].startMinute!) {
          scheduledIssue('time_order', [
            items[i - 1],
            a,
          ], 'Thứ tự hoạt động chưa theo giờ bắt đầu.');
        }
        for (var j = i + 1; j < items.length; j++) {
          final b = items[j];
          if (a.startMinute != null &&
              a.endMinute != null &&
              b.startMinute != null &&
              b.endMinute != null &&
              a.endMinute! > a.startMinute! &&
              b.endMinute! > b.startMinute! &&
              a.startMinute! < b.endMinute! &&
              b.startMinute! < a.endMinute!) {
            scheduledIssue(
              'overlap',
              [a, b],
              'Hai hoạt động bị trùng giờ; sửa lịch hoặc ghi lý do chấp nhận.',
            );
          }
        }
      }
    }
    try {
      final totals = BudgetCalculator.calculate(document);
      if (totals.unknownEstimateCount > 0) {
        issue(
          'unknown_estimates',
          'estimates',
          'Có ${totals.unknownEstimateCount} khoản chưa biết giá.',
          warning: true,
        );
      }
      if (totals.estimateRemaining < 0) {
        issue(
          'estimated_overbudget',
          'estimates',
          'Chi phí dự kiến vượt ngân sách.',
          warning: true,
        );
      }
      if (totals.actualRemaining < 0) {
        issue(
          'actual_overbudget',
          'actualExpenses',
          'Chi phí đã chi vượt ngân sách.',
          warning: true,
        );
      }
    } on BudgetCalculationException catch (error) {
      issue(error.code, 'estimates', 'Tổng chi phí vượt giới hạn hỗ trợ.');
    }
    if (document.items.isNotEmpty) {
      issue(
        'unverified_feasibility',
        'items',
        'Chưa xác minh giờ mở cửa, thời gian di chuyển và tính khả thi của lịch.',
        warning: true,
      );
    }
    return List.unmodifiable(issues);
  }
}

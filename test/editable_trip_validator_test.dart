import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/services/editable_trip_validator.dart';

EditableTripDocumentV2 fixture() {
  final rows = jsonDecode(
    File('test/fixtures/editable_trip_v2_vectors.json').readAsStringSync(),
  ) as List;
  return EditableTripCodec.decode(rows.first['rawText'] as String);
}

TripItem item(String id, int position, int start, int end) => TripItem(
  id: id,
  dayId: '00000000-0000-4000-8000-000000000001',
  position: position,
  title: 'Tham quan',
  placeId: null,
  startMinute: start,
  endMinute: end,
  notes: '',
  provenance: FieldProvenance(
    quality: 'user_provided',
    sourceRefs: [],
    observedAt: null,
  ),
);
bool blocked(List<EditableValidationIssue> issues) =>
    issues.any((i) => i.isBlocking);
void main() {
  test('item limit accepts 1000 and rejects 1001 without truncation', () {
    final base = fixture();
    final items = List.generate(
      1000,
      (i) => TripItem.fromJson({
        ...item(
          '00000000-0000-4000-8000-${(10000 + i).toString().padLeft(12, '0')}',
          i,
          500,
          600,
        ).toJson(),
        'startMinute': null,
        'endMinute': null,
      }),
    );
    expect(
      blocked(EditableTripValidator.validate(base.copyWith(items: items))),
      false,
    );
    final extra = item('00000000-0000-4000-8000-000000099999', 1000, 500, 600);
    expect(
      blocked(
        EditableTripValidator.validate(base.copyWith(items: [...items, extra])),
      ),
      true,
    );
  });
  test('draft_without_dates_is_not_account_save_ready', () {
    final base = fixture();
    expect(blocked(EditableTripValidator.validate(base)), false);
    expect(
      blocked(
        EditableTripValidator.validate(base, mode: ValidationMode.accountSave),
      ),
      true,
    );
  });
  test('calendar, time range, missing references and unknown are distinct', () {
    final base = fixture();
    final bad = base.copyWith(
      input: TripInput.fromJson({
        ...base.input.toJson(),
        'startDate': '2026-02-30',
      }),
    );
    expect(blocked(EditableTripValidator.validate(bad)), true);
    expect(
      blocked(
        EditableTripValidator.validate(
          base.copyWith(
            items: [item('00000000-0000-4000-8000-000000000010', 0, 600, 500)],
          ),
        ),
      ),
      true,
    );
    final orphan = TripItem.fromJson({
      ...item('00000000-0000-4000-8000-000000000010', 0, 500, 600).toJson(),
      'dayId': '00000000-0000-4000-8000-000000000099',
    });
    expect(
      blocked(EditableTripValidator.validate(base.copyWith(items: [orphan]))),
      true,
    );
    expect(
      EditableTripValidator.validate(base)
          .any((i) => i.code == 'unknown_estimates' && !i.isBlocking),
      true,
    );
  });
  test('overlap exception matches exact time fingerprint and reason', () {
    final base = fixture().copyWith(
      items: [
        item('00000000-0000-4000-8000-000000000010', 0, 500, 600),
        item('00000000-0000-4000-8000-000000000011', 1, 550, 650),
      ],
    );
    final overlap = EditableTripValidator.validate(base)
        .singleWhere((i) => i.code == 'overlap');
    final acknowledged = base.copyWith(
      exceptions: [
        ValidationException(
          issueCode: overlap.code,
          itemIds: overlap.itemIds,
          reason: 'Hai hoạt động thay thế, tôi sẽ chọn một',
          fingerprint: overlap.fingerprint!,
        ),
      ],
    );
    expect(blocked(EditableTripValidator.validate(acknowledged)), false);
    final changed = acknowledged.copyWith(
      items: [
        acknowledged.items.first,
        TripItem.fromJson({
          ...acknowledged.items.last.toJson(),
          'endMinute': 700,
        }),
      ],
    );
    expect(blocked(EditableTripValidator.validate(changed)), true);
    final fake = base.copyWith(
      exceptions: [
        ValidationException(
          issueCode: 'known_closed',
          itemIds: overlap.itemIds,
          reason: 'Tự khai',
          fingerprint: overlap.fingerprint!,
        ),
      ],
    );
    expect(blocked(EditableTripValidator.validate(fake)), true);
  });
  test('date range must match every day and max 366; counts cannot be zero', () {
    final base = fixture();
    final complete = base.copyWith(
      input: TripInput.fromJson({
        ...base.input.toJson(),
        'startDate': '2026-10-15',
        'endDate': '2026-10-15',
      }),
      days: [
        TripDay.fromJson({...base.days.first.toJson(), 'date': '2026-10-15'}),
      ],
    );
    expect(
      blocked(
        EditableTripValidator.validate(
          complete,
          mode: ValidationMode.accountSave,
        ),
      ),
      false,
    );
    expect(
      blocked(
        EditableTripValidator.validate(
          complete.copyWith(
            input: TripInput.fromJson({
              ...complete.input.toJson(),
              'endDate': '2026-10-14',
            }),
          ),
        ),
      ),
      true,
    );
    expect(
      blocked(
        EditableTripValidator.validate(
          base.copyWith(
            input: TripInput.fromJson({
              ...base.input.toJson(),
              'travelerCount': 0,
            }),
          ),
        ),
      ),
      true,
    );
    final days = List.generate(
      366,
      (i) => TripDay(
        id: '00000000-0000-4000-8000-${(100 + i).toString().padLeft(12, '0')}',
        ordinal: i + 1,
        date: null,
        notes: '',
      ),
    );
    expect(
      blocked(EditableTripValidator.validate(base.copyWith(days: days))),
      false,
    );
    expect(
      blocked(
        EditableTripValidator.validate(
          base.copyWith(
            days: [
              ...days,
              TripDay(
                id: '00000000-0000-4000-8000-000000009999',
                ordinal: 367,
                date: null,
                notes: '',
              ),
            ],
          ),
        ),
      ),
      true,
    );
  });
}

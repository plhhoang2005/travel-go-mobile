import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_command.dart';
import 'package:travelgo_mobile/features/trip_planner/services/editable_trip_mutator.dart';
import 'package:travelgo_mobile/features/trip_planner/services/editable_trip_validator.dart';

const day1 = '00000000-0000-4000-8000-000000000001';
const day2 = '00000000-0000-4000-8000-000000000005';
const item1 = '00000000-0000-4000-8000-000000000010';
const item2 = '00000000-0000-4000-8000-000000000011';
EditableTripDocumentV2 fixture() {
  final rows = jsonDecode(
    File('test/fixtures/editable_trip_v2_vectors.json').readAsStringSync(),
  ) as List;
  final base = EditableTripCodec.decode(rows.first['rawText'] as String);
  final provenance = FieldProvenance(
    quality: 'user_provided',
    sourceRefs: [],
    observedAt: null,
  );
  final a = TripItem(
    id: item1,
    dayId: day1,
    position: 0,
    title: 'Đại Nội',
    placeId: null,
    startMinute: 500,
    endMinute: 600,
    notes: '',
    provenance: provenance,
  );
  final b = TripItem(
    id: item2,
    dayId: day1,
    position: 1,
    title: 'Ăn trưa',
    placeId: null,
    startMinute: 700,
    endMinute: 750,
    notes: '',
    provenance: provenance,
  );
  return base.copyWith(
    days: [
      ...base.days,
      TripDay(id: day2, ordinal: 2, date: null, notes: ''),
    ],
    items: [a, b],
    estimates: [
      EstimatedExpense.fromJson({
        ...base.estimates.first.toJson(),
        'itemId': item1,
      }),
    ],
    actualExpenses: [
      ActualExpense.fromJson({
        ...base.actualExpenses.single.toJson(),
        'itemId': item1,
      }),
    ],
  );
}

void main() {
  test(
    'remaining typed operations roundtrip without changing actual implicitly',
    () {
      final base = fixture();
      final added = TripItem.fromJson({
        ...base.items.first.toJson(),
        'id': '00000000-0000-4000-8000-000000000012',
        'position': 2,
        'startMinute': 800,
        'endMinute': 900,
      });
      final commands = <EditableCommand>[
        SetTripInputCommand(
          TripInput.fromJson({...base.input.toJson(), 'travelerCount': 4}),
        ),
        const DayNotesCommand(day1, 'Đi chậm'),
        AddItemCommand(added),
        PutEstimateCommand(
          EstimatedExpense.fromJson({
            ...base.estimates.first.toJson(),
            'unitAmountVnd': 120000,
          }),
        ),
        PutActualCommand(
          ActualExpense.fromJson({
            ...base.actualExpenses.single.toJson(),
            'amountVnd': 260000,
          }),
        ),
      ];
      final direct = EditableTripMutator.apply(base, commands);
      final replay = EditableTripMutator.apply(
        base,
        commands.map((c) => EditableCommand.fromJson(c.toJson())).toList(),
      );
      expect(
        EditableTripCodec.digest(direct),
        EditableTripCodec.digest(replay),
      );
      expect(direct.actualExpenses.single.amountVnd, 260000);
      expect(direct.days.first.notes, 'Đi chậm');
      expect(direct.items.length, 3);
      final withoutActual = EditableTripMutator.apply(direct, [
        DeleteActualCommand(direct.actualExpenses.single.id),
      ]);
      expect(withoutActual.actualExpenses, isEmpty);
      expect(withoutActual.estimates.length, 1);
      final resizing = ResizeDaysCommand(days: base.days);
      expect(
        EditableTripCodec.digest(
          EditableTripMutator.apply(base, [
            EditableCommand.fromJson(resizing.toJson()),
          ]),
        ),
        EditableTripCodec.digest(base),
      );
    },
  );
  test('remove_item_inactivates_estimate_preserves_actual_250000', () {
    final base = fixture();
    final original = EditableTripCodec.digest(base);
    final after = EditableTripMutator.apply(base, [RemoveItemCommand(item1)]);
    expect(after.items.map((i) => i.id), [item2]);
    expect(after.items.single.position, 0);
    expect(after.estimates.single.active, false);
    expect(after.estimates.single.itemId, isNull);
    expect(after.actualExpenses.single.amountVnd, 250000);
    expect(after.actualExpenses.single.itemId, isNull);
    expect(after.actualExpenses.single.sourceItemSnapshot!.title, 'Đại Nội');
    expect(
      after.actualExpenses.single.paidOn,
      base.actualExpenses.single.paidOn,
    );
    expect(
      after.actualExpenses.single.description,
      base.actualExpenses.single.description,
    );
    expect(EditableTripCodec.digest(base), original);
  });
  test('move_and_reorder_preserve_ids_and_expense_links', () {
    final base = fixture();
    final reordered = EditableTripMutator.apply(base, [
      ReorderDayCommand(day1, [item2, item1]),
    ]);
    expect(reordered.items.map((i) => i.id), [item2, item1]);
    final moved = EditableTripMutator.apply(reordered, [
      MoveItemCommand(item1, day2, 0),
    ]);
    expect(moved.items.singleWhere((i) => i.id == item1).dayId, day2);
    expect(moved.actualExpenses.single.itemId, item1);
    expect(moved.actualExpenses.single.amountVnd, 250000);
    expect(
      () => EditableTripMutator.apply(base, [
        ReorderDayCommand(day1, [item1, item1]),
      ]),
      throwsA(isA<EditableMutationException>()),
    );
  });
  test('resize preview does not mutate, unresolved removal rejects', () {
    final base = fixture();
    final original = EditableTripCodec.digest(base);
    final remaining = [
      TripDay.fromJson({...base.days.last.toJson(), 'ordinal': 1}),
    ];
    final preview = EditableTripMutator.previewResize(
      base,
      base.input,
      remaining,
    );
    expect(preview.affectedItemIds.toSet(), {item1, item2});
    expect(EditableTripCodec.digest(base), original);
    expect(
      () =>
          EditableTripMutator.apply(base, [ResizeDaysCommand(days: remaining)]),
      throwsA(isA<EditableMutationException>()),
    );
    final after = EditableTripMutator.apply(base, [
      ResizeDaysCommand(
        days: remaining,
        moves: [ItemMove(item2, day2, 0)],
        removedItemIds: [item1],
      ),
    ]);
    expect(after.items.single.id, item2);
    expect(after.actualExpenses.single.amountVnd, 250000);
    expect(after.actualExpenses.single.sourceItemSnapshot!.dayId, day1);
  });
  test('mixed_itinerary_actual_batch_is_atomic', () {
    final base = fixture();
    final original = EditableTripCodec.digest(base);
    final paid = ActualExpense.fromJson({
      ...base.actualExpenses.single.toJson(),
      'amountVnd': 275000,
    });
    final after = EditableTripMutator.apply(base, [
      RemoveItemCommand(item2),
      PutActualCommand(paid),
    ]);
    expect(after.items.length, 1);
    expect(after.actualExpenses.single.amountVnd, 275000);
    expect(
      () => EditableTripMutator.apply(base, [
        PutActualCommand(paid),
        RemoveItemCommand('00000000-0000-4000-8000-000000009999'),
      ]),
      throwsA(isA<EditableMutationException>()),
    );
    expect(EditableTripCodec.digest(base), original);
  });
  test(
    'changed_time_invalidates_exception and forged acknowledgment rejects',
    () {
      final base = fixture();
      final overlap = EditableTripMutator.apply(base, [
        EditItemCommand.fromItem(
          TripItem.fromJson({...base.items.last.toJson(), 'startMinute': 550}),
        ),
      ]);
      final issue = EditableTripValidator.validate(overlap)
          .singleWhere((i) => i.code == 'overlap');
      final exception = ValidationException(
        issueCode: 'overlap',
        itemIds: issue.itemIds,
        reason: 'Hoạt động thay thế',
        fingerprint: issue.fingerprint!,
      );
      final acknowledged = EditableTripMutator.apply(overlap, [
        AcknowledgeIssueCommand(exception),
      ]);
      expect(acknowledged.exceptions.length, 1);
      final changed = EditableTripMutator.apply(acknowledged, [
        EditItemCommand.fromItem(
          TripItem.fromJson({
            ...acknowledged.items.last.toJson(),
            'endMinute': 800,
          }),
        ),
      ]);
      expect(changed.exceptions, isEmpty);
      expect(
        () => EditableTripMutator.apply(base, [
          AcknowledgeIssueCommand(exception),
        ]),
        throwsA(isA<EditableMutationException>()),
      );
    },
  );
  test('typed commands reject unknown keys and wire replay agrees', () {
    final base = fixture();
    final command = MoveItemCommand(item1, day2, 0);
    final replay = EditableCommand.fromJson(command.toJson());
    expect(
      EditableTripCodec.digest(EditableTripMutator.apply(base, [command])),
      EditableTripCodec.digest(EditableTripMutator.apply(base, [replay])),
    );
    expect(
      () =>
          EditableCommand.fromJson({...command.toJson(), 'actualExpenses': []}),
      throwsA(isA<EditableMutationException>()),
    );
  });
}

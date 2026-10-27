import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/services/budget_calculator.dart';

EditableTripDocumentV2 fixture() {
  final rows = jsonDecode(
    File('test/fixtures/editable_trip_v2_vectors.json').readAsStringSync(),
  ) as List;
  return EditableTripCodec.decode(rows.first['rawText'] as String);
}

void main() {
  test('money_vector_500000 keeps unknown separate from actual', () {
    final totals = BudgetCalculator.calculate(fixture());
    expect(totals.knownEstimate, 300000);
    expect(totals.unknownEstimateCount, 1);
    expect(totals.estimateRemaining, 200000);
    expect(totals.actualRemaining, 250000);
    expect(totals.actualTotal, 250000);
  });
  test('all bases use integer multipliers and inactive unknown is ignored', () {
    final base = fixture();
    for (final entry in {
      'trip_total': 100000,
      'per_person': 300000,
      'per_day': 100000,
      'per_person_day': 300000,
      'custom_quantity': 400000,
    }.entries) {
      final estimate = EstimatedExpense.fromJson({
        ...base.estimates.first.toJson(),
        'basis': entry.key,
        'customQuantity': entry.key == 'custom_quantity' ? 4 : null,
      });
      expect(
        BudgetCalculator.calculate(base.copyWith(estimates: [estimate]))
            .knownEstimate,
        entry.value,
      );
    }
    final inactive = EstimatedExpense.fromJson({
      ...base.estimates.last.toJson(),
      'active': false,
    });
    expect(
      BudgetCalculator.calculate(base.copyWith(estimates: [inactive]))
          .unknownEstimateCount,
      0,
    );
  });
  test('known zero, overbudget and negative remaining are truthful', () {
    final base = fixture();
    final zero = EstimatedExpense.fromJson({
      ...base.estimates.first.toJson(),
      'unitAmountVnd': 0,
    });
    final small = base.copyWith(
      input: TripInput.fromJson({...base.input.toJson(), 'totalBudgetVnd': 0}),
      estimates: [zero],
    );
    final totals = BudgetCalculator.calculate(small);
    expect(totals.knownEstimate, 0);
    expect(totals.unknownEstimateCount, 0);
    expect(totals.actualRemaining, -250000);
  });
  test('multiplication and sum overflow cannot wrap to valid money', () {
    final base = fixture();
    final max = EstimatedExpense.fromJson({
      ...base.estimates.first.toJson(),
      'unitAmountVnd': 9007199254740991,
    });
    expect(
      () => BudgetCalculator.calculate(base.copyWith(estimates: [max])),
      throwsA(isA<BudgetCalculationException>()),
    );
    final single = EstimatedExpense.fromJson({
      ...max.toJson(),
      'basis': 'trip_total',
    });
    final another = EstimatedExpense.fromJson({
      ...single.toJson(),
      'id': '00000000-0000-4000-8000-000000000009',
    });
    expect(
      () => BudgetCalculator.calculate(
        base.copyWith(estimates: [single, another]),
      ),
      throwsA(isA<BudgetCalculationException>()),
    );
  });
}

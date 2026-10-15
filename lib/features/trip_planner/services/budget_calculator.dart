import '../../trips/models/editable_trip_codec.dart';
import '../models/editable_trip_document.dart';

class BudgetCalculationException implements Exception {
  final String code;
  const BudgetCalculationException(this.code);
  @override
  String toString() => 'BudgetCalculationException($code)';
}

class BudgetTotals {
  final int knownEstimate, unknownEstimateCount, actualTotal;
  final int estimateRemaining, actualRemaining;
  const BudgetTotals({
    required this.knownEstimate,
    required this.unknownEstimateCount,
    required this.actualTotal,
    required this.estimateRemaining,
    required this.actualRemaining,
  });
}

class BudgetCalculator {
  static final _limit = BigInt.from(EditableTripCodec.maxMoney);
  static int _checked(BigInt value) {
    if (value < BigInt.zero || value > _limit) {
      throw const BudgetCalculationException('money_overflow');
    }
    return value.toInt();
  }

  static int multiplier(EstimatedExpense entry, EditableTripDocumentV2 doc) {
    return switch (entry.basis) {
      'trip_total' => 1,
      'per_person' => doc.input.travelerCount,
      'per_day' => doc.days.length,
      'per_person_day' => doc.input.travelerCount * doc.days.length,
      'custom_quantity' =>
        entry.customQuantity ??
            (throw const BudgetCalculationException('quantity_required')),
      _ => throw const BudgetCalculationException('invalid_basis'),
    };
  }

  static BudgetTotals calculate(EditableTripDocumentV2 document) {
    EditableTripCodec.validateDocument(document);
    var known = BigInt.zero;
    var unknown = 0;
    var actual = BigInt.zero;
    for (final entry in document.estimates) {
      if (!entry.active) {
        continue;
      }
      if (entry.unitAmountVnd == null) {
        unknown++;
        continue;
      }
      final amount =
          BigInt.from(entry.unitAmountVnd!) *
          BigInt.from(multiplier(entry, document));
      _checked(amount);
      known += amount;
      _checked(known);
    }
    for (final entry in document.actualExpenses) {
      actual += BigInt.from(entry.amountVnd);
      _checked(actual);
    }
    final knownInt = _checked(known);
    final actualInt = _checked(actual);
    return BudgetTotals(
      knownEstimate: knownInt,
      unknownEstimateCount: unknown,
      actualTotal: actualInt,
      estimateRemaining: document.input.totalBudgetVnd - knownInt,
      actualRemaining: document.input.totalBudgetVnd - actualInt,
    );
  }
}

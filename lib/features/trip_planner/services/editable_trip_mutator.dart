import '../../trips/models/editable_trip_codec.dart';
import '../models/editable_trip_command.dart';
import '../models/editable_trip_document.dart';
import 'budget_calculator.dart';
import 'editable_trip_validator.dart';

class ResizePreview {
  final TripInput input;
  final List<TripDay> proposedDays;
  final List<String> affectedItemIds;
  final BudgetTotals beforeTotals;
  ResizePreview({
    required this.input,
    required List<TripDay> proposedDays,
    required List<String> affectedItemIds,
    required this.beforeTotals,
  }) : proposedDays = List.unmodifiable(proposedDays),
       affectedItemIds = List.unmodifiable(affectedItemIds);
}

class EditableTripMutator {
  static Never _fail(String code) => throw EditableMutationException(code);
  static TripItem _item(EditableTripDocumentV2 doc, String id) {
    for (final item in doc.items) {
      if (item.id == id) {
        return item;
      }
    }
    _fail('item_unavailable');
  }

  static List<TripItem> _dayItems(EditableTripDocumentV2 doc, String dayId) =>
      doc.items.where((i) => i.dayId == dayId).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
  static EditableTripDocumentV2 _order(
    EditableTripDocumentV2 doc,
    String dayId,
    List<TripItem> ordered,
  ) {
    return doc.copyWith(
      items: [
        ...doc.items.where((i) => i.dayId != dayId),
        for (var i = 0; i < ordered.length; i++)
          TripItem.fromJson({...ordered[i].toJson(), 'position': i}),
      ],
    );
  }

  static EditableTripDocumentV2 _remove(EditableTripDocumentV2 doc, String id) {
    final removed = _item(doc, id);
    final day = doc.days.firstWhere((d) => d.id == removed.dayId);
    final next = doc.copyWith(
      items: doc.items.where((i) => i.id != id).toList(),
      estimates: doc.estimates
          .map(
            (e) => e.itemId == id
                ? EstimatedExpense.fromJson({
                    ...e.toJson(),
                    'active': false,
                    'itemId': null,
                  })
                : e,
          )
          .toList(),
      actualExpenses: doc.actualExpenses
          .map(
            (e) => e.itemId == id
                ? ActualExpense.fromJson({
                    ...e.toJson(),
                    'itemId': null,
                    'sourceItemSnapshot':
                        e.sourceItemSnapshot?.toJson() ??
                        ItemSnapshot(
                          title: removed.title,
                          dayId: day.id,
                          date: day.date,
                        ).toJson(),
                  })
                : e,
          )
          .toList(),
    );
    return _order(next, removed.dayId, _dayItems(next, removed.dayId));
  }

  static EditableTripDocumentV2 _insert(
    EditableTripDocumentV2 doc,
    TripItem item,
  ) {
    if (!doc.days.any((d) => d.id == item.dayId)) {
      _fail('day_unavailable');
    }
    final target = _dayItems(doc, item.dayId);
    if (item.position < 0 || item.position > target.length) {
      _fail('invalid_position');
    }
    target.insert(item.position, item);
    return _order(doc, item.dayId, target);
  }

  static EditableTripDocumentV2 _move(
    EditableTripDocumentV2 doc,
    String id,
    String dayId,
    int position,
  ) {
    final old = _item(doc, id);
    var next = doc.copyWith(items: doc.items.where((i) => i.id != id).toList());
    next = _order(next, old.dayId, _dayItems(next, old.dayId));
    return _insert(
      next,
      TripItem.fromJson({
        ...old.toJson(),
        'dayId': dayId,
        'position': position,
      }),
    );
  }

  static ResizePreview previewResize(
    EditableTripDocumentV2 base,
    TripInput input,
    List<TripDay> days,
  ) {
    final retained = days.map((d) => d.id).toSet();
    return ResizePreview(
      input: input,
      proposedDays: days,
      affectedItemIds: base.items
          .where((i) => !retained.contains(i.dayId))
          .map((i) => i.id)
          .toList(),
      beforeTotals: BudgetCalculator.calculate(base),
    );
  }

  static EditableTripDocumentV2 apply(
    EditableTripDocumentV2 base,
    List<EditableCommand> commands,
  ) {
    if (commands.length > 4000) {
      _fail('command_limit');
    }
    try {
      EditableTripCodec.validateDocument(base);
      var doc = base;
      for (final command in commands) {
        switch (command) {
          case SetTripInputCommand():
            doc = doc.copyWith(input: command.input);
          case ResizeDaysCommand():
            final nextIds = command.days.map((d) => d.id).toSet();
            if (nextIds.length != command.days.length) {
              _fail('duplicate_day');
            }
            final affected = doc.items
                .where((i) => !nextIds.contains(i.dayId))
                .map((i) => i.id)
                .toSet();
            final moved = command.moves.map((m) => m.itemId).toSet();
            final removed = command.removedItemIds.toSet();
            if (moved.length != command.moves.length ||
                removed.length != command.removedItemIds.length ||
                moved.intersection(removed).isNotEmpty ||
                !affected.containsAll(moved) ||
                !affected.containsAll(removed) ||
                !({...moved, ...removed}).containsAll(affected)) {
              _fail('unresolved_resize');
            }
            for (final id in command.removedItemIds) {
              doc = _remove(doc, id);
            }
            doc = doc.copyWith(days: command.days);
            for (final move in command.moves) {
              doc = _move(doc, move.itemId, move.dayId, move.position);
            }
          case DayNotesCommand():
            if (!doc.days.any((d) => d.id == command.dayId)) {
              _fail('day_unavailable');
            }
            doc = doc.copyWith(
              days: doc.days
                  .map(
                    (d) => d.id == command.dayId
                        ? TripDay.fromJson({
                            ...d.toJson(),
                            'notes': command.notes,
                          })
                        : d,
                  )
                  .toList(),
            );
          case AddItemCommand():
            if (doc.items.any((i) => i.id == command.item.id)) {
              _fail('duplicate_item');
            }
            doc = _insert(doc, command.item);
          case EditItemCommand():
            final old = _item(doc, command.itemId);
            final edited = TripItem.fromJson({
              ...old.toJson(),
              'title': command.title,
              'notes': command.notes,
              'placeId': command.placeId,
              'startMinute': command.startMinute,
              'endMinute': command.endMinute,
              'provenance': command.provenance.toJson(),
            });
            doc = doc.copyWith(
              items: doc.items.map((i) => i.id == old.id ? edited : i).toList(),
            );
          case MoveItemCommand():
            doc = _move(doc, command.itemId, command.dayId, command.position);
          case ReorderDayCommand():
            if (!doc.days.any((d) => d.id == command.dayId)) {
              _fail('day_unavailable');
            }
            final old = {
              for (final i in _dayItems(doc, command.dayId)) i.id: i,
            };
            if (command.orderedItemIds.length != old.length ||
                command.orderedItemIds.toSet().length != old.length ||
                !old.keys.toSet().containsAll(command.orderedItemIds)) {
              _fail('invalid_permutation');
            }
            doc = _order(
              doc,
              command.dayId,
              command.orderedItemIds.map((id) => old[id]!).toList(),
            );
          case RemoveItemCommand():
            doc = _remove(doc, command.itemId);
          case PutEstimateCommand():
            final entries = doc.estimates.toList();
            final index = entries.indexWhere(
              (e) => e.id == command.estimate.id,
            );
            if (index < 0) {
              entries.add(command.estimate);
            } else {
              entries[index] = command.estimate;
            }
            doc = doc.copyWith(estimates: entries);
          case PutActualCommand():
            final entries = doc.actualExpenses.toList();
            final index = entries.indexWhere((e) => e.id == command.actual.id);
            if (index < 0) {
              entries.add(command.actual);
            } else {
              entries[index] = command.actual;
            }
            doc = doc.copyWith(actualExpenses: entries);
          case DeleteActualCommand():
            if (!doc.actualExpenses.any((e) => e.id == command.expenseId)) {
              _fail('expense_unavailable');
            }
            doc = doc.copyWith(
              actualExpenses: doc.actualExpenses
                  .where((e) => e.id != command.expenseId)
                  .toList(),
            );
          case AcknowledgeIssueCommand():
            final exception = command.exception;
            final matches = EditableTripValidator.validate(doc).where(
              (i) =>
                  i.code == exception.issueCode &&
                  i.fingerprint == exception.fingerprint &&
                  i.itemIds.length == exception.itemIds.length &&
                  i.itemIds.toSet().containsAll(exception.itemIds),
            );
            if (exception.reason.trim().isEmpty || matches.isEmpty) {
              _fail('stale_issue');
            }
            doc = doc.copyWith(
              exceptions: [
                ...doc.exceptions.where(
                  (e) => e.fingerprint != exception.fingerprint,
                ),
                exception,
              ],
            );
        }
      }
      final ids = doc.items.map((i) => i.id).toSet();
      doc = doc.copyWith(
        exceptions: doc.exceptions
            .where((e) => ids.containsAll(e.itemIds))
            .toList(),
      );
      final dayOrder = {
        for (var i = 0; i < doc.days.length; i++) doc.days[i].id: i,
      };
      final sorted = doc.items.toList()
        ..sort((a, b) {
          final day = (dayOrder[a.dayId] ?? 9999).compareTo(
            dayOrder[b.dayId] ?? 9999,
          );
          return day != 0 ? day : a.position.compareTo(b.position);
        });
      doc = doc.copyWith(items: sorted);
      final issues = EditableTripValidator.validate(doc);
      if (issues.any(
        (i) => i.isBlocking && !{'overlap', 'time_order'}.contains(i.code),
      )) {
        _fail('invalid_result');
      }
      final current = issues
          .where((i) => i.fingerprint != null)
          .map((i) => '${i.code}:${i.fingerprint}')
          .toSet();
      doc = doc.copyWith(
        exceptions: doc.exceptions
            .where((e) => current.contains('${e.issueCode}:${e.fingerprint}'))
            .toList(),
      );
      // Encoding also checks the byte bound; do not return an unsavable result.
      EditableTripCodec.encode(doc);
      return doc;
    } on EditableMutationException {
      rethrow;
    } on Object {
      throw const EditableMutationException('invalid_result');
    }
  }
}

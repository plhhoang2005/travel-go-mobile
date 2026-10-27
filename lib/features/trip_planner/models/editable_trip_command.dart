import 'editable_trip_document.dart';

class EditableMutationException implements Exception {
  final String code;
  const EditableMutationException(this.code);
  @override
  String toString() => 'EditableMutationException($code)';
}

sealed class EditableCommand {
  const EditableCommand();
  Map<String, Object?> toJson();
  factory EditableCommand.fromJson(Map<String, Object?> json) {
    try {
      return _decodeCommand(json);
    } on EditableMutationException {
      rethrow;
    } on Object {
      throw const EditableMutationException('invalid_command');
    }
  }
}

class SetTripInputCommand extends EditableCommand {
  final TripInput input;
  const SetTripInputCommand(this.input);
  @override
  Map<String, Object?> toJson() => {'op': 'setInput', 'input': input.toJson()};
}

class ItemMove {
  final String itemId, dayId;
  final int position;
  const ItemMove(this.itemId, this.dayId, this.position);
  Map<String, Object?> toJson() => {
    'itemId': itemId,
    'dayId': dayId,
    'position': position,
  };
}

class ResizeDaysCommand extends EditableCommand {
  final List<TripDay> days;
  final List<ItemMove> moves;
  final List<String> removedItemIds;
  ResizeDaysCommand({
    required List<TripDay> days,
    List<ItemMove> moves = const [],
    List<String> removedItemIds = const [],
  }) : days = List.unmodifiable(days),
       moves = List.unmodifiable(moves),
       removedItemIds = List.unmodifiable(removedItemIds);
  @override
  Map<String, Object?> toJson() => {
    'op': 'resizeDays',
    'days': days.map((d) => d.toJson()).toList(),
    'moves': moves.map((m) => m.toJson()).toList(),
    'removedItemIds': removedItemIds,
  };
}

class DayNotesCommand extends EditableCommand {
  final String dayId, notes;
  const DayNotesCommand(this.dayId, this.notes);
  @override
  Map<String, Object?> toJson() => {
    'op': 'setDayNotes',
    'dayId': dayId,
    'notes': notes,
  };
}

class AddItemCommand extends EditableCommand {
  final TripItem item;
  const AddItemCommand(this.item);
  @override
  Map<String, Object?> toJson() => {'op': 'addItem', 'item': item.toJson()};
}

class EditItemCommand extends EditableCommand {
  final String itemId, title, notes;
  final String? placeId;
  final int? startMinute, endMinute;
  final FieldProvenance provenance;
  const EditItemCommand({
    required this.itemId,
    required this.title,
    required this.notes,
    required this.placeId,
    required this.startMinute,
    required this.endMinute,
    required this.provenance,
  });
  factory EditItemCommand.fromItem(TripItem item) => EditItemCommand(
    itemId: item.id,
    title: item.title,
    notes: item.notes,
    placeId: item.placeId,
    startMinute: item.startMinute,
    endMinute: item.endMinute,
    provenance: item.provenance,
  );
  @override
  Map<String, Object?> toJson() => {
    'op': 'editItem',
    'itemId': itemId,
    'title': title,
    'notes': notes,
    'placeId': placeId,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'provenance': provenance.toJson(),
  };
}

class MoveItemCommand extends EditableCommand {
  final String itemId, dayId;
  final int position;
  const MoveItemCommand(this.itemId, this.dayId, this.position);
  @override
  Map<String, Object?> toJson() => {
    'op': 'moveItem',
    'itemId': itemId,
    'dayId': dayId,
    'position': position,
  };
}

class ReorderDayCommand extends EditableCommand {
  final String dayId;
  final List<String> orderedItemIds;
  ReorderDayCommand(this.dayId, List<String> orderedItemIds)
    : orderedItemIds = List.unmodifiable(orderedItemIds);
  @override
  Map<String, Object?> toJson() => {
    'op': 'reorderDay',
    'dayId': dayId,
    'orderedItemIds': orderedItemIds,
  };
}

class RemoveItemCommand extends EditableCommand {
  final String itemId;
  const RemoveItemCommand(this.itemId);
  @override
  Map<String, Object?> toJson() => {'op': 'removeItem', 'itemId': itemId};
}

class PutEstimateCommand extends EditableCommand {
  final EstimatedExpense estimate;
  const PutEstimateCommand(this.estimate);
  @override
  Map<String, Object?> toJson() => {
    'op': 'putEstimate',
    'estimate': estimate.toJson(),
  };
}

class PutActualCommand extends EditableCommand {
  final ActualExpense actual;
  const PutActualCommand(this.actual);
  @override
  Map<String, Object?> toJson() => {
    'op': 'putActual',
    'actual': actual.toJson(),
  };
}

class DeleteActualCommand extends EditableCommand {
  final String expenseId;
  const DeleteActualCommand(this.expenseId);
  @override
  Map<String, Object?> toJson() => {
    'op': 'deleteActual',
    'expenseId': expenseId,
  };
}

class AcknowledgeIssueCommand extends EditableCommand {
  final ValidationException exception;
  const AcknowledgeIssueCommand(this.exception);
  @override
  Map<String, Object?> toJson() => {
    'op': 'acknowledgeIssue',
    'exception': exception.toJson(),
  };
}

void _keys(Map<String, Object?> json, String fields) {
  final keys = fields.split(' ');
  if (json.length != keys.length || json.keys.any((k) => !keys.contains(k))) {
    throw const EditableMutationException('invalid_command_keys');
  }
}

Map<String, Object?> _entity(Object? value, String fields) {
  final map = editableObject(value);
  _keys(map, fields);
  if (map.containsKey('provenance')) {
    _keys(editableObject(map['provenance']), 'quality sourceRefs observedAt');
  }
  if (map['sourceItemSnapshot'] != null) {
    _keys(editableObject(map['sourceItemSnapshot']), 'title dayId date');
  }
  return map;
}

EditableCommand _decodeCommand(Map<String, Object?> j) {
  switch (j['op']) {
    case 'setInput':
      _keys(j, 'op input');
      return SetTripInputCommand(
        TripInput.fromJson(
          _entity(
            j['input'],
            'title destinationId destinationName startDate endDate timezone origin travelerCount totalBudgetVnd interests priority',
          ),
        ),
      );
    case 'resizeDays':
      _keys(j, 'op days moves removedItemIds');
      return ResizeDaysCommand(
        days: (j['days'] as List)
            .map((v) => TripDay.fromJson(_entity(v, 'id ordinal date notes')))
            .toList(),
        moves: (j['moves'] as List).map((v) {
          final m = _entity(v, 'itemId dayId position');
          return ItemMove(
            m['itemId'] as String,
            m['dayId'] as String,
            m['position'] as int,
          );
        }).toList(),
        removedItemIds: List<String>.from(j['removedItemIds'] as List),
      );
    case 'setDayNotes':
      _keys(j, 'op dayId notes');
      return DayNotesCommand(j['dayId'] as String, j['notes'] as String);
    case 'addItem':
      _keys(j, 'op item');
      return AddItemCommand(
        TripItem.fromJson(
          _entity(
            j['item'],
            'id dayId position title placeId startMinute endMinute notes provenance',
          ),
        ),
      );
    case 'editItem':
      _keys(
        j,
        'op itemId title notes placeId startMinute endMinute provenance',
      );
      _keys(editableObject(j['provenance']), 'quality sourceRefs observedAt');
      return EditItemCommand(
        itemId: j['itemId'] as String,
        title: j['title'] as String,
        notes: j['notes'] as String,
        placeId: j['placeId'] as String?,
        startMinute: j['startMinute'] as int?,
        endMinute: j['endMinute'] as int?,
        provenance: FieldProvenance.fromJson(editableObject(j['provenance'])),
      );
    case 'moveItem':
      _keys(j, 'op itemId dayId position');
      return MoveItemCommand(
        j['itemId'] as String,
        j['dayId'] as String,
        j['position'] as int,
      );
    case 'reorderDay':
      _keys(j, 'op dayId orderedItemIds');
      return ReorderDayCommand(
        j['dayId'] as String,
        List<String>.from(j['orderedItemIds'] as List),
      );
    case 'removeItem':
      _keys(j, 'op itemId');
      return RemoveItemCommand(j['itemId'] as String);
    case 'putEstimate':
      _keys(j, 'op estimate');
      return PutEstimateCommand(
        EstimatedExpense.fromJson(
          _entity(
            j['estimate'],
            'id itemId category unitAmountVnd basis customQuantity active description provenance',
          ),
        ),
      );
    case 'putActual':
      _keys(j, 'op actual');
      return PutActualCommand(
        ActualExpense.fromJson(
          _entity(
            j['actual'],
            'id itemId amountVnd category paidOn description sourceItemSnapshot provenance',
          ),
        ),
      );
    case 'deleteActual':
      _keys(j, 'op expenseId');
      return DeleteActualCommand(j['expenseId'] as String);
    case 'acknowledgeIssue':
      _keys(j, 'op exception');
      return AcknowledgeIssueCommand(
        ValidationException.fromJson(
          _entity(j['exception'], 'issueCode itemIds reason fingerprint'),
        ),
      );
    default:
      throw const EditableMutationException('unsupported_command');
  }
}

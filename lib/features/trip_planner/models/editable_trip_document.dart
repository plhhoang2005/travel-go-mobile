/// Immutable manual itinerary contract. Wire validation lives in EditableTripCodec.
Map<String, Object?> editableObject(Object? value) =>
    Map<String, Object?>.from(value as Map);

class TripInput {
  final String title;
  final String? destinationId;
  final String? destinationName;
  final String? startDate;
  final String? endDate;
  final String timezone;
  final String origin;
  final int travelerCount;
  final int totalBudgetVnd;
  final List<String> interests;
  final String priority;
  TripInput({
    required this.title,
    required this.destinationId,
    required this.destinationName,
    required this.startDate,
    required this.endDate,
    required this.timezone,
    required this.origin,
    required this.travelerCount,
    required this.totalBudgetVnd,
    required List<String> interests,
    required this.priority,
  }) : interests = List.unmodifiable(interests);
  factory TripInput.fromJson(Map<String, Object?> json) => TripInput(
    title: json['title'] as String,
    destinationId: json['destinationId'] as String?,
    destinationName: json['destinationName'] as String?,
    startDate: json['startDate'] as String?,
    endDate: json['endDate'] as String?,
    timezone: json['timezone'] as String,
    origin: json['origin'] as String,
    travelerCount: json['travelerCount'] as int,
    totalBudgetVnd: json['totalBudgetVnd'] as int,
    interests: List<String>.from(json['interests'] as List),
    priority: json['priority'] as String,
  );
  Map<String, Object?> toJson() => {
    'title': title,
    'destinationId': destinationId,
    'destinationName': destinationName,
    'startDate': startDate,
    'endDate': endDate,
    'timezone': timezone,
    'origin': origin,
    'travelerCount': travelerCount,
    'totalBudgetVnd': totalBudgetVnd,
    'interests': interests,
    'priority': priority,
  };
}

class TripDay {
  final String id;
  final int ordinal;
  final String? date;
  final String notes;
  TripDay({
    required this.id,
    required this.ordinal,
    required this.date,
    required this.notes,
  });
  factory TripDay.fromJson(Map<String, Object?> json) => TripDay(
    id: json['id'] as String,
    ordinal: json['ordinal'] as int,
    date: json['date'] as String?,
    notes: json['notes'] as String,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'ordinal': ordinal,
    'date': date,
    'notes': notes,
  };
}

class TripItem {
  final String id;
  final String dayId;
  final int position;
  final String title;
  final String? placeId;
  final int? startMinute;
  final int? endMinute;
  final String notes;
  final FieldProvenance provenance;
  TripItem({
    required this.id,
    required this.dayId,
    required this.position,
    required this.title,
    required this.placeId,
    required this.startMinute,
    required this.endMinute,
    required this.notes,
    required this.provenance,
  });
  factory TripItem.fromJson(Map<String, Object?> json) => TripItem(
    id: json['id'] as String,
    dayId: json['dayId'] as String,
    position: json['position'] as int,
    title: json['title'] as String,
    placeId: json['placeId'] as String?,
    startMinute: json['startMinute'] as int?,
    endMinute: json['endMinute'] as int?,
    notes: json['notes'] as String,
    provenance: FieldProvenance.fromJson(editableObject(json['provenance'])),
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'dayId': dayId,
    'position': position,
    'title': title,
    'placeId': placeId,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'notes': notes,
    'provenance': provenance.toJson(),
  };
}

class FieldProvenance {
  final String quality;
  final List<String> sourceRefs;
  final String? observedAt;
  FieldProvenance({
    required this.quality,
    required List<String> sourceRefs,
    required this.observedAt,
  }) : sourceRefs = List.unmodifiable(sourceRefs);
  factory FieldProvenance.fromJson(Map<String, Object?> json) =>
      FieldProvenance(
        quality: json['quality'] as String,
        sourceRefs: List<String>.from(json['sourceRefs'] as List),
        observedAt: json['observedAt'] as String?,
      );
  Map<String, Object?> toJson() => {
    'quality': quality,
    'sourceRefs': sourceRefs,
    'observedAt': observedAt,
  };
}

class EstimatedExpense {
  final String id;
  final String? itemId;
  final String category;
  final int? unitAmountVnd;
  final String basis;
  final int? customQuantity;
  final bool active;
  final String description;
  final FieldProvenance provenance;
  EstimatedExpense({
    required this.id,
    required this.itemId,
    required this.category,
    required this.unitAmountVnd,
    required this.basis,
    required this.customQuantity,
    required this.active,
    required this.description,
    required this.provenance,
  });
  factory EstimatedExpense.fromJson(Map<String, Object?> json) =>
      EstimatedExpense(
        id: json['id'] as String,
        itemId: json['itemId'] as String?,
        category: json['category'] as String,
        unitAmountVnd: json['unitAmountVnd'] as int?,
        basis: json['basis'] as String,
        customQuantity: json['customQuantity'] as int?,
        active: json['active'] as bool,
        description: json['description'] as String,
        provenance: FieldProvenance.fromJson(
          editableObject(json['provenance']),
        ),
      );
  Map<String, Object?> toJson() => {
    'id': id,
    'itemId': itemId,
    'category': category,
    'unitAmountVnd': unitAmountVnd,
    'basis': basis,
    'customQuantity': customQuantity,
    'active': active,
    'description': description,
    'provenance': provenance.toJson(),
  };
}

class ActualExpense {
  final String id;
  final String? itemId;
  final int amountVnd;
  final String category;
  final String paidOn;
  final String description;
  final ItemSnapshot? sourceItemSnapshot;
  final FieldProvenance provenance;
  ActualExpense({
    required this.id,
    required this.itemId,
    required this.amountVnd,
    required this.category,
    required this.paidOn,
    required this.description,
    required this.sourceItemSnapshot,
    required this.provenance,
  });
  factory ActualExpense.fromJson(Map<String, Object?> json) => ActualExpense(
    id: json['id'] as String,
    itemId: json['itemId'] as String?,
    amountVnd: json['amountVnd'] as int,
    category: json['category'] as String,
    paidOn: json['paidOn'] as String,
    description: json['description'] as String,
    sourceItemSnapshot: json['sourceItemSnapshot'] == null
        ? null
        : ItemSnapshot.fromJson(editableObject(json['sourceItemSnapshot'])),
    provenance: FieldProvenance.fromJson(editableObject(json['provenance'])),
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'itemId': itemId,
    'amountVnd': amountVnd,
    'category': category,
    'paidOn': paidOn,
    'description': description,
    'sourceItemSnapshot': sourceItemSnapshot?.toJson(),
    'provenance': provenance.toJson(),
  };
}

class ItemSnapshot {
  final String title;
  final String dayId;
  final String? date;
  ItemSnapshot({required this.title, required this.dayId, required this.date});
  factory ItemSnapshot.fromJson(Map<String, Object?> json) => ItemSnapshot(
    title: json['title'] as String,
    dayId: json['dayId'] as String,
    date: json['date'] as String?,
  );
  Map<String, Object?> toJson() => {
    'title': title,
    'dayId': dayId,
    'date': date,
  };
}

class ValidationException {
  final String issueCode;
  final List<String> itemIds;
  final String reason;
  final String fingerprint;
  ValidationException({
    required this.issueCode,
    required List<String> itemIds,
    required this.reason,
    required this.fingerprint,
  }) : itemIds = List.unmodifiable(itemIds);
  factory ValidationException.fromJson(Map<String, Object?> json) =>
      ValidationException(
        issueCode: json['issueCode'] as String,
        itemIds: List<String>.from(json['itemIds'] as List),
        reason: json['reason'] as String,
        fingerprint: json['fingerprint'] as String,
      );
  Map<String, Object?> toJson() => {
    'issueCode': issueCode,
    'itemIds': itemIds,
    'reason': reason,
    'fingerprint': fingerprint,
  };
}

class SourceReference {
  final String kind;
  final String? sourceId;
  final String? sourceDigest;
  SourceReference({
    required this.kind,
    required this.sourceId,
    required this.sourceDigest,
  });
  factory SourceReference.fromJson(Map<String, Object?> json) =>
      SourceReference(
        kind: json['kind'] as String,
        sourceId: json['sourceId'] as String?,
        sourceDigest: json['sourceDigest'] as String?,
      );
  Map<String, Object?> toJson() => {
    'kind': kind,
    'sourceId': sourceId,
    'sourceDigest': sourceDigest,
  };
}

class EditableTripDocumentV2 {
  final TripInput input;
  final List<TripDay> days;
  final List<TripItem> items;
  final List<EstimatedExpense> estimates;
  final List<ActualExpense> actualExpenses;
  final List<ValidationException> exceptions;
  final SourceReference source;
  int get schemaVersion => 2;
  EditableTripDocumentV2({
    required this.input,
    required List<TripDay> days,
    List<TripItem> items = const [],
    List<EstimatedExpense> estimates = const [],
    List<ActualExpense> actualExpenses = const [],
    List<ValidationException> exceptions = const [],
    required this.source,
  }) : days = List.unmodifiable(days),
       items = List.unmodifiable(items),
       estimates = List.unmodifiable(estimates),
       actualExpenses = List.unmodifiable(actualExpenses),
       exceptions = List.unmodifiable(exceptions);
  factory EditableTripDocumentV2.fromJson(Map<String, Object?> json) =>
      EditableTripDocumentV2(
        input: TripInput.fromJson(editableObject(json['input'])),
        days: (json['days'] as List)
            .map((v) => TripDay.fromJson(editableObject(v)))
            .toList(),
        items: (json['items'] as List)
            .map((v) => TripItem.fromJson(editableObject(v)))
            .toList(),
        estimates: (json['estimates'] as List)
            .map((v) => EstimatedExpense.fromJson(editableObject(v)))
            .toList(),
        actualExpenses: (json['actualExpenses'] as List)
            .map((v) => ActualExpense.fromJson(editableObject(v)))
            .toList(),
        exceptions: (json['exceptions'] as List)
            .map((v) => ValidationException.fromJson(editableObject(v)))
            .toList(),
        source: SourceReference.fromJson(editableObject(json['source'])),
      );
  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'input': input.toJson(),
    'days': days.map((v) => v.toJson()).toList(),
    'items': items.map((v) => v.toJson()).toList(),
    'estimates': estimates.map((v) => v.toJson()).toList(),
    'actualExpenses': actualExpenses.map((v) => v.toJson()).toList(),
    'exceptions': exceptions.map((v) => v.toJson()).toList(),
    'source': source.toJson(),
  };
  EditableTripDocumentV2 copyWith({
    TripInput? input,
    List<TripDay>? days,
    List<TripItem>? items,
    List<EstimatedExpense>? estimates,
    List<ActualExpense>? actualExpenses,
    List<ValidationException>? exceptions,
    SourceReference? source,
  }) => EditableTripDocumentV2(
    input: input ?? this.input,
    days: days ?? this.days,
    items: items ?? this.items,
    estimates: estimates ?? this.estimates,
    actualExpenses: actualExpenses ?? this.actualExpenses,
    exceptions: exceptions ?? this.exceptions,
    source: source ?? this.source,
  );
}

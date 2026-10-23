import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/services/manual_trip_factory.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';

String Function() _idGenerator() {
  var count = 1;
  return () => '00000000-0000-4000-8000-${(count++).toString().padLeft(12, '0')}';
}

void main() {
  group('Manual Dynamic Destination Identity', () {
    const publishedId = 'dest-quy-nhon-2026';
    const publishedName = 'Quy Nhơn';

    test('dynamic_destination_survives_manual_roundtrip', () {
      final ids = _idGenerator();
      final factory = ManualTripFactory(newId: ids);

      final initialDoc = factory.fromInput(
        PlanTripRequest.presetMinh(),
        TripMetadataV1(
          title: 'Khám phá Quy Nhơn',
          destinationId: publishedId,
          destinationName: publishedName,
          startDate: '2026-11-01',
          endDate: '2026-11-03',
        ),
      );

      final originalExpense = ActualExpense(
        id: ids(),
        itemId: null,
        amountVnd: 350000,
        category: 'food',
        paidOn: '2026-11-01',
        description: 'Bánh xèo tôm nhảy',
        sourceItemSnapshot: null,
        provenance: FieldProvenance(
          quality: 'user_provided',
          sourceRefs: const [],
          observedAt: null,
        ),
      );

      final docWithExpense = EditableTripDocumentV2(
        input: initialDoc.input,
        days: initialDoc.days,
        items: initialDoc.items,
        estimates: initialDoc.estimates,
        actualExpenses: [originalExpense],
        exceptions: initialDoc.exceptions,
        source: initialDoc.source,
      );

      final encoded = EditableTripCodec.encode(docWithExpense);
      final reopened = EditableTripCodec.decode(encoded);

      // Pinned assertions:
      expect(reopened.input.destinationId, publishedId);
      expect(reopened.input.destinationName, publishedName);
      expect(reopened.actualExpenses.length, 1);
      expect(reopened.actualExpenses.first.id, originalExpense.id);
      expect(reopened.actualExpenses.first.amountVnd, originalExpense.amountVnd);
      expect(reopened.actualExpenses.first.description, originalExpense.description);
      expect(reopened.actualExpenses.first.paidOn, originalExpense.paidOn);
      expect(reopened.actualExpenses.first.category, originalExpense.category);
    });

    test('accepts legacy destination IDs and dynamic lowercase IDs', () {
      final ids = _idGenerator();
      final factory = ManualTripFactory(newId: ids);

      for (final legacyId in ['ha-noi', 'hue', 'da-lat', 'ho-chi-minh']) {
        final doc = factory.fromInput(
          PlanTripRequest.presetMinh(),
          TripMetadataV1(
            title: 'Chuyến đi $legacyId',
            destinationId: legacyId,
            destinationName: 'Tên $legacyId',
          ),
        );
        expect(doc.input.destinationId, legacyId);
        final encoded = EditableTripCodec.encode(doc);
        final reopened = EditableTripCodec.decode(encoded);
        expect(reopened.input.destinationId, legacyId);
      }

      for (final dynamicId in [
        'dest-phu-yen',
        'vn/lam-dong/bao-loc',
        'region-12345678-abcd',
      ]) {
        final doc = factory.fromInput(
          PlanTripRequest.presetMinh(),
          TripMetadataV1(
            title: 'Chuyến đi $dynamicId',
            destinationId: dynamicId,
            destinationName: 'Địa điểm $dynamicId',
          ),
        );
        expect(doc.input.destinationId, dynamicId);
        final encoded = EditableTripCodec.encode(doc);
        final reopened = EditableTripCodec.decode(encoded);
        expect(reopened.input.destinationId, dynamicId);
      }
    });

    test('rejects malformed destination IDs or blank destinationName on decode', () {
      final ids = _idGenerator();
      final validDoc = ManualTripFactory(newId: ids).fromInput(
        PlanTripRequest.presetMinh(),
        TripMetadataV1(
          destinationId: 'hue',
          destinationName: 'Huế',
        ),
      );
      final validJson = EditableTripCodec.encode(validDoc);

      // Malformed destinationId (uppercase, spaces, invalid chars, starting dash)
      for (final badId in [
        'INVALID_CAPS',
        '-leading-dash',
        'has space',
        'special!@#',
        'a' * 121, // exceeds 120 chars
      ]) {
        final tampered = validJson.replaceFirst('"destinationId":"hue"', '"destinationId":"$badId"');
        expect(
          () => EditableTripCodec.decode(tampered),
          throwsA(isA<EditableCodecException>().having((e) => e.code, 'code', 'invalid_input')),
          reason: 'Failed to reject bad destinationId: $badId',
        );
      }

      // Blank or oversize destinationName
      final blankName = validJson.replaceFirst('"destinationName":"Huế"', '"destinationName":"   "');
      expect(
        () => EditableTripCodec.decode(blankName),
        throwsA(isA<EditableCodecException>().having((e) => e.code, 'code', 'invalid_input')),
      );

      final overLengthName = validJson.replaceFirst('"destinationName":"Huế"', '"destinationName":"${'A' * 181}"');
      expect(
        () => EditableTripCodec.decode(overLengthName),
        throwsA(isA<EditableCodecException>().having((e) => e.code, 'code', 'invalid_input')),
      );
    });

    test('historical or hidden destination remains readable without network lookup', () {
      final ids = _idGenerator();
      final hiddenDestinationDoc = ManualTripFactory(newId: ids).fromInput(
        PlanTripRequest.presetMinh(),
        TripMetadataV1(
          title: 'Chuyến đi cũ',
          destinationId: 'dest-delisted-2025',
          destinationName: 'Địa điểm cũ đã ẩn',
        ),
      );

      final encoded = EditableTripCodec.encode(hiddenDestinationDoc);
      // Pure codec decode must parse historical destination successfully
      final reopened = EditableTripCodec.decode(encoded);
      expect(reopened.input.destinationId, 'dest-delisted-2025');
      expect(reopened.input.destinationName, 'Địa điểm cũ đã ẩn');
    });
  });
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';

void main() {
  group('PlanTripRequest - Adaptive Extensions', () {
    test('Default constructor supports optional destination, dates, and companionType', () {
      final req = PlanTripRequest(
        origin: 'Hà Nội',
        numDays: 4,
        numPeople: 2,
        budgetVnd: 6000000,
        preferences: ['núi', 'ẩm thực', 'check-in'],
        priority: 'balanced',
        destinationId: 'da-lat',
        destinationName: 'Đà Lạt',
        startDate: '2026-11-01',
        endDate: '2026-11-04',
        companionType: 'couple',
      );

      expect(req.destinationId, 'da-lat');
      expect(req.destinationName, 'Đà Lạt');
      expect(req.startDate, '2026-11-01');
      expect(req.endDate, '2026-11-04');
      expect(req.companionType, 'couple');

      final json = req.toJson();
      expect(json['destinationId'], 'da-lat');
      expect(json['destinationName'], 'Đà Lạt');
      expect(json['startDate'], '2026-11-01');
      expect(json['endDate'], '2026-11-04');
      expect(json['companionType'], 'couple');

      final deserialized = PlanTripRequest.fromJson(json);
      expect(deserialized.destinationId, 'da-lat');
      expect(deserialized.destinationName, 'Đà Lạt');
      expect(deserialized.startDate, '2026-11-01');
      expect(deserialized.endDate, '2026-11-04');
      expect(deserialized.companionType, 'couple');
    });

    test('copyWith handles new adaptive fields properly', () {
      final base = PlanTripRequest.presetMinh();
      expect(base.destinationId, isNull);
      expect(base.companionType, 'group');

      final updated = base.copyWith(
        origin: 'Đà Nẵng',
        destinationId: 'phu-quoc',
        destinationName: 'Phú Quốc',
        startDate: '2026-12-10',
        endDate: '2026-12-14',
        companionType: 'family',
      );

      expect(updated.origin, 'Đà Nẵng');
      expect(updated.destinationId, 'phu-quoc');
      expect(updated.destinationName, 'Phú Quốc');
      expect(updated.startDate, '2026-12-10');
      expect(updated.endDate, '2026-12-14');
      expect(updated.companionType, 'family');
      expect(updated.budgetVnd, base.budgetVnd);
    });

    test('Preserves existing presets without breaking legacy schema', () {
      final minh = PlanTripRequest.presetMinh();
      expect(minh.origin, 'TP. Hồ Chí Minh');
      expect(minh.destinationId, isNull);
      expect(minh.destinationName, isNull);
      expect(minh.startDate, isNull);
      expect(minh.endDate, isNull);
      expect(minh.companionType, 'group');

      final json = minh.toJson();
      // Verify legacy JSON does not include null keys
      expect(json.containsKey('destinationId'), isFalse);
      expect(json.containsKey('destinationName'), isFalse);
      expect(json.containsKey('startDate'), isFalse);
      expect(json.containsKey('endDate'), isFalse);
      expect(json.containsKey('companionType'), isFalse);
    });

    test('TripPayloadCodec validates and roundtrips adaptive request fields', () {
      final req = PlanTripRequest(
        origin: 'Cần Thơ',
        numDays: 3,
        numPeople: 4,
        budgetVnd: 12000000,
        preferences: ['biển', 'nghỉ dưỡng'],
        priority: 'comfortable',
        destinationId: 'nha-trang',
        destinationName: 'Nha Trang',
        startDate: '2026-11-15',
        endDate: '2026-11-17',
        companionType: 'family',
      );

      final payload = CanonicalTripPayloadV1(
        metadata: TripMetadataV1(title: 'Nha Trang Gia Đình'),
        request: req,
      );

      final encoded = TripPayloadCodec.encode(payload);
      final decoded = TripPayloadCodec.decode(jsonDecode(encoded));

      expect(decoded.request!.destinationId, 'nha-trang');
      expect(decoded.request!.destinationName, 'Nha Trang');
      expect(decoded.request!.startDate, '2026-11-15');
      expect(decoded.request!.endDate, '2026-11-17');
      expect(decoded.request!.companionType, 'family');
    });
  });
}

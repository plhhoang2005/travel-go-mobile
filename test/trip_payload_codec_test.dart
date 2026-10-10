import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';

void main() {
  group('TripPayloadCodec - Full-field and Partial Roundtrip', () {
    test('Roundtrips complete CanonicalTripPayloadV1 with request and plan', () {
      final req = PlanTripRequest(
        origin: 'TP. Hồ Chí Minh',
        numDays: 3,
        numPeople: 2,
        budgetVnd: 5000000,
        preferences: ['biển', 'ẩm thực'],
        priority: 'balanced',
      );

      final plan = PlanTripResponse(
        winnerId: 'phu-quoc',
        topDestinations: [
          DestinationCard(
            id: 'phu-quoc',
            name: 'Phú Quốc',
            totalScore: 92.5,
            normalizedScores: {'weather': 0.9, 'cost': 0.85},
            scoreContributions: {'weather': 0.4, 'cost': 0.35},
            estimatedCostVnd: 4500000,
            weatherSource: 'OpenWeather',
            avgTempMax: 30.5,
            avgPrecipitation: 2.1,
            latitude: 10.2899,
            longitude: 103.9840,
            region: 'Kiên Giang',
          ),
        ],
        transportOptions: [
          TransportOption(
            mode: 'flight',
            displayName: 'Máy bay',
            priceTotalVnd: 2200000,
            durationHours: 1.0,
            comfortScore: 9,
            isParetoOptimal: true,
            tradeoffType: 'fastest',
            recommendationReason: 'Nhanh nhất cho chuyến đi 3 ngày',
          ),
          TransportOption(
            mode: 'ferry',
            displayName: 'Tàu cao tốc',
            priceTotalVnd: 800000,
            durationHours: 3.5,
            comfortScore: 6,
            isParetoOptimal: false,
            tradeoffType: 'cheapest',
            recommendationReason: 'Tiết kiệm chi phí',
          ),
        ],
        itineraryDays: [
          ItineraryDay(
            day: 1,
            title: 'Khám phá bãi Sao',
            activities: [
              Activity(
                time: '09:00',
                title: 'Tắm biển bãi Sao',
                costVnd: 200000,
                durationHours: 3.0,
              ),
            ],
          ),
        ],
        budgetBreakdown: BudgetBreakdown(
          transport: 2200000,
          accommodation: 1500000,
          food: 800000,
          attractions: 300000,
          remainingSafetyMargin: 200000,
        ),
        aiExplanation: 'Lộ trình tối ưu cho ngân sách và thời tiết.',
        dataSources: {'weather': 'Live API', 'flight': 'Cached Schedule'},
        assumptions: ['Thời tiết nắng ráo', 'Giá vé khứ hồi'],
      );

      final metadata = TripMetadataV1(
        title: 'Kỳ nghỉ Phú Quốc',
        destinationId: 'phu-quoc',
        destinationName: 'Phú Quốc',
        startDate: '2026-11-10',
        endDate: '2026-11-13',
        timezone: 'Asia/Ho_Chi_Minh',
      );

      final original = CanonicalTripPayloadV1(
        schemaVersion: 1,
        metadata: metadata,
        request: req,
        plan: plan,
      );

      final canonicalString = TripPayloadCodec.encode(original);
      final digest1 = TripPayloadCodec.computeDigest(original);

      final decoded = TripPayloadCodec.decode({
        'schemaVersion': 1,
        'metadata': metadata.toJson(),
        'request': req.toJson(),
        'plan': plan.toJson(),
      });

      expect(decoded.schemaVersion, 1);
      expect(decoded.metadata.title, 'Kỳ nghỉ Phú Quốc');
      expect(decoded.metadata.destinationName, 'Phú Quốc');
      expect(decoded.metadata.destinationId, 'phu-quoc');
      expect(decoded.metadata.startDate, '2026-11-10');
      expect(decoded.metadata.endDate, '2026-11-13');
      expect(decoded.metadata.timezone, 'Asia/Ho_Chi_Minh');

      expect(decoded.request!.origin, 'TP. Hồ Chí Minh');
      expect(decoded.request!.budgetVnd, 5000000);
      expect(decoded.request!.preferences, ['biển', 'ẩm thực']);

      expect(decoded.plan!.winnerId, 'phu-quoc');
      expect(decoded.plan!.topDestinations.first.name, 'Phú Quốc');
      expect(decoded.plan!.topDestinations.first.latitude, 10.2899);
      expect(decoded.plan!.topDestinations.first.longitude, 103.9840);
      expect(decoded.plan!.transportOptions[0].isParetoOptimal, isTrue);
      expect(decoded.plan!.transportOptions[1].isParetoOptimal, isFalse);
      expect(decoded.plan!.itineraryDays.first.activities.first.title, 'Tắm biển bãi Sao');
      expect(decoded.plan!.budgetBreakdown!.transport, 2200000);

      // Re-encode decoded object and verify digest matches
      final digest2 = TripPayloadCodec.computeDigest(decoded);
      expect(digest2, equals(digest1));
      expect(TripPayloadCodec.encode(decoded), equals(canonicalString));
    });

    test('Roundtrips input-only draft (plan == null, destinationName == null)', () {
      final req = PlanTripRequest(
        origin: 'Hà Nội',
        numDays: 4,
        numPeople: 1,
        budgetVnd: 3000000,
        preferences: ['núi'],
        priority: 'cheapest',
      );

      final metadata = TripMetadataV1(
        title: 'Chuyến đi miền Bắc',
        destinationId: null,
        destinationName: null,
        startDate: null,
        endDate: null,
        timezone: null,
      );

      final draft = CanonicalTripPayloadV1(
        schemaVersion: 1,
        metadata: metadata,
        request: req,
        plan: null,
      );

      final encoded = TripPayloadCodec.encode(draft);
      expect(encoded.contains('"plan":null'), isTrue);
      expect(encoded.contains('"destinationName":null'), isTrue);

      final digest = TripPayloadCodec.computeDigest(draft);
      expect(digest, isNotEmpty);

      final decoded = TripPayloadCodec.decode({
        'schemaVersion': 1,
        'metadata': metadata.toJson(),
        'request': req.toJson(),
        'plan': null,
      });

      expect(decoded.plan, isNull);
      expect(decoded.request!.origin, 'Hà Nội');
      expect(decoded.metadata.destinationName, isNull);
      expect(TripPayloadCodec.computeDigest(decoded), equals(digest));
    });

    test('Roundtrips plan with null budgetBreakdown and null coordinates', () {
      final plan = PlanTripResponse(
        winnerId: 'da-lat',
        topDestinations: [
          DestinationCard(
            id: 'da-lat',
            name: 'Đà Lạt',
            totalScore: 85.0,
            normalizedScores: {},
            scoreContributions: {},
            estimatedCostVnd: 3000000,
            weatherSource: 'Forecast',
            avgTempMax: 22.0,
            avgPrecipitation: 0.0,
            latitude: null,
            longitude: null,
            region: 'Lâm Đồng',
          ),
        ],
        transportOptions: [],
        itineraryDays: [],
        budgetBreakdown: null,
        aiExplanation: 'Giải thích ngắn',
        dataSources: {'mode': 'offline'},
        assumptions: [],
      );

      final payload = CanonicalTripPayloadV1(
        schemaVersion: 1,
        metadata: TripMetadataV1(title: 'Đà Lạt mộng mơ'),
        request: null,
        plan: plan,
      );

      final encoded = TripPayloadCodec.encode(payload);
      expect(encoded.contains('"budgetBreakdown":null'), isTrue);
      expect(encoded.contains('"latitude":null'), isTrue);

      final decoded = TripPayloadCodec.decode({
        'schemaVersion': 1,
        'metadata': payload.metadata.toJson(),
        'request': null,
        'plan': plan.toJson(),
      });

      expect(decoded.plan!.budgetBreakdown, isNull);
      expect(decoded.plan!.topDestinations.first.latitude, isNull);
    });
  });

  group('TripPayloadCodec - Digest Sensitivity and Context Independence', () {
    final baseReq = PlanTripRequest(
      origin: 'Đà Nẵng',
      numDays: 2,
      numPeople: 2,
      budgetVnd: 2500000,
      preferences: ['văn hóa'],
      priority: 'balanced',
    );

    test('Changing metadata changes the content digest', () {
      final p1 = CanonicalTripPayloadV1(
        schemaVersion: 1,
        metadata: TripMetadataV1(title: 'Hội An Tour', destinationName: 'Hội An'),
        request: baseReq,
      );

      final p2 = CanonicalTripPayloadV1(
        schemaVersion: 1,
        metadata: TripMetadataV1(title: 'Hội An Tour Đặc Biệt', destinationName: 'Hội An'),
        request: baseReq,
      );

      final p3 = CanonicalTripPayloadV1(
        schemaVersion: 1,
        metadata: TripMetadataV1(title: 'Hội An Tour', destinationName: 'Hội An', startDate: '2026-12-01'),
        request: baseReq,
      );

      final digest1 = TripPayloadCodec.computeDigest(p1);
      final digest2 = TripPayloadCodec.computeDigest(p2);
      final digest3 = TripPayloadCodec.computeDigest(p3);

      expect(digest1, isNot(equals(digest2)));
      expect(digest1, isNot(equals(digest3)));
    });

    test('External context changes do not alter content digest', () {
      final payload = CanonicalTripPayloadV1(
        schemaVersion: 1,
        metadata: TripMetadataV1(title: 'Huế di sản'),
        request: baseReq,
      );

      final digestA = TripPayloadCodec.computeDigest(payload);

      // Simulate external context (ownerId, sessionId, retryCount, draftId)
      // Since context is outside the content envelope, the digest of the payload is unchanged
      final contextA = {
        'ownerId': 'user-111',
        'sessionId': 'session-aaa',
        'fetchedAt': '2026-10-10T10:00:00Z',
        'retryCount': 0,
        'draftId': 'draft-uuid-1',
      };

      final contextB = {
        'ownerId': 'user-222',
        'sessionId': 'session-bbb',
        'fetchedAt': '2026-10-10T11:00:00Z',
        'retryCount': 3,
        'draftId': 'draft-uuid-2',
      };

      expect(contextA['ownerId'], isNot(equals(contextB['ownerId'])));
      expect(TripPayloadCodec.computeDigest(payload), equals(digestA));
    });

    test('Array order difference changes the digest', () {
      final req1 = PlanTripRequest(
        origin: 'Cần Thơ',
        numDays: 2,
        numPeople: 2,
        budgetVnd: 2000000,
        preferences: ['sông nước', 'chợ nổi'],
        priority: 'balanced',
      );

      final req2 = PlanTripRequest(
        origin: 'Cần Thơ',
        numDays: 2,
        numPeople: 2,
        budgetVnd: 2000000,
        preferences: ['chợ nổi', 'sông nước'],
        priority: 'balanced',
      );

      final p1 = CanonicalTripPayloadV1(metadata: TripMetadataV1(title: 'Miền Tây'), request: req1);
      final p2 = CanonicalTripPayloadV1(metadata: TripMetadataV1(title: 'Miền Tây'), request: req2);

      expect(TripPayloadCodec.computeDigest(p1), isNot(equals(TripPayloadCodec.computeDigest(p2))));
    });

    test('Map with shuffled keys produces identical canonical string and digest', () {
      final raw1 = <String, dynamic>{
        'schemaVersion': 1,
        'metadata': <String, dynamic>{
          'title': 'Chuyến đi',
          'destinationId': 'dest-1',
          'destinationName': 'Tên',
          'startDate': '2026-05-01',
          'endDate': '2026-05-03',
          'timezone': 'UTC',
        },
        'request': <String, dynamic>{
          'origin': 'Đà Nẵng',
          'numDays': 2,
          'numPeople': 2,
          'budgetVnd': 2500000,
          'preferences': ['văn hóa'],
          'priority': 'balanced',
        },
        'plan': null,
      };

      // Completely inverted key insertion order
      final raw2 = <String, dynamic>{
        'plan': null,
        'request': <String, dynamic>{
          'priority': 'balanced',
          'preferences': ['văn hóa'],
          'budgetVnd': 2500000,
          'numPeople': 2,
          'numDays': 2,
          'origin': 'Đà Nẵng',
        },
        'schemaVersion': 1,
        'metadata': <String, dynamic>{
          'timezone': 'UTC',
          'endDate': '2026-05-03',
          'startDate': '2026-05-01',
          'destinationName': 'Tên',
          'destinationId': 'dest-1',
          'title': 'Chuyến đi',
        },
      };

      // Inverted insertion order produces different raw JSON serialization
      expect(jsonEncode(raw1), isNot(equals(jsonEncode(raw2))));

      final p1 = TripPayloadCodec.decode(raw1);
      final p2 = TripPayloadCodec.decode(raw2);

      expect(TripPayloadCodec.encode(p1), equals(TripPayloadCodec.encode(p2)));
      expect(TripPayloadCodec.computeDigest(p1), equals(TripPayloadCodec.computeDigest(p2)));
    });
  });

  group('TripPayloadCodec - Unicode, Escapes, and UTF-16 Ordinal Ordering', () {
    test('Preserves composed vs decomposed Vietnamese without NFC normalization', () {
      // Composed 'ế' = U+1EBF
      final composed = 'Hu\u1EBF';
      // Decomposed 'e' + combining hat + combining acute = e + U+0302 + U+0301
      final decomposed = 'Hue\u0302\u0301';

      final pComposed = CanonicalTripPayloadV1(
        metadata: TripMetadataV1(title: composed),
        request: PlanTripRequest.presetMinh(),
      );

      final pDecomposed = CanonicalTripPayloadV1(
        metadata: TripMetadataV1(title: decomposed),
        request: PlanTripRequest.presetMinh(),
      );

      final digest1 = TripPayloadCodec.computeDigest(pComposed);
      final digest2 = TripPayloadCodec.computeDigest(pDecomposed);

      // Must be distinct because bytes are distinct and no implicit normalization is performed
      expect(digest1, isNot(equals(digest2)));
    });

    test('Orders keys by UTF-16 code-unit ordinal (competing BMP vs non-BMP nested keys)', () {
      // BMP Private Use Area '\uE000' (UTF-16 code unit 0xE000, UTF-8 bytes 0xEE 0x80 0x80)
      // non-BMP emoji '\u{1F600}' (UTF-16 code units 0xD83D 0xDE00, UTF-8 bytes 0xF0 0x9F 0x98 0x80)
      // In UTF-16 ordinal ordering: 0xD83D < 0xE000, so non-BMP '\u{1F600}' MUST precede BMP '\uE000'.
      // In UTF-8 byte ordering: 0xEE < 0xF0, so BMP '\uE000' would precede non-BMP '\u{1F600}'.
      final rawMap = <String, dynamic>{
        'schemaVersion': 1,
        'metadata': <String, dynamic>{
          'title': 'Test BMP vs Non-BMP',
          'destinationId': null,
          'destinationName': null,
          'startDate': null,
          'endDate': null,
          'timezone': null,
        },
        'request': null,
        'plan': <String, dynamic>{
          'winnerId': 'dest-1',
          'topDestinations': [
            <String, dynamic>{
              'id': 'dest-1',
              'name': 'Dest 1',
              'totalScore': 90.0,
              'normalizedScores': <String, dynamic>{
                '\uE000': 0.5,
                '\u{1F600}': 0.8,
              },
              'scoreContributions': <String, dynamic>{},
              'estimatedCostVnd': 1000000,
              'weatherSource': 'OpenWeather',
              'avgTempMax': 30.0,
              'avgPrecipitation': 0.0,
              'latitude': null,
              'longitude': null,
              'region': 'South',
            },
          ],
          'transportOptions': <dynamic>[],
          'itineraryDays': <dynamic>[],
          'budgetBreakdown': null,
          'aiExplanation': 'Explanation',
          'dataSources': <String, dynamic>{'api': 'live'},
          'assumptions': <dynamic>[],
        },
      };

      final payload = TripPayloadCodec.decode(rawMap);
      final encoded = TripPayloadCodec.encode(payload);

      // Verify that non-BMP '\u{1F600}' appears before BMP '\uE000' in canonical output
      final nonBmpIdx = encoded.indexOf('\u{1F600}');
      final bmpIdx = encoded.indexOf('\uE000');
      expect(nonBmpIdx, isNonNegative);
      expect(bmpIdx, isNonNegative);
      expect(nonBmpIdx < bmpIdx, isTrue);

      final digest = TripPayloadCodec.computeDigest(payload);
      expect(digest, isNotEmpty);
      expect(TripPayloadCodec.computeDigest(payload), equals(digest));
    });

    test('Properly escapes quotes, backslashes, and control characters', () {
      final p = CanonicalTripPayloadV1(
        metadata: TripMetadataV1(
          title: 'Line 1\nLine 2\t"Quoted" and \\backslash\\',
        ),
        request: PlanTripRequest.presetMinh(),
      );

      final encoded = TripPayloadCodec.encode(p);
      expect(encoded.contains(r'Line 1\nLine 2\t\"Quoted\" and \\backslash\\'), isTrue);
    });
  });

  group('TripPayloadCodec - Numeric Rules', () {
    test('Normalizes -0.0 to 0.0 for double values', () {
      final plan = PlanTripResponse(
        winnerId: 'test',
        topDestinations: [
          DestinationCard(
            id: 'test',
            name: 'Test',
            totalScore: -0.0,
            normalizedScores: {'score': -0.0},
            scoreContributions: {},
            estimatedCostVnd: 1000,
            weatherSource: '',
            avgTempMax: 0.0,
            avgPrecipitation: 0.0,
            region: '',
          ),
        ],
        transportOptions: [],
        itineraryDays: [],
        aiExplanation: '',
        dataSources: {},
        assumptions: [],
      );

      final payload = CanonicalTripPayloadV1(
        metadata: TripMetadataV1(title: 'Test Zero'),
        plan: plan,
      );

      final encoded = TripPayloadCodec.encode(payload);
      expect(encoded.contains('-0.0'), isFalse);
      expect(encoded.contains('0.0'), isTrue);
    });

    test('Rejects non-finite double values', () {
      final badPlan = PlanTripResponse(
        winnerId: 'test',
        topDestinations: [
          DestinationCard(
            id: 'test',
            name: 'Test',
            totalScore: double.nan,
            normalizedScores: {},
            scoreContributions: {},
            estimatedCostVnd: 1000,
            weatherSource: '',
            avgTempMax: 0.0,
            avgPrecipitation: 0.0,
            region: '',
          ),
        ],
        transportOptions: [],
        itineraryDays: [],
        aiExplanation: '',
        dataSources: {},
        assumptions: [],
      );

      expect(
        () => CanonicalTripPayloadV1(
          metadata: TripMetadataV1(title: 'Bad Nan'),
          plan: badPlan,
        ),
        throwsA(isA<CorruptPayloadException>()),
      );
    });
  });

  group('TripPayloadCodec - Strict Rejection and Validation', () {
    test('Rejects empty map', () {
      expect(
        () => TripPayloadCodec.decode({}),
        throwsA(isA<CorruptPayloadException>()),
      );
    });

    test('Rejects invalid schemaVersion values', () {
      final validMeta = {'title': 'T', 'destinationId': null, 'destinationName': null, 'startDate': null, 'endDate': null, 'timezone': null};
      final validReq = PlanTripRequest.presetMinh().toJson();

      // Null schemaVersion with envelope
      expect(
        () => TripPayloadCodec.decode({'schemaVersion': null, 'metadata': validMeta, 'request': validReq, 'plan': null}),
        throwsA(isA<InvalidSchemaVersionException>()),
      );

      // Zero schemaVersion
      expect(
        () => TripPayloadCodec.decode({'schemaVersion': 0, 'metadata': validMeta, 'request': validReq, 'plan': null}),
        throwsA(isA<InvalidSchemaVersionException>()),
      );

      // Negative schemaVersion
      expect(
        () => TripPayloadCodec.decode({'schemaVersion': -1, 'metadata': validMeta, 'request': validReq, 'plan': null}),
        throwsA(isA<InvalidSchemaVersionException>()),
      );

      // String schemaVersion
      expect(
        () => TripPayloadCodec.decode({'schemaVersion': '1', 'metadata': validMeta, 'request': validReq, 'plan': null}),
        throwsA(isA<InvalidSchemaVersionException>()),
      );

      // Double schemaVersion
      expect(
        () => TripPayloadCodec.decode({'schemaVersion': 1.0, 'metadata': validMeta, 'request': validReq, 'plan': null}),
        throwsA(isA<InvalidSchemaVersionException>()),
      );

      // Future schemaVersion
      expect(
        () => TripPayloadCodec.decode({'schemaVersion': 2, 'metadata': validMeta, 'request': validReq, 'plan': null}),
        throwsA(isA<UnsupportedSchemaVersionException>()),
      );
    });

    test('Rejects payload when both request and plan are null', () {
      expect(
        () => CanonicalTripPayloadV1(
          schemaVersion: 1,
          metadata: TripMetadataV1(title: 'Both null'),
          request: null,
          plan: null,
        ),
        throwsA(isA<EmptyPayloadContentException>()),
      );

      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': {'title': 'Both null', 'destinationId': null, 'destinationName': null, 'startDate': null, 'endDate': null, 'timezone': null},
          'request': null,
          'plan': null,
        }),
        throwsA(isA<EmptyPayloadContentException>()),
      );
    });

    test('Rejects unknown content envelope keys', () {
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': {'title': 'T', 'destinationId': null, 'destinationName': null, 'startDate': null, 'endDate': null, 'timezone': null},
          'request': PlanTripRequest.presetMinh().toJson(),
          'plan': null,
          'unknownExtraKey': 123,
        }),
        throwsA(isA<CorruptPayloadException>()),
      );
    });

    test('Rejects missing required content envelope keys', () {
      final validMeta = {'title': 'T', 'destinationId': null, 'destinationName': null, 'startDate': null, 'endDate': null, 'timezone': null};
      final validReq = PlanTripRequest.presetMinh().toJson();

      // Missing 'plan' key
      expect(
        () => TripPayloadCodec.decode({'schemaVersion': 1, 'metadata': validMeta, 'request': validReq}),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Missing 'request' key
      expect(
        () => TripPayloadCodec.decode({'schemaVersion': 1, 'metadata': validMeta, 'plan': null}),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Missing 'metadata' key
      expect(
        () => TripPayloadCodec.decode({'schemaVersion': 1, 'request': validReq, 'plan': null}),
        throwsA(isA<CorruptPayloadException>()),
      );
    });

    test('Rejects missing required metadata keys and non-string metadata values', () {
      final validReq = PlanTripRequest.presetMinh().toJson();

      // Empty metadata map
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': <String, dynamic>{},
          'request': validReq,
          'plan': null,
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Metadata missing 'timezone' key
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': {
            'title': 'T',
            'destinationId': null,
            'destinationName': null,
            'startDate': null,
            'endDate': null,
            // missing 'timezone'
          },
          'request': validReq,
          'plan': null,
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Non-string metadata field
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': {
            'title': 12345, // invalid type
            'destinationId': null,
            'destinationName': null,
            'startDate': null,
            'endDate': null,
            'timezone': null,
          },
          'request': validReq,
          'plan': null,
        }),
        throwsA(isA<CorruptPayloadException>()),
      );
    });

    test('Rejects unknown keys in request', () {
      final validMeta = {'title': 'T', 'destinationId': null, 'destinationName': null, 'startDate': null, 'endDate': null, 'timezone': null};
      final reqWithUnknown = {
        ...PlanTripRequest.presetMinh().toJson(),
        'unexpectedExtraField': 'malicious',
      };

      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': reqWithUnknown,
          'plan': null,
        }),
        throwsA(isA<CorruptPayloadException>()),
      );
    });

    test('Rejects invalid types and fractional money in request', () {
      final validMeta = {'title': 'T', 'destinationId': null, 'destinationName': null, 'startDate': null, 'endDate': null, 'timezone': null};

      // Fractional budgetVnd (double instead of integer)
      final reqFracBudget = {
        ...PlanTripRequest.presetMinh().toJson(),
        'budgetVnd': 2000000.5,
      };
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': reqFracBudget,
          'plan': null,
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Double numDays instead of integer
      final reqDoubleDays = {
        ...PlanTripRequest.presetMinh().toJson(),
        'numDays': 3.0,
      };
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': reqDoubleDays,
          'plan': null,
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Non-string element in preferences list
      final reqBadPref = {
        ...PlanTripRequest.presetMinh().toJson(),
        'preferences': ['biển', 999],
      };
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': reqBadPref,
          'plan': null,
        }),
        throwsA(isA<CorruptPayloadException>()),
      );
    });

    test('Rejects unknown keys in plan and plan components', () {
      final validMeta = {'title': 'T', 'destinationId': null, 'destinationName': null, 'startDate': null, 'endDate': null, 'timezone': null};

      // Unknown key in plan root
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': null,
          'plan': {
            'winnerId': 'd1',
            'topDestinations': [],
            'transportOptions': [],
            'itineraryDays': [],
            'budgetBreakdown': null,
            'aiExplanation': 'Ex',
            'dataSources': {'api': 'v1'},
            'assumptions': [],
            'unknownPlanRootField': 42,
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Unknown key in topDestinations item
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': null,
          'plan': {
            'winnerId': 'd1',
            'topDestinations': [
              {
                'id': 'd1',
                'name': 'D1',
                'totalScore': 80.0,
                'normalizedScores': {},
                'scoreContributions': {},
                'estimatedCostVnd': 1000000,
                'weatherSource': 'src',
                'avgTempMax': 30.0,
                'avgPrecipitation': 0.0,
                'latitude': null,
                'longitude': null,
                'region': 'r',
                'unknownDestField': true,
              }
            ],
            'transportOptions': [],
            'itineraryDays': [],
            'budgetBreakdown': null,
            'aiExplanation': 'Ex',
            'dataSources': {'api': 'v1'},
            'assumptions': [],
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Unknown key in transportOptions item
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': null,
          'plan': {
            'winnerId': 'd1',
            'topDestinations': [],
            'transportOptions': [
              {
                'mode': 'flight',
                'displayName': 'Máy bay',
                'priceTotalVnd': 2000000,
                'durationHours': 2.0,
                'comfortScore': 8,
                'paretoOptimal': true,
                'tradeoffType': 'fastest',
                'recommendationReason': 'quick',
                'unknownTransportField': 'bad',
              }
            ],
            'itineraryDays': [],
            'budgetBreakdown': null,
            'aiExplanation': 'Ex',
            'dataSources': {'api': 'v1'},
            'assumptions': [],
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Unknown key in itineraryDays item
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': null,
          'plan': {
            'winnerId': 'd1',
            'topDestinations': [],
            'transportOptions': [],
            'itineraryDays': [
              {
                'day': 1,
                'title': 'Ngày 1',
                'activities': [],
                'unknownDayField': 'extra',
              }
            ],
            'budgetBreakdown': null,
            'aiExplanation': 'Ex',
            'dataSources': {'api': 'v1'},
            'assumptions': [],
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Unknown key in activities item
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': null,
          'plan': {
            'winnerId': 'd1',
            'topDestinations': [],
            'transportOptions': [],
            'itineraryDays': [
              {
                'day': 1,
                'title': 'Ngày 1',
                'activities': [
                  {
                    'time': '09:00',
                    'title': 'Đi chơi',
                    'costVnd': 50000,
                    'durationHours': 1.5,
                    'unknownActivityField': 123,
                  }
                ],
              }
            ],
            'budgetBreakdown': null,
            'aiExplanation': 'Ex',
            'dataSources': {'api': 'v1'},
            'assumptions': [],
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Unknown key in budgetBreakdown
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': null,
          'plan': {
            'winnerId': 'd1',
            'topDestinations': [],
            'transportOptions': [],
            'itineraryDays': [],
            'budgetBreakdown': {
              'transport': 1000,
              'accommodation': 2000,
              'food': 500,
              'attractions': 300,
              'remainingSafetyMargin': 200,
              'unknownBudgetField': 999,
            },
            'aiExplanation': 'Ex',
            'dataSources': {'api': 'v1'},
            'assumptions': [],
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );
    });

    test('Rejects fractional currency and partial shapes in plan components', () {
      final validMeta = {'title': 'T', 'destinationId': null, 'destinationName': null, 'startDate': null, 'endDate': null, 'timezone': null};

      // Destination with fractional estimatedCostVnd
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': null,
          'plan': {
            'winnerId': 'd1',
            'topDestinations': [
              {
                'id': 'd1',
                'name': 'D1',
                'totalScore': 80.0,
                'normalizedScores': {},
                'scoreContributions': {},
                'estimatedCostVnd': 4500000.5, // fractional
                'weatherSource': 'src',
                'avgTempMax': 30.0,
                'avgPrecipitation': 0.0,
                'latitude': null,
                'longitude': null,
                'region': 'r',
              }
            ],
            'transportOptions': [],
            'itineraryDays': [],
            'budgetBreakdown': null,
            'aiExplanation': 'Ex',
            'dataSources': {'api': 'v1'},
            'assumptions': [],
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Transport with fractional priceTotalVnd
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': null,
          'plan': {
            'winnerId': 'd1',
            'topDestinations': [],
            'transportOptions': [
              {
                'mode': 'bus',
                'displayName': 'Xe',
                'priceTotalVnd': 250000.75, // fractional
                'durationHours': 4.0,
                'comfortScore': 6,
                'paretoOptimal': true,
                'tradeoffType': 'cheapest',
                'recommendationReason': 'reason',
              }
            ],
            'itineraryDays': [],
            'budgetBreakdown': null,
            'aiExplanation': 'Ex',
            'dataSources': {'api': 'v1'},
            'assumptions': [],
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Activity with fractional costVnd
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': null,
          'plan': {
            'winnerId': 'd1',
            'topDestinations': [],
            'transportOptions': [],
            'itineraryDays': [
              {
                'day': 1,
                'title': 'Ngày 1',
                'activities': [
                  {
                    'time': '10:00',
                    'title': 'Vé tham quan',
                    'costVnd': 150000.5, // fractional
                    'durationHours': 2.0,
                  }
                ],
              }
            ],
            'budgetBreakdown': null,
            'aiExplanation': 'Ex',
            'dataSources': {'api': 'v1'},
            'assumptions': [],
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // BudgetBreakdown with fractional transport
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': null,
          'plan': {
            'winnerId': 'd1',
            'topDestinations': [],
            'transportOptions': [],
            'itineraryDays': [],
            'budgetBreakdown': {
              'transport': 1200000.5, // fractional
              'accommodation': 1000000,
              'food': 500000,
              'attractions': 300000,
              'remainingSafetyMargin': 200000,
            },
            'aiExplanation': 'Ex',
            'dataSources': {'api': 'v1'},
            'assumptions': [],
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Partial itinerary day missing activities and title
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': validMeta,
          'request': null,
          'plan': {
            'winnerId': 'd1',
            'topDestinations': [],
            'transportOptions': [],
            'itineraryDays': [
              {
                'day': 1,
                // missing title and activities
              }
            ],
            'budgetBreakdown': null,
            'aiExplanation': 'Ex',
            'dataSources': {'api': 'v1'},
            'assumptions': [],
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );
    });

    test('Rejects missing required fields in request (no permissive fallback to preset)', () {
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': {'title': 'T', 'destinationId': null, 'destinationName': null, 'startDate': null, 'endDate': null, 'timezone': null},
          'request': {
            'origin': 'TP. Hồ Chí Minh',
            // missing numDays, numPeople, budgetVnd, preferences, priority
          },
          'plan': null,
        }),
        throwsA(isA<CorruptPayloadException>()),
      );
    });

    test('Rejects missing required fields in plan (no permissive empty plan)', () {
      expect(
        () => TripPayloadCodec.decode({
          'schemaVersion': 1,
          'metadata': {'title': 'T', 'destinationId': null, 'destinationName': null, 'startDate': null, 'endDate': null, 'timezone': null},
          'request': null,
          'plan': {
            'winnerId': 'dest-1',
            // missing topDestinations, transportOptions, itineraryDays...
          },
        }),
        throwsA(isA<CorruptPayloadException>()),
      );
    });

    test('Rejects strings with U+0000 or unpaired surrogates', () {
      expect(
        () => CanonicalTripPayloadV1(
          metadata: TripMetadataV1(title: 'Contains \u0000 null'),
          request: PlanTripRequest.presetMinh(),
        ),
        throwsA(isA<CorruptPayloadException>()),
      );

      // Unpaired high surrogate
      expect(
        () => TripMetadataV1(title: 'High \uD83D alone'),
        throwsA(isA<CorruptPayloadException>()),
      );
    });

    test('Validates real calendar dates and leap years strictly', () {
      // Leap year 2024-02-29 is valid
      expect(
        TripMetadataV1(title: 'T', startDate: '2024-02-29').startDate,
        '2024-02-29',
      );

      // Non-leap year 2026-02-29 is invalid
      expect(
        () => TripMetadataV1(title: 'T', startDate: '2026-02-29'),
        throwsA(isA<InvalidDateFormatException>()),
      );

      // Impossible date 2026-02-30 is invalid
      expect(
        () => TripMetadataV1(title: 'T', startDate: '2026-02-30'),
        throwsA(isA<InvalidDateFormatException>()),
      );

      // Invalid format
      expect(
        () => TripMetadataV1(title: 'T', startDate: '2026/05/01'),
        throwsA(isA<InvalidDateFormatException>()),
      );

      // endDate before startDate
      expect(
        () => TripMetadataV1(
          title: 'T',
          startDate: '2026-05-10',
          endDate: '2026-05-08',
        ),
        throwsA(isA<InvalidDateRangeException>()),
      );
    });
  });

  group('TripPayloadCodec - Fallback, Pareto, and Immutable Freeze', () {
    test('Preserves isFallback derived from dataSources', () {
      final offlinePlan = PlanTripResponse(
        winnerId: '1',
        topDestinations: [],
        transportOptions: [],
        itineraryDays: [],
        aiExplanation: '',
        dataSources: {'osm': 'Offline Fallback Cache'},
        assumptions: [],
      );
      expect(offlinePlan.isFallback, isTrue);

      final livePlan = PlanTripResponse(
        winnerId: '1',
        topDestinations: [],
        transportOptions: [],
        itineraryDays: [],
        aiExplanation: '',
        dataSources: {'osm': 'Online OpenStreetMap'},
        assumptions: [],
      );
      expect(livePlan.isFallback, isFalse);
    });

    test('TransportOption uses single canonical key paretoOptimal with false precedence', () {
      final opt = TransportOption(
        mode: 'bus',
        displayName: 'Xe khách',
        priceTotalVnd: 300000,
        durationHours: 6.0,
        comfortScore: 5,
        isParetoOptimal: false,
        tradeoffType: 'cheapest',
        recommendationReason: 'Rẻ',
      );

      final json = opt.toJson();
      expect(json.containsKey('paretoOptimal'), isTrue);
      expect(json.containsKey('isParetoOptimal'), isFalse);
      expect(json['paretoOptimal'], isFalse);

      // Reader prefers paretoOptimal over isParetoOptimal
      final fromWire = TransportOption.fromJson({
        'mode': 'bus',
        'displayName': 'Xe',
        'paretoOptimal': false,
        'isParetoOptimal': true, // legacy conflicted key
      });
      expect(fromWire.isParetoOptimal, isFalse);
    });

    test('Mutating collections before first encode and between encodes does not alter payload or digest', () {
      final prefs = <String>['ẩm thực', 'biển'];
      final req = PlanTripRequest(
        origin: 'TP. Hồ Chí Minh',
        numDays: 3,
        numPeople: 2,
        budgetVnd: 4000000,
        preferences: prefs,
        priority: 'balanced',
      );

      final normalized = <String, double>{'weather': 0.8};
      final contributions = <String, double>{'weather': 0.4};
      final activities = <Activity>[
        Activity(time: '08:00', title: 'Ăn sáng', costVnd: 50000, durationHours: 1.0),
      ];
      final days = <ItineraryDay>[
        ItineraryDay(day: 1, title: 'Ngày 1', activities: activities),
      ];
      final destinations = <DestinationCard>[
        DestinationCard(
          id: 'd1',
          name: 'D1',
          totalScore: 80.0,
          normalizedScores: normalized,
          scoreContributions: contributions,
          estimatedCostVnd: 1000000,
          weatherSource: 'src',
          avgTempMax: 28.0,
          avgPrecipitation: 0.0,
          latitude: null,
          longitude: null,
          region: 'South',
        ),
      ];
      final transports = <TransportOption>[
        TransportOption(
          mode: 'bus',
          displayName: 'Xe khách',
          priceTotalVnd: 200000,
          durationHours: 3.0,
          comfortScore: 5,
          isParetoOptimal: true,
          tradeoffType: 'cheapest',
          recommendationReason: 'r',
        ),
      ];
      final dataSources = <String, String>{'api': 'live'};
      final assumptions = <String>['nắng đẹp'];

      final plan = PlanTripResponse(
        winnerId: 'd1',
        topDestinations: destinations,
        transportOptions: transports,
        itineraryDays: days,
        budgetBreakdown: null,
        aiExplanation: 'Ex',
        dataSources: dataSources,
        assumptions: assumptions,
      );

      final payload = CanonicalTripPayloadV1(
        metadata: TripMetadataV1(title: 'Freeze Test'),
        request: req,
        plan: plan,
      );

      // Independent original-content expected baseline (not derived from mutated sources)
      const expectedPrefs = ['ẩm thực', 'biển'];
      const expectedNormalized = {'weather': 0.8};
      const expectedContributions = {'weather': 0.4};
      const expectedDataSources = {'api': 'live'};
      const expectedAssumptions = ['nắng đẹp'];

      // Mutate all external source collections BEFORE first encode (including days list)
      prefs.add('chợ đêm');
      normalized['cost'] = 0.5;
      contributions['cost'] = 0.3;
      activities.add(Activity(time: '12:00', title: 'Ăn trưa', costVnd: 60000, durationHours: 1.0));
      days.add(ItineraryDay(day: 2, title: 'Ngày 2', activities: []));
      destinations.add(DestinationCard(id: 'd2', name: 'D2', totalScore: 70.0, normalizedScores: {}, scoreContributions: {}, estimatedCostVnd: 500000, weatherSource: 's', avgTempMax: 25.0, avgPrecipitation: 0.0, region: 'r'));
      transports.add(TransportOption(mode: 'flight', displayName: 'Bay', priceTotalVnd: 1000000, durationHours: 1.0, comfortScore: 9, isParetoOptimal: false, tradeoffType: 'fastest', recommendationReason: 'f'));
      dataSources['new'] = 'extra';
      assumptions.add('giả định mới');

      // Assert BEFORE first encode: payload retained all original content and excluded all additions
      expect(payload.request!.preferences, equals(expectedPrefs));
      expect(payload.request!.preferences.length, 2);
      expect(payload.request!.preferences.contains('chợ đêm'), isFalse);

      expect(payload.plan!.topDestinations.length, 1);
      expect(payload.plan!.topDestinations.first.id, 'd1');
      expect(payload.plan!.topDestinations.first.normalizedScores, equals(expectedNormalized));
      expect(payload.plan!.topDestinations.first.scoreContributions, equals(expectedContributions));

      expect(payload.plan!.transportOptions.length, 1);
      expect(payload.plan!.transportOptions.first.mode, 'bus');

      expect(payload.plan!.itineraryDays.length, 1);
      expect(payload.plan!.itineraryDays.first.day, 1);
      expect(payload.plan!.itineraryDays.first.activities.length, 1);
      expect(payload.plan!.itineraryDays.first.activities.first.title, 'Ăn sáng');

      expect(payload.plan!.dataSources, equals(expectedDataSources));
      expect(payload.plan!.assumptions, equals(expectedAssumptions));

      // First encoding
      final digest1 = TripPayloadCodec.computeDigest(payload);

      // Mutate again BETWEEN first and second encode
      prefs.add('cà phê');
      activities.clear();
      days.clear();
      destinations.clear();
      transports.clear();
      normalized.clear();
      contributions.clear();
      dataSources.clear();
      assumptions.clear();

      // Second encoding
      final digest2 = TripPayloadCodec.computeDigest(payload);
      expect(digest2, equals(digest1));

      // Verify that internal collections inside payload are strictly unmodifiable
      expect(() => payload.request!.preferences.add('chợ nổi'), throwsUnsupportedError);
      expect(() => payload.plan!.topDestinations.first.normalizedScores['extra'] = 1.0, throwsUnsupportedError);
      expect(() => payload.plan!.topDestinations.first.scoreContributions['extra'] = 1.0, throwsUnsupportedError);
      expect(() => payload.plan!.itineraryDays.add(ItineraryDay(day: 9, title: '9', activities: [])), throwsUnsupportedError);
      expect(() => payload.plan!.itineraryDays.first.activities.add(Activity(time: 'x', title: 'x', costVnd: 0, durationHours: 0)), throwsUnsupportedError);
      expect(() => payload.plan!.dataSources['extra'] = 'val', throwsUnsupportedError);
      expect(() => payload.plan!.assumptions.add('extra'), throwsUnsupportedError);
    });
  });

  group('TripPayloadCodec - Legacy Context and Bare Plan Handling', () {
    test('decodeBareLegacyPlan extracts bare plan and keeps metadata null without fabricating dates', () {
      final barePlan = {
        'winnerId': 'nha-trang',
        'topDestinations': [],
        'transportOptions': [],
        'itineraryDays': [],
        'aiExplanation': 'Tóm tắt',
        'dataSources': {'api': 'live'},
        'assumptions': [],
      };

      final payload = TripPayloadCodec.decodeBareLegacyPlan(barePlan);
      expect(payload.schemaVersion, 1);
      expect(payload.plan!.winnerId, 'nha-trang');
      expect(payload.request, isNull);
      expect(payload.metadata.title, isNull);
      expect(payload.metadata.startDate, isNull);
      expect(payload.metadata.endDate, isNull);
    });

    test('decodeLegacyRow preserves original timestamps and numeric totals in LegacyTripRowContext', () {
      final legacyRow = {
        'id': 'trip-uuid-999',
        'user_id': 'user-auth-123',
        'title': 'Kỳ nghỉ Nha Trang',
        'destination_name': 'Nha Trang',
        'num_days': 3.5, // fractional legacy days preserved without truncation
        'budget_total': 6500000.5,
        'status': 'planning',
        'start_date': '2026-08-15T07:30:00.000Z',
        'end_date': '2026-08-19T18:00:00.000Z',
        'created_at': '2026-08-01T12:00:00.000Z',
        'ai_plan_data': {
          'winnerId': 'nha-trang',
          'topDestinations': [],
          'transportOptions': [],
          'itineraryDays': [],
          'aiExplanation': 'Nha Trang tuyệt đẹp',
          'dataSources': {},
          'assumptions': [],
        },
      };

      final result = TripPayloadCodec.decodeLegacyRow(legacyRow);

      expect(result.payload.metadata.title, 'Kỳ nghỉ Nha Trang');
      expect(result.payload.metadata.destinationName, 'Nha Trang');
      // Travel dates in metadata remain null because raw timestamp is not calendar date YYYY-MM-DD
      expect(result.payload.metadata.startDate, isNull);
      expect(result.payload.metadata.endDate, isNull);

      // Legacy context preserves exact raw timestamps and fractional totals
      expect(result.legacyContext.id, 'trip-uuid-999');
      expect(result.legacyContext.userId, 'user-auth-123');
      expect(result.legacyContext.numDays, 3.5);
      expect(result.legacyContext.budgetTotal, 6500000.5);
      expect(result.legacyContext.startDate, '2026-08-15T07:30:00.000Z');
      expect(result.legacyContext.endDate, '2026-08-19T18:00:00.000Z');
      expect(result.legacyContext.createdAt, '2026-08-01T12:00:00.000Z');
    });
  });

  group('TripPayloadCodec - Literal Golden Vectors (Hardcoded)', () {
    test('Golden Vector 1: matches literal canonical string and literal SHA-256 hash', () {
      const expectedCanonical =
          '{"metadata":{"destinationId":null,"destinationName":"Ha Noi","endDate":null,"startDate":null,"timezone":null,"title":"HN"},"plan":null,"request":{"budgetVnd":2000000,"numDays":2,"numPeople":1,"origin":"SG","preferences":["food"],"priority":"balanced"},"schemaVersion":1}';
      const expectedHash = '1a492d03942746d47ab927820b52ca8713b0a7f06d095616768915181fedb45e';

      final payload = CanonicalTripPayloadV1(
        schemaVersion: 1,
        metadata: TripMetadataV1(
          title: 'HN',
          destinationId: null,
          destinationName: 'Ha Noi',
          startDate: null,
          endDate: null,
          timezone: null,
        ),
        request: PlanTripRequest(
          origin: 'SG',
          numDays: 2,
          numPeople: 1,
          budgetVnd: 2000000,
          preferences: ['food'],
          priority: 'balanced',
        ),
        plan: null,
      );

      final actualCanonical = TripPayloadCodec.encode(payload);
      final actualHash = TripPayloadCodec.computeDigest(payload);

      expect(actualCanonical, equals(expectedCanonical));
      expect(actualHash, equals(expectedHash));
    });

    test('Golden Vector 2 (Vietnamese Unicode, escapes): matches literal canonical string and hash', () {
      const expectedCanonical =
          '{"metadata":{"destinationId":"phu-quoc","destinationName":"Phú Quốc","endDate":"2026-11-05","startDate":"2026-11-02","timezone":"Asia/Ho_Chi_Minh","title":"Chuyến đi \\"Phú Quốc\\"\\nnghỉ dưỡng"},"plan":null,"request":{"budgetVnd":4000000,"numDays":3,"numPeople":2,"origin":"TP. Hồ Chí Minh","preferences":["biển","ẩm thực"],"priority":"balanced"},"schemaVersion":1}';
      const expectedHash = 'bb4c57ff86e93638f9c79e1877e1db3fd79a0afba3ef73de36225c677bc56d98';

      final payload = CanonicalTripPayloadV1(
        schemaVersion: 1,
        metadata: TripMetadataV1(
          title: 'Chuyến đi "Phú Quốc"\nnghỉ dưỡng',
          destinationId: 'phu-quoc',
          destinationName: 'Phú Quốc',
          startDate: '2026-11-02',
          endDate: '2026-11-05',
          timezone: 'Asia/Ho_Chi_Minh',
        ),
        request: PlanTripRequest(
          origin: 'TP. Hồ Chí Minh',
          numDays: 3,
          numPeople: 2,
          budgetVnd: 4000000,
          preferences: ['biển', 'ẩm thực'],
          priority: 'balanced',
        ),
        plan: null,
      );

      final actualCanonical = TripPayloadCodec.encode(payload);
      final actualHash = TripPayloadCodec.computeDigest(payload);

      expect(actualCanonical, equals(expectedCanonical));
      expect(actualHash, equals(expectedHash));
    });

    test('Golden Vector 3 (Full Canonical Plan with competing Unicode keys, -0.0 normalization, exponent formatting 1e-7, and arrays): matches literal canonical string and hash', () {
      const expectedCanonical =
          '{"metadata":{"destinationId":"hn-1","destinationName":"Hà Nội","endDate":"2026-12-12","startDate":"2026-12-10","timezone":"Asia/Bangkok","title":"Chuyến đi Hà Nội"},"plan":{"aiExplanation":"Lộ trình tối ưu","assumptions":["Thời tiết khô ráo"],"budgetBreakdown":{"accommodation":600000,"attractions":100000,"food":300000,"remainingSafetyMargin":500000,"transport":1500000},"dataSources":{"osm":"v1"},"itineraryDays":[{"activities":[{"costVnd":0,"durationHours":2.0,"time":"08:30","title":"Dạo Hồ Gươm"}],"day":1,"title":"Phố cổ và Hồ Gươm"}],"topDestinations":[{"avgPrecipitation":0.0,"avgTempMax":22.5,"estimatedCostVnd":2500000,"id":"hn-1","latitude":21.0285,"longitude":105.8542,"name":"Hà Nội","normalizedScores":{"p-value":1e-7,"weather":0.85},"region":"Bắc Bộ","scoreContributions":{"😀":0.55,"":0.35},"totalScore":92.5,"weatherSource":"OpenWeather"}],"transportOptions":[{"comfortScore":9,"displayName":"Máy bay","durationHours":1.25,"mode":"flight","paretoOptimal":true,"priceTotalVnd":1500000,"recommendationReason":"Tiết kiệm thời gian","tradeoffType":"fastest"}],"winnerId":"hn-1"},"request":{"budgetVnd":3000000,"numDays":2,"numPeople":1,"origin":"Đà Nẵng","preferences":["di tích","ẩm thực"],"priority":"balanced"},"schemaVersion":1}';
      const expectedHash = '57298dc9ac9c1e5fe1bcb299c0fb942fc60b90b073da20a082a419b9d74d46d3';

      final payload = CanonicalTripPayloadV1(
        schemaVersion: 1,
        metadata: TripMetadataV1(
          title: 'Chuyến đi Hà Nội',
          destinationId: 'hn-1',
          destinationName: 'Hà Nội',
          startDate: '2026-12-10',
          endDate: '2026-12-12',
          timezone: 'Asia/Bangkok',
        ),
        request: PlanTripRequest(
          origin: 'Đà Nẵng',
          numDays: 2,
          numPeople: 1,
          budgetVnd: 3000000,
          preferences: ['di tích', 'ẩm thực'],
          priority: 'balanced',
        ),
        plan: PlanTripResponse(
          winnerId: 'hn-1',
          topDestinations: [
            DestinationCard(
              id: 'hn-1',
              name: 'Hà Nội',
              totalScore: 92.5,
              normalizedScores: {'p-value': 1e-7, 'weather': 0.85},
              scoreContributions: {'\uE000': 0.35, '\u{1F600}': 0.55},
              estimatedCostVnd: 2500000,
              weatherSource: 'OpenWeather',
              avgTempMax: 22.5,
              avgPrecipitation: -0.0, // Tests -0.0 normalization to 0.0
              latitude: 21.0285,
              longitude: 105.8542,
              region: 'Bắc Bộ',
            ),
          ],
          transportOptions: [
            TransportOption(
              mode: 'flight',
              displayName: 'Máy bay',
              priceTotalVnd: 1500000,
              durationHours: 1.25,
              comfortScore: 9,
              isParetoOptimal: true,
              tradeoffType: 'fastest',
              recommendationReason: 'Tiết kiệm thời gian',
            ),
          ],
          itineraryDays: [
            ItineraryDay(
              day: 1,
              title: 'Phố cổ và Hồ Gươm',
              activities: [
                Activity(
                  time: '08:30',
                  title: 'Dạo Hồ Gươm',
                  costVnd: 0,
                  durationHours: 2.0,
                ),
              ],
            ),
          ],
          budgetBreakdown: BudgetBreakdown(
            transport: 1500000,
            accommodation: 600000,
            food: 300000,
            attractions: 100000,
            remainingSafetyMargin: 500000,
          ),
          aiExplanation: 'Lộ trình tối ưu',
          dataSources: {'osm': 'v1'},
          assumptions: ['Thời tiết khô ráo'],
        ),
      );

      final actualCanonical = TripPayloadCodec.encode(payload);
      final actualHash = TripPayloadCodec.computeDigest(payload);

      expect(actualCanonical, equals(expectedCanonical));
      expect(actualHash, equals(expectedHash));
    });
  });

  group('TripPayloadCodec - SQLite FFI Host Driver Smoke', () {
    test('Real SQLite FFI host smoke: open/create/write/read/close/reopen/cleanup', () async {
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      final tempDir = Directory.systemTemp.createTempSync('travelgo_ffi_test_');
      final dbPath = '${tempDir.path}${Platform.pathSeparator}smoke.db';
      Database? db;

      Object? primaryError;
      StackTrace? primaryStack;
      try {
        db = await factory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute(
                'CREATE TABLE guest_drafts (id TEXT PRIMARY KEY, payload TEXT, digest TEXT)',
              );
            },
          ),
        );

        final validPayload = CanonicalTripPayloadV1(
          schemaVersion: 1,
          metadata: TripMetadataV1(
            title: 'SQLite Smoke Trip',
            destinationId: 'vung-tau',
            destinationName: 'Vũng Tàu',
            startDate: '2026-12-01',
            endDate: '2026-12-03',
            timezone: 'Asia/Ho_Chi_Minh',
          ),
          request: PlanTripRequest.presetMinh(),
          plan: null,
        );

        final actualCanonical = TripPayloadCodec.encode(validPayload);
        final actualDigest = TripPayloadCodec.computeDigest(validPayload);

        await db.insert('guest_drafts', {
          'id': 'draft-test-1',
          'payload': actualCanonical,
          'digest': actualDigest,
        });

        final query1 = await db.query(
          'guest_drafts',
          where: 'id = ?',
          whereArgs: ['draft-test-1'],
        );
        expect(query1.length, 1);
        expect(query1.first['digest'], actualDigest);

        await db.close();
        db = null;

        // Reopen database file to verify persistence across connection close
        db = await factory.openDatabase(dbPath);
        final query2 = await db.query(
          'guest_drafts',
          where: 'id = ?',
          whereArgs: ['draft-test-1'],
        );
        expect(query2.length, 1);
        expect(query2.first['payload'], actualCanonical);
        expect(query2.first['digest'], actualDigest);

        // Decode directly with TripPayloadCodec.decode and verify roundtrip equivalence
        final rawMap = jsonDecode(query2.first['payload'] as String) as Map<String, dynamic>;
        final decoded = TripPayloadCodec.decode(rawMap);
        expect(decoded.schemaVersion, 1);
        expect(decoded.metadata.title, 'SQLite Smoke Trip');
        expect(decoded.metadata.destinationName, 'Vũng Tàu');
        expect(decoded.request!.origin, PlanTripRequest.presetMinh().origin);
        expect(TripPayloadCodec.computeDigest(decoded), equals(actualDigest));

        await db.close();
        db = null;
      } catch (e, st) {
        primaryError = e;
        primaryStack = st;
      } finally {
        Object? closeError;
        StackTrace? closeStack;
        Object? deleteError;
        StackTrace? deleteStack;

        // Attempt close independently
        if (db != null && db.isOpen) {
          try {
            await db.close();
            db = null;
          } catch (e, st) {
            closeError = e;
            closeStack = st;
          }
        }

        // Attempt directory cleanup independently
        if (tempDir.existsSync()) {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (e, st) {
            deleteError = e;
            deleteStack = st;
          }
        }

        // When a primary error exists, explicitly report each cleanup error/stack
        // as secondary diagnostic information before rethrowing the primary error with its original stack
        if (primaryError != null) {
          if (closeError != null) {
            // ignore: avoid_print
            print('Secondary cleanup diagnostic - SQLite close failed: $closeError\n$closeStack');
          }
          if (deleteError != null) {
            // ignore: avoid_print
            print('Secondary cleanup diagnostic - Temp directory deletion failed: $deleteError\n$deleteStack');
          }
          Error.throwWithStackTrace(primaryError, primaryStack!);
        }

        // When no primary error exists, cleanup failure must still fail the test
        if (closeError != null) {
          Error.throwWithStackTrace(closeError, closeStack!);
        }
        if (deleteError != null) {
          Error.throwWithStackTrace(deleteError, deleteStack!);
        }
      }
    });
  });
}

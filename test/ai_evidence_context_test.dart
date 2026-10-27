import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/ai_evidence_context.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/services/budget_calculator.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';

import 'editable_local_store_test.dart' as fixture;

PublicCatalogueSnapshot snapshot() {
  final text = File('test/fixtures/catalogue_evidence_vectors.json')
      .readAsStringSync();
  final bytes = utf8.encode(text);
  return PublicCatalogueParser.parse(
    payloadText: text,
    manifest: DiscoveryManifest(
      contract: 'travelgo.discovery.manifest.v2',
      schemaVersion: 2,
      version: 7,
      objectKey: 'releases/v2/7.json',
      sha256: sha256.convert(bytes).toString(),
      byteLength: bytes.length,
      publishedAt: DateTime.utc(2026, 10, 27),
    ),
    now: DateTime.utc(2026, 10, 27),
    origin: 'storage',
  );
}

EditableTripDocumentV2 document() {
  final d = fixture.doc();
  return d.copyWith(
    input: TripInput.fromJson({
      ...d.input.toJson(),
      'destinationId': 'new-city',
      'destinationName': 'New City',
    }),
  );
}

void main() {
  test('context binds exact snapshot, document digest, budgets and excludes private notes', () {
    final d = document();
    final c = AiEvidenceContext.fromDocument(d, snapshot: snapshot());
    final json = c.toJson();
    final totals = BudgetCalculator.calculate(d);
    expect(json['catalogueVersion'], '7');
    expect(json['catalogueDigest'], snapshot().sha256);
    expect(json['baseDigest'], EditableTripCodec.digest(d));
    expect(
      (json['budget'] as Map)['estimateRemaining'],
      totals.estimateRemaining,
    );
    expect((json['budget'] as Map)['actualRemaining'], totals.actualRemaining);
    expect(
      (json['budget'] as Map)['unknownEstimateCount'],
      totals.unknownEstimateCount,
    );
    expect(json.containsKey('notes'), isFalse);
    expect(jsonEncode(json), isNot(contains('paidOn')));
    expect(
      () => (json['dates'] as List).add('2026-01-01'),
      throwsUnsupportedError,
    );
  });
  test('day scope and unknown dates preserve calendar identity without inventing today', () {
    final d = document();
    final c = AiEvidenceContext.fromDocument(
      d,
      snapshot: snapshot(),
      scope: 'day',
      selectedDay: 1,
    ).toJson();
    expect(c['selectedDay'], 1);
    expect((c['dayDates'] as List).single, {
      'day': 1,
      'date': d.days.single.date,
    });
    final unknown = d.copyWith(
      input: TripInput.fromJson({
        ...d.input.toJson(),
        'startDate': null,
        'endDate': null,
      }),
      days: [
        TripDay.fromJson({...d.days.single.toJson(), 'date': null}),
      ],
    );
    expect(
      AiEvidenceContext.fromDocument(
        unknown,
        snapshot: snapshot(),
      ).toJson()['dates'],
      isEmpty,
    );
    expect(
      () => AiEvidenceContext.fromDocument(
        d,
        snapshot: snapshot(),
        scope: 'day',
        selectedDay: 2,
      ),
      throwsFormatException,
    );
  });
  test('catalogue mismatch blocks context instead of silently using another destination', () {
    expect(
      () => AiEvidenceContext.fromDocument(fixture.doc(), snapshot: snapshot()),
      throwsFormatException,
    );
  });
  test('SQL A3 context export', () {
    const dir = String.fromEnvironment('A3_CONTEXT_EXPORT_DIR');
    if (dir.isEmpty) return;
    final d = document();
    final context = AiEvidenceContext.fromDocument(d, snapshot: snapshot());
    File('$dir/a3-document.json').writeAsStringSync(EditableTripCodec.encode(d));
    File('$dir/a3-request.json').writeAsStringSync(jsonEncode(context.request(
      intent: 'generate', requestId: 'a3000000-0000-4000-8000-000000000003')));
  });
}

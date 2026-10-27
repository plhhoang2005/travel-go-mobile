import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trip_planner/services/manual_trip_factory.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/services/legacy_trip_copy_adapter.dart';

String Function() ids() {
  var n = 100;
  return () => '00000000-0000-4000-8000-${(n++).toString().padLeft(12, '0')}';
}

CanonicalTripPayloadV1 source({
  String destination = 'hue',
  String time = '08:30',
  int cost = 100000,
  bool planOnly = false,
  int day = 1,
}) => CanonicalTripPayloadV1(
  metadata: TripMetadataV1(destinationId: destination, destinationName: 'Huế'),
  request: planOnly ? null : PlanTripRequest.presetMinh(),
  plan: PlanTripResponse(
    winnerId: destination,
    topDestinations: [],
    transportOptions: [],
    itineraryDays: [
      ItineraryDay(
        day: day,
        title: 'Ngày 1',
        activities: [
          Activity(
            time: time,
            title: 'Đại Nội',
            costVnd: cost,
            durationHours: 1.5,
          ),
        ],
      ),
    ],
    aiExplanation: '',
    dataSources: {'itinerary': 'offline fallback'},
    assumptions: [],
    budgetBreakdown: BudgetBreakdown(
      transport: 100000,
      accommodation: 100000,
      food: 100000,
      attractions: 100000,
      remainingSafetyMargin: 0,
    ),
  ),
);
void main() {
  test('hue_seed_keeps_inputs_without_fake_dates_or_service_dependencies', () {
    final doc = ManualTripFactory(newId: ids()).fromInput(
      PlanTripRequest.presetMinh(),
      TripMetadataV1(
        title: 'Huế cùng bạn',
        destinationId: 'hue',
        destinationName: 'Huế',
      ),
    );
    expect(doc.input.destinationId, 'hue');
    expect(doc.input.totalBudgetVnd, 4000000);
    expect(doc.input.origin, 'TP. Hồ Chí Minh');
    expect(doc.days.length, 3);
    expect(doc.days.every((d) => d.date == null), true);
    expect(doc.items, isEmpty);
    expect(
      EditableTripCodec.decode(EditableTripCodec.encode(doc)).input.title,
      'Huế cùng bạn',
    );
  });
  test(
    'copy_generates_new_ids_cost_is_estimate_not_actual_and_source_unchanged',
    () {
      final old = source();
      final digest = TripPayloadCodec.computeDigest(old);
      final adapter = LegacyTripCopyAdapter(newId: ids());
      final copy = adapter.preview(
        old,
        sourceDigest: digest,
        sourceTripId: '00000000-0000-4000-8000-000000000050',
      );
      final doc = copy.document!;
      expect(copy.needsDestination, false);
      expect(doc.items.single.startMinute, 510);
      expect(doc.items.single.endMinute, isNull);
      expect(doc.estimates.length, 1);
      expect(doc.estimates.single.unitAmountVnd, 100000);
      expect(doc.estimates.single.provenance.quality, 'estimated');
      expect(doc.actualExpenses, isEmpty);
      expect(doc.source.kind, 'manual_v1_copy');
      expect(TripPayloadCodec.computeDigest(old), digest);
      final second = adapter.preview(old, sourceDigest: digest).document!;
      expect(second.items.single.id, isNot(doc.items.single.id));
    },
  );
  test('invalid_legacy_time_kept_in_notes_and_ambiguous_zero_is_unknown', () {
    final old = source(time: 'Buổi sáng', cost: 0);
    final result = LegacyTripCopyAdapter(newId: ids())
        .preview(old, sourceDigest: TripPayloadCodec.computeDigest(old));
    expect(result.document!.items.single.startMinute, isNull);
    expect(result.document!.items.single.notes, contains('Buổi sáng'));
    expect(result.document!.estimates.single.unitAmountVnd, isNull);
    expect(result.document!.estimates.single.provenance.quality, 'unknown');
  });
  test('unmapped_destination_and_plan_only_require_explicit_input', () {
    final old = source(destination: 'vung-tau');
    final result = LegacyTripCopyAdapter(newId: ids())
        .preview(old, sourceDigest: TripPayloadCodec.computeDigest(old));
    expect(result.needsDestination, true);
    expect(result.document!.input.destinationId, isNull);
    final only = source(planOnly: true);
    final missing = LegacyTripCopyAdapter(newId: ids())
        .preview(only, sourceDigest: TripPayloadCodec.computeDigest(only));
    expect(missing.needsInput, true);
    expect(missing.document, isNull);
    final completed = LegacyTripCopyAdapter(newId: ids()).preview(
      only,
      sourceDigest: TripPayloadCodec.computeDigest(only),
      inputOverride: PlanTripRequest.presetMinh(),
    );
    expect(completed.document, isNotNull);
  });
  test('unmappable day never silently drops activities', () {
    final old = source(day: 8);
    final result = LegacyTripCopyAdapter(newId: ids())
        .preview(old, sourceDigest: TripPayloadCodec.computeDigest(old));
    expect(result.document, isNull);
    expect(result.issues.any((i) => i.code == 'legacy_day_out_of_range'), true);
  });
}

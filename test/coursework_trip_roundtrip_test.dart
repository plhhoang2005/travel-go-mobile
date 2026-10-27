// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_command.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/manual_trip_input_form.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/budget_calculator.dart';
import 'package:travelgo_mobile/features/trip_planner/services/editable_trip_validator.dart';
import 'package:travelgo_mobile/features/trip_planner/services/manual_trip_factory.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_repository.dart';

import 'editable_local_store_test.dart' as records;
import 'editable_trip_repository_test.dart' as repository;
import 'editable_trip_service_test.dart' as transport;

int _sequence = 20000;
String nextId() =>
    '00000000-0000-4000-8000-${(_sequence++).toString().padLeft(12, '0')}';

EditableTripDocumentV2 courseworkDocument({String? destinationId}) {
  final empty = ManualTripFactory(newId: nextId).fromInput(
    PlanTripRequest.presetMinh().copyWith(
      numDays: 2,
      numPeople: 2,
      budgetVnd: 1000000,
    ),
    TripMetadataV1(
      title: 'Kế hoạch Phú Yên',
      destinationId: destinationId,
      destinationName: destinationId == null ? 'Phú Yên' : 'Huế',
      startDate: '2026-11-24',
      endDate: '2026-11-25',
    ),
  );
  final provenance = FieldProvenance(
    quality: 'user_provided',
    sourceRefs: [],
    observedAt: null,
  );
  final item = TripItem(
    id: nextId(),
    dayId: empty.days.first.id,
    position: 0,
    title: 'Dạo biển',
    placeId: null,
    startMinute: 540,
    endMinute: 600,
    notes: 'Giữ ghi chú này',
    provenance: provenance,
  );
  EstimatedExpense estimate(String basis, int? amount) => EstimatedExpense(
    id: nextId(),
    itemId: basis == 'per_person' ? item.id : null,
    category: 'food',
    unitAmountVnd: amount,
    basis: basis,
    customQuantity: null,
    active: true,
    description: basis,
    provenance: provenance,
  );
  return empty.copyWith(
    items: [item],
    estimates: [estimate('per_person', 100000), estimate('trip_total', 50000)],
    actualExpenses: [
      ActualExpense(
        id: nextId(),
        itemId: item.id,
        amountVnd: 70000,
        category: 'food',
        paidOn: '2026-11-24',
        description: 'Đã thanh toán',
        sourceItemSnapshot: null,
        provenance: provenance,
      ),
    ],
  );
}

List<String> useCourseworkTransport(
  repository.Context ctx, {
  bool dropCreateAck = false,
}) {
  final calls = <String>[];
  var drop = dropCreateAck;
  ctx.remote.close();
  ctx.remote = transport.service(ctx.lifecycle, (request) async {
    final rpc = request.uri.path.split('/').last;
    calls.add(rpc);
    if (rpc == 'list_owned_trips_v2') {
      final head = ctx.server.latest;
      return transport.jsonReply({
        'items': head == null
            ? []
            : [
                {
                  ...transport.summary(),
                  'title': head.document.input.title,
                  'destinationName': head.document.input.destinationName,
                  'version': head.version,
                },
              ],
        'nextCursor': null,
      });
    }
    final result = await ctx.server.respond(request);
    if (drop && rpc == 'create_editable_trip_v2') {
      drop = false;
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return result;
  });
  ctx.repository = EditableTripRepository(
    store: ctx.disk.store,
    lifecycle: ctx.lifecycle,
    service: ctx.remote,
    newId: nextId,
  );
  return calls;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'self-entered destination survives factory and codec without invented ID',
    () {
      final doc = courseworkDocument();
      expect(doc.input.destinationId, isNull);
      expect(doc.input.destinationName, 'Phú Yên');
      expect(
        EditableTripCodec.decode(EditableTripCodec.encode(doc))
            .input
            .destinationName,
        'Phú Yên',
      );
    },
  );
  test('account validation accepts a named self-entered destination', () {
    final source = records.doc();
    final doc = source.copyWith(
      input: TripInput.fromJson({
        ...source.input.toJson(),
        'destinationId': null,
        'destinationName': 'Phú Yên',
      }),
    );
    expect(
      EditableTripValidator.validate(
        doc,
        mode: ValidationMode.accountSave,
      ).where((issue) => issue.isBlocking),
      isEmpty,
    );
  });
  test('C5 money vector keeps estimates and actuals separate', () {
    final totals = BudgetCalculator.calculate(
      courseworkDocument(destinationId: 'hue'),
    );
    expect(totals.knownEstimate, 250000);
    expect(totals.actualTotal, 70000);
    expect(totals.estimateRemaining, 750000);
    expect(totals.actualRemaining, 930000);
  });
  test('unknown prices and traveler changes never rewrite actual expenses', () {
    final doc = courseworkDocument(destinationId: 'hue');
    final unknown = EstimatedExpense.fromJson({
      ...doc.estimates.last.toJson(),
      'id': nextId(),
      'unitAmountVnd': null,
      'provenance': {
        'quality': 'unknown',
        'sourceRefs': <Object>[],
        'observedAt': null,
      },
    });
    final changed = doc.copyWith(
      input: TripInput.fromJson({...doc.input.toJson(), 'travelerCount': 3}),
      estimates: [...doc.estimates, unknown],
    );
    final totals = BudgetCalculator.calculate(changed);
    expect(totals.knownEstimate, 350000);
    expect(totals.unknownEstimateCount, 1);
    expect(totals.actualTotal, 70000);
    expect(
      changed.actualExpenses.single.toJson(),
      doc.actualExpenses.single.toJson(),
    );
  });
  test('blank, missing and oversized manual destination names cannot be account-saved', () {
    final doc = records.doc();
    for (final name in <String?>[null, '', '  ', 'a' * 181]) {
      final bad = doc.copyWith(
        input: TripInput.fromJson({
          ...doc.input.toJson(),
          'destinationId': null,
          'destinationName': name,
        }),
      );
      expect(
        EditableTripValidator.validate(
          bad,
          mode: ValidationMode.accountSave,
        ).any((issue) => issue.isBlocking),
        isTrue,
      );
    }
  });
  for (final destination in <String?>[null, 'hue']) {
    test(
      'account create/read/update/delete roundtrip for $destination',
      () async {
        await repository.run((ctx) async {
          await ctx.login();
          final calls = useCourseworkTransport(ctx);
          final planner = ManualPlannerProvider(
            repositoryLoader: () async => ctx.repository,
            lifecycle: ctx.lifecycle,
            newId: nextId,
          );
          try {
            final initial = courseworkDocument(destinationId: destination);
            planner.openNew(initial);
            planner.previewSave();
            planner.cancelPreview();
            expect(ctx.server.creates, 0);
            expect(
              EditableTripCodec.digest(planner.document!),
              EditableTripCodec.digest(initial),
            );
            expect(await planner.confirmSave(planner.previewSave()), isTrue);
            expect(
              (await ctx.repository.listOwned()).items.single.destinationName,
              initial.input.destinationName,
            );
            final view = await ctx.repository.readTrip(records.tripId);
            expect(view.head!.document.toJson(), initial.toJson());
            planner.openSaved(view);
            planner.dispatch(
              DayNotesCommand(initial.days.first.id, 'Ghi chú sau khi mở lại'),
            );
            planner.dispatch(RemoveItemCommand(initial.items.single.id));
            expect(planner.document!.actualExpenses.single.amountVnd, 70000);
            expect(
              planner.document!.actualExpenses.single.sourceItemSnapshot?.title,
              'Dạo biển',
            );
            expect(await planner.confirmSave(planner.previewSave()), isTrue);
            final reopened = await ctx.repository.readTrip(records.tripId);
            expect(reopened.head!.version, 2);
            expect(
              reopened.head!.document.input.destinationName,
              initial.input.destinationName,
            );
            expect(
              reopened.head!.document.days.first.notes,
              'Ghi chú sau khi mở lại',
            );
            expect(
              reopened.head!.document.actualExpenses.single.id,
              initial.actualExpenses.single.id,
            );
            expect(
              (await ctx.repository.deleteTrip(reopened.head!)).status.name,
              'deleted',
            );
            expect(
              (await ctx.repository.readTrip(records.tripId)).head,
              isNull,
            );
            expect(ctx.server.creates, 1);
            expect(ctx.server.updates, 1);
            expect(ctx.server.deletes, 1);
            expect(calls.every((rpc) => rpc.endsWith('_v2')), isTrue);
          } finally {
            planner.dispose();
          }
        });
      },
    );
  }
  test(
    'lost create ACK retries the frozen request without a second trip',
    () async {
      await repository.run((ctx) async {
        await ctx.login();
        final calls = useCourseworkTransport(ctx, dropCreateAck: true);
        final planner = ManualPlannerProvider(
          repositoryLoader: () async => ctx.repository,
          lifecycle: ctx.lifecycle,
          newId: nextId,
        );
        try {
          planner.openNew(courseworkDocument());
          expect(await planner.confirmSave(planner.previewSave()), isFalse);
          expect(planner.state, ManualPlannerState.uncertain);
          expect(planner.hasPendingSave, isTrue);
          expect(ctx.server.creates, 1);
          expect(await planner.retrySave(), isTrue);
          expect(ctx.server.creates, 1);
          expect(
            calls.where((rpc) => rpc == 'get_editable_mutation_v2'),
            isNotEmpty,
          );
          expect((await ctx.repository.listOwned()).items.length, 1);
        } finally {
          planner.dispose();
        }
      });
    },
  );
  if (const bool.fromEnvironment('COURSEWORK_EXPORT_SQL')) {
    test('SQL fixture export', () {
      final dir = Directory(
        const String.fromEnvironment('COURSEWORK_SQL_FIXTURE_DIR'),
      )..createSync(recursive: true);
      File('${dir.path}/document.json')
          .writeAsStringSync(EditableTripCodec.encode(courseworkDocument()));
    });
  }
  testWidgets(
    'product editor requires an account and preserves the guest draft',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          final planner = ManualPlannerProvider(
            repositoryLoader: () async => ctx.repository,
            lifecycle: ctx.lifecycle,
            newId: nextId,
          );
          try {
            final document = courseworkDocument();
            planner.openNew(document);
            await tester.pumpWidget(
              MaterialApp(
                home: ManualPlannerScreen(
                  planner: planner,
                  destinations: const [],
                  enableBudget: true,
                  accountSaveOnly: true,
                ),
              ),
            );
            final review = find.text('Xem lại trước khi lưu');
            await tester.scrollUntilVisible(review, 300);
            await tester.tap(review);
            await tester.pumpAndSettle();
            expect(
              find.text('Đăng nhập để lưu chuyến đi vào tài khoản.'),
              findsOneWidget,
            );
            expect(find.text('Lưu bản nháp trên máy'), findsNothing);
            expect(planner.document!.toJson(), document.toJson());
            expect(planner.state, ManualPlannerState.editing);
            expect(ctx.server.creates, 0);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            planner.dispose();
          }
        }),
      );
    },
  );
  for (final scenario in [
    (id: null, rename: true),
    (id: null, rename: false),
    (id: 'retired/phu-yen', rename: false),
  ]) {
    testWidgets('destination editor preserves name: $scenario', (tester) async {
      final source = records.doc();
      final initial = source.copyWith(
        input: TripInput.fromJson({
          ...source.input.toJson(),
          'destinationId': scenario.id,
          'destinationName': 'Phú Yên',
        }),
      );
      ManualTripInputResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<ManualTripInputResult>(
                        MaterialPageRoute(
                          builder: (_) => ManualTripInputForm(
                            initialDocument: initial,
                            destinations: const [],
                            newId: nextId,
                          ),
                        ),
                      );
                },
                child: const Text('Mở thông tin'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở thông tin'));
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('trip.destinationName'));
      if (scenario.id == null) {
        expect(name, findsOneWidget);
        expect(tester.widget<TextFormField>(name).controller!.text, 'Phú Yên');
      } else {
        expect(name, findsNothing);
        expect(find.text('Phú Yên'), findsWidgets);
      }
      if (scenario.rename) {
        await tester.enterText(name, 'Phú Yên mới');
      } else {
        final budget = find.byKey(const ValueKey('trip.budget'));
        await tester.ensureVisible(budget);
        await tester.enterText(budget, '2000000');
      }
      await tester.ensureVisible(find.text('Xem thay đổi'));
      await tester.tap(find.text('Xem thay đổi'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Áp dụng thay đổi'));
      await tester.tap(find.text('Áp dụng thay đổi'));
      await tester.pumpAndSettle();
      expect(result?.input.destinationId, scenario.id);
      expect(
        result?.input.destinationName,
        scenario.rename ? 'Phú Yên mới' : 'Phú Yên',
      );
      if (!scenario.rename) {
        expect(result?.input.totalBudgetVnd, 2000000);
      }
      expect(initial.input.destinationName, 'Phú Yên');
    });
  }
}

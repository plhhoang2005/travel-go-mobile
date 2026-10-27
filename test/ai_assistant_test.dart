import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart'
    as catalogue;
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/services/ai_assistant_service.dart';
import 'package:travelgo_mobile/features/trip_planner/services/ai_generation_service.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/services/editable_trip_mutator.dart';

import 'editable_local_store_test.dart' as records;

Map<String, Object?> assistantResult(
  String intent, {
  List<Object?> operations = const [],
  List<Object?> recommendations = const [],
  int numDays = 1,
}) => {
  'contract': 'travelgo.assistant.v1',
  'intent': intent,
  'destinationId': 'hue',
  'numDays': numDays,
  'selectedDay': 1,
  'summary': 'Tư vấn tham khảo',
  'recommendations': recommendations,
  'operations': operations,
  'warnings': <String>[],
  'model': 'gemini-3.5-flash-lite',
  'verification': 'unverified',
};
int assistantId = 700;
String nextAssistantId() =>
    '00000000-0000-4000-8000-${(assistantId++).toString().padLeft(12, '0')}';
void main() {
  test('ai_move_to_afternoon_reorders_without_overlap', () {
    final base = records.doc();
    final dayId = base.days.first.id;
    const idA = '00000000-0000-4000-8000-000000000a01';
    const idB = '00000000-0000-4000-8000-000000000b01';
    final before = base.copyWith(
      items: [
        TripItem(
          id: idA,
          dayId: dayId,
          position: 0,
          title: 'Hoạt động A',
          placeId: 'hue/citadel',
          startMinute: 540,
          endMinute: 600,
          notes: 'Notes A',
          provenance: FieldProvenance(
            quality: 'user_provided',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
        TripItem(
          id: idB,
          dayId: dayId,
          position: 1,
          title: 'Hoạt động B',
          placeId: 'hue/thien-mu',
          startMinute: 660,
          endMinute: 720,
          notes: 'Notes B',
          provenance: FieldProvenance(
            quality: 'user_provided',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
      ],
    );
    final context = AiAssistantContext.fromDocument(
      before,
      selectedDay: 1,
      places: const [
        catalogue.PlaceReference(
          id: 'hue/citadel',
          name: 'Đại Nội Huế',
          sourceId: 'src_citadel',
        ),
        catalogue.PlaceReference(
          id: 'hue/thien-mu',
          name: 'Chùa Thiên Mụ',
          sourceId: 'src_thien_mu',
        ),
      ],
    );
    final rawInput = EditableTripCodec.encode(before);

    final result = AiAssistantResult.fromJson(
      assistantResult(
        'modify',
        operations: [
          {
            'kind': 'edit',
            'itemId': idA,
            'title': 'Hoạt động A chiều',
            'placeId': 'hue/citadel',
            'startMinute': 780,
            'endMinute': 840,
          },
        ],
      ),
      context,
      'modify',
    );

    final prepared = prepareAiModification(
      before,
      result,
      context,
      nextAssistantId,
    );

    expect(prepared.canApply, isTrue);
    expect(prepared.issues.where((i) => i.isBlocking), isEmpty);
    expect(
      prepared.document.items.map((i) => i.id).toList(),
      [idB, idA],
    );
    final replayed = EditableTripMutator.apply(before, prepared.commands);
    expect(
      EditableTripCodec.canonicalJson(replayed.toJson()),
      EditableTripCodec.canonicalJson(prepared.document.toJson()),
    );
    expect(EditableTripCodec.encode(before), rawInput);
  });

  test('ai_insert_early_and_null_time_stable_order', () {
    final base = records.doc();
    final dayId = base.days.first.id;
    const idExisting = '00000000-0000-4000-8000-000000000e01';
    final before = base.copyWith(
      items: [
        TripItem(
          id: idExisting,
          dayId: dayId,
          position: 0,
          title: 'Hoạt động 09-10',
          placeId: 'hue/citadel',
          startMinute: 540,
          endMinute: 600,
          notes: 'Existing',
          provenance: FieldProvenance(
            quality: 'user_provided',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
      ],
    );
    final context = AiAssistantContext.fromDocument(
      before,
      selectedDay: 1,
      places: const [
        catalogue.PlaceReference(
          id: 'hue/citadel',
          name: 'Đại Nội Huế',
          sourceId: 'src_citadel',
        ),
        catalogue.PlaceReference(
          id: 'hue/market',
          name: 'Chợ Đông Ba',
          sourceId: 'src_market',
        ),
      ],
    );

    final result = AiAssistantResult.fromJson(
      assistantResult(
        'modify',
        operations: [
          {
            'kind': 'add',
            'title': 'Hoạt động sáng sớm',
            'placeId': 'hue/market',
            'category': 'attractions',
            'costVnd': 50000,
            'startMinute': 480,
            'endMinute': 540,
          },
          {
            'kind': 'add',
            'title': 'Hoạt động dạo tự do',
            'placeId': null,
            'category': 'attractions',
            'costVnd': 0,
            'startMinute': null,
            'endMinute': null,
          },
        ],
      ),
      context,
      'modify',
    );

    final prepared = prepareAiModification(
      before,
      result,
      context,
      nextAssistantId,
    );

    expect(prepared.canApply, isTrue);
    expect(prepared.issues.where((i) => i.isBlocking), isEmpty);
    final dayItems = prepared.document.items.where((i) => i.dayId == dayId).toList();
    expect(dayItems.length, 3);
    expect(dayItems[0].startMinute, 480);
    expect(dayItems[0].endMinute, 540);
    expect(dayItems[1].id, idExisting);
    expect(dayItems[1].startMinute, 540);
    expect(dayItems[2].startMinute, isNull);
    expect(dayItems[2].endMinute, isNull);

    final replayed = EditableTripMutator.apply(before, prepared.commands);
    expect(
      EditableTripCodec.canonicalJson(replayed.toJson()),
      EditableTripCodec.canonicalJson(prepared.document.toJson()),
    );
  });

  test('ai_batch_preserves_other_days_and_financial_ledger', () {
    final baseSingle = records.doc();
    const day2Id = '00000000-0000-4000-8000-0000000000d2';
    final base = baseSingle.copyWith(
      input: TripInput.fromJson({
        ...baseSingle.input.toJson(),
        'startDate': '2026-10-15',
        'endDate': '2026-10-16',
      }),
      days: [
        baseSingle.days.first,
        TripDay(id: day2Id, ordinal: 2, date: '2026-10-16', notes: 'Ghi chú ngày 2'),
      ],
    );
    expect(base.days.length, 2);
    final day1 = base.days[0];
    final day2 = base.days[1];

    const idD1A = '00000000-0000-4000-8000-000000000101';
    const idD1B = '00000000-0000-4000-8000-000000000102';
    const idD2 = '00000000-0000-4000-8000-000000000201';
    const idActual = '00000000-0000-4000-8000-000000000999';

    final before = base.copyWith(
      items: [
        TripItem(
          id: idD1A,
          dayId: day1.id,
          position: 0,
          title: 'Ngày 1 - A',
          placeId: 'hue/citadel',
          startMinute: 540,
          endMinute: 600,
          notes: 'Notes D1A',
          provenance: FieldProvenance(
            quality: 'user_provided',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
        TripItem(
          id: idD1B,
          dayId: day1.id,
          position: 1,
          title: 'Ngày 1 - B',
          placeId: 'hue/thien-mu',
          startMinute: 660,
          endMinute: 720,
          notes: 'Notes D1B',
          provenance: FieldProvenance(
            quality: 'user_provided',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
        TripItem(
          id: idD2,
          dayId: day2.id,
          position: 0,
          title: 'Ngày 2 - Giữ nguyên',
          placeId: 'hue/tombs',
          startMinute: 500,
          endMinute: 600,
          notes: 'Notes Day 2',
          provenance: FieldProvenance(
            quality: 'user_provided',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
      ],
      actualExpenses: [
        ActualExpense(
          id: idActual,
          itemId: idD1A,
          amountVnd: 120000,
          category: 'attractions',
          paidOn: '2026-10-15',
          description: 'Vé tham quan đã mua',
          sourceItemSnapshot: null,
          provenance: FieldProvenance(
            quality: 'user_provided',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
      ],
    );

    final context = AiAssistantContext.fromDocument(
      before,
      selectedDay: 1,
      places: const [
        catalogue.PlaceReference(
          id: 'hue/citadel',
          name: 'Đại Nội Huế',
          sourceId: 'src_citadel',
        ),
        catalogue.PlaceReference(
          id: 'hue/thien-mu',
          name: 'Chùa Thiên Mụ',
          sourceId: 'src_thien_mu',
        ),
        catalogue.PlaceReference(
          id: 'hue/perfume-river',
          name: 'Sông Hương',
          sourceId: 'src_perfume_river',
        ),
      ],
    );
    final rawInput = EditableTripCodec.encode(before);

    final result = AiAssistantResult.fromJson(
      assistantResult(
        'modify',
        numDays: 2,
        operations: [
          {'kind': 'remove', 'itemId': idD1A},
          {
            'kind': 'edit',
            'itemId': idD1B,
            'title': 'Ngày 1 - B Chiều',
            'placeId': 'hue/thien-mu',
            'startMinute': 840,
            'endMinute': 900,
          },
          {
            'kind': 'add',
            'title': 'Ngày 1 - Hoạt động mới sáng',
            'placeId': 'hue/perfume-river',
            'category': 'attractions',
            'costVnd': 30000,
            'startMinute': 540,
            'endMinute': 600,
          },
        ],
      ),
      context,
      'modify',
    );

    final prepared = prepareAiModification(
      before,
      result,
      context,
      nextAssistantId,
    );

    expect(prepared.canApply, isTrue);
    final day2Items = prepared.document.items.where((i) => i.dayId == day2.id).toList();
    expect(day2Items.length, 1);
    expect(day2Items.first.id, idD2);
    expect(day2Items.first.title, 'Ngày 2 - Giữ nguyên');
    expect(day2Items.first.startMinute, 500);

    expect(prepared.document.actualExpenses.length, 1);
    expect(prepared.document.actualExpenses.first.id, idActual);
    expect(prepared.document.actualExpenses.first.amountVnd, 120000);
    expect(prepared.document.actualExpenses.first.description, 'Vé tham quan đã mua');

    final day1Items = prepared.document.items.where((i) => i.dayId == day1.id).toList();
    expect(day1Items.length, 2);
    expect(day1Items[0].startMinute, 540);
    expect(day1Items[1].id, idD1B);
    expect(day1Items[1].startMinute, 840);

    final replayed = EditableTripMutator.apply(before, prepared.commands);
    expect(
      EditableTripCodec.canonicalJson(replayed.toJson()),
      EditableTripCodec.canonicalJson(prepared.document.toJson()),
    );
    expect(EditableTripCodec.encode(before), rawInput);
  });

  test('ai_activity_identity_change_requires_estimate_review', () {
    final base = assistantDoc();
    final item = base.items.first;
    const estId = '00000000-0000-4000-8000-000000000e99';
    final beforeWithEstimate = base.copyWith(
      estimates: [
        EstimatedExpense(
          id: estId,
          itemId: item.id,
          category: 'attractions',
          unitAmountVnd: 100000,
          basis: 'trip_total',
          customQuantity: null,
          active: true,
          description: 'Vé tham quan ban đầu',
          provenance: FieldProvenance(
            quality: 'estimated',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
      ],
    );
    final context = AiAssistantContext.fromDocument(
      beforeWithEstimate,
      selectedDay: 1,
      places: const [
        catalogue.PlaceReference(
          id: 'hue/citadel',
          name: 'Đại Nội Huế',
          sourceId: 'src_citadel',
        ),
        catalogue.PlaceReference(
          id: 'hue/thien-mu',
          name: 'Chùa Thiên Mụ',
          sourceId: 'src_thien_mu',
        ),
      ],
    );

    // Ca 1: Đổi tên khác hẳn -> requiresEstimateReview = true
    final resTitleChange = AiAssistantResult.fromJson(
      assistantResult(
        'modify',
        operations: [
          {
            'kind': 'edit',
            'itemId': item.id,
            'title': 'Bữa tối ẩm thực Huế',
            'placeId': item.placeId,
            'startMinute': item.startMinute,
            'endMinute': item.endMinute,
          },
        ],
      ),
      context,
      'modify',
    );
    final prepTitleChange = prepareAiModification(
      beforeWithEstimate,
      resTitleChange,
      context,
      nextAssistantId,
    );
    expect(prepTitleChange.requiresEstimateReview, isTrue);
    expect(prepTitleChange.estimateReviewItemIds, [item.id]);

    // Ca 2: Đổi địa điểm -> requiresEstimateReview = true
    final resPlaceChange = AiAssistantResult.fromJson(
      assistantResult(
        'modify',
        operations: [
          {
            'kind': 'edit',
            'itemId': item.id,
            'title': item.title,
            'placeId': 'hue/thien-mu',
            'startMinute': item.startMinute,
            'endMinute': item.endMinute,
          },
        ],
      ),
      context,
      'modify',
    );
    final prepPlaceChange = prepareAiModification(
      beforeWithEstimate,
      resPlaceChange,
      context,
      nextAssistantId,
    );
    expect(prepPlaceChange.requiresEstimateReview, isTrue);

    // Ca 3: Chỉ đổi giờ -> requiresEstimateReview = false
    final resTimeOnly = AiAssistantResult.fromJson(
      assistantResult(
        'modify',
        operations: [
          {
            'kind': 'edit',
            'itemId': item.id,
            'title': item.title,
            'placeId': item.placeId,
            'startMinute': 720,
            'endMinute': 780,
          },
        ],
      ),
      context,
      'modify',
    );
    final prepTimeOnly = prepareAiModification(
      beforeWithEstimate,
      resTimeOnly,
      context,
      nextAssistantId,
    );
    expect(prepTimeOnly.requiresEstimateReview, isFalse);

    // Ca 4: Tên chỉ đổi whitespace/case -> requiresEstimateReview = false
    final resCaseOnly = AiAssistantResult.fromJson(
      assistantResult(
        'modify',
        operations: [
          {
            'kind': 'edit',
            'itemId': item.id,
            'title': '  ${item.title.toUpperCase()}  '.trim(),
            'placeId': item.placeId,
            'startMinute': item.startMinute,
            'endMinute': item.endMinute,
          },
        ],
      ),
      context,
      'modify',
    );
    final prepCaseOnly = prepareAiModification(
      beforeWithEstimate,
      resCaseOnly,
      context,
      nextAssistantId,
    );
    expect(prepCaseOnly.requiresEstimateReview, isFalse);

    // Ca 5: Estimate bị inactive -> requiresEstimateReview = false
    final beforeInactive = beforeWithEstimate.copyWith(
      estimates: [
        EstimatedExpense.fromJson({
          ...beforeWithEstimate.estimates.first.toJson(),
          'active': false,
        }),
      ],
    );
    final contextInactive = AiAssistantContext.fromDocument(
      beforeInactive,
      selectedDay: 1,
      places: const [
        catalogue.PlaceReference(
          id: 'hue/citadel',
          name: 'Đại Nội Huế',
          sourceId: 'src_citadel',
        ),
      ],
    );
    final prepInactive = prepareAiModification(
      beforeInactive,
      resTitleChange,
      contextInactive,
      nextAssistantId,
    );
    expect(prepInactive.requiresEstimateReview, isFalse);
  });

  testWidgets(
    'ai_estimate_review_ack_gates_apply_but_not_cancel',
    (tester) async {
      final base = assistantDoc();
      final item = base.items.first;
      final docWithEstimate = base.copyWith(
        estimates: [
          EstimatedExpense(
            id: '00000000-0000-4000-8000-000000000e99',
            itemId: item.id,
            category: 'attractions',
            unitAmountVnd: 100000,
            basis: 'trip_total',
            customQuantity: null,
            active: true,
            description: 'Vé tham quan',
            provenance: FieldProvenance(
              quality: 'estimated',
              sourceRefs: [],
              observedAt: null,
            ),
          ),
        ],
      );
      final planner = assistantPlanner()..openNew(docWithEstimate);
      final auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);

      final context = AiAssistantContext.fromDocument(
        docWithEstimate,
        selectedDay: 1,
        places: const [
          catalogue.PlaceReference(
            id: 'hue/citadel',
            name: 'Đại Nội Huế',
            sourceId: 'src_citadel',
          ),
        ],
      );
      final result = AiAssistantResult.fromJson(
        assistantResult(
          'modify',
          operations: [
            {
              'kind': 'edit',
              'itemId': item.id,
              'title': 'Ăn tối nhà hàng Cung Đình',
              'placeId': item.placeId,
              'startMinute': item.startMinute,
              'endMinute': item.endMinute,
            },
          ],
        ),
        context,
        'modify',
      );
      final modification = prepareAiModification(
        docWithEstimate,
        result,
        context,
        nextAssistantId,
      );

      await tester.pumpWidget(
        assistantApp(
          planner,
          auth,
          (intent, prompt, history, id) async => AiAssistantReply(result, modification),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-open')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('ai-assistant-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đề xuất chỉnh lịch').last);
      await tester.pumpAndSettle();

      await sendAssistant(tester, 'Đổi tham quan thành ăn tối');

      final ackFinder = find.byKey(const ValueKey('ai-assistant-estimate-review-ack'));
      await tester.ensureVisible(ackFinder);
      expect(ackFinder, findsOneWidget);

      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('ai-assistant-apply')))
            .onPressed,
        isNull,
      );

      await tester.tap(ackFinder);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('ai-assistant-apply')))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const ValueKey('ai-assistant-cancel')));
      await tester.pumpAndSettle();
      expect(planner.document?.items.first.title, item.title);
    },
  );

  testWidgets(
    'ai_estimate_ack_cannot_leak_between_previews',
    (tester) async {
      final base = assistantDoc();
      final item = base.items.first;
      final docWithEstimate = base.copyWith(
        estimates: [
          EstimatedExpense(
            id: '00000000-0000-4000-8000-000000000e99',
            itemId: item.id,
            category: 'attractions',
            unitAmountVnd: 100000,
            basis: 'trip_total',
            customQuantity: null,
            active: true,
            description: 'Vé tham quan',
            provenance: FieldProvenance(
              quality: 'estimated',
              sourceRefs: [],
              observedAt: null,
            ),
          ),
        ],
      );
      final planner = assistantPlanner()..openNew(docWithEstimate);
      final auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);

      final context = AiAssistantContext.fromDocument(
        docWithEstimate,
        selectedDay: 1,
        places: const [
          catalogue.PlaceReference(
            id: 'hue/citadel',
            name: 'Đại Nội Huế',
            sourceId: 'src_citadel',
          ),
        ],
      );
      final result = AiAssistantResult.fromJson(
        assistantResult(
          'modify',
          operations: [
            {
              'kind': 'edit',
              'itemId': item.id,
              'title': 'Ăn tối nhà hàng Cung Đình',
              'placeId': item.placeId,
              'startMinute': item.startMinute,
              'endMinute': item.endMinute,
            },
          ],
        ),
        context,
        'modify',
      );
      final modification = prepareAiModification(
        docWithEstimate,
        result,
        context,
        nextAssistantId,
      );

      await tester.pumpWidget(
        assistantApp(
          planner,
          auth,
          (intent, prompt, history, id) async => AiAssistantReply(result, modification),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-open')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('ai-assistant-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đề xuất chỉnh lịch').last);
      await tester.pumpAndSettle();

      await sendAssistant(tester, 'Đổi tham quan thành ăn tối');

      final ackFinder = find.byKey(const ValueKey('ai-assistant-estimate-review-ack'));
      await tester.ensureVisible(ackFinder);
      await tester.tap(ackFinder);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('ai-assistant-apply')))
            .onPressed,
        isNotNull,
      );

      // Đóng preview A
      await tester.tap(find.byKey(const ValueKey('ai-assistant-cancel')));
      await tester.pumpAndSettle();

      // Mở lại preview mới: ACK cũ không được rò rỉ sang phiên mới
      await tester.tap(find.byKey(const ValueKey('ai-assistant-open')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ai-assistant-estimate-review-ack')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('ai-assistant-cancel')));
      await tester.pumpAndSettle();
    },
  );
  test('multiline question/history/answer stay usable without allowing control characters', () {
    final context = AiAssistantContext.fromDocument(
      assistantDoc(),
      selectedDay: 1,
    );
    final request = assistantRequest(
      context,
      'advice',
      'Ngày này\nnên chuẩn bị gì?',
      [
        {'role': 'user', 'text': 'Câu hỏi\ntrước đó'},
        {'role': 'model', 'text': 'Phần một\nPhần hai'},
      ],
      nextAssistantId(),
    );
    expect(request['prompt'], 'Ngày này\nnên chuẩn bị gì?');
    expect(
      AiAssistantResult.fromJson(
        {...assistantResult('advice'), 'summary': 'Mục một\nMục hai'},
        context,
        'advice',
      ).summary,
      'Mục một\nMục hai',
    );
    expect(
      () => assistantRequest(
        context,
        'advice',
        'Nội dung\u0001không hợp lệ',
        const [],
        nextAssistantId(),
      ),
      throwsFormatException,
    );
  });
  testWidgets(
    'recommendations show reason/unknown quality without an apply action or draft mutation',
    (tester) async {
      final planner = assistantPlanner(),
          auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);
      final before = EditableTripCodec.encode(planner.document!),
          context = AiAssistantContext.fromDocument(
            planner.document!,
            selectedDay: 1,
          );
      await tester.pumpWidget(
        assistantApp(planner, auth, (intent, prompt, history, id) async {
          expect(intent, 'recommendations');
          expect(prompt, isNotEmpty);
          return AiAssistantReply(
            AiAssistantResult.fromJson(
              assistantResult(
                'recommendations',
                recommendations: [
                  {
                    'title': 'Hoạt động văn hóa',
                    'reason': 'Phù hợp sở thích; cần kiểm tra giờ mở cửa.',
                    'placeId': null,
                  },
                ],
              ),
              context,
              'recommendations',
            ),
          );
        }),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-open')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-assistant-mode')),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gợi ý hoạt động').last);
      await tester.pumpAndSettle();
      await sendAssistant(tester, '');
      expect(find.textContaining('Phù hợp sở thích'), findsOneWidget);
      expect(find.textContaining('Địa điểm chưa xác minh.'), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-assistant-apply')), findsNothing);
      expect(EditableTripCodec.encode(planner.document!), before);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'chat sends only after consent; next question includes bounded RAM history and never mutates draft',
    (tester) async {
      final planner = assistantPlanner(),
          auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);
      final before = EditableTripCodec.encode(planner.document!),
          ids = <String>[],
          histories = <List<Map<String, Object?>>>[];
      final context = AiAssistantContext.fromDocument(
        planner.document!,
        selectedDay: 1,
      );
      await tester.pumpWidget(
        assistantApp(planner, auth, (intent, prompt, history, id) async {
          ids.add(id);
          histories.add(history);
          expect(
            jsonEncode(assistantRequest(context, intent, prompt, history, id)),
            isNot(contains('PRIVATE_NOTE_NOT_SENT')),
          );
          return AiAssistantReply(
            AiAssistantResult.fromJson(
              assistantResult('advice'),
              context,
              'advice',
            ),
          );
        }),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-open')));
      await tester.pumpAndSettle();
      expect(ids, isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('ai-assistant-send')),
            )
            .onPressed,
        isNull,
      );
      await sendAssistant(tester, 'Ngày này cần chuẩn bị gì?');
      expect(ids, hasLength(1));
      expect(histories.single, isEmpty);
      expect(EditableTripCodec.encode(planner.document!), before);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('ai-assistant-consent')),
            )
            .value,
        false,
      );
      await sendAssistant(tester, 'Còn cách nào khác không?');
      expect(ids, hasLength(2));
      expect(ids[1], isNot(ids[0]));
      expect(histories.last, hasLength(2));
      expect(histories.last.first['role'], 'user');
      expect(histories.last.first['text'], 'Ngày này cần chuẩn bị gì?');
      expect(EditableTripCodec.encode(planner.document!), before);
      expect(planner.hasPendingSave, false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'modify shows before/after then applies exactly once, keeping linked actual and never saving automatically',
    (tester) async {
      final planner = assistantPlanner(),
          auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);
      final original = planner.document!,
          context = AiAssistantContext.fromDocument(
            planner.document!,
            selectedDay: 1,
          );
      final result = AiAssistantResult.fromJson(
        assistantResult(
          'modify',
          operations: [
            {'kind': 'remove', 'itemId': original.items.first.id},
          ],
        ),
        context,
        'modify',
      );
      await tester.pumpWidget(
        assistantApp(
          planner,
          auth,
          (intent, prompt, history, id) async => AiAssistantReply(
            result,
            prepareAiModification(original, result, context, nextAssistantId),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-open')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-assistant-mode')),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đề xuất chỉnh lịch').last);
      await tester.pumpAndSettle();
      await sendAssistant(tester, 'Xóa hoạt động này nhưng giữ khoản đã chi');
      expect(
        EditableTripCodec.encode(planner.document!),
        EditableTripCodec.encode(original),
      );
      expect(find.text('Xem thay đổi trước khi xác nhận'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-assistant-apply')),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-apply')));
      await tester.pumpAndSettle();
      expect(planner.document!.items, isEmpty);
      expect(planner.document!.actualExpenses.single.amountVnd, 45000);
      expect(
        planner.document!.actualExpenses.single.sourceItemSnapshot!.title,
        original.items.first.title,
      );
      expect(planner.hasPendingSave, false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'uncertain retry freezes payload and identity; Cancel ignores late results',
    (tester) async {
      final planner = assistantPlanner(),
          auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);
      final original = EditableTripCodec.encode(planner.document!),
          context = AiAssistantContext.fromDocument(
            planner.document!,
            selectedDay: 1,
          ),
          held = Completer<AiAssistantReply>(),
          ids = <String>[],
          prompts = <String>[];
      await tester.pumpWidget(
        assistantApp(planner, auth, (intent, prompt, history, id) async {
          ids.add(id);
          prompts.add(prompt);
          if (ids.length == 1) {
            throw const AiGenerationFailure('outcome_pending');
          }
          return held.future;
        }),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-open')));
      await tester.pumpAndSettle();
      await sendAssistant(tester, 'Lịch này nên điều chỉnh gì?');
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('ai-assistant-prompt')),
            )
            .enabled,
        false,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-assistant-send')),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-send')));
      await tester.pump();
      expect(ids, hasLength(2));
      expect(ids[1], ids[0]);
      expect(prompts[1], prompts[0]);
      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-assistant-cancel')),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-cancel')));
      await tester.pumpAndSettle();
      held.complete(
        AiAssistantReply(
          AiAssistantResult.fromJson(
            assistantResult('advice'),
            context,
            'advice',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(EditableTripCodec.encode(planner.document!), original);
      expect(find.byKey(const ValueKey('ai-assistant-apply')), findsNothing);
      expect(planner.isEditable, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'authority invalidation closes pending assistant before a late answer; large text actions remain reachable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final planner = assistantPlanner(),
          auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);
      final held = Completer<AiAssistantReply>(),
          context = AiAssistantContext.fromDocument(
            planner.document!,
            selectedDay: 1,
          ),
          before = EditableTripCodec.encode(planner.document!);
      await tester.pumpWidget(
        assistantApp(planner, auth, (_, _, _, _) => held.future, large: true),
      );
      await tester.tap(find.byKey(const ValueKey('ai-assistant-open')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ai-assistant-cancel')).hitTestable(),
        findsOneWidget,
      );
      await sendAssistant(tester, 'Tôi cần chuẩn bị gì?', pending: true);
      auth.onLocalAccountInvalidated();
      await tester.pumpAndSettle();
      held.complete(
        AiAssistantReply(
          AiAssistantResult.fromJson(
            assistantResult('advice'),
            context,
            'advice',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-assistant-prompt')), findsNothing);
      expect(EditableTripCodec.encode(planner.document!), before);
      expect(tester.takeException(), isNull);
    },
  );
  test('client rejects known closed windows/travel deficits and stale snapshot before preview', () {
    const places = [
      catalogue.PlaceReference(
        id: 'hue/citadel',
        name: 'Kinh thành',
        sourceId: 'fixture',
      ),
      catalogue.PlaceReference(
        id: 'hue/other',
        name: 'Điểm khác',
        sourceId: 'fixture',
      ),
    ];
    final before = assistantDoc(),
        context = AiAssistantContext.fromDocument(
          assistantDoc(),
          selectedDay: 1,
          places: places,
          openingWindows: [
            {
              'placeId': 'hue/citadel',
              'startMinute': 480,
              'endMinute': 660,
              'sourceRef': 'fixture-hours',
            },
          ],
          routes: [
            {
              'fromPlaceId': 'hue/citadel',
              'toPlaceId': 'hue/other',
              'minMinutes': 30,
              'sourceRef': 'fixture-route',
            },
          ],
        );
    final edit = {
      'kind': 'edit',
      'itemId': before.items.first.id,
      'title': 'Tham quan',
      'placeId': 'hue/citadel',
      'startMinute': 550,
      'endMinute': 700,
    };
    expect(
      () => AiAssistantResult.fromJson(
        assistantResult('modify', operations: [edit]),
        context,
        'modify',
      ),
      throwsFormatException,
    );
    final add = {
      'kind': 'add',
      'title': 'Điểm khác',
      'placeId': 'hue/other',
      'startMinute': 610,
      'endMinute': 650,
      'costVnd': null,
      'category': 'other',
    };
    expect(
      () => AiAssistantResult.fromJson(
        assistantResult('modify', operations: [add]),
        context,
        'modify',
      ),
      throwsFormatException,
    );
    final remove = AiAssistantResult.fromJson(
      assistantResult(
        'modify',
        operations: [
          {'kind': 'remove', 'itemId': before.items.first.id},
        ],
      ),
      context,
      'modify',
    );
    final changed = before.copyWith(
      input: TripInput.fromJson({
        ...before.input.toJson(),
        'title': 'Bản đã thay đổi',
      }),
    );
    expect(
      () => prepareAiModification(changed, remove, context, nextAssistantId),
      throwsA(
        isA<AiGenerationFailure>().having((e) => e.code, 'reason', 'stale'),
      ),
    );
  });
  test('assistant scope forwards selected activities/date/priority but excludes notes/title/actual/GPS', () {
    final doc = assistantDoc();
    final context = AiAssistantContext.fromDocument(doc, selectedDay: 1);
    final value = context.toJson();
    expect(value['date'], doc.days.first.date);
    expect(value['priority'], doc.input.priority);
    expect(value.containsKey('actualExpenses'), false);
    expect(value.containsKey('notes'), false);
    expect(value.containsKey('title'), false);
    final activities = value['activities'] as List;
    expect(activities.length, doc.items.length);
    expect((activities.first as Map).containsKey('notes'), false);
    expect(value['weather'], 'unknown');
  });
  test('advice/recommendations cannot produce commands and unsafe prompt is rejected', () {
    final c = AiAssistantContext.fromDocument(assistantDoc(), selectedDay: 1);
    final reply = AiAssistantResult.fromJson(
      assistantResult('advice'),
      c,
      'advice',
    );
    expect(reply.operations, isEmpty);
    expect(
      () => AiAssistantResult.fromJson(
        assistantResult(
          'advice',
          operations: [
            {'kind': 'remove', 'itemId': assistantDoc().items.first.id},
          ],
        ),
        c,
        'advice',
      ),
      throwsFormatException,
    );
    expect(
      () => assistantRequest(
        c,
        'advice',
        'email private@example.com',
        const [],
        nextAssistantId(),
      ),
      throwsFormatException,
    );
  });
  test('modify remove keeps financial ledger and records source snapshot; preview preparation never mutates input', () {
    final before = assistantDoc(),
        context = AiAssistantContext.fromDocument(
          assistantDoc(),
          selectedDay: 1,
        );
    final bytes = EditableTripCodec.encode(before);
    final result = AiAssistantResult.fromJson(
      assistantResult(
        'modify',
        operations: [
          {'kind': 'remove', 'itemId': before.items.first.id},
        ],
      ),
      context,
      'modify',
    );
    final prepared = prepareAiModification(
      before,
      result,
      context,
      nextAssistantId,
    );
    expect(EditableTripCodec.encode(before), bytes);
    expect(prepared.document.items, isEmpty);
    expect(
      prepared.document.actualExpenses.length,
      before.actualExpenses.length,
    );
    for (var i = 0; i < before.actualExpenses.length; i++) {
      final a = before.actualExpenses[i],
          b = prepared.document.actualExpenses[i];
      expect(b.id, a.id);
      expect(b.amountVnd, a.amountVnd);
      expect(b.paidOn, a.paidOn);
      expect(b.description, a.description);
      expect(b.category, a.category);
    }
    expect(prepared.commands.length, 1);
  });
  test('wrong subject scope/unknown item/raw ledger operations/verified output rejected', () {
    final c = AiAssistantContext.fromDocument(assistantDoc(), selectedDay: 1);
    for (final op in [
      {'kind': 'remove', 'itemId': nextAssistantId()},
      {'kind': 'putActual', 'amountVnd': 0},
      {'kind': 'resizeDays', 'days': []},
    ]) {
      expect(
        () => AiAssistantResult.fromJson(
          assistantResult('modify', operations: [op]),
          c,
          'modify',
        ),
        throwsFormatException,
      );
    }
    expect(
      () => AiAssistantResult.fromJson(
        {...assistantResult('advice'), 'verification': 'verified'},
        c,
        'advice',
      ),
      throwsFormatException,
    );
    expect(
      () => AiAssistantResult.fromJson(
        {...assistantResult('advice'), 'selectedDay': 2},
        c,
        'advice',
      ),
      throwsFormatException,
    );
  });
}

ManualPlannerProvider assistantPlanner() => ManualPlannerProvider(
  repositoryLoader: () async =>
      throw StateError('assistant must not save automatically'),
  newId: nextAssistantId,
)..openNew(assistantDoc());
Widget assistantApp(
  ManualPlannerProvider planner,
  AuthProvider auth,
  AiAssistantGenerator generate, {
  bool large = false,
}) => ChangeNotifierProvider.value(
  value: auth,
  child: MaterialApp(
    builder: large
        ? (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          )
        : null,
    home: ManualPlannerScreen(
      planner: planner,
      destinations: const [],
      enableMapNetworkTiles: false,
      assistantGenerate: generate,
    ),
  ),
);
Future<void> sendAssistant(
  WidgetTester tester,
  String prompt, {
  bool pending = false,
}) async {
  await tester.ensureVisible(find.byKey(const ValueKey('ai-assistant-prompt')));
  await tester.enterText(
    find.byKey(const ValueKey('ai-assistant-prompt')),
    prompt,
  );
  await tester.pump();
  await tester.ensureVisible(
    find.byKey(const ValueKey('ai-assistant-consent')),
  );
  await tester.tap(find.byKey(const ValueKey('ai-assistant-consent')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('ai-assistant-send')));
  await tester.tap(find.byKey(const ValueKey('ai-assistant-send')));
  if (pending) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

EditableTripDocumentV2 assistantDoc() {
  final base = records.doc();
  const itemId = '00000000-0000-4000-8000-000000000901';
  return base.copyWith(
    items: [
      TripItem(
        id: itemId,
        dayId: base.days.first.id,
        position: 0,
        title: 'Tham quan Kinh thành',
        placeId: 'hue/citadel',
        startMinute: 540,
        endMinute: 600,
        notes: 'PRIVATE_NOTE_NOT_SENT',
        provenance: FieldProvenance(
          quality: 'user_provided',
          sourceRefs: [],
          observedAt: null,
        ),
      ),
    ],
    actualExpenses: [
      ActualExpense(
        id: '00000000-0000-4000-8000-000000000902',
        itemId: itemId,
        amountVnd: 45000,
        category: 'attractions',
        paidOn: '2026-10-15',
        description: 'Khoản đã chi giữ nguyên',
        sourceItemSnapshot: null,
        provenance: FieldProvenance(
          quality: 'user_provided',
          sourceRefs: [],
          observedAt: null,
        ),
      ),
    ],
  );
}

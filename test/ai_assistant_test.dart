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

import 'editable_local_store_test.dart' as records;

Map<String, Object?> assistantResult(
  String intent, {
  List<Object?> operations = const [],
  List<Object?> recommendations = const [],
}) => {
  'contract': 'travelgo.assistant.v1',
  'intent': intent,
  'destinationId': 'hue',
  'numDays': 1,
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

// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/profile/presentation/screens/profile_screen.dart';

const ownerA = 'a1111111-1111-4111-8111-111111111111';
const ownerB = 'b2222222-2222-4222-8222-222222222222';
Map<String, Object?> row(String owner, {String? style}) => {
  'id': owner,
  'interests': <String>[],
  'typical_budget_vnd': null,
  'travel_style': style,
};
http.Response reply(Object? value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
User sdkUser(String owner) => User.fromJson({
  'id': owner,
  'email': 'fixture@example.invalid',
  'aud': 'authenticated',
  'role': 'authenticated',
  'created_at': '2026-10-18T00:00:00Z',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
})!;
AuthProvider fixture(
  Future<http.Response> Function(http.Request) handle, {
  WidgetTester? tester,
}) {
  final client = SupabaseClient(
    'https://fixture.invalid',
    'fixture-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final response = await handle(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
  );
  final auth = AuthProvider(
    client: client,
    trustedRoleFetcher: (_) async => 'customer',
  );
  auth.simulateSupabaseUser(sdkUser(ownerA));
  addTearDown(() async {
    auth.dispose();
    if (tester == null) {
      await client.dispose();
    } else {
      // The SDK owns a real isolate; its shutdown cannot complete in FakeAsync.
      await tester.runAsync(client.dispose);
    }
  });
  return auth;
}

Widget app(AuthProvider auth, {bool large = false}) =>
    ChangeNotifierProvider.value(
      value: auth,
      child: MaterialApp(
        builder: large
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                ),
                child: child!,
              )
            : null,
        home: const CustomerProfileScreen(),
      ),
    );

void main() {
  test('preferences canonicalize input, distinguish unset and zero, immutable list', () {
    final input = <String>[' Thiên nhiên '];
    final prefs = TravelPreferences.fromInput(
      interests: input,
      typicalBudgetVnd: 0,
      travelStyle: ' Thư thái ',
    );
    input.clear();
    expect(prefs.interests, ['Thiên nhiên']);
    expect(() => prefs.interests.add('x'), throwsUnsupportedError);
    expect(prefs.toJson(), {
      'interests': ['Thiên nhiên'],
      'typical_budget_vnd': 0,
      'travel_style': 'Thư thái',
    });
    expect(TravelPreferences.fromInput(travelStyle: ' ').toJson(), {
      'interests': [],
      'typical_budget_vnd': null,
      'travel_style': null,
    });
    expect(TravelPreferences.fromJson(prefs.toJson()).toJson(), prefs.toJson());
    expect(
      TravelPreferences.fromInput(typicalBudgetVnd: 9007199254740991)
          .typicalBudgetVnd,
      9007199254740991,
    );
  });
  test('reject invalid money, duplicate/oversized interests, malformed server values', () {
    for (final amount in [-1, 9007199254740992]) {
      expect(
        () => TravelPreferences.fromInput(typicalBudgetVnd: amount),
        throwsFormatException,
      );
    }
    for (final interests in [
      <String>[''],
      ['a', 'a'],
      ['x' * 81],
      List.generate(21, (i) => '$i'),
    ]) {
      expect(
        () => TravelPreferences.fromInput(interests: interests),
        throwsFormatException,
      );
    }
    expect(
      () => TravelPreferences.fromInput(travelStyle: 'x' * 81),
      throwsFormatException,
    );
    for (final malformed in [
      <String, Object?>{},
      {...row(ownerA), 'typical_budget_vnd': 1.5},
      {
        ...row(ownerA),
        'interests': [null],
      },
      {...row(ownerA), 'travel_style': ''},
    ]) {
      expect(
        () => TravelPreferences.fromJson(malformed),
        throwsFormatException,
      );
    }
  });
  test('load/update use owner filter and only allowed columns; null clears persist', () async {
    var stored = row(ownerA, style: 'Thư thái');
    final calls = <http.Request>[];
    final auth = fixture((req) async {
      calls.add(req);
      if (req.method == 'PATCH') {
        stored = {...stored, ...jsonDecode(req.body) as Map<String, dynamic>};
        return reply(stored);
      }
      return reply([stored]);
    });
    expect(await auth.loadTravelPreferences(), isTrue);
    expect(auth.travelPreferencesLoaded, isTrue);
    expect(auth.currentUser!.travelPreferences!.travelStyle, 'Thư thái');
    expect(
      await auth.updateTravelPreferences(TravelPreferences.fromInput()),
      isTrue,
    );
    final patch = calls.singleWhere((r) => r.method == 'PATCH');
    expect(jsonDecode(patch.body), {
      'interests': [],
      'typical_budget_vnd': null,
      'travel_style': null,
    });
    expect(patch.url.queryParameters['id'], 'eq.$ownerA');
    expect(
      calls.where((r) => r.method == 'GET'),
      hasLength(1),
      reason: 'mutation acknowledgement must not be inferred from a second GET',
    );
    expect(auth.currentUser!.travelPreferences!.travelStyle, isNull);
    expect(auth.currentUser!.role, UserRole.customer);
  });
  test(
    'Guest cannot read/write; schema error is safe and does not become saved',
    () async {
      var calls = 0;
      final auth = fixture((req) async {
        calls++;
        return reply({
          'code': '42703',
          'message': 'PRIVATE_DB_DETAILS',
        }, status: 400);
      });
      expect(await auth.loadTravelPreferences(), isFalse);
      expect(auth.travelPreferencesLoaded, isFalse);
      expect(
        auth.travelPreferencesError,
        isNot(contains('PRIVATE_DB_DETAILS')),
      );
      expect(
        await auth.updateTravelPreferences(TravelPreferences.fromInput()),
        isFalse,
      );
      auth.continueAsGuest();
      expect(auth.travelPreferencesLoaded, isFalse);
      expect(auth.travelPreferencesLoading, isFalse);
      expect(await auth.loadTravelPreferences(), isFalse);
      expect(
        await auth.updateTravelPreferences(TravelPreferences.fromInput()),
        isFalse,
      );
      expect(calls, 1);
    },
  );
  test('wrong owner/malformed load and zero-row/wrong-owner PATCH never acknowledge', () async {
    for (final bad in [
      <Object?>[],
      [row(ownerB)],
      [
        {...row(ownerA), 'typical_budget_vnd': -1},
      ],
    ]) {
      final auth = fixture((req) async => reply(bad));
      expect(await auth.loadTravelPreferences(), isFalse);
      expect(auth.travelPreferencesLoaded, isFalse);
    }
    for (final bad in [
      null,
      row(ownerB),
      {...row(ownerA), 'travel_style': ''},
    ]) {
      final auth = fixture(
        (req) async => req.method == 'GET' ? reply([row(ownerA)]) : reply(bad),
      );
      expect(await auth.loadTravelPreferences(), isTrue);
      expect(
        await auth.updateTravelPreferences(TravelPreferences.fromInput()),
        isFalse,
      );
      expect(auth.travelPreferencesError, isNotNull);
    }
  });
  test(
    'late A load cannot replace B preferences or clear B request state',
    () async {
      final entered = Completer<void>(), release = Completer<http.Response>();
      final auth = fixture((req) async {
        if (req.url.queryParameters['id'] == 'eq.$ownerA') {
          entered.complete();
          return release.future;
        }
        return reply([row(ownerB, style: 'Phong cách B')]);
      });
      final pending = auth.loadTravelPreferences();
      await entered.future;
      auth.continueAsGuest();
      auth.simulateSupabaseUser(sdkUser(ownerB));
      expect(await auth.loadTravelPreferences(), isTrue);
      release.complete(reply([row(ownerA, style: 'Phong cách A')]));
      expect(await pending, isFalse);
      expect(auth.currentUser!.travelPreferences!.travelStyle, 'Phong cách B');
      expect(auth.travelPreferencesError, isNull);
      expect(auth.travelPreferencesLoading, isFalse);
    },
  );
  test(
    'late A mutation never publishes profile or error after Guest transition',
    () async {
      final entered = Completer<void>(), release = Completer<http.Response>();
      final auth = fixture((req) async {
        if (req.method == 'PATCH') {
          entered.complete();
          return release.future;
        }
        return reply([row(ownerA)]);
      });
      await auth.loadTravelPreferences();
      final pending = auth.updateTravelPreferences(
        TravelPreferences.fromInput(travelStyle: 'A'),
      );
      await entered.future;
      auth.continueAsGuest();
      release.complete(reply(row(ownerA, style: 'A')));
      expect(await pending, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.travelPreferencesLoaded, isFalse);
      expect(auth.travelPreferencesError, isNull);
    },
  );
  testWidgets(
    'preferences Cancel never PATCHes; Save acknowledges server and reopens',
    (tester) async {
      var stored = row(ownerA);
      var patches = 0;
      final auth = (await tester.runAsync(
        () async => fixture((req) async {
          if (req.method == 'PATCH') {
            patches++;
            stored = {
              ...stored,
              ...jsonDecode(req.body) as Map<String, dynamic>,
            };
            return reply(stored);
          }
          return reply([stored]);
        }, tester: tester),
      ))!;
      await tester.pumpWidget(app(auth));
      await tester.tap(find.text('Sở thích du lịch'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-interests')),
        'Thiên nhiên\nẨm thực',
      );
      await tester.tap(
        find.byKey(const ValueKey('profile-preferences-cancel')),
      );
      await tester.pumpAndSettle();
      expect(patches, 0);
      await tester.tap(find.text('Sở thích du lịch'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('profile-interests')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(find.byKey(const ValueKey('profile-budget')), '0');
      await tester.enterText(
        find.byKey(const ValueKey('profile-style')),
        'Thư thái',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-preferences-save')),
      );
      await tester.tap(find.byKey(const ValueKey('profile-preferences-save')));
      await tester.pumpAndSettle();
      expect(patches, 1);
      expect(auth.currentUser!.travelPreferences!.typicalBudgetVnd, 0);
      await tester.tap(find.text('Sở thích du lịch'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('profile-style')))
            .controller!
            .text,
        'Thư thái',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'account change hides old profile modal; large keyboard keeps actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = (await tester.runAsync(
        () async => fixture(
          (req) async => reply([row(ownerA, style: 'Phong cách riêng A')]),
          tester: tester,
        ),
      ))!;
      await tester.pumpWidget(app(auth, large: true));
      await tester.scrollUntilVisible(
        find.text('Sở thích du lịch').hitTestable(),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sở thích du lịch'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-preferences-cancel')),
      );
      expect(
        find.byKey(const ValueKey('profile-preferences-cancel')).hitTestable(),
        findsOneWidget,
      );
      auth.continueAsGuest();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-style')), findsNothing);
      expect(find.text('Phong cách riêng A'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

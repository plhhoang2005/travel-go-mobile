import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/core/presentation/travel_image.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:travelgo_mobile/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:travelgo_mobile/features/auth/presentation/screens/splash_screen.dart';
import 'package:travelgo_mobile/features/profile/presentation/screens/profile_screen.dart';

class PendingAuth extends AuthProvider {
  final ready = Completer<void>();
  @override
  Future<void> get initialization => ready.future;
}

User user(String id) => User(
  id: id,
  email: '$id@example.invalid',
  appMetadata: {},
  userMetadata: {'full_name': 'Người dùng $id'},
  aud: 'authenticated',
  createdAt: '2026-10-17T00:00:00Z',
);

Widget app(
  AuthProvider auth,
  Widget screen, {
  bool large = false,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: auth),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    home: screen,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(large ? 2 : 1),
        disableAnimations: true,
      ),
      child: child!,
    ),
  ),
);

void narrow(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('guest_and_account_secondary_actions_keep_identity_boundary', (
    tester,
  ) async {
    narrow(tester);
    final auth = AuthProvider()..continueAsGuest();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      app(auth, const CustomerProfileScreen(), large: true),
    );
    expect(find.text('Khách Vãng Lai'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Đăng nhập / Đăng ký ngay'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng nhập / Đăng ký ngay'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(auth.isGuest, isTrue);
    expect(auth.isAuthenticated, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CustomerProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile_large_text_and_splash_pending_are_accessible', (
    tester,
  ) async {
    narrow(tester);
    final auth = PendingAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(app(auth, const SplashScreen(), large: true));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('TravelGO Mobile'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(auth.isGuest, isFalse);
    expect(auth.isAuthenticated, isFalse);
    auth.ready.complete();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(auth.isGuest, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'onboarding_reduced_motion_uses_credited_photos_and_truthful_copy',
    (tester) async {
      narrow(tester);
      final auth = AuthProvider();
      addTearDown(auth.dispose);
      await tester.pumpWidget(app(auth, const OnboardingScreen(), large: true));
      await tester.pumpAndSettle();
      expect(find.byType(TravelImage), findsWidgets);
      expect(find.textContaining('20%'), findsNothing);
      await tester.tap(find.text('Tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.tap(find.text('Tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('Theo dõi ngân sách rõ ràng'), findsOneWidget);
      expect(auth.isGuest, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

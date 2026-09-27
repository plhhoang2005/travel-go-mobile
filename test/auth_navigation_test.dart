import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/navigation/presentation/screens/main_navigation_shell.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/core/constants/supabase_constants.dart';
import 'package:travelgo_mobile/features/favorites/providers/favorites_provider.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/home/providers/home_catalog_provider.dart';

void main() {
  group('AuthProvider Unit Tests', () {
    test('Initial state is not authenticated', () {
      final auth = AuthProvider();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('continueAsGuest sets isGuest to true', () {
      final auth = AuthProvider();
      auth.continueAsGuest();
      expect(auth.isGuest, isTrue);
      expect(auth.isAuthenticated, isFalse);
    });

    test('quickDemoLogin with customer sets Minh profile', () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.customer);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.role, UserRole.customer);
      expect(auth.currentUser?.fullName, 'Hoàng Minh');
      expect(auth.isGuest, isFalse);
    });

    test('quickDemoLogin with partner sets Furama profile', () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.partner);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.role, UserRole.partner);
      expect(auth.currentUser?.fullName, 'Resort Furama Đà Nẵng');
    });

    test('quickDemoLogin with admin sets Admin profile', () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.admin);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.role, UserRole.admin);
    });

    test('verifyOtp succeeds with 6-digit code', () async {
      final auth = AuthProvider();
      final result = await auth.verifyOtp('123456');
      expect(result, isTrue);
      expect(auth.isAuthenticated, isTrue);
    });

    test('verifyOtp fails with code shorter than 6 digits', () async {
      final auth = AuthProvider();
      final result = await auth.verifyOtp('123');
      expect(result, isFalse);
      expect(auth.errorMessage, isNotNull);
    });

    test('logout clears user and sets isGuest to true', () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.customer);
      expect(auth.isAuthenticated, isTrue);

      auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.isGuest, isTrue);
    });

    test('login without Supabase connection reports error safely without mock fallback', () async {
      final auth = AuthProvider();
      final success = await auth.login('minh@travelgo.vn', '123456');
      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('kết nối'));
    });

    test('register without Supabase connection reports error safely without mock fallback', () async {
      final auth = AuthProvider();
      final success = await auth.register(
        fullName: 'Nguyễn Văn Test',
        email: 'test@travelgo.vn',
        phone: '0912345678',
        password: 'password123',
      );
      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('kết nối'));
    });

    test('signInWithOAuth without Supabase connection reports error safely', () async {
      final auth = AuthProvider();
      final success = await auth.signInWithOAuth(OAuthProvider.facebook);
      expect(success, isFalse);
      expect(auth.errorMessage, contains('kết nối'));
    });

    test('SupabaseConstants holds valid configuration', () {
      expect(SupabaseConstants.projectUrl, startsWith('https://'));
      expect(SupabaseConstants.projectUrl, contains('.supabase.co'));
      expect(SupabaseConstants.publishableKey, startsWith('sb_publishable_'));
    });
  });

  group('Navigation Shell Widget Tests', () {
    testWidgets('MainNavigationShell renders 5 bottom destinations and switches tabs',
        (WidgetTester tester) async {
      final authProvider = AuthProvider()..continueAsGuest();
      final tripProvider = TripProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: tripProvider),
            ChangeNotifierProvider(create: (_) => FavoritesProvider()),
            ChangeNotifierProvider(create: (_) => SavedTripsProvider()),
            ChangeNotifierProvider(create: (_) => HomeCatalogProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MainNavigationShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check bottom navigation items
      final navBar = find.byType(NavigationBar);
      expect(find.descendant(of: navBar, matching: find.text('Trang chủ')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Khám phá')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Chuyến đi')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Yêu thích')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Cá nhân')), findsOneWidget);

      // Verify initial tab is Home and displays guest greeting instead of hardcoded name
      expect(find.text('Điểm đến nổi bật'), findsOneWidget);
      expect(find.text('Xin chào, Quý khách'), findsOneWidget);
      expect(find.text('Vãng lai'), findsOneWidget);
      expect(find.text('Xin chào, Hoàng'), findsNothing);

      // Switch to Explore tab
      await tester.tap(find.descendant(of: navBar, matching: find.text('Khám phá')));
      await tester.pumpAndSettle();
      expect(find.text('Khám Phá Việt Nam'), findsOneWidget);

      // Switch to Trips tab
      await tester.tap(find.text('Chuyến đi'));
      await tester.pumpAndSettle();
      expect(find.text('Chuyến Đi Của Tôi'), findsOneWidget);

      // Switch to Favorites tab
      await tester.tap(find.text('Yêu thích'));
      await tester.pumpAndSettle();
      expect(find.text('Danh Sách Yêu Thích'), findsOneWidget);

      // Switch to Profile tab
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('Tài Khoản'), findsOneWidget);
      expect(find.text('Khách Vãng Lai'), findsOneWidget);
    });
  });
}

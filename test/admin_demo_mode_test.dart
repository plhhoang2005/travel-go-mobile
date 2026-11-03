import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:travelgo_mobile/features/admin/presentation/screens/admin_shell_screen.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/profile/presentation/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Demo Sandbox Mode Tests', () {
    testWidgets('Demo Admin sees Quản trị navigation in ProfileScreen', (tester) async {
      final auth = AuthProvider();
      await tester.runAsync(() => auth.quickDemoLogin(UserRole.admin));
      expect(auth.isDemoSession, isTrue);
      expect(auth.currentUser?.role, UserRole.admin);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(home: CustomerProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản trị'), findsOneWidget);
      expect(find.text('Quản lý người dùng và địa điểm'), findsOneWidget);

      auth.dispose();
    });

    testWidgets('Demo Customer (Minh) does NOT see Quản trị navigation in ProfileScreen', (tester) async {
      final auth = AuthProvider();
      await tester.runAsync(() => auth.quickDemoLogin(UserRole.customer));
      expect(auth.isDemoSession, isTrue);
      expect(auth.currentUser?.role, UserRole.customer);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(home: CustomerProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản trị'), findsNothing);

      auth.dispose();
    });

    testWidgets('Guest does NOT see Quản trị navigation in ProfileScreen', (tester) async {
      final auth = AuthProvider()..continueAsGuest();
      expect(auth.isGuest, isTrue);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(home: CustomerProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quản trị'), findsNothing);

      auth.dispose();
    });

    testWidgets('Demo Admin enters AdminShellScreen, sees sandbox banner, and manages sandbox users', (
      tester,
    ) async {
      final auth = AuthProvider();
      await tester.runAsync(() => auth.quickDemoLogin(UserRole.admin));
      expect(auth.isDemoSession, isTrue);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(home: AdminShellScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('admin-demo-sandbox-banner')), findsOneWidget);
      expect(find.text('Chế độ Demo Quản Trị - Dữ liệu Sandbox (Ngoại tuyến)'), findsOneWidget);

      // Verify sandbox users loaded
      expect(find.text('Quản lý người dùng'), findsOneWidget);
      expect(find.text('Hoàng Minh'), findsOneWidget);
      expect(find.text('Quản Trị TravelGO'), findsOneWidget);
      expect(find.text('Tài Khoản Vi Phạm (Spam)'), findsOneWidget);

      auth.dispose();
    });

    testWidgets('Demo Admin navigates to Catalogue tab in AdminShellScreen', (tester) async {
      final auth = AuthProvider();
      await tester.runAsync(() => auth.quickDemoLogin(UserRole.admin));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(home: AdminShellScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Danh mục' tab in bottom navigation
      await tester.tap(find.text('Danh mục'));
      await tester.pumpAndSettle();

      // Verify destinations in Tab 0
      expect(find.text('Đà Lạt'), findsWidgets);
      expect(find.text('Đà Nẵng'), findsWidgets);

      // Switch to 'Địa điểm' tab
      await tester.tap(find.textContaining('Địa điểm'));
      await tester.pumpAndSettle();

      // Verify places in Tab 1
      expect(find.text('Bà Nà Hills'), findsOneWidget);
      expect(find.text('Hồ Xuân Hương'), findsOneWidget);

      auth.dispose();
    });
  });
}

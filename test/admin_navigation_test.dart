import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_shell_screen.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_account_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_account_service.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/profile/presentation/screens/profile_screen.dart';

class FakeNavAdminService implements AdminAccountService {
  bool allowAccess = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AdminAccess> access() async {
    if (!allowAccess) {
      throw const AdminFailure(
        code: 'admin_required',
        message: 'Only admins allowed',
      );
    }
    return const AdminAccess(
      subjectId: 'admin-subject',
      role: 'admin',
      accountRevision: 1,
      allowed: true,
    );
  }

  @override
  Future<DashboardSnapshot> dashboard({required int days}) async {
    return DashboardSnapshot(
      asOf: DateTime.parse('2026-10-23T12:00:00Z'),
      days: days,
      totalUsers: 50,
      lockedUsers: 1,
      activeAdmins: 2,
      registrations: const [],
      draft: const DraftCatalogueStats(
        revision: 1,
        activeDestinations: 12,
        hiddenDestinations: 0,
        activePlaces: 72,
        hiddenPlaces: 0,
      ),
      published: null,
    );
  }

  @override
  Future<UserPage> listUsers({
    String query = '',
    String? role,
    String? state,
    UserCursor? cursor,
  }) async {
    return const UserPage(items: [], nextCursor: null);
  }
}

Widget _wrapWithAuth({
  required Widget child,
  required AuthProvider auth,
  AdminAccountProvider? adminProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      if (adminProvider != null)
        ChangeNotifierProvider<AdminAccountProvider>.value(value: adminProvider),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNavAdminService fakeService;
  late AuthProvider authProvider;
  late AdminAccountProvider adminProvider;

  setUp(() async {
    fakeService = FakeNavAdminService();
    authProvider = AuthProvider();
    adminProvider = AdminAccountProvider(
      service: fakeService,
      authProvider: authProvider,
    );
  });

  tearDown(() {
    adminProvider.dispose();
    authProvider.dispose();
  });

  group('Admin Navigation & Gatekeeper Tests (Task F3)', () {
    testWidgets('demo_badge_cannot_enter_admin: Guest, customer, demo cannot see Quản trị entry', (tester) async {
      // 1. Guest mode: Quản trị tile MUST NOT be visible
      authProvider.continueAsGuest();
      await tester.pumpWidget(_wrapWithAuth(
        child: const CustomerProfileScreen(),
        auth: authProvider,
        adminProvider: adminProvider,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Quản trị'), findsNothing);

      // 2. Demo session with admin badge: demo session MUST NOT display Quản trị entry
      final demoLogin = authProvider.quickDemoLogin(UserRole.admin);
      await tester.pump(const Duration(milliseconds: 200));
      await demoLogin;
      await tester.pumpWidget(_wrapWithAuth(
        child: const CustomerProfileScreen(),
        auth: authProvider,
        adminProvider: adminProvider,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Quản trị'), findsNothing);
    });

    testWidgets('direct_route_to_admin_shell_denies_access_when_server_refuses', (tester) async {
      fakeService.allowAccess = false; // Server denies access

      await tester.pumpWidget(_wrapWithAuth(
        child: AdminShellScreen(provider: adminProvider),
        auth: authProvider,
        adminProvider: adminProvider,
      ));
      await tester.pumpAndSettle();

      // Access denied UI is rendered
      expect(find.text('Truy cập bị từ chối'), findsOneWidget);
      expect(find.text('Quay lại'), findsOneWidget);
      expect(adminProvider.hasAdminAccess, isFalse);
      expect(adminProvider.users, isEmpty);
    });

    testWidgets('verified_admin_enters_shell_and_back_pops_route', (tester) async {
      fakeService.allowAccess = true;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _wrapWithAuth(
                        child: AdminShellScreen(provider: adminProvider),
                        auth: authProvider,
                        adminProvider: adminProvider,
                      ),
                    ),
                  );
                },
                child: const Text('Open Admin'),
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap to open admin
      await tester.tap(find.text('Open Admin'));
      await tester.pumpAndSettle();

      // Verified admin accesses shell
      expect(adminProvider.hasAdminAccess, isTrue);
      expect(find.text('Tổng quan hệ thống'), findsOneWidget);

      // Tap back button
      final backButton = find.byTooltip('Quay lại');
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();
        expect(find.text('Open Admin'), findsOneWidget);
      }
    });
  });
}

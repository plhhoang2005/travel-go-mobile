import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_user_detail_screen.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_account_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_account_service.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

import 'coursework_admin_account_flow_test.dart' show CourseworkAdminAuth;

class MockAdminService implements AdminAccountService {
  final List<String> sentMutationRequestIds = [];
  DashboardSnapshot? dashboardToReturn;
  Object? dashboardError;

  List<UserSummary> usersToReturn = [];
  UserCursor? nextCursorToReturn;
  UserDetail? userDetailToReturn;
  AdminFailure? mutationError;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AdminAccess> access() async {
    return const AdminAccess(
      subjectId: 'admin-1',
      role: 'admin',
      accountRevision: 1,
      allowed: true,
    );
  }

  @override
  Future<DashboardSnapshot> dashboard({required int days}) async {
    if (dashboardError != null) throw dashboardError!;
    return dashboardToReturn ??
        DashboardSnapshot(
          asOf: DateTime.parse('2026-10-23T12:00:00Z'),
          days: days,
          totalUsers: 100,
          lockedUsers: 3,
          activeAdmins: 2,
          registrations: const [
            RegistrationDayPoint(date: '2026-10-23', count: 4),
          ],
          draft: const DraftCatalogueStats(
            revision: 5,
            activeDestinations: 12,
            hiddenDestinations: 1,
            activePlaces: 72,
            hiddenPlaces: 0,
          ),
          published: const PublishedCatalogueStats(
            version: 'v2',
            sourceRevision: 4,
            activeDestinations: 12,
            activePlaces: 72,
          ),
        );
  }

  @override
  Future<UserPage> listUsers({
    String query = '',
    String? role,
    String? state,
    UserCursor? cursor,
  }) async {
    return UserPage(items: usersToReturn, nextCursor: nextCursorToReturn);
  }

  @override
  Future<UserDetail> getUser(String targetId) async {
    return userDetailToReturn ??
        UserDetail(
          summary: UserSummary(
            id: targetId,
            fullName: 'Nguyen Van Target',
            email: 'target@example.com',
            role: 'customer',
            state: 'enabled',
            revision: 2,
            createdAt: DateTime.parse('2026-10-20T10:00:00Z'),
            lastSignInAt: null,
            authSynced: true,
          ),
          audit: const [],
        );
  }

  @override
  Future<AccountOperation> mutate({
    required String requestId,
    required String targetId,
    required int expectedRevision,
    required String action,
    required String reason,
  }) async {
    sentMutationRequestIds.add(requestId);
    if (mutationError != null) throw mutationError!;
    final old = userDetailToReturn;
    if (old != null) {
      userDetailToReturn = UserDetail(
        summary: UserSummary(
          id: old.id,
          fullName: old.fullName,
          email: old.email,
          role: old.role,
          state: action == 'lock' ? 'locked' : 'enabled',
          revision: expectedRevision + 1,
          createdAt: old.createdAt,
          authSynced: true,
        ),
        audit: old.audit,
      );
    }
    return AccountOperation(
      id: 'op-1',
      targetId: targetId,
      action: action,
      state: 'completed',
      targetRevision: expectedRevision + 1,
      authSynced: true,
    );
  }
}

Widget _wrapScreen({
  required Widget child,
  required AdminAccountProvider provider,
  double width = 400,
  double height = 800,
  double textScale = 1.0,
}) {
  return ChangeNotifierProvider<AdminAccountProvider>.value(
    value: provider,
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAdminService mockService;
  late AuthProvider authProvider;
  late AdminAccountProvider provider;

  setUp(() async {
    mockService = MockAdminService();
    authProvider = CourseworkAdminAuth();
    provider = AdminAccountProvider(
      service: mockService,
      authProvider: authProvider,
    );
    await provider.enter();
  });

  tearDown(() {
    provider.dispose();
    authProvider.dispose();
  });

  group('Admin Dashboard Screen Widget Tests', () {
    testWidgets('Dashboard renders metrics truthfully and switches 7/30 days', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapScreen(child: const AdminDashboardScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tổng tài khoản'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Tài khoản bị khóa'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Admin hoạt động'), findsOneWidget);
      final adminCard = find.ancestor(
        of: find.text('Admin hoạt động'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: adminCard, matching: find.text('2')),
        findsOneWidget,
      );
      expect(find.textContaining('Bản nháp (Revision 5)'), findsOneWidget);
      expect(find.textContaining('Phiên bản v2'), findsOneWidget);

      // Switch to 30 days
      await tester.tap(find.text('30 ngày'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng ký mới (30 ngày)'), findsOneWidget);
    });

    testWidgets(
      'Dashboard displays retry banner when backend unavailable and does not invent zero',
      (tester) async {
        mockService.dashboardError = const AdminFailure(
          code: 'upstream_unavailable',
          message: 'Could not connect to database statistics',
        );

        await tester.pumpWidget(
          _wrapScreen(child: const AdminDashboardScreen(), provider: provider),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Không thể tải dữ liệu thống kê'),
          findsOneWidget,
        );
        expect(find.text('Thử lại'), findsOneWidget);
        expect(find.text('100'), findsNothing);
      },
    );
  });

  group('Admin Users Screen Widget Tests', () {
    testWidgets(
      'Users list renders items, null lastSignIn renders Chưa đăng nhập',
      (tester) async {
        mockService.usersToReturn = [
          UserSummary(
            id: 'u-1',
            fullName: 'Tran Thi B',
            email: 'b@example.com',
            role: 'customer',
            state: 'enabled',
            revision: 1,
            createdAt: DateTime.parse('2026-10-23T00:00:00Z'),
            lastSignInAt: null,
            authSynced: true,
          ),
        ];

        await tester.pumpWidget(
          _wrapScreen(child: const AdminUsersScreen(), provider: provider),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tran Thi B'), findsOneWidget);
        expect(find.text('b@example.com'), findsOneWidget);
        expect(find.text('• Chưa đăng nhập'), findsOneWidget);
        expect(find.text('USER'), findsOneWidget);
      },
    );
  });

  group('Admin User Detail & Dialog Invariant Tests', () {
    testWidgets('dialog transport retry keeps frozen identity and reason', (
      tester,
    ) async {
      mockService.userDetailToReturn = UserDetail(
        summary: UserSummary(
          id: 'target',
          fullName: 'Target',
          email: 'target@example.invalid',
          role: 'customer',
          state: 'enabled',
          revision: 1,
          createdAt: DateTime.utc(2026),
          authSynced: true,
        ),
        audit: const [],
      );
      mockService.mutationError = const AdminFailure(
        code: 'network_error',
        outcomeUncertain: true,
        message: 'lost ACK',
      );
      await tester.pumpWidget(
        _wrapScreen(
          child: const AdminUserDetailScreen(userId: 'target'),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cấp quyền Admin'), findsNothing);
      await tester.tap(find.text('Khóa tài khoản'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Lý do được giữ');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(mockService.sentMutationRequestIds.length, 1);
      expect(find.text('Lý do được giữ'), findsOneWidget);
      mockService.mutationError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(mockService.sentMutationRequestIds.length, 2);
      expect(mockService.sentMutationRequestIds.toSet().length, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(provider.selectedUser!.state, 'locked');
    });

    testWidgets(
      'user rows at 320dp and 2x text wrap status and preserve filters',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        mockService.usersToReturn = [
          UserSummary(
            id: 'target',
            fullName: 'Tên người dùng',
            email: 'target@example.invalid',
            role: 'customer',
            state: 'locked',
            revision: 2,
            createdAt: DateTime.utc(2026),
            lastSignInAt: DateTime.utc(2026, 10, 26),
            authSynced: false,
          ),
        ];
        provider.setFilter(role: 'customer', state: 'locked');
        await provider.loadUsers();
        await tester.pumpWidget(
          _wrapScreen(
            child: const AdminUsersScreen(),
            provider: provider,
            width: 320,
            height: 600,
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'target');
        await tester.pump(const Duration(milliseconds: 350));
        expect(provider.roleFilter, 'customer');
        expect(provider.stateFilter, 'locked');
        expect(find.byTooltip('Xóa tìm kiếm'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('cancel_and_double_confirm_do_not_duplicate_mutation', (
      tester,
    ) async {
      mockService.userDetailToReturn = UserDetail(
        summary: UserSummary(
          id: 'target-to-lock',
          fullName: 'Target User',
          email: 'target@example.com',
          role: 'customer',
          state: 'enabled',
          revision: 2,
          createdAt: DateTime.parse('2026-10-20T10:00:00Z'),
          lastSignInAt: null,
          authSynced: true,
        ),
        audit: const [],
      );

      await tester.pumpWidget(
        _wrapScreen(
          child: const AdminUserDetailScreen(userId: 'target-to-lock'),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Khóa tài khoản button to open dialog
      await tester.tap(find.text('Khóa tài khoản'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Case 1: Cancel sends zero mutations
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(mockService.sentMutationRequestIds, isEmpty);

      // Re-open dialog
      await tester.tap(find.text('Khóa tài khoản'));
      await tester.pumpAndSettle();

      // Enter required reason
      await tester.enterText(
        find.byType(TextFormField),
        'Vi phạm chính sách cộng đồng',
      );
      await tester.pump();

      // Double tap confirm rapidly
      await tester.tap(find.text('Xác nhận'), warnIfMissed: false);
      await tester.tap(find.text('Xác nhận'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Invariant: confirm twice sends only 1 request ID
      expect(mockService.sentMutationRequestIds.length, 1);
      expect(mockService.sentMutationRequestIds.toSet().length, 1);
    });

    testWidgets(
      'Responsive test: width 320dp and textScale 2.0 does not overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        mockService.userDetailToReturn = UserDetail(
          summary: UserSummary(
            id: 'target-uuid-long-long-long-long',
            fullName: 'Nguyễn Văn Rất Dài Cần Kiểm Tra Tràn Khung Màn Hình Hẹp',
            email:
                'nguyenvanratdaicankiemtratrankhungmanhinhhep@example.invalid',
            role: 'customer',
            state: 'enabled',
            revision: 15,
            createdAt: DateTime.parse('2026-10-20T10:00:00Z'),
            lastSignInAt: DateTime.parse('2026-10-23T09:00:00Z'),
            authSynced: false,
          ),
          audit: [
            AuditEvent(
              id: 'evt-1',
              actorId: 'admin-caller',
              targetId: 'target-uuid-long-long-long-long',
              eventKind: 'account_locked',
              reason: 'Lý do dài kiểm tra hiển thị trên thiết bị màn hình nhỏ không bị lỗi tràn pixel',
              createdAt: DateTime.parse('2026-10-23T09:30:00Z'),
            ),
          ],
        );

        await tester.pumpWidget(
          _wrapScreen(
            child: const AdminUserDetailScreen(
              userId: 'target-uuid-long-long-long-long',
            ),
            provider: provider,
            width: 320,
            height: 600,
            textScale: 2.0,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}

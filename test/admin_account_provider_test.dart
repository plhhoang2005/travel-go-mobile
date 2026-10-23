import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_account_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_account_service.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

class FakeAdminAccountService implements AdminAccountService {
  Completer<UserPage>? listUsersCompleter;
  Completer<UserDetail>? getUserCompleter;
  Completer<AccountOperation>? mutateCompleter;

  final List<String> sentMutationRequestIds = [];

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
  Future<UserPage> listUsers({
    String query = '',
    String? role,
    String? state,
    UserCursor? cursor,
  }) async {
    if (listUsersCompleter != null) {
      return listUsersCompleter!.future;
    }
    return UserPage(
      items: [
        UserSummary(
          id: 'u-1',
          fullName: 'Test User',
          email: 'test@example.com',
          role: 'customer',
          state: 'enabled',
          revision: 1,
          createdAt: DateTime.parse('2026-10-23T10:00:00Z'),
          lastSignInAt: null,
          authSynced: true,
        ),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<UserDetail> getUser(String targetId) async {
    if (getUserCompleter != null) {
      return getUserCompleter!.future;
    }
    return UserDetail(
      summary: UserSummary(
        id: targetId,
        fullName: 'Detail for $targetId',
        email: '$targetId@example.com',
        role: 'customer',
        state: 'enabled',
        revision: 1,
        createdAt: DateTime.parse('2026-10-23T10:00:00Z'),
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
    if (mutateCompleter != null) {
      return mutateCompleter!.future;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdminAccountProvider Unit & Invariant Tests', () {
    late FakeAdminAccountService fakeService;
    late AuthProvider authProvider;
    late AdminAccountProvider provider;

    setUp(() async {
      fakeService = FakeAdminAccountService();
      authProvider = AuthProvider();
      await authProvider.quickDemoLogin(UserRole.admin);
      provider = AdminAccountProvider(
        service: fakeService,
        authProvider: authProvider,
      );
    });

    tearDown(() {
      provider.dispose();
      authProvider.dispose();
    });

    test('owner_change_clears_existing_and_late_admin_data', () async {
      fakeService.listUsersCompleter = Completer<UserPage>();

      // 1. Trigger user loading
      final loadFuture = provider.loadUsers();
      expect(provider.isLoadingUsers, isTrue);

      // 2. Owner changes / logout while request is still pending
      authProvider.continueAsGuest();

      // Invariant: provider.users must be EMPTY immediately before resolving held response
      expect(provider.users, isEmpty);
      expect(provider.hasAdminAccess, isFalse);

      // 3. Resolve the held response now
      fakeService.listUsersCompleter!.complete(UserPage(
        items: [
          UserSummary(
            id: 'late-user-1',
            fullName: 'Late User',
            email: 'late@example.com',
            role: 'customer',
            state: 'enabled',
            revision: 1,
            createdAt: DateTime.parse('2026-10-23T10:00:00Z'),
            lastSignInAt: null,
            authSynced: true,
          ),
        ],
        nextCursor: null,
      ));
      await loadFuture;

      // Invariant: provider.users must REMAIN empty after resolving held response (late response discarded)
      expect(provider.users, isEmpty);
    });

    test('query_and_detail_race_cannot_overwrite_newer_selection', () async {
      final compA = Completer<UserDetail>();
      final compB = Completer<UserDetail>();

      // Request user A
      fakeService.getUserCompleter = compA;
      final futureA = provider.selectUser('user-A');

      // Immediately switch and request user B
      fakeService.getUserCompleter = compB;
      final futureB = provider.selectUser('user-B');

      // Now complete A first
      compA.complete(UserDetail(
        summary: UserSummary(
          id: 'user-A',
          fullName: 'User A',
          email: 'a@example.com',
          role: 'customer',
          state: 'enabled',
          revision: 1,
          createdAt: DateTime.parse('2026-10-23T10:00:00Z'),
          lastSignInAt: null,
          authSynced: true,
        ),
        audit: const [],
      ));
      await futureA;

      // Assert user A did NOT overwrite the current selection
      expect(provider.selectedUser, isNull);

      // Now complete B
      compB.complete(UserDetail(
        summary: UserSummary(
          id: 'user-B',
          fullName: 'User B',
          email: 'b@example.com',
          role: 'customer',
          state: 'enabled',
          revision: 1,
          createdAt: DateTime.parse('2026-10-23T10:00:00Z'),
          lastSignInAt: null,
          authSynced: true,
        ),
        audit: const [],
      ));
      await futureB;

      // User B is selected
      expect(provider.selectedUser?.id, 'user-B');
    });

    test('retry_same_action_asserts_sentIds_toSet_length_is_1', () async {
      // First attempt fails with uncertain outcome or 503
      fakeService.mutateCompleter = Completer<AccountOperation>()
        ..completeError(const AdminFailure(
          code: 'upstream_unavailable',
          outcomeUncertain: true,
          message: 'Server timeout',
        ));

      final firstSuccess = await provider.confirmMutation(
        targetId: 'target-1',
        expectedRevision: 2,
        action: 'lock',
        reason: 'Violated Terms',
      );
      expect(firstSuccess, isFalse);
      expect(provider.error?.outcomeUncertain, isTrue);
      expect(fakeService.sentMutationRequestIds.length, 1);

      // Now retry the operation
      fakeService.mutateCompleter = Completer<AccountOperation>()
        ..complete(const AccountOperation(
          id: 'op-1',
          targetId: 'target-1',
          action: 'lock',
          state: 'completed',
          targetRevision: 3,
          authSynced: true,
        ));

      final retrySuccess = await provider.retryOperation();
      expect(retrySuccess, isTrue);
      expect(fakeService.sentMutationRequestIds.length, 2);

      // Both attempts must use the EXACT same requestId
      expect(fakeService.sentMutationRequestIds.toSet().length, 1);
    });
  });
}

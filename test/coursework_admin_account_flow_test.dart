import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_account_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_account_service.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

// Synthetic authority for provider races. Real session proof is tested in
// admin_account_service_test; this fixture never connects to Supabase.
class CourseworkAdminAuth extends AuthProvider {
  UserEntity? user = const UserEntity(
    id: 'admin-1',
    fullName: 'Admin',
    email: 'admin@example.invalid',
    phone: '',
    role: UserRole.admin,
  );
  int epoch = 1;
  bool demo = false;
  @override
  UserEntity? get currentUser => user;
  @override
  int get authEpoch => epoch;
  @override
  bool get isDemoSession => demo;
  void change({UserEntity? next, bool sameOwner = false}) {
    if (!sameOwner) user = next;
    epoch++;
    notifyListeners();
  }
}

UserDetail courseworkUser(
  String id, {
  String state = 'enabled',
  int revision = 1,
  bool synced = true,
}) => UserDetail(
  summary: UserSummary(
    id: id,
    fullName: id,
    email: '$id@example.invalid',
    role: 'customer',
    state: state,
    revision: revision,
    createdAt: DateTime.utc(2026),
    authSynced: synced,
  ),
  audit: const [],
);

class CourseworkAdminService implements AdminAccountService {
  Completer<AdminAccess>? accessHeld;
  final lists =
      <
        ({
          String query,
          String? role,
          String? state,
          UserCursor? cursor,
          Completer<UserPage> result,
        })
      >[];
  bool holdLists = false;
  Completer<AccountOperation>? mutationHeld;
  final mutations = <String>[];
  UserDetail detail = courseworkUser('target');
  Object? readError;
  AccountOperation? operationReply;
  AccountOperation? reconcileReply;
  AdminFailure? reconcileError;
  final reconciliationIds = <String>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<AdminAccess> access() async => accessHeld == null
      ? const AdminAccess(
          subjectId: 'admin-1',
          role: 'admin',
          accountRevision: 1,
          allowed: true,
        )
      : accessHeld!.future;
  @override
  Future<UserPage> listUsers({
    String query = '',
    String? role,
    String? state,
    UserCursor? cursor,
  }) {
    final result = Completer<UserPage>();
    lists.add((
      query: query,
      role: role,
      state: state,
      cursor: cursor,
      result: result,
    ));
    if (!holdLists) result.complete(const UserPage(items: []));
    return result.future;
  }

  @override
  Future<UserDetail> getUser(String targetId) async {
    if (readError != null) throw readError!;
    return detail;
  }

  @override
  Future<AccountOperation> mutate({
    required String requestId,
    required String targetId,
    required int expectedRevision,
    required String action,
    required String reason,
  }) async {
    mutations.add(requestId);
    if (mutationHeld != null) return mutationHeld!.future;
    return AccountOperation(
      id: requestId,
      targetId: targetId,
      action: action,
      state: 'completed',
      targetRevision: expectedRevision + 1,
      authSynced: true,
    );
  }

  @override
  Future<AccountOperation> operation(String id) async => operationReply!;
  @override
  Future<AccountOperation> reconcile({
    required String requestId,
    required String operationId,
    required int expectedRevision,
    required String reason,
  }) async {
    reconciliationIds.add(requestId);
    if (reconcileError != null) throw reconcileError!;
    return reconcileReply!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CourseworkAdminAuth auth;
  late CourseworkAdminService service;
  late AdminAccountProvider provider;
  setUp(() {
    auth = CourseworkAdminAuth();
    service = CourseworkAdminService();
    provider = AdminAccountProvider(service: service, authProvider: auth);
  });
  tearDown(() {
    provider.dispose();
    auth.dispose();
  });

  test('needs_retry reconciles separately and lost reconcile ACK keeps attempt identity', () async {
    await provider.enter();
    const pending = AccountOperation(
      id: 'op',
      targetId: 'target',
      action: 'lock',
      state: 'needs_retry',
      targetRevision: 2,
      authSynced: false,
    );
    service.mutationHeld = Completer<AccountOperation>()..complete(pending);
    service.detail = courseworkUser(
      'target',
      state: 'locked',
      revision: 2,
      synced: false,
    );
    expect(
      await provider.confirmMutation(
        targetId: 'target',
        expectedRevision: 1,
        action: 'lock',
        reason: 'test',
      ),
      isTrue,
    );
    service.operationReply = pending;
    service.reconcileError = const AdminFailure(
      code: 'network_error',
      outcomeUncertain: true,
      message: 'reconcile ACK lost',
    );
    expect(await provider.retryOperation(), isFalse);
    service.reconcileError = null;
    service.reconcileReply = const AccountOperation(
      id: 'op',
      targetId: 'target',
      action: 'lock',
      state: 'completed',
      targetRevision: 2,
      authSynced: true,
    );
    service.detail = courseworkUser('target', state: 'locked', revision: 2);
    expect(await provider.retryOperation(), isTrue);
    expect(service.reconciliationIds.length, 2);
    expect(service.reconciliationIds.toSet().length, 1);
    expect(service.mutations.length, 1);
    expect(provider.hasRetryableOperation, isFalse);
  });

  test(
    'reopened detail restores pending operation for deliberate reconcile',
    () async {
      await provider.enter();
      const operation = AccountOperation(
        id: 'op',
        targetId: 'target',
        action: 'lock',
        state: 'needs_retry',
        targetRevision: 2,
        authSynced: false,
      );
      service.detail = UserDetail(
        summary: courseworkUser(
          'target',
          state: 'locked',
          revision: 2,
          synced: false,
        ).summary,
        audit: const [],
        pendingOperation: operation,
      );
      await provider.selectUser('target');
      expect(provider.hasRetryableOperation, isTrue);
      expect(provider.pendingTargetId, 'target');
      service.operationReply = operation;
      service.reconcileReply = const AccountOperation(
        id: 'op',
        targetId: 'target',
        action: 'lock',
        state: 'completed',
        targetRevision: 2,
        authSynced: true,
      );
      service.detail = courseworkUser('target', state: 'locked', revision: 2);
      expect(await provider.retryOperation(), isTrue);
      expect(service.mutations, isEmpty);
      expect(service.reconciliationIds.length, 1);
    },
  );

  for (final failure in [false, true]) {
    test(
      'late access ${failure ? 'error' : 'success'} cannot restore revoked context',
      () async {
        service.accessHeld = Completer<AdminAccess>();
        final old = provider.enter();
        auth.change();
        if (failure) {
          service.accessHeld!.completeError(
            const AdminFailure(code: 'network_error', message: 'old'),
          );
        } else {
          service.accessHeld!.complete(
            const AdminAccess(
              subjectId: 'admin-1',
              role: 'admin',
              accountRevision: 1,
              allowed: true,
            ),
          );
        }
        await old;
        expect(provider.hasAdminAccess, isFalse);
        expect(provider.error, isNull);
      },
    );
  }
  test('access ACK subject must match caller; demo is denied', () async {
    service.accessHeld = Completer<AdminAccess>()
      ..complete(
        const AdminAccess(
          subjectId: 'other-admin',
          role: 'admin',
          accountRevision: 1,
          allowed: true,
        ),
      );
    await provider.enter();
    expect(provider.hasAdminAccess, isFalse);
    service.accessHeld = null;
    auth.demo = true;
    await provider.enter();
    expect(provider.hasAdminAccess, isFalse);
  });
  test(
    'same owner new authority clears PII and late mutation cannot republish',
    () async {
      await provider.enter();
      await provider.selectUser('target');
      service.mutationHeld = Completer<AccountOperation>();
      final old = provider.confirmMutation(
        targetId: 'target',
        expectedRevision: 1,
        action: 'lock',
        reason: 'test',
      );
      auth.change(sameOwner: true);
      expect(provider.selectedUser, isNull);
      expect(provider.isMutating, isFalse);
      service.mutationHeld!.complete(
        const AccountOperation(
          id: 'op',
          targetId: 'target',
          action: 'lock',
          state: 'completed',
          targetRevision: 2,
          authSynced: true,
        ),
      );
      expect(await old, isFalse);
      expect(provider.pendingOperation, isNull);
      expect(provider.error, isNull);
    },
  );
  test('query edits preserve other filters and invalidate old response immediately', () async {
    await provider.enter();
    provider.setFilter(role: 'admin', state: 'locked');
    service.holdLists = true;
    final old = provider.loadUsers();
    provider.setFilter(query: 'new');
    expect(provider.roleFilter, 'admin');
    expect(provider.stateFilter, 'locked');
    final newer = provider.loadUsers();
    expect(service.lists.length, 2);
    service.lists[1].result.complete(
      UserPage(items: [courseworkUser('new').summary]),
    );
    await newer;
    service.lists[0].result.completeError(
      const AdminFailure(code: 'network_error', message: 'old'),
    );
    await old;
    expect(provider.users.single.id, 'new');
    expect(provider.error, isNull);
    provider.setFilter(role: null);
    expect(provider.stateFilter, 'locked');
  });
  test(
    'duplicate next page is dispatched once; failed page preserves results',
    () async {
      await provider.enter();
      service.holdLists = true;
      final first = provider.loadUsers();
      service.lists.single.result.complete(
        UserPage(
          items: [courseworkUser('one').summary],
          nextCursor: const UserCursor(
            createdAt: '2026-01-01T00:00:00Z',
            id: 'one',
          ),
        ),
      );
      await first;
      final next = provider.loadUsers(nextPage: true);
      await provider.loadUsers(nextPage: true);
      expect(service.lists.length, 2);
      service.lists.last.result.completeError(
        const AdminFailure(code: 'network_error', message: 'page'),
      );
      await next;
      expect(provider.users.single.id, 'one');
      expect(provider.hasMoreUsers, isTrue);
    },
  );
  test(
    'completed unlock uses readback instead of guessing unlocking',
    () async {
      await provider.enter();
      service.detail = courseworkUser('target', state: 'locked', revision: 2);
      await provider.selectUser('target');
      service.detail = courseworkUser('target', revision: 3);
      expect(
        await provider.confirmMutation(
          targetId: 'target',
          expectedRevision: 2,
          action: 'unlock',
          reason: 'test',
        ),
        isTrue,
      );
      expect(provider.selectedUser!.state, 'enabled');
      expect(provider.selectedUser!.revision, 3);
    },
  );
  test('completed ACK with failed readback retries read only', () async {
    await provider.enter();
    service.readError = const AdminFailure(
      code: 'network_error',
      message: 'readback',
    );
    await provider.confirmMutation(
      targetId: 'target',
      expectedRevision: 1,
      action: 'lock',
      reason: 'test',
    );
    service.readError = null;
    service.detail = courseworkUser('target', state: 'locked', revision: 2);
    await provider.retryOperation();
    expect(service.mutations.length, 1);
    expect(provider.selectedUser!.state, 'locked');
  });
  test('wrong target ACK never updates current user', () async {
    await provider.enter();
    await provider.selectUser('target');
    service.mutationHeld = Completer<AccountOperation>()
      ..complete(
        const AccountOperation(
          id: 'wrong',
          targetId: 'other',
          action: 'lock',
          state: 'completed',
          targetRevision: 2,
          authSynced: true,
        ),
      );
    expect(
      await provider.confirmMutation(
        targetId: 'target',
        expectedRevision: 1,
        action: 'lock',
        reason: 'test',
      ),
      isFalse,
    );
    expect(provider.selectedUser!.state, 'enabled');
  });
  test('server permission denial clears loaded PII', () async {
    await provider.enter();
    await provider.selectUser('target');
    service.readError = const AdminFailure(
      code: 'admin_required',
      message: 'revoked',
    );
    await provider.selectUser('target');
    expect(provider.hasAdminAccess, isFalse);
    expect(provider.users, isEmpty);
  });
  test(
    'new mutation after completion cannot retry previous operation receipt',
    () async {
      await provider.enter();
      service.detail = courseworkUser('target', state: 'locked', revision: 2);
      expect(
        await provider.confirmMutation(
          targetId: 'target',
          expectedRevision: 1,
          action: 'lock',
          reason: 'first',
        ),
        isTrue,
      );
      service.mutationHeld = Completer<AccountOperation>()
        ..completeError(
          const AdminFailure(
            code: 'network_error',
            outcomeUncertain: true,
            message: 'second ACK lost',
          ),
        );
      expect(
        await provider.confirmMutation(
          targetId: 'target',
          expectedRevision: 2,
          action: 'unlock',
          reason: 'second',
        ),
        isFalse,
      );
      final secondId = service.mutations.last;
      service.mutationHeld = null;
      service.detail = courseworkUser('target', revision: 3);
      expect(await provider.retryOperation(), isTrue);
      expect(service.mutations.length, 3);
      expect(service.mutations.last, secondId);
      expect(service.mutations.first, isNot(secondId));
      expect(provider.selectedUser!.state, 'enabled');
    },
  );
}

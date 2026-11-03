// Demo Admin Services for TravelGO
// Provides an in-memory, zero-network sandbox environment for testing and evaluating Admin features.

import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/admin/services/admin_account_service.dart';
import 'package:travelgo_mobile/features/admin/services/admin_catalogue_service.dart';
import 'package:travelgo_mobile/features/admin/services/admin_publication_service.dart';

// =============================================================================
// 1. DEMO ADMIN ACCOUNT SERVICE (QUẢN TRỊ NGƯỜI DÙNG SANDBOX)
// =============================================================================

class DemoAdminAccountService implements AdminAccountService {
  final List<UserSummary> _sandboxUsers = [
    UserSummary(
      id: 'usr-minh-01',
      email: 'hoangminh.traveler@gmail.com',
      fullName: 'Hoàng Minh',
      role: 'customer',
      state: 'enabled',
      revision: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      lastSignInAt: DateTime.now().subtract(const Duration(hours: 2)),
      authSynced: true,
    ),
    UserSummary(
      id: 'adm-root-01',
      email: 'admin@travelgo.vn',
      fullName: 'Quản Trị TravelGO',
      role: 'admin',
      state: 'enabled',
      revision: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 100)),
      lastSignInAt: DateTime.now(),
      authSynced: true,
    ),
    UserSummary(
      id: 'usr-locked-02',
      email: 'spammer@fake.vn',
      fullName: 'Tài Khoản Vi Phạm (Spam)',
      role: 'customer',
      state: 'locked',
      revision: 2,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      lastSignInAt: DateTime.now().subtract(const Duration(days: 3)),
      authSynced: true,
    ),
    UserSummary(
      id: 'usr-linh-03',
      email: 'thailinh.danang@gmail.com',
      fullName: 'Thái Linh',
      role: 'customer',
      state: 'enabled',
      revision: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      lastSignInAt: DateTime.now().subtract(const Duration(hours: 5)),
      authSynced: true,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AdminAccess> access() async {
    return const AdminAccess(
      subjectId: 'adm-root-01',
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
    final q = query.trim().toLowerCase();
    final filtered = _sandboxUsers.where((u) {
      if (q.isNotEmpty &&
          !u.fullName.toLowerCase().contains(q) &&
          !u.email.toLowerCase().contains(q)) {
        return false;
      }
      if (role != null && role.isNotEmpty && u.role != role) {
        return false;
      }
      if (state != null && state.isNotEmpty && u.state != state) {
        return false;
      }
      return true;
    }).toList();

    return UserPage(items: filtered, nextCursor: null);
  }

  @override
  Future<UserDetail> getUser(String targetId) async {
    final user = _sandboxUsers.firstWhere(
      (u) => u.id == targetId,
      orElse: () => _sandboxUsers.first,
    );

    return UserDetail(
      summary: user,
      audit: const [],
      pendingOperation: null,
    );
  }

  @override
  Future<DashboardSnapshot> dashboard({required int days}) async {
    return DashboardSnapshot(
      asOf: DateTime.now(),
      days: days,
      totalUsers: _sandboxUsers.length,
      lockedUsers: _sandboxUsers.where((u) => u.state == 'locked').length,
      activeAdmins: _sandboxUsers.where((u) => u.role == 'admin').length,
      registrations: [
        RegistrationDayPoint(
          date: DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10),
          count: 3,
        ),
        RegistrationDayPoint(
          date: DateTime.now().toIso8601String().substring(0, 10),
          count: 5,
        ),
      ],
      draft: const DraftCatalogueStats(
        revision: 1,
        activeDestinations: 10,
        hiddenDestinations: 0,
        activePlaces: 72,
        hiddenPlaces: 0,
      ),
      published: const PublishedCatalogueStats(
        version: 'v2.1',
        sourceRevision: 1,
        activeDestinations: 10,
        activePlaces: 72,
      ),
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
    final idx = _sandboxUsers.indexWhere((u) => u.id == targetId);
    if (idx != -1) {
      final current = _sandboxUsers[idx];
      final newState = action == 'lock' ? 'locked' : (action == 'unlock' ? 'enabled' : current.state);
      _sandboxUsers[idx] = UserSummary(
        id: current.id,
        email: current.email,
        fullName: current.fullName,
        role: current.role,
        state: newState,
        revision: current.revision + 1,
        createdAt: current.createdAt,
        lastSignInAt: current.lastSignInAt,
        authSynced: true,
      );
    }

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
  Future<AccountOperation> reconcile({
    required String requestId,
    required String operationId,
    required int expectedRevision,
    required String reason,
  }) async {
    return AccountOperation(
      id: operationId,
      targetId: 'usr-admin-01',
      action: 'reconcile',
      state: 'completed',
      targetRevision: expectedRevision,
      authSynced: true,
    );
  }
}

// =============================================================================
// 2. DEMO ADMIN CATALOGUE SERVICE (QUẢN TRỊ ĐỊA ĐIỂM SANDBOX)
// =============================================================================

class DemoAdminCatalogueService implements AdminCatalogueService {
  int _revision = 1;
  final List<AdminDestinationDraft> _destinations = [
    const AdminDestinationDraft(
      id: 'da-lat',
      name: 'Đà Lạt',
      slug: 'da-lat',
      region: 'Tây Nguyên',
      description: 'Thành phố sương mù ngàn hoa mộng mơ.',
      active: true,
    ),
    const AdminDestinationDraft(
      id: 'da-nang',
      name: 'Đà Nẵng',
      slug: 'da-nang',
      region: 'Miền Trung',
      description: 'Thành phố biển hiện đại đáng sống.',
      active: true,
    ),
    const AdminDestinationDraft(
      id: 'ha-noi',
      name: 'Hà Nội',
      slug: 'ha-noi',
      region: 'Miền Bắc',
      description: 'Thủ đô nghìn năm văn hiến cổ kính.',
      active: true,
    ),
    const AdminDestinationDraft(
      id: 'phu-quoc',
      name: 'Phú Quốc',
      slug: 'phu-quoc',
      region: 'Miền Nam',
      description: 'Đảo ngọc biển xanh cát trắng nắng vàng.',
      active: true,
    ),
  ];

  final List<AdminPlaceDraft> _places = [
    const AdminPlaceDraft(
      id: 'p-xuan-huong',
      destinationId: 'da-lat',
      name: 'Hồ Xuân Hương',
      slug: 'ho-xuan-huong',
      description: 'Trái tim của thành phố Đà Lạt, khung cảnh nên thơ.',
      latitude: 11.9404,
      longitude: 108.4452,
      active: true,
    ),
    const AdminPlaceDraft(
      id: 'p-lang-biang',
      destinationId: 'da-lat',
      name: 'Đỉnh Langbiang',
      slug: 'dinh-langbiang',
      description: 'Nóc nhà của cao nguyên Lâm Viên hùng vĩ.',
      latitude: 12.0469,
      longitude: 108.4389,
      active: true,
    ),
    const AdminPlaceDraft(
      id: 'p-bana-hills',
      destinationId: 'da-nang',
      name: 'Bà Nà Hills',
      slug: 'ba-na-hills',
      description: 'Đường lên tiên cảnh với biểu tượng Cầu Vàng nổi tiếng.',
      latitude: 15.9988,
      longitude: 107.9961,
      active: true,
    ),
    const AdminPlaceDraft(
      id: 'p-cau-rong',
      destinationId: 'da-nang',
      name: 'Cầu Rồng Đà Nẵng',
      slug: 'cau-rong',
      description: 'Cây cầu phun lửa và nước độc đáo qua sông Hàn.',
      latitude: 16.0611,
      longitude: 108.2272,
      active: true,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AdminCatalogueSnapshot> read() async {
    return AdminCatalogueSnapshot(
      revision: _revision,
      payload: const {},
      history: [
        AdminDraftVersion(
          revision: _revision,
          reason: 'Khởi tạo dữ liệu mẫu sandbox',
          changedAt: DateTime.now(),
          payloadHash: 'hash-sandbox-01',
        ),
      ],
      destinations: List.unmodifiable(_destinations),
      places: List.unmodifiable(_places),
    );
  }

  @override
  Future<AdminCatalogueSnapshot> version(int revision) async {
    return read();
  }

  @override
  Future<AdminCatalogueSnapshot> command({
    required String requestId,
    required int expectedRevision,
    required Map<String, Object?> command,
    required String reason,
  }) async {
    _revision++;
    final cmd = command['command'] as String?;

    if (cmd == 'hidePlace' || cmd == 'archivePlace') {
      final placeId = command['placeId'] as String?;
      final idx = _places.indexWhere((p) => p.id == placeId);
      if (idx != -1) {
        final cur = _places[idx];
        _places[idx] = AdminPlaceDraft(
          id: cur.id,
          destinationId: cur.destinationId,
          name: cur.name,
          slug: cur.slug,
          description: cur.description,
          latitude: cur.latitude,
          longitude: cur.longitude,
          active: false,
        );
      }
    } else if (cmd == 'restorePlace') {
      final placeId = command['placeId'] as String?;
      final idx = _places.indexWhere((p) => p.id == placeId);
      if (idx != -1) {
        final cur = _places[idx];
        _places[idx] = AdminPlaceDraft(
          id: cur.id,
          destinationId: cur.destinationId,
          name: cur.name,
          slug: cur.slug,
          description: cur.description,
          latitude: cur.latitude,
          longitude: cur.longitude,
          active: true,
        );
      }
    } else if (cmd == 'createPlace') {
      final newPlace = AdminPlaceDraft(
        id: 'p-new-${DateTime.now().millisecondsSinceEpoch}',
        destinationId: command['destinationId'] as String? ?? 'da-lat',
        name: command['name'] as String? ?? 'Địa điểm mới',
        slug: command['slug'] as String? ?? 'dia-diem-moi',
        description: command['description'] as String? ?? '',
        active: true,
      );
      _places.add(newPlace);
    } else if (cmd == 'updatePlace') {
      final placeId = command['placeId'] as String?;
      final idx = _places.indexWhere((p) => p.id == placeId);
      if (idx != -1) {
        final cur = _places[idx];
        _places[idx] = AdminPlaceDraft(
          id: cur.id,
          destinationId: cur.destinationId,
          name: command['name'] as String? ?? cur.name,
          slug: cur.slug,
          description: command['description'] as String? ?? cur.description,
          latitude: cur.latitude,
          longitude: cur.longitude,
          active: cur.active,
        );
      }
    }

    return read();
  }
}

// =============================================================================
// 3. DEMO ADMIN PUBLICATION SERVICE (XUẤT BẢN SANDBOX)
// =============================================================================

class DemoAdminPublicationService implements AdminPublicationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PublicationPreview> preview({
    required String requestId,
    required int draftRevision,
  }) async {
    return PublicationPreview(
      previewId: 'prev-sandbox-01',
      sourceRevision: draftRevision,
      expectedActiveVersion: 1,
      previewDigest: 'digest-sandbox-01',
      summary: const PublicationSummary(added: 0, changed: 1, hidden: 0),
      warnings: const [],
      blockers: const [],
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<PublicationOperation> publish({
    required String requestId,
    required PublicationPreview preview,
    required int expectedDraftRevision,
    required int expectedActiveVersion,
  }) async {
    return PublicationOperation(
      id: 'op-sandbox-01',
      state: 'completed',
      version: expectedActiveVersion + 1,
      sourceRevision: expectedDraftRevision,
    );
  }

  @override
  Future<PublicationOperation> operation(String operationId) async {
    return PublicationOperation(
      id: operationId,
      state: 'completed',
      version: 2,
      sourceRevision: 1,
    );
  }
}

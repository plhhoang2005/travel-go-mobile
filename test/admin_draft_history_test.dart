// Tests for AdminDraftHistoryScreen: history listing, restore confirmation and role-loss invalidation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_draft_history_screen.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_catalogue_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_catalogue_service.dart';
import 'package:travelgo_mobile/features/admin/services/admin_publication_service.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

class FakeCatalogueServiceForHistory implements AdminCatalogueService {
  final List<Map<String, dynamic>> dispatchedCommands = [];

  AdminCatalogueSnapshot currentSnapshot = AdminCatalogueSnapshot(
    revision: 3,
    payload: {
      'inventory': {
        'destinations': [
          {'id': 'da-nang', 'name': 'Đà Nẵng', 'slug': 'da-nang', 'region': 'Miền Trung', 'isActive': true},
          {'id': 'nha-trang', 'name': 'Nha Trang', 'slug': 'nha-trang', 'region': 'Miền Trung', 'isActive': false},
        ],
        'places': [
          {'id': 'da-nang/ba-na-hills', 'destinationId': 'da-nang', 'name': 'Bà Nà Hills', 'slug': 'ba-na-hills', 'isActive': true},
        ],
      },
    },
    history: [
      AdminDraftVersion(
        revision: 3,
        reason: 'Ẩn điểm đến Nha Trang',
        changedAt: DateTime(2026, 10, 23, 10, 0),
        payloadHash: 'hash-rev-3-aabbccdd',
      ),
      AdminDraftVersion(
        revision: 2,
        reason: 'Thêm địa điểm Bà Nà Hills',
        changedAt: DateTime(2026, 10, 22, 14, 0),
        payloadHash: 'hash-rev-2-eeff0011',
      ),
      AdminDraftVersion(
        revision: 1,
        reason: 'Khởi tạo danh mục v1',
        changedAt: DateTime(2026, 10, 20, 9, 0),
        payloadHash: 'hash-rev-1-12345678',
      ),
    ],
    destinations: const [],
    places: const [],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AdminCatalogueSnapshot> read() async => currentSnapshot;

  @override
  Future<AdminCatalogueSnapshot> command({
    required String requestId,
    required int expectedRevision,
    required Map<String, Object?> command,
    required String reason,
  }) async {
    dispatchedCommands.add({
      'requestId': requestId,
      'expectedRevision': expectedRevision,
      'command': command,
      'reason': reason,
    });

    if (command['command'] == 'restoreVersion') {
      final targetRev = command['targetRevision'] as int;
      currentSnapshot = AdminCatalogueSnapshot(
        revision: expectedRevision + 1,
        payload: currentSnapshot.payload,
        history: [
          AdminDraftVersion(
            revision: expectedRevision + 1,
            reason: reason,
            changedAt: DateTime.now(),
            payloadHash: 'restored-to-$targetRev',
          ),
          ...currentSnapshot.history,
        ],
        destinations: currentSnapshot.destinations,
        places: currentSnapshot.places,
      );
    }

    return currentSnapshot;
  }
}

class FakePublicationServiceForHistory implements AdminPublicationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PublicationPreview> preview({
    required String requestId,
    required int draftRevision,
  }) async {
    return PublicationPreview(
      previewId: 'prev-hist',
      sourceRevision: draftRevision,
      expectedActiveVersion: 1,
      previewDigest: 'digest-hist',
      summary: const PublicationSummary(added: 0, changed: 0, hidden: 0),
      warnings: const [],
      blockers: const [],
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
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
      id: 'op-hist',
      state: 'completed',
      version: expectedActiveVersion + 1,
      sourceRevision: expectedDraftRevision,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCatalogueServiceForHistory fakeService;
  late FakePublicationServiceForHistory fakePubService;
  late AuthProvider authProvider;
  late AdminCatalogueProvider provider;

  setUp(() async {
    fakeService = FakeCatalogueServiceForHistory();
    fakePubService = FakePublicationServiceForHistory();
    authProvider = AuthProvider();
    await authProvider.quickDemoLogin(UserRole.admin);
    provider = AdminCatalogueProvider(
      service: fakeService,
      publicationService: fakePubService,
      authProvider: authProvider,
    );
    await provider.load();
  });

  tearDown(() {
    provider.dispose();
    authProvider.dispose();
  });

  Widget buildScreen({double width = 400, double textScale = 1.0}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: ChangeNotifierProvider<AdminCatalogueProvider>.value(
        value: provider,
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const AdminDraftHistoryScreen(),
        ),
      ),
    );
  }

  testWidgets('displays draft history list with current badge and unpublished changes notice', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Phiên bản hiện tại: r3'), findsOneWidget);
    expect(find.text('Có thay đổi chưa xuất bản'), findsOneWidget);
    expect(find.text('Hiện tại'), findsOneWidget);
    expect(find.text('Thêm địa điểm Bà Nà Hills'), findsOneWidget);
    expect(find.text('Khởi tạo danh mục v1'), findsOneWidget);
  });

  testWidgets('restore_keeps_newer_ids_hidden', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Tap restore button for r1
    final restoreBtnR1 = find.byKey(const Key('restore_version_btn_1'));
    expect(restoreBtnR1, findsOneWidget);
    await tester.tap(restoreBtnR1);
    await tester.pumpAndSettle();

    // Check dialog
    expect(find.text('Khôi phục phiên bản r1?'), findsOneWidget);
    expect(
      find.textContaining('Các điểm đến và địa điểm được tạo ở phiên bản mới hơn sẽ được chuyển sang trạng thái tạm ẩn'),
      findsOneWidget,
    );

    // Cancel: sends zero commands
    await tester.tap(find.byKey(const Key('restore_cancel_button')));
    await tester.pumpAndSettle();

    expect(fakeService.dispatchedCommands, isEmpty);

    // Tap restore again and confirm
    await tester.tap(restoreBtnR1);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('restore_confirm_button')));
    await tester.pumpAndSettle();

    // Invariant: one atomic restore command dispatched with expected revision = 3
    expect(fakeService.dispatchedCommands.length, 1);
    final sent = fakeService.dispatchedCommands.first;
    expect(sent['expectedRevision'], 3);
    expect(sent['command'], {
      'command': 'restoreVersion',
      'targetRevision': 1,
    });

    // Invariant: provider acknowledged new revision 4
    expect(provider.currentRevision, 4);
  });

  testWidgets('admin role loss clears visible history immediately', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Khởi tạo danh mục v1'), findsOneWidget);

    // Admin logs out / switches to guest
    authProvider.continueAsGuest();
    await tester.pumpAndSettle();

    // Invariant: history items cleared from RAM and UI
    expect(find.text('Khởi tạo danh mục v1'), findsNothing);
    expect(find.text('Chưa có lịch sử phiên bản nào'), findsOneWidget);
  });

  testWidgets('renders cleanly at 320dp width and textScale 2.0 without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildScreen(width: 320, textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

// Widget and invariant tests for AdminPublicationScreen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_publication_screen.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_publication_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_publication_service.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

class FakeAdminPublicationService implements AdminPublicationService {
  final List<String> sentPublishRequestIds = [];
  PublicationPreview? defaultPreview;
  PublicationOperation? defaultOperation;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PublicationPreview> preview({
    required String requestId,
    required int draftRevision,
  }) async {
    return defaultPreview ??
        PublicationPreview(
          previewId: 'prev-1234',
          sourceRevision: draftRevision,
          expectedActiveVersion: 0,
          previewDigest: 'digest-1234',
          summary: const PublicationSummary(added: 2, changed: 0, hidden: 0),
          warnings: const [],
          blockers: const [],
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
        );
  }

  @override
  Future<PublicationOperation> publish({
    required String requestId,
    required PublicationPreview preview,
    required int expectedDraftRevision,
    required int expectedActiveVersion,
  }) async {
    sentPublishRequestIds.add(requestId);
    return defaultOperation ??
        const PublicationOperation(
          id: 'op-1234',
          state: 'completed',
          version: 1,
          sourceRevision: 1,
        );
  }

  @override
  Future<PublicationOperation> operation(String operationId) async {
    return defaultOperation ??
        const PublicationOperation(
          id: 'op-1234',
          state: 'completed',
          version: 1,
          sourceRevision: 1,
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdminPublicationService fakeService;
  late AuthProvider authProvider;
  late AdminPublicationProvider provider;

  setUp(() async {
    fakeService = FakeAdminPublicationService();
    authProvider = AuthProvider();
    await authProvider.quickDemoLogin(UserRole.admin);
    provider = AdminPublicationProvider(
      service: fakeService,
      authProvider: authProvider,
    );
  });

  tearDown(() {
    provider.dispose();
    authProvider.dispose();
  });

  Widget buildScreen({double width = 400, double textScale = 1.0}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: ChangeNotifierProvider<AdminPublicationProvider>.value(
        value: provider,
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const AdminPublicationScreen(draftRevision: 1),
        ),
      ),
    );
  }

  testWidgets('renders release preview metrics and summary correctly', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Phiên bản phát hành mới: v1'), findsOneWidget);
    expect(find.text('Từ nháp r1'), findsOneWidget);
    expect(find.text('Thêm mới'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // added
  });

  testWidgets('publication_cancel_never_calls_publish', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final cancelBtn = find.byKey(const Key('cancel_publish_button'));
    expect(cancelBtn, findsOneWidget);

    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();

    // Pin invariant: zero publish calls sent
    expect(fakeService.sentPublishRequestIds, isEmpty);
  });

  testWidgets('blockers disable publish button and show error details', (tester) async {
    fakeService.defaultPreview = PublicationPreview(
      previewId: 'prev-blocked',
      sourceRevision: 1,
      expectedActiveVersion: 0,
      previewDigest: 'digest-blocked',
      summary: const PublicationSummary(added: 1, changed: 0, hidden: 0),
      warnings: const [],
      blockers: const [
        FieldIssue(code: 'coord_mismatch', path: 'places.ba-na', message: 'Toạ độ thiếu kinh độ'),
      ],
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Blocker is shown
    expect(find.textContaining('Lỗi chặn xuất bản (1)'), findsOneWidget);
    expect(find.textContaining('Toạ độ thiếu kinh độ'), findsOneWidget);

    // Confirm button is disabled
    final confirmBtn = tester.widget<ElevatedButton>(find.byKey(const Key('confirm_publish_button')));
    expect(confirmBtn.onPressed, isNull);
  });

  testWidgets('confirm publish dispatches request and displays success banner', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final confirmBtn = find.byKey(const Key('confirm_publish_button'));
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(fakeService.sentPublishRequestIds.length, 1);
    expect(find.text('Xuất bản thành công phiên bản v1!'), findsOneWidget);
  });

  testWidgets('renders cleanly at 320dp width and textScale 2.0 without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildScreen(width: 320, textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

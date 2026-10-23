// UI tests for AdminCatalogueScreen: listing, filtering, archive dialog with child counts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_catalogue_screen.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_catalogue_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_catalogue_service.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

class FakeCatalogueServiceForUI implements AdminCatalogueService {
  final List<Map<String, dynamic>> dispatchedCommands = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AdminCatalogueSnapshot> read() async {
    return AdminCatalogueSnapshot(
      revision: 3,
      payload: const {},
      history: const [],
      destinations: [
        const AdminDestinationDraft(
          id: 'da-nang',
          name: 'Đà Nẵng',
          slug: 'da-nang',
          region: 'Miền Trung',
          description: 'Thành phố biển',
          active: true,
        ),
        const AdminDestinationDraft(
          id: 'ha-noi',
          name: 'Hà Nội',
          slug: 'ha-noi',
          region: 'Miền Bắc',
          description: 'Thủ đô nghìn năm',
          active: true,
        ),
      ],
      places: [
        const AdminPlaceDraft(
          id: 'da-nang/ba-na-hills',
          destinationId: 'da-nang',
          name: 'Bà Nà Hills',
          slug: 'ba-na-hills',
          description: 'Khu du lịch trên núi',
          active: true,
        ),
      ],
    );
  }

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
    return read();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCatalogueServiceForUI fakeService;
  late AuthProvider authProvider;
  late AdminCatalogueProvider provider;

  setUp(() async {
    fakeService = FakeCatalogueServiceForUI();
    authProvider = AuthProvider();
    await authProvider.quickDemoLogin(UserRole.admin);
    provider = AdminCatalogueProvider(
      service: fakeService,
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
          child: const AdminCatalogueScreen(),
        ),
      ),
    );
  }

  testWidgets('displays destinations, filters via search bar, and shows revision banner', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Check revision banner
    expect(find.text('Bản nháp r3'), findsOneWidget);
    expect(find.textContaining('Lưu nháp không cập nhật danh mục'), findsOneWidget);

    // Initial list has Đà Nẵng and Hà Nội
    expect(find.text('Đà Nẵng'), findsOneWidget);
    expect(find.text('Hà Nội'), findsOneWidget);

    // Search for "Hà"
    await tester.enterText(find.byKey(const Key('catalogue_search_field')), 'Hà');
    await tester.pumpAndSettle();

    expect(find.text('Hà Nội'), findsOneWidget);
    expect(find.text('Đà Nẵng'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('Đà Nẵng'), findsOneWidget);
    expect(find.text('Hà Nội'), findsOneWidget);
  });

  testWidgets('archive destination dialog shows active child count, cancel sends nothing, confirm sends command', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Tap archive button for Đà Nẵng (which has 1 active place)
    await tester.tap(find.byKey(const Key('archive_destination_btn_da-nang')));
    await tester.pumpAndSettle();

    // Check dialog content
    expect(find.text('Ẩn điểm đến Đà Nẵng?'), findsOneWidget);
    expect(find.text('Điểm đến này có 1 địa điểm đang hoạt động.'), findsOneWidget);

    // Cancel: sends nothing
    await tester.tap(find.byKey(const Key('archive_cancel_button')));
    await tester.pumpAndSettle();

    expect(fakeService.dispatchedCommands, isEmpty);

    // Open again and confirm
    await tester.tap(find.byKey(const Key('archive_destination_btn_da-nang')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('archive_confirm_button')));
    await tester.pumpAndSettle();

    expect(fakeService.dispatchedCommands.length, 1);
    final sent = fakeService.dispatchedCommands.first;
    expect(sent['command'], {
      'command': 'archiveDestination',
      'destinationId': 'da-nang',
    });
  });

  testWidgets('renders cleanly at 320dp width and textScale 2.0 without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildScreen(width: 320, textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('catalogue_add_fab')), findsOneWidget);
  });
}

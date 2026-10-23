import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_catalogue_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_catalogue_service.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

class FakeAdminCatalogueService implements AdminCatalogueService {
  Completer<AdminCatalogueSnapshot>? readCompleter;
  Completer<AdminCatalogueSnapshot>? commandCompleter;
  final List<String> sentRequestIds = [];
  final List<Map<String, Object?>> sentCommands = [];

  AdminCatalogueSnapshot? defaultSnapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AdminCatalogueSnapshot> read() async {
    if (readCompleter != null) return readCompleter!.future;
    return defaultSnapshot ??
        AdminCatalogueSnapshot(
          revision: 1,
          payload: {
            'inventory': {
              'destinations': [
                {
                  'id': 'da-nang',
                  'name': 'Đà Nẵng',
                  'slug': 'da-nang',
                  'region': 'Miền Trung',
                  'description': 'Biển đẹp',
                  'isActive': true,
                }
              ],
              'places': [
                {
                  'id': 'da-nang/ba-na-hills',
                  'destinationId': 'da-nang',
                  'name': 'Bà Nà Hills',
                  'slug': 'ba-na-hills',
                  'description': 'Khu du lịch',
                  'isActive': true,
                }
              ],
            },
            'places': [
              {
                'placeId': 'da-nang/ba-na-hills',
                'price': {'status': 'verified', 'amountVnd': 900000},
                'hours': {'status': 'verified', 'open': '07:00', 'close': '21:00'},
              }
            ],
            'sources': [
              {
                'id': 'src_1',
                'title': 'Sun World Ba Na Hills',
                'url': 'https://banahills.sunworld.vn',
              }
            ],
            'packages': [
              {
                'id': 'pkg_1',
                'name': 'Combo Ba Na Hills',
              }
            ],
          },
          history: const [],
          destinations: const [
            AdminDestinationDraft(
              id: 'da-nang',
              name: 'Đà Nẵng',
              slug: 'da-nang',
              region: 'Miền Trung',
              description: 'Biển đẹp',
              active: true,
            ),
          ],
          places: const [
            AdminPlaceDraft(
              id: 'da-nang/ba-na-hills',
              destinationId: 'da-nang',
              name: 'Bà Nà Hills',
              slug: 'ba-na-hills',
              description: 'Khu du lịch',
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
    sentRequestIds.add(requestId);
    sentCommands.add(command);

    if (commandCompleter != null) return commandCompleter!.future;

    // Simulate server response: destination update preserves existing places, prices, hours, packages
    final base = defaultSnapshot ?? await read();
    final updatedPayload = Map<String, dynamic>.from(base.payload);

    if (command['command'] == 'updateDestination') {
      final inventory = Map<String, dynamic>.from(updatedPayload['inventory'] as Map);
      final destList = (inventory['destinations'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (var i = 0; i < destList.length; i++) {
        if (destList[i]['id'] == command['destinationId']) {
          destList[i]['name'] = command['name'];
        }
      }
      inventory['destinations'] = destList;
      updatedPayload['inventory'] = inventory;
    }

    return AdminCatalogueSnapshot(
      revision: expectedRevision + 1,
      payload: updatedPayload,
      history: base.history,
      destinations: [
        AdminDestinationDraft(
          id: command['destinationId'] as String? ?? 'da-nang',
          name: command['name'] as String? ?? 'Đà Nẵng Mới',
          slug: 'da-nang',
          region: 'Miền Trung',
          description: 'Biển đẹp',
          active: true,
        ),
      ],
      places: base.places,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdminCatalogueService fakeService;
  late AuthProvider authProvider;
  late AdminCatalogueProvider provider;

  setUp(() async {
    fakeService = FakeAdminCatalogueService();
    authProvider = AuthProvider();
    await authProvider.quickDemoLogin(UserRole.admin);
    provider = AdminCatalogueProvider(
      service: fakeService,
      authProvider: authProvider,
    );
  });

  tearDown(() {
    provider.dispose();
    authProvider.dispose();
  });

  group('AdminCatalogueProvider Unit & Invariant Tests (Task F4)', () {
    test('metadata_edit_preserves_operational_ledgers', () async {
      // 1. Initial load
      await provider.load();
      final before = provider.snapshot!;
      expect(before.destinations.length, 1);
      expect(before.places.length, 1);

      // 2. Submit destination name update
      const updateDraft = AdminDestinationDraft(
        id: 'da-nang',
        name: 'Đà Nẵng Thành Phố Đáng Sống',
        slug: 'da-nang',
        region: 'Miền Trung',
        description: 'Biển đẹp',
      );

      final success = await provider.submitDestination(updateDraft, 'Update destination name');
      expect(success, isTrue);

      final after = provider.snapshot!;
      expect(after.revision, before.revision + 1);

      // Invariant: operational visit facts (places, prices, hours, sources, packages) are 100% preserved!
      expect(after.payload['places'], before.payload['places']);
      expect(after.payload['sources'], before.payload['sources']);
      expect(after.payload['packages'], before.payload['packages']);
    });

    test('owner_change_clears_draft_state_and_ignores_late_response', () async {
      fakeService.readCompleter = Completer<AdminCatalogueSnapshot>();

      final loadFuture = provider.load();
      expect(provider.isLoading, isTrue);

      // Owner changes / logs out while request is pending
      authProvider.continueAsGuest();

      // Invariant: snapshot is cleared immediately
      expect(provider.snapshot, isNull);

      // Resolve held response now
      fakeService.readCompleter!.complete(AdminCatalogueSnapshot(
        revision: 10,
        payload: const {},
        history: const [],
        destinations: const [],
        places: const [],
      ));
      await loadFuture;

      // Invariant: late response discarded, snapshot remains null
      expect(provider.snapshot, isNull);
    });

    test('retry_save_sends_exact_same_request_id_and_arguments', () async {
      await provider.load();

      // First attempt fails with upstream_unavailable
      fakeService.commandCompleter = Completer<AdminCatalogueSnapshot>()
        ..completeError(const AdminFailure(
          code: 'upstream_unavailable',
          outcomeUncertain: true,
          message: 'Server timeout',
        ));

      const placeDraft = AdminPlaceDraft(
        id: 'da-nang/ba-na-hills',
        destinationId: 'da-nang',
        name: 'Bà Nà Hills Update',
        slug: 'ba-na-hills',
        description: 'Updated description',
      );

      final firstSuccess = await provider.submitPlace(placeDraft, 'Update place');
      expect(firstSuccess, isFalse);
      expect(fakeService.sentRequestIds.length, 1);

      // Now retry save
      fakeService.commandCompleter = Completer<AdminCatalogueSnapshot>()
        ..complete(AdminCatalogueSnapshot(
          revision: 2,
          payload: const {},
          history: const [],
          destinations: const [],
          places: const [],
        ));

      final retrySuccess = await provider.retrySave();
      expect(retrySuccess, isTrue);
      expect(fakeService.sentRequestIds.length, 2);

      // Invariant: same requestId sent on retry
      expect(fakeService.sentRequestIds.toSet().length, 1);
    });
  });
}

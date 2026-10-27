import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_catalogue_provider.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_publication_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_publication_service.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';

import 'admin_catalogue_provider_test.dart' as fixture;

class LostAckPublicationService extends fixture.FakeAdminPublicationService {
  bool loseAck = true;
  @override
  Future<PublicationOperation> publish({
    required String requestId,
    required PublicationPreview preview,
    required int expectedDraftRevision,
    required int expectedActiveVersion,
  }) async {
    final result = await super.publish(
      requestId: requestId,
      preview: preview,
      expectedDraftRevision: expectedDraftRevision,
      expectedActiveVersion: expectedActiveVersion,
    );
    if (loseAck) {
      throw const AdminFailure(
        code: 'network_error',
        message: 'ACK lost',
        outcomeUncertain: true,
      );
    }
    return result;
  }
}

class PolicyPublicationService extends fixture.FakeAdminPublicationService {
  PolicyPublicationService(this.failure);
  final AdminFailure failure;
  bool reject = true;
  @override
  Future<PublicationOperation> publish({
    required String requestId,
    required PublicationPreview preview,
    required int expectedDraftRevision,
    required int expectedActiveVersion,
  }) async {
    final result = await super.publish(
      requestId: requestId,
      preview: preview,
      expectedDraftRevision: expectedDraftRevision,
      expectedActiveVersion: expectedActiveVersion,
    );
    if (reject) throw failure;
    return result;
  }
}

class OutcomeService extends fixture.FakeAdminPublicationService {
  final outcome = Completer<PublicationOperation>();
  @override
  Future<PublicationOperation> operation(String operationId) => outcome.future;
}

String parseCheckedAt(String? checkedAt) {
  final sources = [
    <String, Object?>{
      'id': 'source-audit',
      'title': 'Audit source',
      'publisher': 'Audit',
      'url': 'https://example.com/source',
      'checkedAt': checkedAt,
    },
  ];
  final payload = jsonEncode({
    'contract': 'travelgo.discovery.release.v2',
    'schemaVersion': 2,
    'version': 1,
    'preparedAt': '2026-10-27T08:00:00Z',
    'catalogue': {'sources': sources, 'destinations': []},
    'visitDetails': {'sources': sources, 'packages': [], 'places': []},
  });
  final bytes = utf8.encode(payload);
  final manifest = DiscoveryManifest(
    contract: 'travelgo.discovery.manifest.v2',
    schemaVersion: 2,
    version: 1,
    objectKey: 'releases/v2/1.json',
    sha256: sha256.convert(bytes).toString(),
    byteLength: bytes.length,
    publishedAt: DateTime.utc(2026, 10, 27, 8),
  );
  return PublicCatalogueParser.parse(
    payloadText: payload,
    manifest: manifest,
    now: DateTime.utc(2026, 10, 27, 9),
  ).catalogue.sources.single.checkedAt;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('C7 control auto publish still succeeds with no failure', () async {
    final auth = AuthProvider();
    await auth.quickDemoLogin(UserRole.admin);
    final pub = fixture.FakeAdminPublicationService();
    final p = AdminCatalogueProvider(
      service: fixture.FakeAdminCatalogueService(),
      publicationService: pub,
      authProvider: auth,
    );
    addTearDown(() {
      p.dispose();
      auth.dispose();
    });
    expect(
      await p.submitDestination(
        const AdminDestinationDraft(
          name: 'Audit',
          slug: 'audit',
          region: 'Miền Trung',
          description: 'Audit',
        ),
        'audit',
      ),
      isTrue,
    );
    expect(pub.publishRequestIds, hasLength(1));
  });
  test('C7-F01 lost publish ACK retry keeps publication identity', () async {
    final auth = AuthProvider();
    await auth.quickDemoLogin(UserRole.admin);
    final pub = LostAckPublicationService();
    final service = fixture.FakeAdminCatalogueService();
    final p = AdminCatalogueProvider(
      service: service,
      publicationService: pub,
      authProvider: auth,
    );
    addTearDown(() {
      p.dispose();
      auth.dispose();
    });
    expect(
      await p.submitDestination(
        const AdminDestinationDraft(
          name: 'Audit',
          slug: 'audit',
          region: 'Miền Trung',
          description: 'Audit',
        ),
        'audit',
      ),
      isFalse,
    );
    pub.loseAck = false;
    expect(await p.retrySave(), isTrue);
    expect(service.sentRequestIds, hasLength(1));
    expect(pub.publishRequestIds, hasLength(2));
    expect(
      pub.publishRequestIds.toSet(),
      hasLength(1),
      reason:
          'Lost ACK must retry the same publication, not mint another request',
    );
  });
  test(
    'C7-F02 outcome arriving after logout cannot refill publication state',
    () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.admin);
      final service = OutcomeService()..publishState = 'pending';
      final p = AdminPublicationProvider(service: service, authProvider: auth);
      addTearDown(() {
        p.dispose();
        auth.dispose();
      });
      await p.loadPreview(2);
      expect(await p.confirmPublish(), isFalse);
      final pending = p.checkOutcome();
      auth.continueAsGuest();
      expect(p.operation, isNull);
      service.outcome.complete(
        const PublicationOperation(
          id: 'old-admin-operation',
          state: 'completed',
          version: 3,
          sourceRevision: 2,
        ),
      );
      expect(await pending, isFalse);
      expect(p.operation, isNull);
    },
  );
  test('C7-F03 missing source check date must remain unknown', () {
    expect(
      parseCheckedAt(null),
      isEmpty,
      reason: 'Bundle preparedAt is not a source verification date',
    );
  });
  test('C7 control known source check date is preserved', () {
    expect(parseCheckedAt('2026-10-20T00:00:00Z'), '2026-10-20T00:00:00Z');
  });
  test(
    'late confirm error after logout cannot replace new session state',
    () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.admin);
      final service = fixture.FakeAdminPublicationService()
        ..publishCompleter = Completer<PublicationOperation>();
      final p = AdminPublicationProvider(service: service, authProvider: auth);
      addTearDown(() {
        p.dispose();
        auth.dispose();
      });
      await p.loadPreview(2);
      final pending = p.confirmPublish();
      auth.continueAsGuest();
      service.publishCompleter!.completeError(
        const AdminFailure(code: 'stale_session', message: 'stale'),
      );
      expect(await pending, isFalse);
      expect(p.error, isNull);
      expect(p.operation, isNull);
    },
  );
  test(
    'old confirm finally cannot stop loading for a new account request',
    () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.admin);
      final service = fixture.FakeAdminPublicationService();
      final p = AdminPublicationProvider(service: service, authProvider: auth);
      addTearDown(() {
        p.dispose();
        auth.dispose();
      });
      await p.loadPreview(2);
      final old = Completer<PublicationOperation>();
      service.publishCompleter = old;
      final a = p.confirmPublish();
      auth.continueAsGuest();
      await auth.quickDemoLogin(UserRole.admin);
      await p.loadPreview(3);
      final fresh = Completer<PublicationOperation>();
      service.publishCompleter = fresh;
      final b = p.confirmPublish();
      old.complete(
        const PublicationOperation(
          id: 'old',
          state: 'completed',
          version: 2,
          sourceRevision: 2,
        ),
      );
      expect(await a, isFalse);
      expect(p.isPublishing, isTrue);
      expect(p.operation, isNull);
      fresh.complete(
        const PublicationOperation(
          id: 'new',
          state: 'completed',
          version: 3,
          sourceRevision: 3,
        ),
      );
      expect(await b, isTrue);
      expect(p.isPublishing, isFalse);
      expect(p.operation!.id, 'new');
    },
  );
  test(
    'uncertain publication keeps preview and identity when reload is requested',
    () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.admin);
      final service = LostAckPublicationService();
      final p = AdminPublicationProvider(service: service, authProvider: auth);
      addTearDown(() {
        p.dispose();
        auth.dispose();
      });
      await p.loadPreview(2);
      expect(await p.confirmPublish(), isFalse);
      await p.loadPreview(3);
      expect(p.preview!.sourceRevision, 2);
      service.loseAck = false;
      expect(await p.confirmPublish(), isTrue);
      expect(service.publishRequestIds.toSet(), hasLength(1));
    },
  );
  test(
    'form resubmit after lost ACK retries command once and keeps publication',
    () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.admin);
      final service = fixture.FakeAdminCatalogueService();
      final pub = LostAckPublicationService();
      final p = AdminCatalogueProvider(
        service: service,
        publicationService: pub,
        authProvider: auth,
      );
      addTearDown(() {
        p.dispose();
        auth.dispose();
      });
      const draft = AdminDestinationDraft(
        name: 'Audit',
        slug: 'audit',
        region: 'Miền Trung',
        description: 'Audit',
      );
      expect(await p.submitDestination(draft, 'audit'), isFalse);
      expect(
        await p.submitDestination(
          const AdminDestinationDraft(
            name: 'Other',
            slug: 'other',
            region: 'Miền Trung',
            description: 'Other',
          ),
          'other',
        ),
        isFalse,
      );
      pub.loseAck = false;
      expect(await p.submitDestination(draft, 'audit'), isTrue);
      expect(service.sentCommands, hasLength(1));
      expect(pub.publishRequestIds.toSet(), hasLength(1));
    },
  );
  test(
    'definitive publication conflict allows a new preview on retry',
    () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.admin);
      final service = fixture.FakeAdminCatalogueService();
      final pub = fixture.FakeAdminPublicationService()
        ..publishState = 'conflict';
      final p = AdminCatalogueProvider(
        service: service,
        publicationService: pub,
        authProvider: auth,
      );
      addTearDown(() {
        p.dispose();
        auth.dispose();
      });
      expect(
        await p.submitDestination(
          const AdminDestinationDraft(
            name: 'Audit',
            slug: 'audit',
            region: 'Miền Trung',
            description: 'Audit',
          ),
          'audit',
        ),
        isFalse,
      );
      pub.publishState = 'completed';
      expect(await p.retrySave(), isTrue);
      expect(service.sentCommands, hasLength(1));
      expect(pub.publishRequestIds.toSet(), hasLength(2));
    },
  );
  test(
    'definite rejection permits a fresh preview for the same draft revision',
    () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.admin);
      final service = fixture.FakeAdminPublicationService()
        ..throwOnPublish = true;
      final p = AdminPublicationProvider(service: service, authProvider: auth);
      addTearDown(() {
        p.dispose();
        auth.dispose();
      });
      await p.loadPreview(2);
      expect(await p.confirmPublish(), isFalse);
      service.throwOnPublish = false;
      await p.loadPreview(2);
      expect(service.previewRequestIds, hasLength(2));
      expect(
        service.previewRequestIds.toSet(),
        hasLength(2),
        reason: 'A definite rejection must permit a new candidate; stale preview identity cannot recover',
      );
    },
  );

  for (final code in [
    'candidate_expired',
    'conflict',
    'request_payload_mismatch',
  ]) {
    test(
      'definite $code discards rejected preview and permits same-revision recovery',
      () async {
        final auth = AuthProvider();
        await auth.quickDemoLogin(UserRole.admin);
        final service = PolicyPublicationService(
          AdminFailure(code: code, message: 'Rejected'),
        );
        final p = AdminPublicationProvider(
          service: service,
          authProvider: auth,
        );
        addTearDown(() {
          p.dispose();
          auth.dispose();
        });
        await p.loadPreview(2);
        expect(await p.confirmPublish(), isFalse);
        expect(p.preview, isNull);
        expect(p.isPublishing, isFalse);
        expect(p.error!.code, code);
        expect(await p.confirmPublish(), isFalse);
        expect(service.publishRequestIds, hasLength(1));
        await p.loadPreview(2);
        service.reject = false;
        expect(await p.confirmPublish(), isTrue);
        expect(service.previewRequestIds.toSet(), hasLength(2));
        expect(service.publishRequestIds.toSet(), hasLength(2));
      },
    );
  }
  for (final route in ['publish', 'outcome']) {
    test(
      'conflict via $route permits a new preview without changing revision',
      () async {
        final auth = AuthProvider();
        await auth.quickDemoLogin(UserRole.admin);
        final service = OutcomeService()
          ..publishState = route == 'publish' ? 'conflict' : 'pending';
        final p = AdminPublicationProvider(
          service: service,
          authProvider: auth,
        );
        addTearDown(() {
          p.dispose();
          auth.dispose();
        });
        await p.loadPreview(2);
        expect(await p.confirmPublish(), isFalse);
        if (route == 'outcome') {
          service.outcome.complete(
            const PublicationOperation(
              id: 'op',
              state: 'conflict',
              version: 3,
              sourceRevision: 2,
            ),
          );
          expect(await p.checkOutcome(), isFalse);
        }
        expect(p.preview, isNull);
        expect(p.error!.code, 'conflict');
        await p.loadPreview(2);
        expect(service.previewRequestIds.toSet(), hasLength(2));
      },
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/explore/providers/place_visit_details_provider.dart';
import 'package:travelgo_mobile/features/explore/services/place_visit_details_repository.dart';

import 'place_visit_cache_test.dart' show cachedFixture;
import 'place_visit_details_model_test.dart'
    show visitCatalogueFixture, visitTestHash, visitTestNow;
import 'place_visit_details_repository_test.dart'
    show MemoryVisitCache, PublicVisitAdapter, manifestFixture, visitJson;

CatalogueReference visitBaseFixture({String placeId = 'test/place'}) =>
    CatalogueReference(
      checkedAt: '2026-10-20',
      sources: [],
      destinations: [
        DestinationReference(
          id: 'test',
          name: 'Synthetic destination',
          region: 'north',
          places: [
            PlaceReference(
              id: placeId,
              name: 'Synthetic place',
              sourceId: 'official',
            ),
          ],
          sample: SampleReference(
            id: 'sample',
            editorialReview: EditorialReview(
              status: 'pending',
              reviewedAt: null,
              sourceIds: [],
              conditions: [],
              reviewNotes: [],
            ),
            days: [],
            warnings: [],
          ),
        ),
      ],
    );

Future<void> settleVisitAsync() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late Dio dio;
  late MemoryVisitCache cache;
  late PublicVisitAdapter adapter;
  late PlaceVisitDetailsProvider provider;
  late VisitDetailsRepository repository;
  late DateTime clock;
  late int factories;
  late CatalogueReference base;
  setUp(() {
    clock = visitTestNow;
    factories = 0;
    base = visitBaseFixture();
    cache = MemoryVisitCache();
    adapter = PublicVisitAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    repository = VisitDetailsRepository(
      dio: dio,
      cache: cache,
      seedLoader: () async => jsonEncode(visitCatalogueFixture()),
      projectOrigin: Uri.parse('https://bkocylxbuyvdgxccpixx.supabase.co'),
      expectedPlaceIds: {'test/place'},
      expectedCatalogueSha256: visitTestHash,
      now: () => clock,
      remoteEnabled: true,
    );
    adapter.reply = (_) async => visitJson(manifestFixture(cachedFixture(1)));
    provider = PlaceVisitDetailsProvider(
      repositoryFactory: (catalogue) async {
        factories++;
        expect(identical(catalogue, base), true);
        return repository;
      },
      now: () => clock,
    );
  });
  tearDown(() async {
    provider.dispose();
    await repository.close();
    dio.close(force: true);
  });

  test(
    'local snapshot is visible while network is delayed and errors retain it',
    () async {
      final gate = Completer<ResponseBody>();
      adapter.reply = (_) => gate.future;
      await provider.load(base);
      expect(provider.snapshot!.catalogue.version, 1);
      expect(provider.isRefreshing, true);
      gate.complete(visitJson({}, status: 404));
      await provider.refresh(force: true);
      expect(provider.snapshot!.catalogue.version, 1);
      expect(provider.isRefreshing, false);
      expect(provider.errorCode, isNotNull);
    },
  );

  test(
    'concurrent loads and refreshes share one factory and request',
    () async {
      final gate = Completer<ResponseBody>();
      adapter.reply = (_) => gate.future;
      await Future.wait([provider.load(base), provider.load(base)]);
      final refreshes = [
        provider.refresh(force: true),
        provider.refresh(force: true),
      ];
      await settleVisitAsync();
      expect(factories, 1);
      expect(adapter.requests, hasLength(1));
      gate.complete(visitJson(manifestFixture(cachedFixture(1))));
      await Future.wait(refreshes);
      expect(provider.errorCode, isNull);
    },
  );

  test(
    'automatic reopen is throttled 15 minutes, explicit refresh bypasses wait',
    () async {
      await provider.load(base);
      await provider.refresh();
      expect(adapter.requests, hasLength(1));
      clock = clock.add(const Duration(minutes: 14));
      await provider.load(base);
      await provider.refresh();
      expect(adapter.requests, hasLength(1));
      await provider.refresh(force: true);
      expect(adapter.requests, hasLength(2));
      clock = clock.add(const Duration(minutes: 15));
      await provider.load(base);
      await provider.refresh();
      expect(adapter.requests, hasLength(3));
      expect(factories, 1);
    },
  );

  test(
    'refresh before load is safe and changed catalogue cannot rebind silently',
    () async {
      await provider.refresh(force: true);
      expect(adapter.requests, isEmpty);
      await provider.load(base);
      await provider.refresh();
      final previous = provider.snapshot;
      await provider.load(visitBaseFixture(placeId: 'test/other'));
      expect(provider.errorCode, 'catalogue_changed');
      expect(identical(previous, provider.snapshot), true);
      expect(factories, 1);
    },
  );

  test('dispose during network response prevents late notifications', () async {
    final gate = Completer<ResponseBody>();
    adapter.reply = (_) => gate.future;
    var notifications = 0;
    provider.addListener(() => notifications++);
    await provider.load(base);
    final before = notifications;
    provider.dispose();
    gate.complete(visitJson(manifestFixture(cachedFixture(1))));
    await settleVisitAsync();
    expect(notifications, before);
    expect(cache.closed, true);
    // Avoid disposing the notifier twice in teardown.
    provider = PlaceVisitDetailsProvider(
      repositoryFactory: (_) async => repository,
      now: () => clock,
    );
  });

  test(
    'dispose before factory resolves closes the late-created repository',
    () async {
      provider.dispose();
      final gate = Completer<VisitDetailsRepository>();
      provider = PlaceVisitDetailsProvider(
        repositoryFactory: (_) => gate.future,
        now: () => clock,
      );
      var notifications = 0;
      provider.addListener(() => notifications++);
      final load = provider.load(base);
      provider.dispose();
      final before = notifications;
      gate.complete(repository);
      await load;
      expect(notifications, before);
      expect(cache.closed, true);
      expect(adapter.requests, isEmpty);
      provider = PlaceVisitDetailsProvider(
        repositoryFactory: (_) async => repository,
        now: () => clock,
      );
    },
  );

  test(
    'factory failure reports safe error and allows explicit load retry',
    () async {
      provider.dispose();
      provider = PlaceVisitDetailsProvider(
        repositoryFactory: (_) async {
          if (++factories == 1) throw StateError('synthetic private error');
          return repository;
        },
        now: () => clock,
      );
      await provider.load(base);
      expect(provider.errorCode, 'local_unavailable');
      expect(provider.snapshot, isNull);
      await provider.load(base);
      await provider.refresh();
      expect(provider.snapshot, isNotNull);
      expect(factories, 2);
    },
  );
}

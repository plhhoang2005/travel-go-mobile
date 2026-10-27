import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';

import 'catalogue_parser_test.dart' show catalogueData;
import 'public_catalogue_consumers_test.dart' show createSnapshot;

void main() {
  test(
    'dynamic place search folds accents and applies UI and V2 region labels',
    () {
      final provider = DiscoveryProvider();
      addTearDown(provider.dispose);
      provider.bindPublicSnapshot(
        createSnapshot(
          destinations: [
            {
              'id': 'coursework-phu-yen',
              'name': 'Phú Yên thử nghiệm',
              'region': 'Miền Trung',
              'places': [
                {
                  'id': 'coursework-phu-yen/dam-o-loan',
                  'destinationId': 'coursework-phu-yen',
                  'name': 'Đầm Ô Loan',
                  'sourceRefs': ['src-01'],
                },
              ],
            },
          ],
        ),
      );
      for (final query in [
        'dam o loan',
        'ĐẦM Ô LOAN',
        'Đa\u0302\u0300m O\u0302 Loan',
      ]) {
        provider.setQuery(query);
        provider.setRegion('Trung');
        expect(provider.visibleDestinations.single.id, 'coursework-phu-yen');
        provider.setRegion('Miền Trung');
        expect(provider.visibleDestinations.single.name, 'Phú Yên thử nghiệm');
        provider.setRegion('Bắc');
        expect(provider.visibleDestinations, isEmpty);
      }
      provider.bindPublicSnapshot(createSnapshot(version: 2));
      provider.setRegion(null);
      provider.setQuery('');
      expect(provider.visibleDestinations, isEmpty);
    },
  );

  test('failed refresh keeps catalogue with an explicit error state', () async {
    var fail = false;
    final provider = DiscoveryProvider(
      publicSnapshotLoader: (_) async {
        if (fail) throw StateError('offline');
        return createSnapshot();
      },
    );
    addTearDown(provider.dispose);
    await provider.load();
    final before = provider.catalogue;
    fail = true;
    await provider.load(force: true);
    expect(provider.catalogue, same(before));
    expect(provider.state, DiscoveryLoadState.error);
  });

  test(
    'search folds accents, combining marks, case, trim and preserves region',
    () async {
      final provider = DiscoveryProvider(
        repository: CatalogueRepository(
          loader: () async => jsonEncode(catalogueData()),
        ),
      );
      addTearDown(provider.dispose);
      await provider.load();
      expect(provider.visibleDestinations.length, 12);
      for (final q in ['  DA NANG ', 'Đà Nẵng', 'Đa\u0300 Nă\u0303ng']) {
        provider.setQuery(q);
        expect(provider.visibleDestinations.single.id, 'da-nang');
      }
      provider.setRegion('Bắc');
      expect(provider.visibleDestinations, isEmpty);
      provider.setQuery('');
      expect(provider.visibleDestinations.length, 4);
      provider.setRegion(null);
      expect(provider.visibleDestinations.length, 12);
      provider.setQuery('no such destination');
      expect(provider.visibleDestinations, isEmpty);
      expect(provider.state, DiscoveryLoadState.ready);
    },
  );
  test(
    'loader errors surface and explicit retry recovers without presets',
    () async {
      var calls = 0;
      final provider = DiscoveryProvider(
        repository: CatalogueRepository(
          loader: () async {
            if (++calls == 1) throw StateError('asset');
            return jsonEncode(catalogueData());
          },
        ),
      );
      addTearDown(provider.dispose);
      await provider.load();
      expect(provider.state, DiscoveryLoadState.error);
      expect(provider.visibleDestinations, isEmpty);
      await provider.load(force: true);
      expect(provider.visibleDestinations.length, 12);
      expect(calls, 2);
    },
  );
  test(
    'superseded load and disposed completion cannot publish or notify',
    () async {
      final loads = <Completer<String>>[];
      final provider = DiscoveryProvider(
        repository: CatalogueRepository(
          loader: () {
            final c = Completer<String>();
            loads.add(c);
            return c.future;
          },
        ),
      );
      final one = provider.load();
      final two = provider.load(force: true);
      loads[1].complete(jsonEncode(catalogueData()));
      await two;
      loads[0].completeError(StateError('old error'));
      await one;
      expect(provider.state, DiscoveryLoadState.ready);
      var notifications = 0;
      provider.addListener(() => notifications++);
      final three = provider.load(force: true);
      final before = notifications;
      provider.dispose();
      loads[2].complete(jsonEncode(catalogueData()));
      await three;
      expect(notifications, before);
    },
  );
}

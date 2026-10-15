import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';

import 'catalogue_parser_test.dart' show catalogueData;

void main() {
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

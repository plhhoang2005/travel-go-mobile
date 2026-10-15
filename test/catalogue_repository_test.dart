import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';

import 'catalogue_parser_test.dart' show catalogueData;

void main() {
  test(
    'repository returns loader failure and rejects malformed contents',
    () async {
      await expectLater(
        CatalogueRepository(loader: () => Future.error(StateError('disk')))
            .load(),
        throwsStateError,
      );
      await expectLater(
        CatalogueRepository(loader: () async => '{broken').load(),
        throwsFormatException,
      );
      await expectLater(
        CatalogueRepository(loader: () async => '{}').load(),
        throwsFormatException,
      );
    },
  );
  test('fresh loader reads preserve reference identities', () async {
    var calls = 0;
    final repository = CatalogueRepository(
      loader: () async {
        calls++;
        return jsonEncode(catalogueData());
      },
    );
    expect((await repository.load()).destinations.first.id, 'ha-noi');
    expect((await repository.load()).destinations.last.id, 'can-tho');
    expect(calls, 2);
  });
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reviewed source bytes equal bundled asset and rootBundle parses all twelve', () async {
    final source = File('docs/phase-2/catalogue/catalogue_readiness_v1.json')
        .readAsStringSync().replaceAll('\r\n', '\n');
    final asset = File('assets/catalogue/catalogue_readiness_v1.json')
        .readAsStringSync().replaceAll('\r\n', '\n');
    expect(asset, equals(source));
    final bundled = await rootBundle.loadString(
      'assets/catalogue/catalogue_readiness_v1.json',
    );
    expect(CatalogueParser().parse(bundled).destinations.length, 12);
  });
}

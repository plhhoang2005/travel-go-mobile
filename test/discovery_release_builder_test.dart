import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';

import '../tool/build_discovery_release.dart';
import 'place_visit_details_model_test.dart' show visitCatalogueFixture;

// Complete SYNTHETIC fixtures live only in a temporary test directory.
// Never upload this output as actual prices or visitor information.
void main() {
  late Directory directory;
  late String datasetPath, outputPath;
  late Map<String, dynamic> data;
  const basePath = 'assets/catalogue/catalogue_readiness_v1.json';
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'travelgo-release-fixture-',
    );
    datasetPath = '${directory.path}/synthetic.json';
    outputPath = '${directory.path}/output';
    final bytes = File(basePath).readAsBytesSync();
    final base = jsonDecode(utf8.decode(bytes));
    data = visitCatalogueFixture();
    data['catalogueSha256'] = sha256.convert(bytes).toString();
    data['places'] = [
      for (final destination in base['destinations'])
        for (final place in destination['places'])
          (jsonDecode(jsonEncode(visitCatalogueFixture()['places'][0]))
                as Map<String, dynamic>)
            ..['placeId'] = place['id'],
    ];
  });
  tearDown(() async => directory.delete(recursive: true));
  Future<void> save() =>
      File(datasetPath).writeAsString('${jsonEncode(data)}\n');

  test(
    'builder preserves raw UTF8 newline and creates matching immutable packet',
    () async {
      await save();
      final result = await buildDiscoveryRelease(
        datasetPath: datasetPath,
        cataloguePath: basePath,
        outputDirectory: outputPath,
      );
      final bytes = File(datasetPath).readAsBytesSync();
      expect(File(result.releasePath).readAsBytesSync(), bytes);
      expect(result.placeCount, 72);
      expect(result.sha256, sha256.convert(bytes).toString());
      final manifest = parseVisitManifest(
        File(result.manifestPath).readAsStringSync(),
      );
      expect(manifest.version, 1);
      expect(manifest.objectPath, 'releases/1.json');
      expect(manifest.byteLength, bytes.length);
      expect(manifest.sha256, result.sha256);
    },
  );

  test(
    'builder refuses an already reserved version without changing its bytes',
    () async {
      await save();
      final first = await buildDiscoveryRelease(
        datasetPath: datasetPath,
        cataloguePath: basePath,
        outputDirectory: outputPath,
      );
      final original = File(first.releasePath).readAsBytesSync();
      data['places'][0]['price']['options'][0]['amountVnd'] = 200;
      await save();
      await expectLater(
        buildDiscoveryRelease(
          datasetPath: datasetPath,
          cataloguePath: basePath,
          outputDirectory: outputPath,
        ),
        throwsA(isA<VisitDataException>()),
      );
      expect(File(first.releasePath).readAsBytesSync(), original);
    },
  );

  for (final failure in ['partial', 'missing', 'source', 'base-hash']) {
    test('$failure refuses publication packet before writing output', () async {
      switch (failure) {
        case 'partial':
          data['places'][0]['hours']['evidence']['reviewState'] = 'unverified';
        case 'missing':
          (data['places'] as List).removeLast();
        case 'source':
          data['places'][0]['price']['evidence']['sourceIds'] = ['absent'];
        case 'base-hash':
          data['catalogueSha256'] = '0' * 64;
      }
      await save();
      await expectLater(
        buildDiscoveryRelease(
          datasetPath: datasetPath,
          cataloguePath: basePath,
          outputDirectory: outputPath,
        ),
        throwsA(isA<VisitDataException>()),
      );
      expect(Directory(outputPath).existsSync(), false);
    });
  }
}

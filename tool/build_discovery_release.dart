import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';

class DiscoveryReleaseBuild {
  final int version, byteLength, placeCount;
  final String releasePath, manifestPath, sha256;
  const DiscoveryReleaseBuild({
    required this.version,
    required this.byteLength,
    required this.placeCount,
    required this.releasePath,
    required this.manifestPath,
    required this.sha256,
  });
}

/// Builds local files only. No network, credentials or upload capability.
Future<DiscoveryReleaseBuild> buildDiscoveryRelease({
  required String datasetPath,
  required String cataloguePath,
  required String outputDirectory,
}) async {
  final baseBytes = await File(cataloguePath).readAsBytes();
  final base = jsonDecode(utf8.decode(baseBytes)) as Map<String, dynamic>;
  final destinations = base['destinations'] as List;
  final ids = destinations
      .expand((d) => (d as Map<String, dynamic>)['places'] as List)
      .map((place) => (place as Map<String, dynamic>)['id'] as String)
      .toList();
  if (destinations.length != 12 ||
      ids.length != 72 ||
      ids.toSet().length != 72) {
    throw const VisitDataException('base_inventory');
  }
  final input = File(datasetPath);
  if (await input.length() > maxVisitReleaseBytes) {
    throw const VisitDataException('response_size');
  }
  final bytes = await input.readAsBytes();
  final catalogue = parseVisitCatalogue(
    utf8.decode(bytes),
    expectedPlaceIds: ids.toSet(),
    expectedCatalogueSha256: crypto.sha256.convert(baseBytes).toString(),
    now: DateTime.now(),
    requireComplete: true,
  );
  final digest = crypto.sha256.convert(bytes).toString();
  final versionDirectory = p.join(
    p.absolute(outputDirectory),
    '${catalogue.version}',
  );
  if (await FileSystemEntity.type(versionDirectory) !=
      FileSystemEntityType.notFound) {
    throw const VisitDataException('output_exists');
  }
  await Directory(outputDirectory).create(recursive: true);
  final reservation = File(
    p.join(outputDirectory, '.version-${catalogue.version}.claim'),
  );
  try {
    // Exclusive reservation also rejects concurrent builders of the same version.
    await reservation.create(exclusive: true);
  } on PathExistsException {
    throw const VisitDataException('output_exists');
  }
  final releasePath = p.join(
    versionDirectory,
    'releases',
    '${catalogue.version}.json',
  );
  final manifestPath = p.join(versionDirectory, 'latest.json');
  await Directory(p.dirname(releasePath)).create(recursive: true);
  await File(releasePath).create(exclusive: true);
  await File(releasePath).writeAsBytes(bytes, flush: true);
  final manifest = <String, Object>{
    'schemaVersion': 1,
    'version': catalogue.version,
    'objectPath': 'releases/${catalogue.version}.json',
    'sha256': digest,
    'byteLength': bytes.length,
    'publishedAt': catalogue.publishedAt.toUtc().toIso8601String(),
    'catalogueSha256': catalogue.catalogueSha256,
  };
  final manifestText =
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
  parseVisitManifest(manifestText);
  await File(manifestPath).create(exclusive: true);
  await File(manifestPath)
      .writeAsString(manifestText, encoding: utf8, flush: true);
  return DiscoveryReleaseBuild(
    version: catalogue.version,
    byteLength: bytes.length,
    placeCount: catalogue.places.length,
    releasePath: releasePath,
    manifestPath: manifestPath,
    sha256: digest,
  );
}

Future<void> main(List<String> args) async {
  const usage =
      'dart run tool/build_discovery_release.dart --dataset <json> '
      '--catalogue <base-json> --out <output-directory>';
  if (args.length == 1 && args.single == '--help') {
    stdout.writeln(usage);
    return;
  }
  final values = <String, String>{};
  if (args.length.isEven) {
    for (var index = 0; index < args.length; index += 2) {
      if (!{'--dataset', '--catalogue', '--out'}.contains(args[index]) ||
          values.containsKey(args[index])) {
        stderr.writeln(usage);
        exitCode = 2;
        return;
      }
      values[args[index]] = args[index + 1];
    }
  }
  if (values.length != 3) {
    stderr.writeln(usage);
    exitCode = 2;
    return;
  }
  try {
    final result = await buildDiscoveryRelease(
      datasetPath: values['--dataset']!,
      cataloguePath: values['--catalogue']!,
      outputDirectory: values['--out']!,
    );
    stdout.writeln(
      'Version ${result.version}; ${result.placeCount} places; ${result.byteLength} bytes',
    );
    stdout.writeln('SHA256 ${result.sha256}');
    stdout.writeln('Release: ${result.releasePath}');
    stdout.writeln('Manifest: ${result.manifestPath}');
  } catch (error) {
    stderr.writeln(
      'Release refused: ${error is VisitDataException ? error.code : 'build_failed'}',
    );
    exitCode = 1;
  }
}

import 'package:flutter/services.dart';

import '../models/catalogue_reference.dart';
import 'catalogue_parser.dart';

class CatalogueRepository {
  static const assetPath = 'assets/catalogue/catalogue_readiness_v1.json';
  final Future<String> Function() _loader;
  final CatalogueParser _parser;
  final Future<CatalogueReference> Function()? snapshotLoader;

  CatalogueRepository({
    Future<String> Function()? loader,
    CatalogueParser? parser,
    this.snapshotLoader,
  }) : _loader =
           loader ?? (() => rootBundle.loadString(assetPath, cache: false)),
       _parser = parser ?? CatalogueParser();

  Future<CatalogueReference> load() async {
    final loader = snapshotLoader;
    if (loader != null) {
      return await loader();
    }
    return _parser.parse(await _loader());
  }
}

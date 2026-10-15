import 'package:flutter/services.dart';

import '../models/catalogue_reference.dart';
import 'catalogue_parser.dart';

class CatalogueRepository {
  static const assetPath = 'assets/catalogue/catalogue_readiness_v1.json';
  final Future<String> Function() _loader;
  final CatalogueParser _parser;
  CatalogueRepository({
    Future<String> Function()? loader,
    CatalogueParser? parser,
  }) : _loader =
           loader ?? (() => rootBundle.loadString(assetPath, cache: false)),
       _parser = parser ?? CatalogueParser();
  Future<CatalogueReference> load() async => _parser.parse(await _loader());
}

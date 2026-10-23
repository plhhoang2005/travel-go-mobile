// Dedicated public repository for Discovery Release V2 with single-flight refresh and atomic updates.

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_cache.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';

class PublicRefreshResult {
  final PublicCatalogueSnapshot snapshot;
  final bool updated;
  final String? errorCode;

  const PublicRefreshResult({
    required this.snapshot,
    required this.updated,
    this.errorCode,
  });
}

class PublicCatalogueRepository {
  final Future<PublicCatalogueSnapshot> Function() seedLoader;
  final PublicCatalogueCache cache;
  final Dio client;
  final String projectOrigin;
  final String? publishableKey;
  final String bucketName;
  final DateTime Function() clock;
  final Duration requestTimeout;

  PublicCatalogueSnapshot? _currentSnapshot;
  DateTime? _lastSuccessfulRefresh;
  Future<PublicRefreshResult>? _inFlightRefresh;
  bool _closed = false;

  PublicCatalogueRepository({
    required this.seedLoader,
    required this.cache,
    required this.client,
    required this.projectOrigin,
    this.publishableKey,
    this.bucketName = 'discovery-catalogue',
    DateTime Function()? clock,
    this.requestTimeout = const Duration(seconds: 15),
  }) : clock = clock ?? (() => DateTime.now().toUtc()) {
    final uri = Uri.tryParse(projectOrigin);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw ArgumentError('Project origin must be a valid HTTPS URI: $projectOrigin');
    }
  }

  PublicCatalogueSnapshot? get currentSnapshot => _currentSnapshot;

  Future<PublicCatalogueSnapshot> load() async {
    if (_closed) {
      throw StateError('PublicCatalogueRepository is closed');
    }
    if (_currentSnapshot != null) {
      return _currentSnapshot!;
    }

    try {
      final cached = await cache.read();
      if (cached != null) {
        _currentSnapshot = cached;
        return cached;
      }
    } catch (_) {
      // Corrupt or failed cache falls back to seed
    }

    final seed = await seedLoader();
    _currentSnapshot = seed;
    return seed;
  }

  Future<PublicRefreshResult> refresh({bool force = false}) {
    if (_closed) {
      return Future.error(StateError('PublicCatalogueRepository is closed'));
    }

    if (_inFlightRefresh != null) {
      return _inFlightRefresh!;
    }

    final operation = _executeRefresh(force: force);
    _inFlightRefresh = operation;
    return operation.whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  Future<PublicRefreshResult> _executeRefresh({required bool force}) async {
    final current = await load();
    if (!force && _lastSuccessfulRefresh != null) {
      final elapsed = clock().difference(_lastSuccessfulRefresh!);
      if (elapsed < const Duration(minutes: 5)) {
        return PublicRefreshResult(snapshot: current, updated: false);
      }
    }

    return _performRefresh(current);
  }

  Future<PublicRefreshResult> _performRefresh(PublicCatalogueSnapshot current) async {
    try {
      // 1. Fetch singleton manifest from public table
      final manifestUri = Uri.parse(
        '$projectOrigin/rest/v1/discovery_release_manifest?id=eq.current&select=contract,schema_version,version,object_key,sha256,byte_length,published_at',
      );

      final manifestHeaders = <String, String>{
        'Accept': 'application/json',
      };
      if (publishableKey != null && publishableKey!.isNotEmpty) {
        manifestHeaders['apikey'] = publishableKey!;
      }

      final manifestResponse = await client.getUri<dynamic>(
        manifestUri,
        options: Options(
          headers: manifestHeaders,
          responseType: ResponseType.json,
          sendTimeout: requestTimeout,
          receiveTimeout: requestTimeout,
          followRedirects: false,
        ),
      );

      if (manifestResponse.statusCode != 200 || manifestResponse.data == null) {
        return PublicRefreshResult(
          snapshot: current,
          updated: false,
          errorCode: 'manifest_fetch_failed',
        );
      }

      final dynamic data = manifestResponse.data;
      Map<String, dynamic> manifestMap;
      if (data is List && data.isNotEmpty && data.first is Map) {
        manifestMap = Map<String, dynamic>.from(data.first as Map);
      } else if (data is Map) {
        manifestMap = Map<String, dynamic>.from(data);
      } else {
        return PublicRefreshResult(
          snapshot: current,
          updated: false,
          errorCode: 'empty_manifest',
        );
      }

      final DiscoveryManifest manifest;
      try {
        manifest = DiscoveryManifest.fromJson(manifestMap);
      } catch (e) {
        return PublicRefreshResult(
          snapshot: current,
          updated: false,
          errorCode: 'invalid_manifest_format',
        );
      }

      // Check schema version
      if (manifest.schemaVersion != 2) {
        return PublicRefreshResult(
          snapshot: current,
          updated: false,
          errorCode: 'unsupported_schema',
        );
      }

      // Check version progression
      if (manifest.version < current.version) {
        return PublicRefreshResult(
          snapshot: current,
          updated: false,
          errorCode: 'manifest_downgrade',
        );
      }

      if (manifest.version == current.version) {
        if (manifest.sha256 == current.sha256) {
          _lastSuccessfulRefresh = clock();
          return PublicRefreshResult(snapshot: current, updated: false);
        } else {
          return PublicRefreshResult(
            snapshot: current,
            updated: false,
            errorCode: 'manifest_conflict',
          );
        }
      }

      // Check object key pattern strictly
      if (!RegExp(r'^releases/v2/[1-9][0-9]*\.json$').hasMatch(manifest.objectKey)) {
        return PublicRefreshResult(
          snapshot: current,
          updated: false,
          errorCode: 'invalid_object_key',
        );
      }

      // 2. Fetch Storage bundle object
      final objectUri = Uri.parse(
        '$projectOrigin/storage/v1/object/public/$bucketName/${manifest.objectKey}',
      );

      final objectResponse = await client.getUri<String>(
        objectUri,
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: requestTimeout,
          receiveTimeout: requestTimeout,
          followRedirects: false, // Strict: no redirects
        ),
      );

      if (objectResponse.statusCode != 200 || objectResponse.data == null) {
        return PublicRefreshResult(
          snapshot: current,
          updated: false,
          errorCode: 'object_fetch_failed',
        );
      }

      final payloadText = objectResponse.data!;

      // 3. Strict parse and verify SHA-256 / ByteLength / bundle structure
      final snapshot = PublicCatalogueParser.parse(
        payloadText: payloadText,
        manifest: manifest,
        now: clock(),
        origin: 'storage',
      );

      // 4. Atomic cache write
      await cache.write(snapshot);

      // 5. Update in-memory state only after successful cache commit
      _currentSnapshot = snapshot;
      _lastSuccessfulRefresh = clock();

      return PublicRefreshResult(
        snapshot: snapshot,
        updated: true,
      );
    } catch (e) {
      return PublicRefreshResult(
        snapshot: current,
        updated: false,
        errorCode: e.toString(),
      );
    }
  }

  Future<void> close() async {
    _closed = true;
    await cache.close();
  }
}

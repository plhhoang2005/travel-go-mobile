import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';

import '../models/place_visit_details.dart';
import 'place_visit_cache.dart';

class VisitSnapshot {
  final VisitCatalogue catalogue;
  final String origin, sha256;
  final DateTime? lastFetchedAt;
  final String? warningCode;
  const VisitSnapshot({
    required this.catalogue,
    required this.origin,
    required this.sha256,
    this.lastFetchedAt,
    this.warningCode,
  });
}

class VisitRefreshResult {
  final VisitSnapshot snapshot;
  final String? errorCode;
  final bool updated;
  const VisitRefreshResult({
    required this.snapshot,
    this.errorCode,
    this.updated = false,
  });
}

/// Use a dedicated public Dio instance without account/auth interceptors.
/// Explicit RequestOptions also avoid inheriting base headers or private data.
class VisitDetailsRepository {
  final Dio dio;
  final VisitReleaseCache cache;
  final Future<String> Function() seedLoader;
  final Uri projectOrigin;
  final Set<String> expectedPlaceIds;
  final String expectedCatalogueSha256;
  final DateTime Function() now;
  final bool remoteEnabled, ownsDio;
  final Duration requestTimeout;
  final Set<CancelToken> _tokens = {};
  VisitSnapshot? _active;
  Future<VisitSnapshot>? _loading;
  Future<VisitRefreshResult>? _refreshing;
  Future<void>? _closing;
  bool _closed = false;
  static const _prefix = '/storage/v1/object/public/discovery-catalogue/';

  VisitDetailsRepository({
    required this.dio,
    required this.cache,
    required this.seedLoader,
    required this.projectOrigin,
    required Set<String> expectedPlaceIds,
    required this.expectedCatalogueSha256,
    required this.now,
    required this.remoteEnabled,
    this.ownsDio = false,
    this.requestTimeout = const Duration(seconds: 15),
  }) : expectedPlaceIds = Set.unmodifiable(expectedPlaceIds) {
    if (projectOrigin.scheme != 'https' ||
        projectOrigin.host.isEmpty ||
        projectOrigin.userInfo.isNotEmpty ||
        projectOrigin.hasQuery ||
        projectOrigin.hasFragment ||
        (projectOrigin.path.isNotEmpty && projectOrigin.path != '/') ||
        projectOrigin.port != 443 ||
        (remoteEnabled &&
            projectOrigin.host != 'bkocylxbuyvdgxccpixx.supabase.co') ||
        requestTimeout <= Duration.zero ||
        requestTimeout > const Duration(seconds: 15)) {
      throw ArgumentError('Invalid public visit origin or timeout');
    }
  }

  VisitCatalogue _parse(String text, {required bool complete}) =>
      parseVisitCatalogue(
        text,
        expectedPlaceIds: expectedPlaceIds,
        expectedCatalogueSha256: expectedCatalogueSha256,
        now: now(),
        requireComplete: complete,
      );

  Future<VisitSnapshot> loadLocal() async {
    if (_closed) {
      throw const VisitDataException('closed');
    }
    final active = _active;
    if (active != null) {
      return active;
    }
    final pending = _loading;
    if (pending != null) {
      return pending;
    }
    final operation = _loadLocal();
    _loading = operation;
    try {
      return await operation;
    } finally {
      _loading = null;
    }
  }

  Future<VisitSnapshot> _loadLocal() async {
    VisitSnapshot? seed, saved;
    var cacheFailed = false;
    try {
      final text = await seedLoader();
      final catalogue = _parse(text, complete: false);
      seed = VisitSnapshot(
        catalogue: catalogue,
        origin: 'bundled',
        sha256: crypto.sha256.convert(utf8.encode(text)).toString(),
        warningCode: catalogue.isComplete ? null : 'seed_incomplete',
      );
    } catch (_) {
      // A valid cached release remains usable when the bundled seed is damaged.
    }
    try {
      final value = await cache.read();
      if (value != null) {
        if (value.payloadUtf8.length > maxVisitReleaseBytes ||
            value.sha256 !=
                crypto.sha256.convert(value.payloadUtf8).toString() ||
            value.catalogueSha256.toLowerCase() !=
                expectedCatalogueSha256.toLowerCase()) {
          throw const VisitDataException('cache_integrity');
        }
        final catalogue = _parse(
          utf8.decode(value.payloadUtf8),
          complete: true,
        );
        if (catalogue.version != value.version ||
            !catalogue.publishedAt.isAtSameMomentAs(value.publishedAt)) {
          throw const VisitDataException('cache_metadata');
        }
        if (seed != null &&
            catalogue.version == seed.catalogue.version &&
            value.sha256 != seed.sha256) {
          throw const VisitDataException('version_conflict');
        }
        saved = VisitSnapshot(
          catalogue: catalogue,
          origin: 'cache',
          sha256: value.sha256,
          lastFetchedAt: value.lastFetchedAt,
        );
      }
    } catch (_) {
      cacheFailed = true;
    }
    if (_closed) {
      throw const VisitDataException('closed');
    }
    final selected =
        saved != null &&
            (seed == null || saved.catalogue.version > seed.catalogue.version)
        ? saved
        : seed;
    if (selected == null) {
      throw const VisitDataException('local_unavailable');
    }
    return _active = VisitSnapshot(
      catalogue: selected.catalogue,
      origin: selected.origin,
      sha256: selected.sha256,
      lastFetchedAt: selected.lastFetchedAt,
      warningCode: cacheFailed ? 'cache_unavailable' : selected.warningCode,
    );
  }

  Future<VisitRefreshResult> refresh(VisitSnapshot current) async {
    final baseline =
        _active != null &&
            _active!.catalogue.version >= current.catalogue.version
        ? _active!
        : current;
    if (_closed) {
      return VisitRefreshResult(snapshot: baseline, errorCode: 'closed');
    }
    if (!remoteEnabled) {
      return VisitRefreshResult(snapshot: baseline);
    }
    final pending = _refreshing;
    if (pending != null) {
      return pending;
    }
    final operation = _refresh(baseline);
    _refreshing = operation;
    try {
      return await operation;
    } finally {
      _refreshing = null;
    }
  }

  Future<VisitRefreshResult> _refresh(VisitSnapshot current) async {
    var persisting = false;
    try {
      final manifestBytes = await _get('latest.json', maxVisitManifestBytes);
      final manifest = parseVisitManifest(utf8.decode(manifestBytes));
      if (manifest.catalogueSha256 != expectedCatalogueSha256.toLowerCase()) {
        throw const VisitDataException('catalogue_hash');
      }
      if (manifest.version < current.catalogue.version) {
        throw const VisitDataException('version_downgrade');
      }
      if (manifest.version == current.catalogue.version) {
        if (manifest.sha256 != current.sha256 ||
            !manifest.publishedAt.isAtSameMomentAs(
              current.catalogue.publishedAt,
            )) {
          throw const VisitDataException('version_conflict');
        }
        return VisitRefreshResult(snapshot: current);
      }
      final bytes = await _get(manifest.objectPath, maxVisitReleaseBytes);
      if (bytes.length != manifest.byteLength ||
          crypto.sha256.convert(bytes).toString() != manifest.sha256) {
        throw const VisitDataException('release_integrity');
      }
      final catalogue = _parse(utf8.decode(bytes), complete: true);
      if (catalogue.version != manifest.version ||
          !catalogue.publishedAt.isAtSameMomentAs(manifest.publishedAt)) {
        throw const VisitDataException('release_metadata');
      }
      if (_closed) {
        throw const VisitDataException('closed');
      }
      final fetched = now().toUtc();
      persisting = true;
      await cache.write(
        CachedVisitRelease(
          version: catalogue.version,
          payloadUtf8: bytes,
          sha256: manifest.sha256,
          catalogueSha256: catalogue.catalogueSha256,
          publishedAt: catalogue.publishedAt,
          lastFetchedAt: fetched,
        ),
      );
      if (_closed) {
        throw const VisitDataException('closed');
      }
      final snapshot = VisitSnapshot(
        catalogue: catalogue,
        origin: 'remote',
        sha256: manifest.sha256,
        lastFetchedAt: fetched,
      );
      _active = snapshot;
      return VisitRefreshResult(snapshot: snapshot, updated: true);
    } catch (error) {
      final code = error is VisitDataException
          ? error.code
          : error is TimeoutException
          ? 'timeout'
          : error is DioException &&
                {
                  DioExceptionType.connectionTimeout,
                  DioExceptionType.receiveTimeout,
                  DioExceptionType.sendTimeout,
                }.contains(error.type)
          ? 'timeout'
          : persisting
          ? 'cache_write'
          : 'remote_unavailable';
      return VisitRefreshResult(snapshot: current, errorCode: code);
    }
  }

  Future<Uint8List> _get(String object, int limit) async {
    // objectPath is generated locally or validated by parseVisitManifest.
    final uri = projectOrigin.resolve('$_prefix$object');
    final token = CancelToken();
    _tokens.add(token);
    final watch = Stopwatch()..start();
    StreamIterator<Uint8List>? iterator;
    Duration remaining() {
      final result = requestTimeout - watch.elapsed;
      if (result <= Duration.zero) {
        throw TimeoutException('public_visit_timeout');
      }
      return result;
    }

    try {
      final response = await dio
          .fetch<ResponseBody>(
            RequestOptions(
              path: uri.toString(),
              method: 'GET',
              headers: {'accept': 'application/json'},
              queryParameters: {},
              extra: {},
              responseType: ResponseType.stream,
              followRedirects: false,
              maxRedirects: 0,
              validateStatus: (_) => true,
              connectTimeout: requestTimeout,
              receiveTimeout: requestTimeout,
              sendTimeout: requestTimeout,
              cancelToken: token,
            ),
          )
          .timeout(remaining());
      final body = response.data;
      if (response.statusCode != 200 || response.isRedirect || body == null) {
        throw const VisitDataException('http_status');
      }
      final length = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      if (length != null && length > limit) {
        throw const VisitDataException('response_size');
      }
      iterator = StreamIterator(body.stream);
      final bytes = BytesBuilder(copy: false);
      while (await iterator.moveNext().timeout(remaining())) {
        final chunk = iterator.current;
        if (bytes.length + chunk.length > limit) {
          throw const VisitDataException('response_size');
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    } finally {
      token.cancel('Public visit request finished');
      await iterator?.cancel();
      _tokens.remove(token);
    }
  }

  Future<void> close() {
    _closed = true;
    for (final token in _tokens.toList()) {
      token.cancel('Public visit repository closed');
    }
    return _closing ??= () async {
      try {
        await _loading;
      } catch (_) {
        /* No active snapshot to publish. */
      }
      await _refreshing;
      await cache.close();
      if (ownsDio) {
        dio.close(force: true);
      }
    }();
  }
}

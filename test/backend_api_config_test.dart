import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/core/constants/api_constants.dart';
import 'package:travelgo_mobile/core/services/backend_api_config.dart';

void main() {
  group('Task R1: BackendApiConfig URL Normalization & Validation', () {
    test('normalizes root URLs, trailing slashes, and maintains https', () {
      expect(
        BackendApiConfig.normalizeAndValidateUrl('http://192.168.1.5:8080'),
        'http://192.168.1.5:8080/api/v1',
      );
      expect(
        BackendApiConfig.normalizeAndValidateUrl('http://192.168.1.5:8080/'),
        'http://192.168.1.5:8080/api/v1',
      );
      expect(
        BackendApiConfig.normalizeAndValidateUrl('http://192.168.1.5:8080/api/v1'),
        'http://192.168.1.5:8080/api/v1',
      );
      expect(
        BackendApiConfig.normalizeAndValidateUrl('http://192.168.1.5:8080/api/v1/'),
        'http://192.168.1.5:8080/api/v1',
      );
      expect(
        BackendApiConfig.normalizeAndValidateUrl('https://my-backend.org'),
        'https://my-backend.org/api/v1',
      );
      expect(
        BackendApiConfig.normalizeAndValidateUrl('https://my-backend.org:8443/api/v1/'),
        'https://my-backend.org:8443/api/v1',
      );
    });

    test('rejects ftp, userInfo, queries, fragments, arbitrary paths, empty strings and empty hosts', () {
      expect(
        () => BackendApiConfig.normalizeAndValidateUrl('ftp://my-domain.com'),
        throwsFormatException,
      );
      expect(
        () => BackendApiConfig.normalizeAndValidateUrl('http://user:pass@192.168.1.5:8080'),
        throwsFormatException,
      );
      expect(
        () => BackendApiConfig.normalizeAndValidateUrl('http://192.168.1.5:8080?foo=bar'),
        throwsFormatException,
      );
      expect(
        () => BackendApiConfig.normalizeAndValidateUrl('http://192.168.1.5:8080#section'),
        throwsFormatException,
      );
      expect(
        () => BackendApiConfig.normalizeAndValidateUrl('http://192.168.1.5:8080/unsupported/path'),
        throwsFormatException,
      );
      expect(
        () => BackendApiConfig.normalizeAndValidateUrl(''),
        throwsFormatException,
      );
      expect(
        () => BackendApiConfig.normalizeAndValidateUrl('   '),
        throwsFormatException,
      );
      expect(
        () => BackendApiConfig.normalizeAndValidateUrl('http:///api/v1'),
        throwsFormatException,
      );
    });
  });

  group('Task R1: BackendApiConfig Persistence Lifecycle', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiConstants.overrideBaseUrl = null;
    });

    test('persists configured URL, increments revision, and restores across new instances', () async {
      final prefs = await SharedPreferences.getInstance();
      final config1 = await BackendApiConfig.load(prefs);
      ApiConstants.configure(config1);

      expect(config1.revision, 0);
      expect(config1.hasPersistence, isTrue);
      expect(config1.persistenceError, isNull);

      const targetUrl = 'http://192.168.1.100:8080';
      const expectedNormalized = 'http://192.168.1.100:8080/api/v1';

      await config1.setBaseUrl(targetUrl);
      expect(config1.effectiveBaseUrl, expectedNormalized);
      expect(config1.revision, 1);
      expect(ApiConstants.baseUrl, expectedNormalized);
      expect(ApiConstants.configRevision, 1);

      // Verify persisted in SharedPreferences
      expect(prefs.getString(BackendApiConfig.storageKey), expectedNormalized);

      // Verify new instance restores saved configuration
      final config2 = await BackendApiConfig.load(prefs);
      expect(config2.effectiveBaseUrl, expectedNormalized);
      expect(config2.persistenceError, isNull);

      // Reset restores default base URL and increments revision
      await config2.reset();
      expect(config2.effectiveBaseUrl, BackendApiConfig.defaultBaseUrl());
      expect(config2.revision, 1);
      expect(prefs.containsKey(BackendApiConfig.storageKey), isFalse);
    });

    test('handles null preferences gracefully with default fallback and error indicator', () async {
      final unpersisted = await BackendApiConfig.load(null);
      expect(unpersisted.effectiveBaseUrl, BackendApiConfig.defaultBaseUrl());
      expect(unpersisted.hasPersistence, isFalse);
      expect(unpersisted.persistenceError, isNotNull);

      // Writing without persistence fails
      expect(
        () => unpersisted.setBaseUrl('http://192.168.1.5:8080'),
        throwsStateError,
      );
      expect(
        () => unpersisted.reset(),
        throwsStateError,
      );
    });

    test('handles invalid or corrupt stored URL with fallback to default and error warning', () async {
      SharedPreferences.setMockInitialValues({
        BackendApiConfig.storageKey: 'CORRUPT_INVALID_URL_###',
      });
      final prefs = await SharedPreferences.getInstance();
      final config = await BackendApiConfig.load(prefs);

      expect(config.effectiveBaseUrl, BackendApiConfig.defaultBaseUrl());
      expect(config.persistenceError, isNotNull);
    });
  });
}

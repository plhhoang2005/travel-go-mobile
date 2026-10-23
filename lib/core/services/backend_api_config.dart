import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackendConfigChangedException implements Exception {
  final String message;
  const BackendConfigChangedException([
    this.message = 'Cấu hình API đã thay đổi trong lúc xử lý yêu cầu.',
  ]);

  @override
  String toString() => 'BackendConfigChangedException: $message';
}

class BackendApiConfig extends ChangeNotifier {
  static const String storageKey = 'backend_api_base_url.v1';

  SharedPreferences? _prefs;
  String _effectiveBaseUrl;
  int _revision = 0;
  String? _persistenceError;

  BackendApiConfig._({
    SharedPreferences? preferences,
    required String initialUrl,
    int initialRevision = 0,
    String? initialPersistenceError,
  })  : _prefs = preferences,
        _effectiveBaseUrl = initialUrl,
        _revision = initialRevision,
        _persistenceError = initialPersistenceError;

  factory BackendApiConfig.unpersisted({String? initialUrl}) =>
      BackendApiConfig._(
        preferences: null,
        initialUrl: initialUrl ?? defaultBaseUrl(),
        initialPersistenceError:
            'Không thể truy cập bộ nhớ thiết bị. Cấu hình sẽ chỉ áp dụng tạm thời.',
      );

  static String defaultBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8080/api/v1';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  String get effectiveBaseUrl => _effectiveBaseUrl;
  int get revision => _revision;
  String? get persistenceError => _persistenceError;
  bool get hasPersistence => _prefs != null;

  static String normalizeAndValidateUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('URL máy chủ không được để trống.');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw const FormatException('URL phải bắt đầu bằng http:// hoặc https://');
    }
    if (uri.host.isEmpty) {
      throw const FormatException('URL phải có địa chỉ máy chủ (host) hợp lệ.');
    }
    if (uri.userInfo.isNotEmpty) {
      throw const FormatException('URL không được chứa thông tin người dùng (userInfo).');
    }
    if (uri.hasQuery) {
      throw const FormatException('URL không được chứa tham số truy vấn (query).');
    }
    if (uri.hasFragment) {
      throw const FormatException('URL không được chứa phần định danh (fragment #).');
    }

    final path = uri.path;
    String finalPath;
    if (path.isEmpty || path == '/') {
      finalPath = '/api/v1';
    } else {
      final normalizedPath =
          path.endsWith('/') ? path.substring(0, path.length - 1) : path;
      if (normalizedPath == '/api/v1') {
        finalPath = '/api/v1';
      } else {
        throw const FormatException('Đường dẫn URL chỉ được là gốc hoặc kết thúc bằng /api/v1.');
      }
    }

    final portSuffix = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portSuffix$finalPath';
  }

  static Future<BackendApiConfig> load(SharedPreferences? preferences) async {
    final fallback = defaultBaseUrl();
    if (preferences == null) {
      return BackendApiConfig._(
        preferences: null,
        initialUrl: fallback,
        initialPersistenceError:
            'Không thể truy cập bộ nhớ thiết bị. Cấu hình sẽ chỉ áp dụng tạm thời.',
      );
    }
    String? stored;
    try {
      stored = preferences.getString(storageKey);
    } catch (_) {
      return BackendApiConfig._(
        preferences: preferences,
        initialUrl: fallback,
        initialPersistenceError:
            'Lỗi khi đọc cấu hình đã lưu. Đang dùng URL mặc định.',
      );
    }

    if (stored == null || stored.trim().isEmpty) {
      return BackendApiConfig._(
        preferences: preferences,
        initialUrl: fallback,
      );
    }

    try {
      final normalized = normalizeAndValidateUrl(stored);
      return BackendApiConfig._(
        preferences: preferences,
        initialUrl: normalized,
      );
    } catch (_) {
      return BackendApiConfig._(
        preferences: preferences,
        initialUrl: fallback,
        initialPersistenceError: 'URL đã lưu không hợp lệ. Đang dùng URL mặc định.',
      );
    }
  }

  Future<void> setBaseUrl(String raw) async {
    final normalized = normalizeAndValidateUrl(raw);
    if (normalized == _effectiveBaseUrl) {
      return;
    }
    if (_prefs == null) {
      _persistenceError = 'Không có bộ nhớ thiết bị; chưa thể lưu bền vững.';
      notifyListeners();
      throw StateError(_persistenceError!);
    }

    final success = await _prefs!.setString(storageKey, normalized);
    if (!success) {
      _persistenceError = 'Ghi bộ nhớ thất bại; giữ cấu hình cũ.';
      notifyListeners();
      throw StateError(_persistenceError!);
    }

    _effectiveBaseUrl = normalized;
    _revision++;
    _persistenceError = null;
    notifyListeners();
  }

  Future<void> reset() async {
    final fallback = defaultBaseUrl();
    if (_prefs == null) {
      _persistenceError = 'Không có bộ nhớ thiết bị; chưa thể xóa cấu hình.';
      notifyListeners();
      throw StateError(_persistenceError!);
    }

    final success = await _prefs!.remove(storageKey);
    if (!success) {
      _persistenceError = 'Xóa bộ nhớ thất bại; giữ cấu hình cũ.';
      notifyListeners();
      throw StateError(_persistenceError!);
    }

    _effectiveBaseUrl = fallback;
    _revision++;
    _persistenceError = null;
    notifyListeners();
  }

  Future<void> retryPersistence(
    Future<SharedPreferences> Function() loader,
  ) async {
    try {
      final prefs = await loader();
      _prefs = prefs;
      _persistenceError = null;
      notifyListeners();
    } catch (e) {
      _persistenceError = 'Thử lại mở bộ nhớ thất bại: $e';
      notifyListeners();
      rethrow;
    }
  }
}

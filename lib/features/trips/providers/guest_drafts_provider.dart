import 'package:flutter/foundation.dart';

import '../models/local_trip_records.dart';
import '../services/guest_import_service.dart';
import '../services/local_trip_store.dart';

/// Callable consent state; app auth/startup and UI wiring are separate packets.
class GuestDraftsProvider extends ChangeNotifier {
  final LocalTripStore store;
  final GuestImportService service;
  final String deviceScope;
  SessionHandle? _handle;
  int _generation = 0;
  int _loadGeneration = 0;
  bool _disposed = false;
  bool _loading = false;
  bool _importing = false;
  String? _error;
  List<GuestDraftSummaryRecord> _drafts = [];
  List<LocalImportJournalRecord> _attempts = [];
  List<GuestImportOutcome> _outcomes = [];
  final Set<ImportSource> _selected = {};

  GuestDraftsProvider({
    required this.store,
    required this.service,
    required this.deviceScope,
  }) {
    if (deviceScope.trim().isEmpty) {
      throw ArgumentError('deviceScope cannot be blank.');
    }
  }

  List<GuestDraftSummaryRecord> get drafts => List.unmodifiable(_drafts);
  List<LocalImportJournalRecord> get attempts => List.unmodifiable(_attempts);
  List<ImportSource> get selectedSources => List.unmodifiable(_selected);
  List<GuestImportOutcome> get outcomes => List.unmodifiable(_outcomes);
  bool get isLoading => _loading;
  bool get isImporting => _importing;
  String? get errorMessage => _error;

  bool _current(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _clear() {
    _generation++;
    _loadGeneration++;
    _selected.clear();
    _attempts = [];
    _outcomes = [];
    _error = null;
    _loading = false;
    _importing = false;
  }

  void bindSession(SessionHandle handle) {
    _clear();
    _handle = null;
    service.unbindSession();
    if (_disposed) throw StateError('Provider disposed.');
    service.bindSession(handle);
    _handle = handle;
    _notify();
  }

  void unbindSession() {
    _clear();
    _handle = null;
    service.unbindSession();
    _notify();
  }

  Future<void> reload() async {
    if (_disposed) return;
    final generation = _generation;
    final load = ++_loadGeneration;
    final handle = _handle;
    _selected.clear();
    _loading = true;
    _error = null;
    _notify();
    try {
      final drafts = await store.listGuestDrafts(deviceScope: deviceScope);
      if (!_current(generation) || load != _loadGeneration) return;
      final attempts = handle == null
          ? <LocalImportJournalRecord>[]
          : await store.listImportJournals(handle: handle);
      if (!_current(generation) || load != _loadGeneration) return;
      _drafts = drafts;
      _attempts = attempts;
    } catch (_) {
      if (_current(generation) && load == _loadGeneration) {
        _drafts = [];
        _attempts = [];
        _error = 'Không thể đọc bản nháp an toàn.';
      }
    } finally {
      if (_current(generation) && load == _loadGeneration) {
        _loading = false;
        _notify();
      }
    }
  }

  void select(ImportSource source, bool selected) {
    if (_disposed || _importing) return;
    if (selected) {
      if (source.deviceScope != deviceScope ||
          !_drafts.any(
            (d) =>
                d.draftId == source.draftId &&
                d.currentRevision == source.revision,
          )) {
        throw ArgumentError(
          'Selection must refer to a displayed Guest revision.',
        );
      }
      _selected.add(source);
    } else {
      _selected.remove(source);
    }
    _notify();
  }

  Future<List<GuestImportOutcome>> confirmAndImport() async {
    if (_disposed || _importing || _selected.isEmpty || _handle == null) {
      return const [];
    }
    final generation = _generation;
    _importing = true;
    _error = null;
    _notify();
    try {
      final confirmation = service.confirmSelection(_selected.toList());
      final result = await service.importConfirmed(confirmation);
      if (!_current(generation)) return const [];
      if (result.any(
        (item) => item.status == GuestImportStatus.sessionInvalidated,
      )) {
        unbindSession();
        return const [];
      }
      _outcomes = result;
      _selected.clear();
      await reload();
      return _current(generation) ? result : const [];
    } catch (_) {
      if (_current(generation)) _error = 'Chưa thể xác nhận chuyển bản nháp.';
      return const [];
    } finally {
      if (_current(generation)) {
        _importing = false;
        _notify();
      }
    }
  }

  Future<GuestImportOutcome> retry(ImportSource source) async {
    if (_disposed || _importing || _handle == null) {
      return GuestImportOutcome(source, GuestImportStatus.sessionInvalidated);
    }
    final generation = _generation;
    _importing = true;
    _notify();
    try {
      final result = await service.retry(source);
      if (!_current(generation)) {
        return GuestImportOutcome(source, GuestImportStatus.sessionInvalidated);
      }
      if (result.status == GuestImportStatus.sessionInvalidated) {
        unbindSession();
        return GuestImportOutcome(source, GuestImportStatus.sessionInvalidated);
      }
      _outcomes = [result];
      await reload();
      return _current(generation)
          ? result
          : GuestImportOutcome(source, GuestImportStatus.sessionInvalidated);
    } finally {
      if (_current(generation)) {
        _importing = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _clear();
    _handle = null;
    service.unbindSession();
    _disposed = true;
    super.dispose();
  }
}

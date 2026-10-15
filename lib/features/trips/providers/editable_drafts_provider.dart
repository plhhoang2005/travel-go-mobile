import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../trip_planner/services/editable_trip_validator.dart';
import '../models/editable_local_records.dart';
import '../models/editable_remote_records.dart';
import '../services/editable_trip_repository.dart';
import '../services/local_account_lifecycle_service.dart';
import '../services/local_trip_store.dart';

class EditableDraftsProvider extends ChangeNotifier {
  final Future<LocalTripStore> Function() storeLoader;
  final Future<EditableTripRepository> Function() repositoryLoader;
  final LocalAccountLifecycleService lifecycle;
  final String deviceScope;
  late final VoidCallback _unregister;
  int _generation = 0, _loadGeneration = 0;
  int? _boundEpoch;
  bool _disposed = false,
      _loading = false,
      _importing = false,
      _uncertain = false;
  String? _error;
  List<EditableDraftRecord> _drafts = [];
  final Map<String, EditableDraftRecord> _selected = {};
  List<EditableMutationReply> _outcomes = [];
  EditableDraftsProvider({
    required this.storeLoader,
    required this.repositoryLoader,
    required this.lifecycle,
    required this.deviceScope,
  }) {
    _boundEpoch = lifecycle.epoch;
    _unregister = lifecycle.registerConsumer(
      invalidate: invalidate,
      bind: (handle) async {
        if (_boundEpoch != handle.coordinatorEpoch) invalidate();
        _boundEpoch = handle.coordinatorEpoch;
      },
    );
  }
  List<EditableDraftRecord> get drafts => List.unmodifiable(_drafts);
  List<EditableDraftRecord> get selected => List.unmodifiable(_selected.values);
  List<EditableMutationReply> get outcomes {
    // Checking the live handle also revokes a silently expired SDK subject.
    final owner = lifecycle.handle?.ownerId;
    if (owner == null) return const [];
    return List.unmodifiable(
      _outcomes.where((r) => r.receipt?.ownerId == owner),
    );
  }

  bool get isLoading => _loading;
  bool get isImporting => _importing;
  bool get uncertain => _uncertain;
  String? get errorMessage => _error;
  void _notify() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  void invalidate() {
    _generation++;
    _loadGeneration++;
    _drafts = [];
    _selected.clear();
    _outcomes = [];
    _loading = false;
    _importing = false;
    _uncertain = false;
    _error = null;
    _boundEpoch = null;
    _notify();
  }

  bool _current(int generation, int epoch, AccountSessionProof? proof) =>
      !_disposed &&
      generation == _generation &&
      lifecycle.epoch == epoch &&
      (proof == null
          ? lifecycle.handle == null
          : lifecycle.isCurrentProof(proof));
  AccountSessionProof? _proof() =>
      lifecycle.handle == null ? null : lifecycle.captureProof();
  Future<void> load() async {
    if (_disposed || _importing || _uncertain) return;
    final generation = _generation,
        epoch = lifecycle.epoch,
        load = ++_loadGeneration;
    final proof = _proof();
    _loading = true;
    _error = null;
    _selected.clear();
    _notify();
    try {
      final store = await storeLoader();
      if (!_current(generation, epoch, proof) || load != _loadGeneration) {
        return;
      }
      final drafts = await store.listEditableDrafts(deviceScope: deviceScope);
      if (!_current(generation, epoch, proof) || load != _loadGeneration) {
        return;
      }
      _drafts = drafts;
    } catch (_) {
      if (!_current(generation, epoch, proof) || load != _loadGeneration) {
        return;
      }
      _error = 'Không đọc được bản nháp trên thiết bị.';
    } finally {
      if (_current(generation, epoch, proof) && load == _loadGeneration) {
        _loading = false;
        _notify();
      }
    }
  }

  void select(String draftId, bool value) {
    if (_disposed || _loading || _importing || _uncertain) return;
    final records = _drafts.where((d) => d.draftId == draftId);
    if (records.length != 1) return;
    if (value) {
      _selected[draftId] = records.single;
    } else {
      _selected.remove(draftId);
    }
    _notify();
  }

  Future<List<EditableMutationReply>> importSelected() async {
    if (_disposed || _loading || _importing || _selected.isEmpty) {
      return const [];
    }
    final proof = _proof();
    if (proof == null) {
      _error = 'Đăng nhập để chọn nhập bản nháp.';
      _notify();
      return const [];
    }
    final generation = _generation, epoch = lifecycle.epoch;
    final sources = List<EditableDraftRecord>.unmodifiable(_selected.values);
    _importing = true;
    _error = null;
    _outcomes = [];
    var submitted = false;
    _notify();
    try {
      final store = await storeLoader();
      if (!_current(generation, epoch, proof)) return const [];
      for (final source in sources) {
        final latest = await store.readEditableDraft(
          deviceScope: deviceScope,
          draftId: source.draftId,
        );
        if (!_current(generation, epoch, proof)) return const [];
        if (latest?.revision != source.revision ||
            latest?.contentDigest != source.contentDigest) {
          throw StateError('Selected revision changed.');
        }
        if (EditableTripValidator.validate(
          source.document,
          mode: ValidationMode.accountSave,
        ).any((i) => i.isBlocking)) {
          _error = 'Bản nháp chưa đủ thông tin. Hoàn thiện ngày, điểm đến và các lỗi trước khi nhập.';
          return const [];
        }
      }
      final repository = await repositoryLoader();
      if (!_current(generation, epoch, proof)) return const [];
      for (final source in sources) {
        submitted = true;
        final reply = await repository.importGuest(source);
        if (!_current(generation, epoch, proof)) return const [];
        _outcomes = [..._outcomes, reply];
        _selected.remove(source.draftId);
      }
      _uncertain = false;
      final drafts = await store.listEditableDrafts(deviceScope: deviceScope);
      if (!_current(generation, epoch, proof)) return const [];
      _drafts = drafts;
      return outcomes;
    } catch (_) {
      if (!_current(generation, epoch, proof)) return const [];
      _uncertain = submitted;
      if (!submitted) _selected.clear();
      _error = submitted
          ? 'Chưa xác nhận đủ kết quả nhập. Thử lại giữ nguyên các bản đã chọn.'
          : 'Bản nháp đã thay đổi. Tải lại danh sách và chọn bản mới.';
      return outcomes;
    } finally {
      if (_current(generation, epoch, proof)) {
        _importing = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _unregister();
    _drafts = [];
    _selected.clear();
    _outcomes = [];
    super.dispose();
  }
}

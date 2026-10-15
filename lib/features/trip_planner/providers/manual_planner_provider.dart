import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:uuid/uuid.dart' show Uuid;

import '../../trips/models/editable_local_records.dart';
import '../../trips/models/editable_remote_records.dart';
import '../../trips/models/editable_trip_codec.dart';
import '../../trips/services/editable_trip_repository.dart';
import '../../trips/services/editable_trip_service.dart';
import '../../trips/services/local_account_lifecycle_service.dart';
import '../models/editable_trip_command.dart';
import '../models/editable_trip_document.dart';
import '../services/budget_calculator.dart';
import '../services/editable_trip_mutator.dart';
import '../services/editable_trip_validator.dart';

enum ManualPlannerState {
  unavailable,
  editing,
  preview,
  saving,
  uncertain,
  conflict,
  error,
  readOnly,
}

class SavePreview {
  final EditableTripDocumentV2 document;
  final EditableTripDocumentV2? beforeDocument;
  final EditableHead? base;
  final SourceBinding? source;
  final List<EditableCommand> commands;
  final List<EditableValidationIssue> issues;
  final BudgetTotals totals;
  final String digest, requestId, draftId, deviceScope;
  final int generation, workspaceGeneration;
  final int? draftRevision;
  final AccountSessionProof? proof;
  SavePreview({
    required this.document,
    required this.beforeDocument,
    required this.base,
    required this.source,
    required List<EditableCommand> commands,
    required List<EditableValidationIssue> issues,
    required this.totals,
    required this.digest,
    required this.requestId,
    required this.generation,
    required this.workspaceGeneration,
    required this.proof,
    required this.draftId,
    required this.deviceScope,
    required this.draftRevision,
  }) : commands = List.unmodifiable(commands),
       issues = List.unmodifiable(issues);
  bool get isAccount => proof != null;
  bool get canConfirm => !issues.any(
    (i) =>
        i.isBlocking &&
        (isAccount || !{'overlap', 'time_order'}.contains(i.code)),
  );
  List<EditableCommand> get actualChanges => List.unmodifiable(
    commands.where((c) => c is PutActualCommand || c is DeleteActualCommand),
  );
}

class ManualPlannerProvider extends ChangeNotifier {
  final Future<EditableTripRepository> Function() repositoryLoader;
  final LocalAccountLifecycleService? lifecycle;
  final String deviceScope;
  final String Function() _newId;
  VoidCallback? _unregister;
  EditableTripDocumentV2? _document, _savedDocument;
  EditableHead? _base;
  SourceBinding? _source;
  AccountSessionProof? _proof;
  String? _baselineDigest, _draftId, _error;
  int? _draftRevision, _boundEpoch;
  int _editorGeneration = 0, _workspaceGeneration = 0, _workspaceEpoch = 0;
  bool _disposed = false, _saving = false;
  final List<EditableCommand> _commands = [];
  SavePreview? _preview, _pending;
  ManualPlannerState _state = ManualPlannerState.unavailable;

  ManualPlannerProvider({
    required this.repositoryLoader,
    this.lifecycle,
    this.deviceScope = 'default',
    String Function()? newId,
  }) : _newId = newId ?? const Uuid().v4 {
    _boundEpoch = lifecycle?.epoch;
    _unregister = lifecycle?.registerConsumer(
      invalidate: invalidate,
      bind: (handle) async {
        if (_boundEpoch != handle.coordinatorEpoch) {
          invalidate();
        }
        _boundEpoch = handle.coordinatorEpoch;
      },
    );
  }

  bool get _authority {
    if (_disposed) return false;
    final authority = lifecycle;
    if (authority == null) return _proof == null;
    final proof = _proof;
    return proof != null
        ? authority.isCurrentProof(proof)
        : authority.epoch == _workspaceEpoch &&
              authority.handle == null &&
              authority.state == LocalAccountLifecycleState.denied;
  }

  EditableTripDocumentV2? get document => _authority ? _document : null;
  EditableHead? get baseHead => _authority ? _base : null;
  int get editorGeneration => _editorGeneration;
  int? get draftRevision => _draftRevision;
  String? get draftId => _draftId;
  String? get currentOwnerId => _authority ? _proof?.ownerId : null;
  bool get isAccount => currentOwnerId != null;
  bool get isSaving => _saving;
  bool get hasPendingSave => _pending != null;
  String? get errorMessage => _error;
  ManualPlannerState get state =>
      _authority ? _state : ManualPlannerState.unavailable;
  bool get isEditable =>
      document != null &&
      _state != ManualPlannerState.readOnly &&
      _state != ManualPlannerState.unavailable;
  bool get dirty =>
      document != null &&
      EditableTripCodec.digest(_document!) != _baselineDigest;
  BudgetTotals? get totals =>
      document == null ? null : BudgetCalculator.calculate(_document!);
  List<EditableValidationIssue> get issues => document == null
      ? const []
      : EditableTripValidator.validate(
          _document!,
          mode: isAccount ? ValidationMode.accountSave : ValidationMode.draft,
        );

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
    _workspaceGeneration++;
    _editorGeneration++;
    _document = null;
    _savedDocument = null;
    _base = null;
    _proof = null;
    _source = null;
    _commands.clear();
    _preview = null;
    _pending = null;
    _baselineDigest = null;
    _draftId = null;
    _draftRevision = null;
    _error = null;
    _saving = false;
    _state = ManualPlannerState.unavailable;
    _boundEpoch = null;
    _notify();
  }

  void _open(EditableTripDocumentV2 value) {
    if (_disposed) throw StateError('Editor is disposed.');
    EditableTripCodec.encode(value);
    final authority = lifecycle;
    AccountSessionProof? proof;
    if (authority != null) {
      if (authority.handle != null) {
        proof = authority.captureProof();
      } else if (authority.state != LocalAccountLifecycleState.denied) {
        throw StateError('Account context is unavailable.');
      }
    }
    invalidate();
    _proof = proof;
    _workspaceEpoch = authority?.epoch ?? 0;
    _boundEpoch = authority?.epoch;
    _document = value;
    _draftId = _newId();
    _state = ManualPlannerState.editing;
  }

  void openNew(EditableTripDocumentV2 value, {SourceBinding? source}) {
    _open(value);
    _source = source;
    _notify();
  }

  void openDraft(EditableDraftRecord record) {
    if (lifecycle?.handle != null) {
      throw StateError('Account cannot edit Guest storage.');
    }
    if (record.deviceScope != deviceScope ||
        EditableTripCodec.digest(record.document) != record.contentDigest) {
      throw StateError('Guest draft content changed.');
    }
    _open(record.document);
    _draftId = record.draftId;
    _draftRevision = record.revision;
    _baselineDigest = record.contentDigest;
    _savedDocument = record.document;
    _notify();
  }

  void openSaved(EditableTripView view) {
    final head = view.head;
    if (head == null || view.state == EditableTripViewState.unavailable) {
      invalidate();
      return;
    }
    final proof = lifecycle?.captureProof();
    if (proof == null || proof.ownerId != head.ownerId) {
      throw StateError('Saved trip owner changed.');
    }
    EditableRecordCodec.head(EditableRecordCodec.headJson(head));
    _open(head.document);
    _base = head;
    _baselineDigest = EditableTripCodec.digest(head.document);
    _savedDocument = head.document;
    _state = view.state == EditableTripViewState.cachedReadOnly
        ? ManualPlannerState.readOnly
        : ManualPlannerState.editing;
    _notify();
  }

  void dispatch(EditableCommand command) => dispatchAll([command]);
  void dispatchAll(List<EditableCommand> commands) {
    if (!isEditable) throw StateError('Editor is read only or unavailable.');
    final changed = EditableTripMutator.apply(_document!, commands);
    _document = changed;
    _commands.addAll(commands);
    _editorGeneration++;
    _preview = null;
    if (!_saving && _pending == null && _state != ManualPlannerState.conflict) {
      _state = ManualPlannerState.editing;
      _error = null;
    }
    _notify();
  }

  SavePreview previewSave() {
    if (!isEditable ||
        _saving ||
        _pending != null ||
        _state == ManualPlannerState.conflict) {
      throw StateError('Resolve the previous save before confirming another.');
    }
    final candidate = _document!;
    final value = SavePreview(
      document: candidate,
      beforeDocument: _savedDocument,
      base: _base,
      source: _source,
      commands: _commands,
      issues: issues,
      totals: BudgetCalculator.calculate(candidate),
      digest: EditableTripCodec.digest(candidate),
      requestId: _newId(),
      generation: _editorGeneration,
      workspaceGeneration: _workspaceGeneration,
      proof: _proof,
      draftId: _draftId!,
      deviceScope: deviceScope,
      draftRevision: _draftRevision,
    );
    _preview = value;
    _state = ManualPlannerState.preview;
    _notify();
    return value;
  }

  void cancelPreview() {
    _preview = null;
    if (_state == ManualPlannerState.preview) {
      _state = ManualPlannerState.editing;
    }
    _notify();
  }

  bool _current(SavePreview value) =>
      !_disposed &&
      _authority &&
      value.workspaceGeneration == _workspaceGeneration &&
      identical(value.proof, _proof);
  Future<bool> confirmSave(SavePreview value) async {
    if (!identical(_preview, value) ||
        !_current(value) ||
        _saving ||
        !value.canConfirm ||
        value.generation != _editorGeneration ||
        value.digest != EditableTripCodec.digest(_document!)) {
      return false;
    }
    _preview = null;
    return await _save(value);
  }

  Future<bool> retrySave() async {
    final value = _pending;
    if (value == null ||
        !_current(value) ||
        _saving ||
        _state == ManualPlannerState.conflict) {
      return false;
    }
    return await _save(value);
  }

  Future<bool> _save(SavePreview value) async {
    _saving = true;
    _state = ManualPlannerState.saving;
    _error = null;
    if (value.isAccount) _pending = value;
    _notify();
    try {
      final repository = await repositoryLoader();
      if (!_current(value)) return false;
      if (!value.isAccount) {
        final record = await repository.saveGuest(
          scope: value.deviceScope,
          draftId: value.draftId,
          expectedRevision: value.draftRevision,
          document: value.document,
        );
        if (!_current(value)) return false;
        _draftRevision = record.revision;
      } else {
        final reply = await repository.saveAccount(
          document: value.document,
          commands: value.commands,
          base: value.base,
          source: value.source,
          requestId: value.requestId,
        );
        if (!_current(value)) return false;
        final head = reply.head;
        final receipt = reply.receipt;
        if (reply.status != EditableMutationStatus.committed ||
            head == null ||
            receipt == null ||
            head.version != receipt.resultVersion ||
            head.contentDigest != value.digest) {
          _pending = null;
          _saving = false;
          _state = ManualPlannerState.conflict;
          _error = 'Chuyến đi đã thay đổi trên tài khoản. Hãy xem bản mới trước khi tiếp tục.';
          _notify();
          return false;
        }
        _base = head;
      }
      _baselineDigest = value.digest;
      _savedDocument = value.document;
      _commands.removeRange(0, value.commands.length);
      _pending = null;
      _saving = false;
      _state = ManualPlannerState.editing;
      _notify();
      return true;
    } catch (error) {
      if (!_current(value)) return false;
      _saving = false;
      if (error is EditableRemoteException &&
          error.code == 'version_conflict') {
        _state = ManualPlannerState.conflict;
        _error = 'Chuyến đi đã có phiên bản mới. Các chỉnh sửa của bạn vẫn được giữ.';
      } else if (error is EditableRemoteException &&
          error.kind == EditableRemoteFailure.deploymentBlocked) {
        _state = ManualPlannerState.error;
        _error = 'Chức năng lưu tài khoản chưa sẵn sàng trên máy chủ.';
      } else if (value.isAccount) {
        _state = ManualPlannerState.uncertain;
        _error = 'Chưa xác nhận được kết quả lưu. Thử lại sẽ dùng đúng yêu cầu đã gửi.';
      } else {
        _state = ManualPlannerState.error;
        _error = 'Chưa lưu được bản nháp. Các chỉnh sửa vẫn còn trên màn hình.';
      }
      _notify();
      return false;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _unregister?.call();
    _unregister = null;
    _document = null;
    _savedDocument = null;
    _base = null;
    _proof = null;
    _pending = null;
    _preview = null;
    _commands.clear();
    super.dispose();
  }
}

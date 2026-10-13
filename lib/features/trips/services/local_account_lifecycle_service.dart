import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

enum LocalAccountLifecycleState {
  resolving,
  ready,
  paused,
  denied,
  cleanupFailed,
}

/// Ephemeral credentials issued only by the checked lifecycle authority.
/// Default Object.toString deliberately does not include any credential fields.
final class AccountSessionProof {
  final String ownerId;
  final int epoch;
  final String accessToken;
  final int expiresAt;
  final Object _issuer;

  AccountSessionProof._(
    this.ownerId,
    this.epoch,
    this.accessToken,
    this.expiresAt,
    this._issuer,
  );
}

/// Real file transport. Fault hooks operate on actual temporary files, not mocks.
/// rename replaces the existing file without deleting it first. Flush/rename is
/// not a claim about hardware power loss or directory fsync on mobile devices.
class LifecycleRegistryFile {
  final String path;
  final Future<void> Function(String step)? onStep;

  LifecycleRegistryFile(this.path, {this.onStep});

  Future<Object?> read() async {
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } on FormatException {
      return null;
    }
  }

  Future<void> write(Map<String, Object?> record) async {
    final target = File(path);
    // App-private parent must already exist; never create arbitrary directory trees.
    final suffix = List.generate(
      16,
      (_) => Random.secure().nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final temporary = File('$path.$suffix.tmp');
    RandomAccessFile? opened;
    Object? failure;
    StackTrace? trace;
    try {
      opened = await temporary.open(mode: FileMode.write);
      await onStep?.call('write');
      await opened.writeString(jsonEncode(record));
      await onStep?.call('flush');
      await opened.flush();
      await opened.close();
      opened = null;
      await onStep?.call('replace');
      await temporary.rename(target.path);
      await onStep?.call('after_replace');
    } catch (e, st) {
      failure = e;
      trace = st;
    } finally {
      try {
        await opened?.close();
      } catch (e, st) {
        failure ??= e;
        trace ??= st;
      }
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (e, st) {
        failure ??= e;
        trace ??= st;
      }
    }
    if (failure != null) Error.throwWithStackTrace(failure, trace!);
  }
}

final class _Subject {
  final String owner;
  final String token;
  final int expiry;
  _Subject(this.owner, this.token, this.expiry);
  String get fingerprint => sha256.convert(utf8.encode(token)).toString();
  bool matches(_Subject? other) =>
      other != null &&
      owner == other.owner &&
      token == other.token &&
      expiry == other.expiry;
}

final class _Registry {
  static const keys = {
    'schemaVersion',
    'state',
    'ownerId',
    'epoch',
    'sessionFingerprint',
    'expiresAt',
    'updatedAt',
  };
  final Map<String, Object?> data;
  _Registry(this.data);

  static _Registry? parse(Object? raw) {
    if (raw is! Map ||
        raw.length != keys.length ||
        raw.keys.any((key) => !keys.contains(key))) {
      return null;
    }
    final map = Map<String, Object?>.from(raw);
    final state = map['state'];
    final epoch = map['epoch'];
    final time = map['updatedAt'];
    if (map['schemaVersion'] is! int ||
        map['schemaVersion'] != 1 ||
        epoch is! int ||
        epoch < 0 ||
        !const {'active', 'sealed', 'revoking', 'signedOut'}.contains(state) ||
        time is! String ||
        !time.endsWith('Z') ||
        DateTime.tryParse(time)?.isUtc != true) {
      return null;
    }
    final owner = map['ownerId'];
    final fingerprint = map['sessionFingerprint'];
    final expiry = map['expiresAt'];
    if (owner == null) {
      if (state == 'sealed' || fingerprint != null || expiry != null) {
        return null;
      }
    } else if (owner is! String ||
        !_validOwner(owner) ||
        fingerprint is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint) ||
        expiry is! int ||
        expiry <= 0) {
      return null;
    }
    return _Registry(map);
  }

  bool permits(_Subject? subject) =>
      subject != null &&
      data['state'] == 'sealed' &&
      data['ownerId'] == subject.owner &&
      data['sessionFingerprint'] == subject.fingerprint &&
      data['expiresAt'] == subject.expiry;
}

bool _validOwner(String owner) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(owner);

final class _Consumer {
  final void Function() invalidate;
  final Future<void> Function(SessionHandle handle) bind;
  bool registered = true;
  _Consumer(this.invalidate, this.bind);
}

final class _AccountTransitionPermit {
  final Object issuer;
  final _Subject subject;
  final int epoch;
  final String kind;
  _AccountTransitionPermit(this.issuer, this.subject, this.epoch, this.kind);
}

/// B6.1 primitive only: callers in B6.2 wire SDK events/lifecycle and must bracket
/// credential mutations and account operations. No SDK mutation or remote delete.
class LocalAccountLifecycleService extends ChangeNotifier {
  final Future<LocalTripStore> Function() _storeLoader;
  final Session? Function() _sessionReader;
  final bool Function() _isDemo;
  final DateTime Function() _clock;
  final Future<String> Function(String token)? _verifySubject;
  final Timer Function(Duration, void Function()) _timerFactory;
  final LifecycleRegistryFile _registry;
  final Object _issuer = Object();
  final List<_Consumer> _consumers = [];
  LocalTripStore? _store;
  SessionHandle? _handle;
  _Subject? _authorizedSubject;
  _Subject? _lastSubject;
  Future<void> _tail = Future.value();
  int _epoch = 0;
  int _controls = 0;
  int _operations = 0;
  int _revocations = 0;
  bool _authMutation = false;
  bool _closed = false;
  bool _consumerFailed = false;
  Timer? _deadline;
  _AccountTransitionPermit? _permit;
  LocalAccountLifecycleState _state = LocalAccountLifecycleState.denied;
  String? _error;

  LocalAccountLifecycleService({
    required this._storeLoader,
    required this._sessionReader,
    required String registryPath,
    LifecycleRegistryFile? registryFile,
    bool Function()? isDemo,
    DateTime Function()? clock,
    this._verifySubject,
    Timer Function(Duration, void Function())? timerFactory,
  }) : _registry = registryFile ?? LifecycleRegistryFile(registryPath),
       _isDemo = isDemo ?? (() => false),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _timerFactory = timerFactory ?? Timer.new;

  int get epoch => _epoch;
  LocalAccountLifecycleState get state => _state;
  String? get error => _error;
  SessionHandle? get handle {
    if (_handle != null && !_authorizedSubject!.matches(_readSubject())) {
      // Expiry/token/subject changes without an SDK event still revoke RAM now.
      unawaited(revokeAccount());
    }
    return _state == LocalAccountLifecycleState.ready ? _handle : null;
  }

  _Subject? _readSubject() {
    if (_closed || _isDemo()) return null;
    try {
      final session = _sessionReader();
      if (session == null ||
          !_validOwner(session.user.id) ||
          session.user.isAnonymous == true ||
          session.tokenType.toLowerCase() != 'bearer' ||
          session.accessToken.trim().isEmpty) {
        return null;
      }
      final expiry = session.expiresAt;
      if (expiry == null ||
          expiry <= _clock().millisecondsSinceEpoch ~/ 1000 + 10) {
        return null;
      }
      return _Subject(session.user.id, session.accessToken, expiry);
    } catch (_) {
      // Malformed SDK expiry/token never becomes local authority.
      return null;
    }
  }

  void _notifyLater() {
    void notify() {
      if (!_closed) notifyListeners();
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notify());
    } else {
      scheduleMicrotask(notify);
    }
  }

  void invalidateAccountContext() {
    _permit = null;
    _epoch++;
    _deadline?.cancel();
    _deadline = null;
    _handle = null;
    _authorizedSubject = null;
    _store?.unbindSession();
    _state = LocalAccountLifecycleState.denied;
    for (final consumer in List<_Consumer>.of(_consumers)) {
      if (!consumer.registered) continue;
      try {
        consumer.invalidate();
      } catch (_) {
        _consumerFailed = true;
      }
    }
    if (_consumerFailed) _fail('Consumer invalidation failed.');
    _notifyLater();
  }

  void _fail(String message) {
    _error =
        message; // Sanitized text only: never stringify tokens or SDK errors.
    _state = LocalAccountLifecycleState.cleanupFailed;
    _notifyLater();
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _controls++;
    _tail = _tail.then((_) async {
      try {
        result.complete(await action());
      } catch (e, st) {
        result.completeError(e, st);
      } finally {
        _controls--;
      }
    });
    return result.future;
  }

  bool _current(int generation, _Subject subject) =>
      !_closed && generation == _epoch && subject.matches(_readSubject());

  Future<LocalTripStore> _loadStore() async {
    final store = _store ?? await _storeLoader();
    _store = store;
    // Loader owns opening/recovery and sharing; service never closes this store.
    store.unbindSession();
    return store;
  }

  Future<void> _write(String state, int generation, _Subject? subject) =>
      _registry.write({
        'schemaVersion': 1,
        'state': state,
        'ownerId': subject?.owner,
        'epoch': generation,
        'sessionFingerprint': subject?.fingerprint,
        'expiresAt': subject?.expiry,
        'updatedAt': _clock().toUtc().toIso8601String(),
      });

  Future<void> _purge(LocalTripStore store, {String? keepOwner}) async {
    final owners = await store.listAccountOwnersForCleanup();
    for (final owner in owners) {
      if (owner == keepOwner) continue;
      await store.purgeAccountData(
        targetOwnerId: owner,
        reason: 'account_lifecycle',
      );
      if (!await store.checkAccountCleanupComplete(ownerId: owner)) {
        throw StateError('Account cleanup is incomplete.');
      }
    }
  }

  AccountSessionProof captureProof() {
    final checkedHandle = handle;
    final subject = _authorizedSubject;
    if (checkedHandle == null ||
        subject == null ||
        _state != LocalAccountLifecycleState.ready) {
      throw StateError('Account context is not authorized.');
    }
    return AccountSessionProof._(
      subject.owner,
      _epoch,
      subject.token,
      subject.expiry,
      _issuer,
    );
  }

  bool isCurrentProof(AccountSessionProof proof) {
    final checkedHandle = handle;
    return identical(proof._issuer, _issuer) &&
        checkedHandle != null &&
        _state == LocalAccountLifecycleState.ready &&
        proof.epoch == _epoch &&
        proof.ownerId == _authorizedSubject?.owner &&
        proof.accessToken == _authorizedSubject?.token &&
        proof.expiresAt == _authorizedSubject?.expiry;
  }

  /// Must bracket every pending import/cache/network action, not only SQL awaits.
  VoidCallback beginAccountOperation(AccountSessionProof proof) {
    if (!isCurrentProof(proof)) throw StateError('Stale account operation.');
    _operations++;
    var finished = false;
    return () {
      if (!finished) {
        finished = true;
        _operations--;
      }
    };
  }

  VoidCallback registerConsumer({
    required VoidCallback invalidate,
    required Future<void> Function(SessionHandle handle) bind,
  }) {
    if (_closed) throw StateError('Lifecycle is closed.');
    final consumer = _Consumer(invalidate, bind);
    _consumers.add(consumer);
    final currentHandle = handle;
    if (currentHandle != null) {
      final generation = _epoch;
      unawaited(
        _enqueue(() async {
          if (!consumer.registered || generation != _epoch || handle == null) {
            return;
          }
          try {
            await consumer.bind(currentHandle);
            if (generation != _epoch || !consumer.registered) {
              consumer.invalidate();
            }
          } catch (_) {
            invalidateAccountContext();
            _fail('Consumer binding failed.');
          }
        }),
      );
    }
    return () {
      if (!consumer.registered) return;
      consumer.registered = false;
      _consumers.remove(consumer);
      try {
        consumer.invalidate();
      } catch (_) {
        _consumerFailed = true;
        invalidateAccountContext();
      }
    };
  }

  Future<SessionHandle?> establishAccount({required bool freshAuthentication}) {
    final subject = _readSubject();
    invalidateAccountContext();
    final generation = _epoch;
    _lastSubject = subject ?? _lastSubject;
    return _enqueue(() async {
      try {
        if (_closed || generation != _epoch) return null;
        _state = LocalAccountLifecycleState.resolving;
        final store = await _loadStore();
        if (generation != _epoch || _closed) return null;
        final record = _Registry.parse(await _registry.read());
        if (generation != _epoch || _closed) return null;
        if (!freshAuthentication && !_recordPermits(record, subject)) {
          await _write('revoking', generation, subject);
          await _purge(store);
          await _write('signedOut', generation, null);
          if (generation == _epoch) _state = LocalAccountLifecycleState.denied;
          return null;
        }
        if (subject == null ||
            !_current(generation, subject) ||
            _authMutation ||
            _revocations > 0 ||
            _consumerFailed) {
          return null;
        }
        await _write('active', generation, subject);
        if (!_current(generation, subject)) return null;
        await _purge(
          store,
          keepOwner: freshAuthentication ? null : subject.owner,
        );
        if (!_current(generation, subject)) return null;
        if (!await store.checkAccountCleanupComplete(ownerId: subject.owner)) {
          throw StateError('Account namespace is blocked.');
        }
        if (freshAuthentication && _verifySubject != null) {
          final verified = await _verifySubject(subject.token);
          if (verified != subject.owner) {
            throw StateError('Subject verification failed.');
          }
        }
        if (!_current(generation, subject)) return null;
        final authorized = await store.activateSession(
          ownerId: subject.owner,
          coordinatorEpoch: generation,
        );
        if (!_current(generation, subject)) {
          store.unbindSession();
          return null;
        }
        _authorizedSubject = subject;
        _handle = authorized;
        for (final consumer in List<_Consumer>.of(_consumers)) {
          if (!consumer.registered) continue;
          await consumer.bind(authorized);
          if (!_current(generation, subject) || !consumer.registered) {
            consumer.invalidate();
          }
          if (!_current(generation, subject)) {
            return null;
          }
        }
        _state = LocalAccountLifecycleState.ready;
        _error = null;
        _deadline = _timerFactory(
          Duration(
            milliseconds:
                (subject.expiry - 10) * 1000 - _clock().millisecondsSinceEpoch,
          ),
          () {
            if (generation == _epoch && !_closed) unawaited(revokeAccount());
          },
        );
        _notifyLater();
        return authorized;
      } catch (_) {
        if (generation == _epoch) {
          invalidateAccountContext();
          _fail(
            'Account authorization failed; cleanup or authentication required.',
          );
        }
        return null;
      }
    });
  }

  bool _recordPermits(_Registry? record, _Subject? subject) =>
      record?.permits(subject) == true;

  Future<SessionHandle?> resumeAccount() =>
      establishAccount(freshAuthentication: false);

  bool _validPermit(_AccountTransitionPermit? permit, String kind) =>
      permit != null &&
      identical(permit.issuer, _issuer) &&
      permit.epoch == _epoch &&
      permit.kind == kind &&
      !_closed &&
      permit.subject.expiry > _clock().millisecondsSinceEpoch ~/ 1000 + 10;

  Future<void> prepareSessionRefresh() {
    final subject = _authorizedSubject;
    if (handle == null ||
        subject == null ||
        _authMutation ||
        _revocations > 0 ||
        _operations > 0 ||
        _controls > 0 ||
        _consumerFailed) {
      return Future.error(StateError('Refresh requires a safe live grant.'));
    }
    invalidateAccountContext();
    _authMutation = true;
    final generation = _epoch;
    _permit = _AccountTransitionPermit(_issuer, subject, generation, 'refresh');
    return _enqueue(() async {
      try {
        await _write('revoking', generation, subject);
        if (!_current(generation, subject)) {
          throw StateError('Refresh canceled.');
        }
      } catch (_) {
        _permit = null;
        _authMutation = false;
        _fail('Refresh preflight failed.');
        throw StateError('Refresh preflight failed.');
      }
    });
  }

  Future<SessionHandle?> completeSessionRefresh({required bool sdkSucceeded}) {
    final permit = _permit;
    final allowed = _validPermit(permit, 'refresh');
    _permit = null;
    _authMutation = false;
    if (!allowed || permit == null) {
      if (permit != null && !_closed) return revokeAccount().then((_) => null);
      return Future.value(null);
    }
    final subject = _readSubject();
    if (subject == null ||
        subject.owner != permit.subject.owner ||
        (!sdkSucceeded && !subject.matches(permit.subject))) {
      return revokeAccount().then((_) => null);
    }
    invalidateAccountContext();
    final generation = _epoch;
    return _enqueue(
      () => _bindPreserving(generation, subject, verify: sdkSucceeded),
    );
  }

  Future<void> suspendForegroundContext() {
    if (_validPermit(_permit, 'live')) return Future.value();
    final subject = _authorizedSubject;
    final safe =
        handle != null &&
        subject != null &&
        _controls == 0 &&
        _operations == 0 &&
        !_authMutation &&
        _revocations == 0 &&
        !_consumerFailed;
    invalidateAccountContext();
    if (safe) {
      _permit = _AccountTransitionPermit(_issuer, subject, _epoch, 'live');
    }
    return Future.value();
  }

  Future<SessionHandle?> resumeForegroundContext() {
    final permit = _permit;
    if (!_validPermit(permit, 'live') || permit == null) return resumeAccount();
    if (!permit.subject.matches(_readSubject())) {
      return revokeAccount().then((_) => null);
    }
    invalidateAccountContext();
    final generation = _epoch;
    return _enqueue(
      () => _bindPreserving(generation, permit.subject, verify: false),
    );
  }

  Future<SessionHandle?> _bindPreserving(
    int generation,
    _Subject subject, {
    required bool verify,
  }) async {
    try {
      if (!_current(generation, subject) ||
          _authMutation ||
          _revocations > 0 ||
          _consumerFailed) {
        return null;
      }
      final store = await _loadStore();
      if (!_current(generation, subject)) return null;
      await _write('active', generation, subject);
      await _purge(store, keepOwner: subject.owner);
      if (!_current(generation, subject) ||
          !await store.checkAccountCleanupComplete(ownerId: subject.owner)) {
        return null;
      }
      if (verify && _verifySubject != null) {
        if (await _verifySubject(subject.token) != subject.owner) {
          throw StateError('Subject mismatch.');
        }
      }
      if (!_current(generation, subject)) return null;
      final bound = await store.activateSession(
        ownerId: subject.owner,
        coordinatorEpoch: generation,
      );
      if (!_current(generation, subject)) {
        store.unbindSession();
        return null;
      }
      _authorizedSubject = subject;
      _lastSubject = subject;
      _handle = bound;
      for (final consumer in List<_Consumer>.of(_consumers)) {
        if (!consumer.registered) continue;
        await consumer.bind(bound);
        if (!_current(generation, subject) || !consumer.registered) {
          consumer.invalidate();
        }
        if (!_current(generation, subject)) return null;
      }
      _state = LocalAccountLifecycleState.ready;
      _error = null;
      _deadline = _timerFactory(
        Duration(
          milliseconds:
              (subject.expiry - 10) * 1000 - _clock().millisecondsSinceEpoch,
        ),
        () {
          if (generation == _epoch && !_closed) unawaited(revokeAccount());
        },
      );
      _notifyLater();
      return bound;
    } catch (_) {
      if (generation == _epoch) {
        invalidateAccountContext();
        _fail('Session transition failed; account remains locked.');
      }
      return null;
    }
  }

  Future<void> prepareAuthenticationMutation() {
    if (_closed || _authMutation || _revocations > 0) {
      return Future.error(StateError('Authentication is busy.'));
    }
    _authMutation = true;
    invalidateAccountContext();
    final generation = _epoch;
    return _enqueue(() async {
      try {
        if (_closed) throw StateError('Lifecycle is closed.');
        await _write('revoking', generation, _lastSubject);
        if (_closed || generation != _epoch || _revocations > 0) {
          throw StateError('Authentication preflight was canceled.');
        }
      } catch (_) {
        _authMutation = false;
        _fail('Authentication preflight failed.');
        throw StateError('Authentication preflight failed.');
      }
    });
  }

  /// B6.2 calls this in finally after the captured SDK mutation has completed.
  void completeAuthenticationMutation() {
    _authMutation = false;
  }

  Future<bool> revokeAccount() {
    invalidateAccountContext();
    final generation = _epoch;
    _revocations++;
    return _enqueue(() async {
      try {
        if (_closed) return false;
        final store = await _loadStore();
        await _write('revoking', generation, _lastSubject);
        await _purge(store);
        await _write('signedOut', generation, null);
        if (generation == _epoch) {
          _state = LocalAccountLifecycleState.denied;
          _error = null;
          _notifyLater();
        }
        return !_consumerFailed;
      } catch (_) {
        _fail('Account cleanup failed; account cache remains locked.');
        return false;
      } finally {
        _revocations--;
      }
    });
  }

  Future<bool> sealForPause() {
    final live = _permit;
    final suspended = _validPermit(live, 'live');
    final subject = suspended ? live?.subject : _authorizedSubject;
    final eligible =
        (suspended || handle != null) &&
        _controls == 0 &&
        _operations == 0 &&
        !_authMutation &&
        _revocations == 0 &&
        !_consumerFailed;
    invalidateAccountContext();
    final generation = _epoch;
    return _enqueue(() async {
      try {
        if (!eligible || subject == null || !_current(generation, subject)) {
          return false;
        }
        final store = await _loadStore();
        if (!await store.checkAccountCleanupComplete(ownerId: subject.owner) ||
            !_current(generation, subject) ||
            _authMutation ||
            _revocations > 0) {
          return false;
        }
        // A failed cleanup for any account makes this process uncertain.
        // Do not grant an offline permit while another namespace is blocked.
        for (final owner in await store.listAccountOwnersForCleanup()) {
          if (!await store.checkAccountCleanupComplete(ownerId: owner)) {
            return false;
          }
        }
        if (!_current(generation, subject)) return false;
        await _write('sealed', generation, subject);
        if (!_current(generation, subject) ||
            _authMutation ||
            _revocations > 0) {
          // A seal completing after synchronous cancellation must be consumed.
          await _write('revoking', generation, subject);
          return false;
        }
        _state = LocalAccountLifecycleState.paused;
        _notifyLater();
        return true;
      } catch (_) {
        _fail('Pause checkpoint failed; offline restart is unavailable.');
        return false;
      }
    });
  }

  Future<void> close() {
    dispose();
    return _tail;
  }

  @override
  void dispose() {
    if (_closed) return;
    invalidateAccountContext();
    _closed = true;
    _consumers.clear();
    super.dispose();
  }
}

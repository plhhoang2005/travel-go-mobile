import 'dart:async';
import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/map_models.dart';

abstract class GroupLocationGateway {
  Future<String> joinGroup({
    required String roomCode,
    required String displayName,
    required String avatarInitials,
  });
  Stream<List<GroupMemberLocation>> watchMembers(String groupId);
  Future<void> publishLocation({
    required String groupId,
    required LatLng position,
  });
  Future<void> markOffline(String groupId);
}

class GroupLocationService implements GroupLocationGateway {
  final SupabaseClient? _injectedClient;
  final DateTime Function() _now;
  RealtimeChannel? _activeChannel;
  StreamController<List<GroupMemberLocation>>? _membersController;
  final Map<String, GroupMemberLocation> _activeMembers = {};
  static final String _sessionUserId =
      'guest_${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  String? _myUserId;
  String? _myDisplayName;
  String? _myAvatarInitials;
  Timer? _staleMembersTimer;
  Future<void> _channelOperations = Future<void>.value();
  int _generation = 0;
  Completer<void>? _pendingSubscribe;

  GroupLocationService({SupabaseClient? client, DateTime Function()? now})
    : _injectedClient = client,
      _now = now ?? DateTime.now;
  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _channelOperations.then((_) => action());
    _channelOperations = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  void _emitMembers() {
    final controller = _membersController;
    if (controller != null && !controller.isClosed) {
      controller.add(_activeMembers.values.toList());
    }
  }

  void _pruneMembers() {
    final now = _now();
    var changed = false;
    for (final entry in _activeMembers.entries.toList()) {
      final age = now.difference(entry.value.updatedAt);
      if (age > const Duration(seconds: 30)) {
        _activeMembers.remove(entry.key);
        changed = true;
      } else if (age > const Duration(seconds: 15) &&
          entry.value.status != GroupMemberStatus.idle) {
        _activeMembers[entry.key] = entry.value.copyWith(
          status: GroupMemberStatus.idle,
        );
        changed = true;
      }
    }
    if (changed) _emitMembers();
  }

  Future<void> _releaseChannel(RealtimeChannel channel) async {
    try {
      await _client.removeChannel(channel).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // Late teardown owns only this captured channel, never a new session.
    }
  }

  @override
  Future<String> joinGroup({
    required String roomCode,
    required String displayName,
    required String avatarInitials,
  }) {
    final code = roomCode.trim().toUpperCase();
    if (code.isEmpty) {
      return Future.error(StateError('Mã phòng không được để trống.'));
    }
    final generation = ++_generation;
    return _serialize(() async {
      if (generation != _generation) {
        throw StateError('Kết nối Radar đã bị hủy.');
      }
      final previous = _activeChannel;
      _activeChannel = null;
      _staleMembersTimer?.cancel();
      _activeMembers.clear();
      unawaited(_membersController?.close());
      _membersController = null;
      if (previous != null) await _releaseChannel(previous);
      if (generation != _generation) {
        throw StateError('Kết nối Radar đã bị hủy.');
      }
      _myUserId ??= _client.auth.currentUser?.id ?? _sessionUserId;
      _myDisplayName = displayName.trim().isEmpty ? 'Bạn' : displayName.trim();
      _myAvatarInitials = avatarInitials.trim().isEmpty
          ? _myDisplayName![0].toUpperCase()
          : avatarInitials.trim();
      final controller =
          StreamController<List<GroupMemberLocation>>.broadcast();
      _membersController = controller;
      final channel = _client.channel('radar:$code');
      _activeChannel = channel;
      channel.onBroadcast(
        event: 'location_ping',
        callback: (payload) {
          if (generation != _generation ||
              !identical(_activeChannel, channel)) {
            return;
          }
          final userId = payload['user_id'] as String? ?? '';
          if (userId.isEmpty || userId == _myUserId) return;
          _activeMembers[userId] = GroupMemberLocation(
            memberId: userId,
            displayName:
                payload['display_name'] as String? ?? 'Thành viên TravelGO',
            avatarInitials: payload['avatar_initials'] as String? ?? 'TG',
            position: LatLng(
              (payload['latitude'] as num?)?.toDouble() ?? 0,
              (payload['longitude'] as num?)?.toDouble() ?? 0,
            ),
            // Local receipt time avoids clock skew between devices breaking TTL.
            updatedAt: _now(),
            status: GroupMemberStatus.online,
            isDemo: false,
          );
          _emitMembers();
        },
      );
      channel.onBroadcast(
        event: 'member_left',
        callback: (payload) {
          if (generation != _generation ||
              !identical(_activeChannel, channel)) {
            return;
          }
          _activeMembers.remove(payload['user_id']);
          _emitMembers();
        },
      );
      final subscribed = Completer<void>();
      _pendingSubscribe = subscribed;
      try {
        channel.subscribe((status, error) {
          if (generation != _generation ||
              !identical(_activeChannel, channel)) {
            return;
          }
          if (status == RealtimeSubscribeStatus.subscribed) {
            if (!subscribed.isCompleted) subscribed.complete();
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut ||
              status == RealtimeSubscribeStatus.closed) {
            final failure =
                error ?? StateError('Kết nối Radar bị đóng: $status');
            if (!subscribed.isCompleted) {
              subscribed.completeError(failure);
            } else if (!controller.isClosed) {
              controller.addError(failure);
            }
          }
        }, const Duration(seconds: 6));
        await subscribed.future.timeout(const Duration(seconds: 6));
        if (generation != _generation) {
          throw StateError('Kết nối Radar đã bị hủy.');
        }
        _staleMembersTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => _pruneMembers(),
        );
        return code;
      } catch (_) {
        if (identical(_activeChannel, channel)) {
          _activeChannel = null;
          _activeMembers.clear();
          _membersController = null;
        }
        unawaited(controller.close());
        await _releaseChannel(channel);
        rethrow;
      } finally {
        if (identical(_pendingSubscribe, subscribed)) _pendingSubscribe = null;
      }
    });
  }

  @override
  Stream<List<GroupMemberLocation>> watchMembers(String groupId) =>
      _membersController?.stream ?? Stream.value([]);

  @override
  Future<void> publishLocation({
    required String groupId,
    required LatLng position,
  }) async {
    final channel = _activeChannel;
    if (channel == null) return;
    await channel
        .sendBroadcastMessage(
          event: 'location_ping',
          payload: {
            'user_id': _myUserId,
            'display_name': _myDisplayName,
            'avatar_initials': _myAvatarInitials,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'updated_at': DateTime.now().toIso8601String(),
            'status': 'online',
          },
        )
        .timeout(const Duration(seconds: 2));
  }

  @override
  Future<void> markOffline(String groupId) {
    ++_generation;
    final channel = _activeChannel;
    _activeChannel = null;
    final pending = _pendingSubscribe;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Kết nối Radar đã bị hủy.'));
    }
    _staleMembersTimer?.cancel();
    _staleMembersTimer = null;
    _activeMembers.clear();
    final controller = _membersController;
    _membersController = null;
    unawaited(controller?.close());
    return _serialize(() async {
      if (channel == null) return;
      try {
        await channel
            .sendBroadcastMessage(
              event: 'member_left',
              payload: {'user_id': _myUserId},
            )
            .timeout(const Duration(seconds: 1));
      } catch (_) {
        // TTL evicts members even when the departure packet cannot be delivered.
      } finally {
        await _releaseChannel(channel);
      }
    });
  }

  Future<void> dispose() => markOffline('');
}

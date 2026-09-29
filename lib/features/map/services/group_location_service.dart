import 'dart:async';
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
  RealtimeChannel? _activeChannel;
  StreamController<List<GroupMemberLocation>>? _membersController;
  final Map<String, GroupMemberLocation> _activeMembers = {};

  String? _myUserId;
  String? _myDisplayName;
  String? _myAvatarInitials;

  GroupLocationService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('Supabase chưa được khởi tạo.');
    }
  }

  @override
  Future<String> joinGroup({
    required String roomCode,
    required String displayName,
    required String avatarInitials,
  }) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw StateError('Mã phòng không được để trống.');
    }

    _myUserId = 'user_${DateTime.now().millisecondsSinceEpoch % 100000}';
    _myDisplayName = displayName.trim().isNotEmpty ? displayName.trim() : 'Bạn';
    _myAvatarInitials = avatarInitials.trim().isNotEmpty
        ? avatarInitials.trim()
        : (_myDisplayName!.isNotEmpty ? _myDisplayName![0].toUpperCase() : 'TG');

    if (_activeChannel != null) {
      try {
        await _activeChannel!.unsubscribe();
        _client.removeChannel(_activeChannel!);
      } catch (_) {}
    }
    _activeMembers.clear();

    _membersController?.close();
    _membersController = StreamController<List<GroupMemberLocation>>.broadcast();

    final channelName = 'radar:$normalizedCode';
    final channel = _client.channel(channelName);

    channel.onBroadcast(
      event: 'location_ping',
      callback: (payload) {
        final userId = payload['user_id'] as String? ?? '';
        if (userId.isEmpty || userId == _myUserId) return;

        final member = GroupMemberLocation(
          memberId: userId,
          displayName: payload['display_name'] as String? ?? 'Thành viên TravelGO',
          avatarInitials: payload['avatar_initials'] as String? ?? 'TG',
          position: LatLng(
            (payload['latitude'] as num?)?.toDouble() ?? 0.0,
            (payload['longitude'] as num?)?.toDouble() ?? 0.0,
          ),
          updatedAt: DateTime.tryParse(payload['updated_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
          status: GroupMemberStatus.online,
          isDemo: false,
        );

        _activeMembers[userId] = member;
        if (_membersController != null && !_membersController!.isClosed) {
          _membersController!.add(_activeMembers.values.toList());
        }
      },
    );

    channel.onBroadcast(
      event: 'member_left',
      callback: (payload) {
        final userId = payload['user_id'] as String? ?? '';
        if (userId.isNotEmpty && _activeMembers.containsKey(userId)) {
          _activeMembers.remove(userId);
          if (_membersController != null && !_membersController!.isClosed) {
            _membersController!.add(_activeMembers.values.toList());
          }
        }
      },
    );

    channel.subscribe();
    _activeChannel = channel;

    return normalizedCode;
  }

  @override
  Stream<List<GroupMemberLocation>> watchMembers(String groupId) {
    if (_membersController != null) {
      return _membersController!.stream;
    }
    return Stream.value([]);
  }

  @override
  Future<void> publishLocation({
    required String groupId,
    required LatLng position,
  }) async {
    final channel = _activeChannel;
    if (channel == null) return;

    await channel.sendBroadcastMessage(
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
    );
  }

  @override
  Future<void> markOffline(String groupId) async {
    final channel = _activeChannel;
    if (channel != null) {
      try {
        await channel.sendBroadcastMessage(
          event: 'member_left',
          payload: {'user_id': _myUserId},
        );
      } catch (_) {}
      try {
        await channel.unsubscribe();
        _client.removeChannel(channel);
      } catch (_) {}
      _activeChannel = null;
    }
    _activeMembers.clear();
    await _membersController?.close();
    _membersController = null;
  }
}

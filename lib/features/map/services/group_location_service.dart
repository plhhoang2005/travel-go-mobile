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
    final response = await _client.rpc(
      'join_map_group',
      params: {
        'p_join_code': roomCode.trim(),
        'p_display_name': displayName.trim(),
        'p_avatar_initials': avatarInitials.trim(),
      },
    );
    if (response is! String || response.isEmpty) {
      throw StateError('Supabase không trả về mã nhóm hợp lệ.');
    }
    return response;
  }

  @override
  Stream<List<GroupMemberLocation>> watchMembers(String groupId) {
    return _client
        .from('map_member_locations')
        .stream(primaryKey: ['group_id', 'user_id'])
        .eq('group_id', groupId)
        .map((rows) => rows.map(_memberFromRow).toList(growable: false));
  }

  @override
  Future<void> publishLocation({
    required String groupId,
    required LatLng position,
  }) async {
    await _client.rpc(
      'publish_map_location',
      params: {
        'p_group_id': groupId,
        'p_latitude': position.latitude,
        'p_longitude': position.longitude,
      },
    );
  }

  @override
  Future<void> markOffline(String groupId) async {
    await _client.rpc(
      'mark_map_location_offline',
      params: {'p_group_id': groupId},
    );
  }

  GroupMemberLocation _memberFromRow(Map<String, dynamic> row) {
    final statusName = row['status'] as String? ?? 'offline';
    final status = switch (statusName) {
      'online' => GroupMemberStatus.online,
      'idle' => GroupMemberStatus.idle,
      _ => GroupMemberStatus.offline,
    };

    return GroupMemberLocation(
      memberId: row['user_id'] as String? ?? '',
      displayName: row['display_name'] as String? ?? 'Thành viên TravelGO',
      avatarInitials: row['avatar_initials'] as String? ?? 'TG',
      position: LatLng(
        (row['latitude'] as num?)?.toDouble() ?? 0,
        (row['longitude'] as num?)?.toDouble() ?? 0,
      ),
      updatedAt:
          DateTime.tryParse(row['updated_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      status: status,
      isDemo: row['is_demo'] as bool? ?? false,
    );
  }
}

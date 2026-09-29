import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';

class GroupRadarSheet extends StatefulWidget {
  final MapProvider provider;

  const GroupRadarSheet({
    super.key,
    required this.provider,
  });

  @override
  State<GroupRadarSheet> createState() => _GroupRadarSheetState();
}

class _GroupRadarSheetState extends State<GroupRadarSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _roomCodeController;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Bạn');
    _roomCodeController = TextEditingController(
      text: widget.provider.activeGroupId ?? 'TG-2026',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final name = _nameController.text.trim().isEmpty ? 'Bạn' : _nameController.text.trim();
    final roomCode = _roomCodeController.text.trim().isEmpty
        ? 'TG-2026'
        : _roomCodeController.text.trim().toUpperCase();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'TG';

    setState(() => _isConnecting = true);
    try {
      await widget.provider.connectGroupRadar(
        userId: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        displayName: name,
        avatarInitials: initials,
        roomCode: roomCode,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Đã kết nối phòng radar: $roomCode'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final primaryColor = colorScheme.primary;
        final isEnabled = widget.provider.isGroupRadarEnabled;
        final isDemo = widget.provider.isDemoGroupRadar;
        final members = widget.provider.groupMembers;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isEnabled ? const Color(0xFF10B981) : primaryColor).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.radar_rounded,
                  color: isEnabled ? const Color(0xFF10B981) : primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRAVEL-GO REALTIME RADAR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: isEnabled ? const Color(0xFF10B981) : primaryColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isEnabled
                          ? 'Phòng: ${widget.provider.activeGroupId ?? (isDemo ? "DEMO" : "TG-2026")}'
                          : 'Radar Nhóm Du Lịch',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF102037),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (isEnabled) ...[
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDemo ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDemo ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isDemo ? Icons.info_outline_rounded : Icons.check_circle_rounded,
                    size: 16,
                    color: isDemo ? const Color(0xFFD97706) : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDemo
                          ? (widget.provider.groupRadarMessage ?? 'Đang hiển thị 4 thành viên demo.')
                          : 'Đang phát GPS thật qua Supabase Realtime Broadcast',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDemo ? const Color(0xFFB45309) : const Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Members List
            Text(
              'THÀNH VIÊN TRONG PHÒNG (${members.length}):',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Color(0xFF91A0B4),
              ),
            ),
            const SizedBox(height: 8),

            if (members.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Text(
                    'Chưa có bạn bè nào khác vào phòng ${widget.provider.activeGroupId}.\nHãy mở app trên điện thoại khác và nhập mã này!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: members.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final m = members[idx];
                    final distMeters = widget.provider.distanceToGroupMemberMeters(m).round();
                    final distStr = distMeters >= 1000
                        ? '${(distMeters / 1000).toStringAsFixed(1)} km'
                        : '$distMeters m';
                    final timeStr = DateFormat('HH:mm').format(m.updatedAt);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4338CA),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                m.avatarInitials,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.displayName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF102037),
                                  ),
                                ),
                                Text(
                                  'Cập nhật: $timeStr · ${m.status == GroupMemberStatus.online ? "Trực tuyến" : "Ngoại tuyến"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF91A0B4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            distStr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF086C61),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Disconnect Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error.withAlpha(120)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                label: const Text('Rời phòng / Tắt Radar', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await widget.provider.disconnectGroupRadar();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ] else ...[
            // Form to Connect
            const Text(
              'Định vị vị trí bạn bè trong đoàn theo thời gian thực trên bản đồ OpenStreetMap.',
              style: TextStyle(fontSize: 13, color: Color(0xFF5E718B), height: 1.4),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Tên hiển thị của bạn',
                prefixIcon: const Icon(Icons.person_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _roomCodeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Mã phòng nhóm',
                hintText: 'VD: TG-2026',
                prefixIcon: const Icon(Icons.meeting_room_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF15803D)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn và bạn bè chỉ cần nhập cùng một Mã phòng, vị trí GPS thật sẽ tự động truyền qua Supabase Broadcast lên bản đồ của nhau mà không cần tài khoản.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF086C61),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isConnecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded, size: 18),
                label: Text(
                  _isConnecting ? 'Đang kết nối...' : 'KẾT NỐI PHÒNG RADAR',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _isConnecting ? null : _handleConnect,
              ),
            ),
            const SizedBox(height: 8),

            Center(
              child: TextButton(
                onPressed: () {
                  widget.provider.setGroupRadarEnabled(true);
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Hoặc xem thử dữ liệu mẫu (4 thành viên demo)',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5E718B)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
      },
    );
  }
}

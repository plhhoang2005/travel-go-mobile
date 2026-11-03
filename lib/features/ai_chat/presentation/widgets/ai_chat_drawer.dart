import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ai_chat_provider.dart';

/// Navigation Drawer hiển thị danh sách lịch sử các phiên chat và quản lý session
class AiChatDrawer extends StatelessWidget {
  const AiChatDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiChatProvider>();
    final sessions = provider.sessions;
    final currentSession = provider.currentSession;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header Drawer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lịch sử hội thoại',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${sessions.length} cuộc trò chuyện',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Nút Tạo cuộc trò chuyện mới
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    provider.createNewSession();
                    Navigator.pop(context); // Đóng drawer
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Cuộc trò chuyện mới',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            // Danh sách các phiên trò chuyện
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có lịch sử hội thoại',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: sessions.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isSelected = currentSession?.id == session.id;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            leading: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurface,
                              ),
                            ),
                            onTap: () {
                              provider.selectSession(session.id);
                              Navigator.pop(context);
                            },
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18),
                              tooltip: 'Tùy chọn',
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Đổi tên'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Xóa',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (action) {
                                if (action == 'rename') {
                                  _showRenameDialog(context, provider, session.id, session.title);
                                } else if (action == 'delete') {
                                  _showDeleteDialog(context, provider, session.id, session.title);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    AiChatProvider provider,
    String sessionId,
    String currentTitle,
  ) {
    final controller = TextEditingController(text: currentTitle);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên cuộc trò chuyện'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập tên mới...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              provider.renameSession(sessionId, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    AiChatProvider provider,
    String sessionId,
    String title,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa cuộc trò chuyện "$title"? Toàn bộ tin nhắn sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteSession(sessionId);
              Navigator.pop(ctx);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

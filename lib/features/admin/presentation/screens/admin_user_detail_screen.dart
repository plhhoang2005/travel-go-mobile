// Admin User Detail Screen: Inspects user details, audit trail, and mutation actions.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_account_provider.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminAccountProvider>().selectUser(widget.userId);
    });
  }

  void _showActionDialog({
    required BuildContext context,
    required UserDetail user,
    required String action,
    required String actionTitle,
    required String targetStateDescription,
  }) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final provider = context.read<AdminAccountProvider>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return ChangeNotifierProvider.value(
          value: provider,
          child: Consumer<AdminAccountProvider>(
            builder: (context, provider, _) {
              final isMutating = provider.isMutating;
              final error = provider.error;
              if (!provider.hasAdminAccess) {
                return AlertDialog(
                  title: const Text('Phiên quản trị đã thay đổi'),
                  content: const Text(
                    'Vui lòng quay lại và xác minh quyền trước khi tiếp tục.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text('Đóng'),
                    ),
                  ],
                );
              }

              return AlertDialog(
                title: Text(actionTitle),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Người dùng: ${user.fullName} (${user.email})'),
                        const SizedBox(height: 4),
                        Text('Mục tiêu: $targetStateDescription'),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: reasonController,
                          enabled:
                              !isMutating && !provider.hasRetryableOperation,
                          decoration: const InputDecoration(
                            labelText: 'Lý do thao tác (bắt buộc)',
                            hintText:
                                'Nhập lý do thực hiện thao tác quản trị...',
                            border: OutlineInputBorder(),
                          ),
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 500,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập lý do (tối thiểu 1 ký tự)';
                            }
                            if (val.trim().length > 500) {
                              return 'Lý do không được vượt quá 500 ký tự';
                            }
                            return null;
                          },
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            provider.needsReadback
                                ? 'Thao tác đã được ghi nhận. Cần tải lại thông tin tài khoản.'
                                : error.userMessage,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isMutating
                        ? null
                        : () => Navigator.of(dialogCtx).pop(),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    onPressed: isMutating
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            final current = provider.selectedUser;
                            final success = provider.hasRetryableOperation
                                ? await provider.retryOperation()
                                : await provider.confirmMutation(
                                    targetId: user.id,
                                    expectedRevision: current?.id == user.id
                                        ? current!.revision
                                        : user.revision,
                                    action: action,
                                    reason: reasonController.text.trim(),
                                  );
                            if (success && dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Thao tác "$actionTitle" đã được ghi nhận',
                                  ),
                                ),
                              );
                            }
                          },
                    child: isMutating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            provider.hasRetryableOperation
                                ? 'Thử lại'
                                : 'Xác nhận',
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AdminAccountProvider>();
    final user = provider.selectedUser?.id == widget.userId
        ? provider.selectedUser
        : null;
    final isLoading = provider.isLoadingDetail;
    final error = provider.error;
    final currentAdminId = provider.authProvider.currentUser?.id;

    final isSelf = user != null && user.id == currentAdminId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết người dùng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading
                ? null
                : () => provider.selectUser(widget.userId),
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading && user == null
            ? const Center(child: CircularProgressIndicator())
            : user == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(error?.userMessage ?? 'Không tìm thấy người dùng'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.selectUser(widget.userId),
                      child: const Text('Tải lại'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Overview Card
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: user.isAdmin
                                      ? AppTheme.primaryColor
                                      : Colors.grey.shade300,
                                  foregroundColor: user.isAdmin
                                      ? Colors.white
                                      : Colors.black87,
                                  child: Icon(
                                    user.isAdmin
                                        ? Icons.admin_panel_settings
                                        : Icons.person,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName.isNotEmpty
                                            ? user.fullName
                                            : '(Không tên)',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _DetailField(
                              label: 'Mã định danh (ID)',
                              value: user.id,
                            ),
                            _DetailField(
                              label: 'Vai trò',
                              value: user.isAdmin
                                  ? 'Quản trị viên (admin)'
                                  : 'Khách hàng (customer)',
                            ),
                            _DetailField(
                              label: 'Trạng thái tài khoản',
                              value: user.state == 'locked'
                                  ? 'Đã bị khóa'
                                  : (user.state == 'unlocking'
                                        ? 'Đang mở khóa'
                                        : 'Đang hoạt động'),
                            ),
                            _DetailField(
                              label: 'Ngày tạo',
                              value: DateFormat('dd/MM/yyyy HH:mm:ss')
                                  .format(user.createdAt.toLocal()),
                            ),
                            _DetailField(
                              label: 'Lần đăng nhập cuối',
                              value: user.lastSignInAt == null
                                  ? 'Chưa đăng nhập'
                                  : DateFormat('dd/MM/yyyy HH:mm:ss')
                                        .format(user.lastSignInAt!.toLocal()),
                            ),
                            _DetailField(
                              label: 'Đồng bộ xác thực',
                              value: user.authSynced
                                  ? 'Đã đồng bộ'
                                  : 'Chưa đồng bộ, cần kiểm tra lại',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actions Section
                    Text(
                      'Thao tác quản trị',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (provider.hasRetryableOperation &&
                        provider.pendingTargetId == user.id) ...[
                      Text(
                        provider.needsReadback
                            ? 'Thao tác đã được ghi nhận. Cần tải lại thông tin tài khoản.'
                            : 'Thao tác chưa hoàn tất đồng bộ xác thực.',
                      ),
                      TextButton.icon(
                        onPressed: provider.isMutating
                            ? null
                            : provider.retryOperation,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          provider.needsReadback
                              ? 'Tải lại kết quả'
                              : 'Kiểm tra và thử lại',
                        ),
                      ),
                    ],

                    if (isSelf)
                      Card(
                        color: Colors.amber.shade50,
                        child: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Không thể tự khóa tài khoản của chính mình.',
                                  style: TextStyle(color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          // Lock / Unlock button
                          if (user.state == 'enabled')
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                              ),
                              onPressed:
                                  provider.hasRetryableOperation ||
                                      provider.isMutating
                                  ? null
                                  : () => _showActionDialog(
                                      context: context,
                                      user: user,
                                      action: 'lock',
                                      actionTitle: 'Khóa tài khoản',
                                      targetStateDescription:
                                          'Khóa quyền truy cập tài khoản',
                                    ),
                              icon: const Icon(Icons.lock, size: 18),
                              label: const Text('Khóa tài khoản'),
                            )
                          else if (user.state == 'locked')
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                              ),
                              onPressed:
                                  provider.hasRetryableOperation ||
                                      provider.isMutating
                                  ? null
                                  : () => _showActionDialog(
                                      context: context,
                                      user: user,
                                      action: 'unlock',
                                      actionTitle: 'Mở khóa tài khoản',
                                      targetStateDescription: 'Mở lại quyền truy cập sau khi đồng bộ xác thực',
                                    ),
                              icon: const Icon(Icons.lock_open, size: 18),
                              label: const Text('Mở khóa tài khoản'),
                            )
                          else if (user.state == 'unlocking')
                            OutlinedButton.icon(
                              onPressed: null,
                              icon: const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              label: const Text('Đang đồng bộ xác thực...'),
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    // Audit Trail Section
                    Text(
                      'Lịch sử quản trị (${user.audit.length} sự kiện)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (user.audit.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Chưa có sự kiện kiểm toán nào được ghi nhận cho tài khoản này.',
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: user.audit.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final event = user.audit[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              event.eventKind.contains('lock')
                                  ? Icons.lock
                                  : (event.eventKind.contains('unlock')
                                        ? Icons.lock_open
                                        : Icons.history),
                              size: 20,
                            ),
                            title: Text(
                              event.eventKind,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Lý do: ${event.reason}'),
                                Text(
                                  'Bởi: ${event.actorId} • ${DateFormat('dd/MM/yyyy HH:mm:ss').format(event.createdAt.toLocal())}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;

  const _DetailField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

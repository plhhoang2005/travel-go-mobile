// Admin Draft History Screen: Inspects previous catalogue draft revisions and restores safely.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_catalogue_provider.dart';

class AdminDraftHistoryScreen extends StatefulWidget {
  const AdminDraftHistoryScreen({super.key});

  @override
  State<AdminDraftHistoryScreen> createState() => _AdminDraftHistoryScreenState();
}

class _AdminDraftHistoryScreenState extends State<AdminDraftHistoryScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminCatalogueProvider>();
      if (provider.snapshot == null && !provider.isLoading) {
        provider.load();
      }
    });
  }

  Future<void> _showRestoreDialog(AdminDraftVersion version) async {
    final provider = context.read<AdminCatalogueProvider>();
    final reasonController = TextEditingController(
      text: 'Khôi phục về phiên bản r${version.revision}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Khôi phục phiên bản r${version.revision}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Các điểm đến và địa điểm được tạo ở phiên bản mới hơn sẽ được chuyển sang trạng thái tạm ẩn để bảo toàn dữ liệu.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('restore_reason_field'),
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do khôi phục *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('restore_cancel_button'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Huỷ bỏ'),
            ),
            ElevatedButton(
              key: const Key('restore_confirm_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận khôi phục'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final reason = reasonController.text.trim();
      final success = await provider.restoreVersion(version.revision, reason);
      if (!mounted) return;
      if (!success && provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error!.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AdminCatalogueProvider>();
    final snapshot = provider.snapshot;
    final isLoading = provider.isLoading;
    final error = provider.error;
    final currentRevision = provider.currentRevision;

    final history = snapshot?.history ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử phiên bản'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: isLoading ? null : () => provider.load(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Phiên bản hiện tại: r$currentRevision',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Text(
                          'Có thay đổi chưa xuất bản',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bản nháp được lưu trên máy chủ, chỉ hiển thị với quản trị viên. Chưa có phiên bản công khai nào được phát hành.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.slate600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            if (isLoading && snapshot == null)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null && snapshot == null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          error.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => provider.load(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (history.isEmpty)
              const Expanded(
                child: Center(child: Text('Chưa có lịch sử phiên bản nào')),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final v = history[i];
                    final isCurrent = v.revision == currentRevision;
                    final hashPrefix = v.payloadHash.substring(0, min(8, v.payloadHash.length));

                    return ListTile(
                      key: Key('history_tile_${v.revision}'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isCurrent ? AppTheme.primaryColor : AppTheme.slate200,
                        foregroundColor: isCurrent ? Colors.white : AppTheme.slate700,
                        child: Text('r${v.revision}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                        v.reason.isEmpty ? 'Cập nhật phiên bản r${v.revision}' : v.reason,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_dateFormat.format(v.changedAt)} • Hash: $hashPrefix',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      trailing: isCurrent
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Text(
                                'Hiện tại',
                                style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                              ),
                            )
                          : OutlinedButton(
                              key: Key('restore_version_btn_${v.revision}'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              onPressed: () => _showRestoreDialog(v),
                              child: const Text('Khôi phục', style: TextStyle(fontSize: 12)),
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
}

// Admin Publication Screen: Preview release summary, inspect blockers/warnings, and confirm immutable publication.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_publication_provider.dart';

class AdminPublicationScreen extends StatefulWidget {
  final int draftRevision;

  const AdminPublicationScreen({
    super.key,
    required this.draftRevision,
  });

  @override
  State<AdminPublicationScreen> createState() => _AdminPublicationScreenState();
}

class _AdminPublicationScreenState extends State<AdminPublicationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminPublicationProvider>();
      if (provider.preview == null && !provider.isLoadingPreview) {
        provider.loadPreview(widget.draftRevision);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AdminPublicationProvider>();
    final preview = provider.preview;
    final operation = provider.operation;
    final isLoading = provider.isLoadingPreview;
    final isPublishing = provider.isPublishing;
    final error = provider.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xuất bản danh mục V2'),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang tạo bản xem trước xuất bản...'),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (operation != null && operation.isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Xuất bản thành công phiên bản v${operation.version}!',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          error.message,
                          style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (preview == null && error != null)
                      OutlinedButton(
                        key: const Key('reload_publication_preview_button'),
                        onPressed: isPublishing
                            ? null
                            : () => provider.loadPreview(widget.draftRevision),
                        child: const Text('Tải lại bản xem trước'),
                      ),

                    if (preview != null) ...[
                      // Version & Summary card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Phiên bản phát hành mới: v${preview.expectedActiveVersion + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primarySoft,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Từ nháp r${preview.sourceRevision}',
                                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Wrap(
                              alignment: WrapAlignment.spaceAround,
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                _buildMetricColumn('Thêm mới', preview.summary.added.toString(), Colors.green),
                                _buildMetricColumn('Thay đổi', preview.summary.changed.toString(), Colors.blue),
                                _buildMetricColumn('Tạm ẩn', preview.summary.hidden.toString(), Colors.grey),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Blockers section
                      if (preview.hasBlockers) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.error, color: Colors.red.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Lỗi chặn xuất bản (${preview.blockers.length})',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...preview.blockers.map((b) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      '• [${b.path}] ${b.message}',
                                      style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Warnings section
                      if (preview.warnings.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cảnh báo (${preview.warnings.length})',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...preview.warnings.map((w) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      '• [${w.path}] ${w.message}',
                                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Info text
                      Text(
                        'Dữ liệu xuất bản sẽ tạo đối tượng công khai bất biến trên máy chủ. Tất cả người dùng sẽ nhận được bản cập nhật này khi làm mới.',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.slate600, height: 1.4),
                      ),
                      const SizedBox(height: 24),

                      // Confirm Publish Button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          key: const Key('confirm_publish_button'),
                          onPressed: (preview.hasBlockers || isPublishing || (operation != null && operation.isCompleted))
                              ? null
                              : () => provider.confirmPublish(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: isPublishing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Xác nhận xuất bản', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Cancel Button
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          key: const Key('cancel_publish_button'),
                          onPressed: isPublishing ? null : () => Navigator.of(context).pop(),
                          child: const Text('Huỷ bỏ'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

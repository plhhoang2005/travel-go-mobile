// Form widget for editing or creating an admin destination draft.

import 'package:flutter/material.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';

class AdminDestinationForm extends StatefulWidget {
  final AdminDestinationDraft? initial;
  final Future<bool> Function(AdminDestinationDraft draft, String reason) onSubmit;
  final VoidCallback? onCancel;

  const AdminDestinationForm({
    super.key,
    this.initial,
    required this.onSubmit,
    this.onCancel,
  });

  @override
  State<AdminDestinationForm> createState() => _AdminDestinationFormState();
}

class _AdminDestinationFormState extends State<AdminDestinationForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _regionController;
  late final TextEditingController _descController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _reasonController;
  bool _isActive = true;
  bool _isSubmitting = false;
  String? _serverError;

  bool get isEditing => widget.initial?.id != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _nameController = TextEditingController(text: init?.name ?? '');
    _slugController = TextEditingController(text: init?.slug ?? '');
    _regionController = TextEditingController(text: init?.region ?? '');
    _descController = TextEditingController(text: init?.description ?? '');
    _imageUrlController = TextEditingController(text: init?.imageUrl ?? '');
    _reasonController = TextEditingController(
      text: isEditing ? 'Cập nhật thông tin điểm đến' : 'Thêm điểm đến mới',
    );
    _isActive = init?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _regionController.dispose();
    _descController.dispose();
    _imageUrlController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String _generateSlug(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll(RegExp(r'[đ]'), 'd')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  Future<void> _handleSubmit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    var slug = _slugController.text.trim();
    if (slug.isEmpty) {
      slug = _generateSlug(name);
    }
    final region = _regionController.text.trim();
    final desc = _descController.text.trim();
    final imageUrl = _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim();
    final reason = _reasonController.text.trim();

    final draft = AdminDestinationDraft(
      id: widget.initial?.id,
      name: name,
      slug: slug,
      region: region,
      description: desc,
      imageUrl: imageUrl,
      active: _isActive,
      sourceRefs: widget.initial?.sourceRefs ?? const [],
      sourceEdits: widget.initial?.sourceEdits ?? const [],
      imageRights: widget.initial?.imageRights,
    );

    setState(() => _isSubmitting = true);
    try {
      final success = await widget.onSubmit(draft, reason);
      if (!mounted) return;
      if (!success) {
        setState(() {
          _serverError = 'Không thể lưu điểm đến. Vui lòng thử lại.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa điểm đến' : 'Thêm điểm đến mới'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryColor.withAlpha(76)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lưu nháp không cập nhật danh mục của khách hàng cho đến khi xuất bản.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_serverError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _serverError!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Name field (1-180 chars)
                TextFormField(
                  key: const Key('destination_name_field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên điểm đến *',
                    hintText: 'VD: Đà Nẵng, Phú Quốc...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final text = val?.trim() ?? '';
                    if (text.isEmpty) return 'Tên điểm đến không được để trống';
                    if (text.length > 180) return 'Tên không được vượt quá 180 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Slug field
                TextFormField(
                  key: const Key('destination_slug_field'),
                  controller: _slugController,
                  decoration: const InputDecoration(
                    labelText: 'Slug (mã định danh URL)',
                    hintText: 'VD: da-nang (để trống sẽ tự tạo)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final text = val?.trim() ?? '';
                    if (text.isNotEmpty && text.length > 100) {
                      return 'Slug không được vượt quá 100 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Region field
                TextFormField(
                  key: const Key('destination_region_field'),
                  controller: _regionController,
                  decoration: const InputDecoration(
                    labelText: 'Vùng / Miền *',
                    hintText: 'VD: Miền Trung, Miền Nam...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final text = val?.trim() ?? '';
                    if (text.isEmpty) return 'Vui lòng nhập vùng / miền';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Description field
                TextFormField(
                  key: const Key('destination_desc_field'),
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả tóm tắt *',
                    hintText: 'Giới thiệu ngắn về điểm đến...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final text = val?.trim() ?? '';
                    if (text.isEmpty) return 'Mô tả không được để trống';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Image URL field
                TextFormField(
                  key: const Key('destination_image_field'),
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'URL hình ảnh đại diện (tuỳ chọn)',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final text = val?.trim() ?? '';
                    if (text.isNotEmpty) {
                      final uri = Uri.tryParse(text);
                      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
                        return 'URL hình ảnh không hợp lệ (phải bắt đầu bằng http:// hoặc https://)';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Reason for change
                TextFormField(
                  key: const Key('destination_reason_field'),
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Lý do thay đổi (ghi nhận nhật ký) *',
                    hintText: 'VD: Cập nhật thông tin điểm đến',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final text = val?.trim() ?? '';
                    if (text.isEmpty) return 'Vui lòng nhập lý do thay đổi';
                    if (text.length > 500) return 'Lý do không được vượt quá 500 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Active toggle
                SwitchListTile.adaptive(
                  key: const Key('destination_active_switch'),
                  title: const Text('Trạng thái hoạt động'),
                  subtitle: Text(_isActive ? 'Đang hoạt động' : 'Tạm ẩn khỏi khách hàng'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('destination_submit_button'),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Lưu nháp',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cancel button
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    key: const Key('destination_cancel_button'),
                    onPressed: _isSubmitting ? null : (widget.onCancel ?? () => Navigator.of(context).pop()),
                    child: const Text('Huỷ bỏ'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

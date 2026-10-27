// Form widget for editing or creating an admin place draft.

import 'package:flutter/material.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';

class AdminPlaceForm extends StatefulWidget {
  final AdminPlaceDraft? initial;
  final List<AdminDestinationDraft> destinations;
  final Future<bool> Function(AdminPlaceDraft draft, String reason) onSubmit;
  final VoidCallback? onCancel;
  final String? Function()? errorMessageProvider;

  const AdminPlaceForm({
    super.key,
    this.initial,
    required this.destinations,
    required this.onSubmit,
    this.onCancel,
    this.errorMessageProvider,
  });

  @override
  State<AdminPlaceForm> createState() => _AdminPlaceFormState();
}

class _AdminPlaceFormState extends State<AdminPlaceForm> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedDestinationId;
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _descController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
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
    _selectedDestinationId = init?.destinationId;
    if (_selectedDestinationId == null && widget.destinations.isNotEmpty) {
      _selectedDestinationId = widget.destinations.first.id;
    }

    _nameController = TextEditingController(text: init?.name ?? '');
    _slugController = TextEditingController(text: init?.slug ?? '');
    _descController = TextEditingController(text: init?.description ?? '');
    _latController = TextEditingController(text: init?.latitude?.toString() ?? '');
    _lngController = TextEditingController(text: init?.longitude?.toString() ?? '');
    _imageUrlController = TextEditingController(text: init?.imageUrl ?? '');
    _reasonController = TextEditingController(
      text: isEditing ? 'Cập nhật thông tin địa điểm' : 'Thêm địa điểm mới',
    );
    _isActive = init?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
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
    final desc = _descController.text.trim();
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();
    final double? lat = latText.isEmpty ? null : double.tryParse(latText);
    final double? lng = lngText.isEmpty ? null : double.tryParse(lngText);
    final imageUrl = _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim();
    final reason = _reasonController.text.trim();

    final draft = AdminPlaceDraft(
      id: widget.initial?.id,
      destinationId: _selectedDestinationId ?? '',
      name: name,
      slug: slug,
      description: desc,
      latitude: lat,
      longitude: lng,
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
        final err = widget.errorMessageProvider?.call();
        setState(() {
          _serverError = err ?? 'Không thể lưu và xuất bản địa điểm. Vui lòng thử lại.';
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

    // Build selectable destinations list, ensuring current selection is present even if inactive
    final availableDestinations = List<AdminDestinationDraft>.from(widget.destinations);
    if (_selectedDestinationId != null &&
        !availableDestinations.any((d) => d.id == _selectedDestinationId)) {
      availableDestinations.insert(
        0,
        AdminDestinationDraft(
          id: _selectedDestinationId,
          name: _selectedDestinationId!,
          slug: _selectedDestinationId!,
          region: 'Không xác định',
          description: '',
          active: false,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa địa điểm' : 'Thêm địa điểm mới'),
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

                // Destination dropdown
                DropdownButtonFormField<String>(
                  key: const Key('place_destination_dropdown'),
                  isExpanded: true,
                  initialValue: _selectedDestinationId,
                  decoration: const InputDecoration(
                    labelText: 'Thuộc điểm đến *',
                    border: OutlineInputBorder(),
                  ),
                  items: availableDestinations.map((d) {
                    return DropdownMenuItem<String>(
                      value: d.id,
                      child: Text(
                        '${d.name} (${d.region})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedDestinationId = val);
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Vui lòng chọn điểm đến';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Name field (1-180 chars)
                TextFormField(
                  key: const Key('place_name_field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên địa điểm *',
                    hintText: 'VD: Cầu Vàng, Bãi Sao...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final text = val?.trim() ?? '';
                    if (text.isEmpty) return 'Tên địa điểm không được để trống';
                    if (text.length > 180) return 'Tên không được vượt quá 180 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Slug field
                TextFormField(
                  key: const Key('place_slug_field'),
                  controller: _slugController,
                  decoration: const InputDecoration(
                    labelText: 'Slug (mã định danh)',
                    hintText: 'VD: cau-vang (để trống sẽ tự tạo)',
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

                // Description field
                TextFormField(
                  key: const Key('place_desc_field'),
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả địa điểm *',
                    hintText: 'Thông tin chi tiết về địa điểm...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final text = val?.trim() ?? '';
                    if (text.isEmpty) return 'Mô tả không được để trống';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Coordinate pair row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('place_lat_field'),
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Vĩ độ (Latitude)',
                          hintText: 'VD: 16.0544',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          final latText = val?.trim() ?? '';
                          final lngText = _lngController.text.trim();
                          if (latText.isNotEmpty && lngText.isEmpty) {
                            return 'Cần nhập đủ cả toạ độ';
                          }
                          if (latText.isEmpty && lngText.isNotEmpty) {
                            return 'Cần nhập đủ cả toạ độ';
                          }
                          if (latText.isNotEmpty) {
                            final parsed = double.tryParse(latText);
                            if (parsed == null || parsed < -90.0 || parsed > 90.0) {
                              return 'Vĩ độ từ -90 đến 90';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const Key('place_lng_field'),
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Kinh độ (Longitude)',
                          hintText: 'VD: 108.2022',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          final lngText = val?.trim() ?? '';
                          final latText = _latController.text.trim();
                          if (lngText.isNotEmpty && latText.isEmpty) {
                            return 'Cần nhập đủ cả toạ độ';
                          }
                          if (lngText.isEmpty && latText.isNotEmpty) {
                            return 'Cần nhập đủ cả toạ độ';
                          }
                          if (lngText.isNotEmpty) {
                            final parsed = double.tryParse(lngText);
                            if (parsed == null || parsed < -180.0 || parsed > 180.0) {
                              return 'Kinh độ từ -180 đến 180';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Image URL field
                TextFormField(
                  key: const Key('place_image_field'),
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
                  key: const Key('place_reason_field'),
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Lý do thay đổi (ghi nhận nhật ký) *',
                    hintText: 'VD: Cập nhật thông tin địa điểm',
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
                  key: const Key('place_active_switch'),
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
                    key: const Key('place_submit_button'),
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
                    key: const Key('place_cancel_button'),
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

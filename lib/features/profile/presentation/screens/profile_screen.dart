import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/models/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../admin/presentation/screens/admin_shell_screen.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  Future<void> _logout(BuildContext context, AuthProvider auth) async {
    final success = await auth.logout();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Đã đăng xuất khỏi thiết bị này.'
              : auth.logoutErrorMessage ?? 'Chưa hoàn tất đăng xuất.',
        ),
      ),
    );
  }

  static ImageProvider? _resolveAvatarImage(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) return null;
    final clean = avatarUrl.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return NetworkImage(clean);
    }
    final file = File(clean);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final guest = auth.isGuest || user == null;
    final name = guest ? 'Khách Vãng Lai' : user.fullName;
    final avatarImage = _resolveAvatarImage(user?.avatarUrl);
    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      appBar: AppBar(
        title: const Text('Tài Khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.bgSurface,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: guest ? null : () => _showAvatarPickerModal(context, auth, user),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: AppTheme.primarySoft,
                          foregroundColor: AppTheme.primaryColor,
                          backgroundImage: avatarImage,
                          child: avatarImage != null
                              ? null
                              : Text(
                                  name.isEmpty ? 'G' : name.characters.first.toUpperCase(),
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                        ),
                        if (!guest)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          guest ? 'Chưa đăng nhập tài khoản' : user.email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: (!guest && user.role == UserRole.admin)
                                    ? AppTheme.mintDark.withValues(alpha: 0.15)
                                    : AppTheme.primarySoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                guest ? 'GUEST' : user.role.badgeName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: (!guest && user.role == UserRole.admin)
                                      ? AppTheme.mintDark
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            if (auth.isDemoSession) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.coralColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Tài khoản minh họa',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.coralColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (guest) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warmCream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.amberAccent.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Bạn đang khám phá ở chế độ Khách. Đăng nhập để mở các chuyến đi của tài khoản.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMain),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryColor, size: 20),
                    ),
                    title: const Text('Thông tin cá nhân', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      guest
                          ? 'Cần đăng nhập để cập nhật hồ sơ'
                          : 'Họ tên, số điện thoại và địa chỉ',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                    onTap: () {
                      if (guest) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vui lòng đăng nhập để cập nhật thông tin cá nhân',
                            ),
                          ),
                        );
                      } else {
                        _showEditProfileDialog(context, auth, user);
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: AppTheme.slate100),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.coralColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.tune_rounded, color: AppTheme.coralColor, size: 20),
                    ),
                    title: const Text('Sở thích du lịch', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      guest
                          ? 'Đăng nhập để lưu hồ sơ du lịch'
                          : 'Sở thích, ngân sách thường dùng và phong cách',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                    onTap: guest
                        ? null
                        : () => _showTravelPreferences(context, auth, user.id),
                  ),
                  if (!guest && user.role == UserRole.admin) ...[
                    const Divider(height: 1, indent: 56, color: AppTheme.slate100),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.mintDark.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.mintDark, size: 20),
                      ),
                      title: const Text('Quản trị', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Quản lý người dùng và địa điểm', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AdminShellScreen()),
                        );
                      },
                    ),
                  ],
                  const Divider(height: 1, indent: 56, color: AppTheme.slate100),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.language_rounded, color: Colors.blue, size: 20),
                    ),
                    title: const Text('Tiếng Việt · VND', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Ngôn ngữ và đơn vị tiền đang hiển thị', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (auth.isLoggingOut || auth.logoutNeedsRetry)
              OutlinedButton.icon(
                onPressed: auth.isLoggingOut
                    ? null
                    : () => _logout(context, auth),
                icon: const Icon(Icons.logout),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                label: Text(
                  auth.isLoggingOut
                      ? 'Đang đăng xuất…'
                      : 'Thử hoàn tất đăng xuất',
                ),
              )
            else if (guest)
              FilledButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                icon: const Icon(Icons.login),
                label: const Text('Đăng nhập / Đăng ký ngay'),
              )
            else
              OutlinedButton.icon(
                onPressed: () => _logout(context, auth),
                icon: const Icon(Icons.logout, color: Colors.red),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                label: const Text('Đăng xuất'),
              ),
          ],
        ),
      ),
    );
  }

  
  Future<void> _showAvatarPickerModal(
    BuildContext context,
    AuthProvider auth,
    UserEntity user,
  ) async {
    final urlController = TextEditingController(text: user.avatarUrl ?? '');
    final presets = [
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
      'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200',
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Đổi ảnh đại diện',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Chọn ảnh đại diện du lịch mẫu:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: presets.map((url) {
                final isSelected = user.avatarUrl == url;
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await auth.updateProfile(avatarUrl: url);
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã cập nhật ảnh đại diện thành công!')),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage: NetworkImage(url),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Hoặc dán đường dẫn ảnh trực tiếp:',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'https://example.com/avatar.jpg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '💡 Ghi chú: Bạn có thể chọn ảnh từ máy, ảnh mẫu hoặc đường dẫn ảnh trực tiếp.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final newUrl = urlController.text.trim();
                  if (newUrl.isNotEmpty) {
                    Navigator.pop(ctx);
                    final ok = await auth.updateProfile(avatarUrl: newUrl);
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã cập nhật ảnh đại diện!')),
                      );
                    }
                  }
                },
                child: const Text('Lưu ảnh đại diện'),
              ),
            ),
          ],
        ),
      ),
    );
    urlController.dispose();
  }

  Future<void> _showTravelPreferences(
    BuildContext context,
    AuthProvider auth,
    String owner,
  ) async {
    final epoch = auth.authEpoch;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _TravelPreferencesDialog(auth: auth, owner: owner, epoch: epoch),
    );
    if (!context.mounted ||
        saved != true ||
        auth.currentUser?.id != owner ||
        auth.authEpoch != epoch ||
        auth.isGuest) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã lưu sở thích du lịch')));
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    AuthProvider auth,
    UserEntity user,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _EditProfileDialog(auth: auth, user: user),
    );
    if (!context.mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thông tin thành công')),
      );
    }
  }
}

class _TravelPreferencesDialog extends StatefulWidget {
  final AuthProvider auth;
  final String owner;
  final int epoch;
  const _TravelPreferencesDialog({
    required this.auth,
    required this.owner,
    required this.epoch,
  });
  @override
  State<_TravelPreferencesDialog> createState() =>
      _TravelPreferencesDialogState();
}

class _TravelPreferencesDialogState extends State<_TravelPreferencesDialog> {
  final _form = GlobalKey<FormState>();
  final _interests = TextEditingController(),
      _budget = TextEditingController(),
      _style = TextEditingController();
  bool _ready = false, _saving = false, _closing = false;
  bool get _current =>
      widget.auth.currentUser?.id == widget.owner &&
      widget.auth.authEpoch == widget.epoch &&
      !widget.auth.isGuest;
  List<String> get _interestValues => _interests.text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _interests.dispose();
    _budget.dispose();
    _style.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted || !_current) return;
    setState(() => _ready = false);
    final loaded = await widget.auth.loadTravelPreferences();
    if (!mounted || !_current) return;
    setState(() {
      _ready = loaded;
      if (loaded) {
        final value = widget.auth.currentUser!.travelPreferences!;
        _interests.text = value.interests.join('\n');
        _budget.text = value.typicalBudgetVnd?.toString() ?? '';
        _style.text = value.travelStyle ?? '';
      }
    });
  }

  Future<void> _save() async {
    if (!_current || _saving || !_ready || !_form.currentState!.validate()) {
      return;
    }
    final preferences = TravelPreferences.fromInput(
      interests: _interestValues,
      typicalBudgetVnd: _budget.text.trim().isEmpty
          ? null
          : int.parse(_budget.text.trim()),
      travelStyle: _style.text,
    );
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final saved = await widget.auth.updateTravelPreferences(preferences);
    if (!mounted || !_current) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.auth,
    builder: (context, _) {
      if (!_current) {
        if (!_closing) {
          _closing = true;
          final route = ModalRoute.of(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && route != null && route.isActive) {
              Navigator.of(context).removeRoute(route);
            }
          });
        }
        return const SizedBox.shrink();
      }
      final loading = widget.auth.travelPreferencesLoading;
      final error = widget.auth.travelPreferencesError;
      return PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: const Text('Sở thích du lịch'),
          scrollable: true,
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lưu cho hồ sơ của bạn. Chuyến đi hiện có không thay đổi.',
                  ),
                  if (loading && !_ready) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                    const Text('Đang tải hồ sơ…'),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  if (!_ready && !loading)
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử tải lại'),
                    ),
                  if (_ready) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('profile-interests'),
                      controller: _interests,
                      enabled: !_saving,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Sở thích (mỗi dòng một mục)',
                        helperText:
                            'Tối đa 20 mục khác nhau, mỗi mục 80 ký tự.',
                      ),
                      validator: (_) {
                        try {
                          TravelPreferences.fromInput(
                            interests: _interestValues,
                          );
                          return null;
                        } on FormatException {
                          return 'Kiểm tra mục trùng, độ dài và số sở thích.';
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('profile-budget'),
                      controller: _budget,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ngân sách thường dùng (VND)',
                        helperText: 'Để trống nếu chưa đặt. Chấp nhận 0 VND.',
                      ),
                      validator: (text) {
                        final raw = text!.trim();
                        if (raw.isEmpty) return null;
                        final value = int.tryParse(raw);
                        return value == null ||
                                value < 0 ||
                                value > TravelPreferences.maxBudgetVnd
                            ? 'Nhập số tiền nguyên không âm trong giới hạn cho phép.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('profile-style'),
                      controller: _style,
                      enabled: !_saving,
                      maxLength: TravelPreferences.maxTextLength,
                      decoration: const InputDecoration(
                        labelText: 'Phong cách du lịch',
                        helperText:
                            'Ví dụ: thư thái, khám phá. Có thể để trống.',
                      ),
                      validator: (value) {
                        try {
                          TravelPreferences.fromInput(travelStyle: value);
                          return null;
                        } on FormatException {
                          return 'Phong cách tối đa 80 ký tự, không xuống dòng.';
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('profile-preferences-cancel'),
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const ValueKey('profile-preferences-save'),
              onPressed: !_ready || _saving || loading ? null : _save,
              child: Text(_saving ? 'Đang lưu…' : 'Lưu sở thích'),
            ),
          ],
        ),
      );
    },
  );
}

class _EditProfileDialog extends StatefulWidget {
  final AuthProvider auth;
  final UserEntity user;

  const _EditProfileDialog({required this.auth, required this.user});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phone);
    _addressController = TextEditingController(text: widget.user.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        title: const Text(
          'Thông Tin Cá Nhân',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chỉnh sửa thông tin hồ sơ của bạn:',
                style: TextStyle(fontSize: 13, color: AppTheme.slate600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: 'Họ và tên',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                enabled: !_isSaving,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: 'Địa chỉ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Email: ${widget.user.email} (Không thể thay đổi)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.slate500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: _isSaving
                ? null
                : () async {
                    final newName = _nameController.text.trim();
                    final newPhone = _phoneController.text.trim();
                    final newAddress = _addressController.text.trim();

                    if (newName.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Họ và tên không được để trống'),
                          ),
                        );
                      }
                      return;
                    }

                    setState(() {
                      _isSaving = true;
                    });

                    final success = await widget.auth.updateProfile(
                      fullName: newName,
                      phone: newPhone,
                      address: newAddress,
                    );

                    if (!context.mounted) return;

                    if (success) {
                      Navigator.pop(context, true);
                    } else {
                      setState(() {
                        _isSaving = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            widget.auth.errorMessage ?? 'Cập nhật thất bại',
                          ),
                        ),
                      );
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF086C61),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

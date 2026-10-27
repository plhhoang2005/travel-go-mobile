import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/backend_api_config.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final guest = auth.isGuest || user == null;
    final name = guest ? 'Khách Vãng Lai' : user.fullName;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tài Khoản')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    name.isEmpty ? 'G' : name.characters.first.toUpperCase(),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleLarge),
                      Text(guest ? 'Chưa đăng nhập tài khoản' : user.email),
                      const SizedBox(height: 8),
                      Text(
                        guest ? 'GUEST' : user.role.badgeName,
                        style: theme.textTheme.labelLarge,
                      ),
                      if (auth.isDemoSession) const Text('Tài khoản minh họa'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (guest) ...[
              const Text(
                'Bạn đang khám phá ở chế độ Khách. Đăng nhập để mở các chuyến đi của tài khoản.',
              ),
              const SizedBox(height: 16),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text('Thông tin cá nhân'),
              subtitle: Text(
                guest
                    ? 'Cần đăng nhập để cập nhật hồ sơ'
                    : 'Họ tên, số điện thoại và địa chỉ',
              ),
              trailing: const Icon(Icons.chevron_right),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune),
              title: const Text('Sở thích du lịch'),
              subtitle: Text(
                guest
                    ? 'Đăng nhập để lưu hồ sơ du lịch'
                    : 'Sở thích, ngân sách thường dùng và phong cách',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: guest
                  ? null
                  : () => _showTravelPreferences(context, auth, user.id),
            ),
            if (!guest &&
                !auth.isDemoSession &&
                user.role == UserRole.admin) ...[
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Quản trị'),
                subtitle: const Text('Quản lý người dùng và địa điểm'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminShellScreen()),
                  );
                },
              ),
            ],
            const Divider(height: 24),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.language),
              title: Text('Tiếng Việt · VND'),
              subtitle: Text('Ngôn ngữ và đơn vị tiền đang hiển thị'),
            ),
            const Divider(height: 24),
            Builder(
              builder: (context) {
                BackendApiConfig? config;
                try {
                  config = context.watch<BackendApiConfig>();
                } catch (_) {}
                final currentUrl =
                    config?.effectiveBaseUrl ?? ApiConstants.baseUrl;
                final displayUrl = currentUrl.split('/api')[0];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.developer_mode),
                  title: const Text('Máy chủ Backend (API)'),
                  subtitle: Text(
                    config?.persistenceError != null
                        ? '$displayUrl · Chưa lưu bền vững'
                        : displayUrl,
                  ),
                  onTap: () => _showBackendConfigDialog(context),
                );
              },
            ),
            const SizedBox(height: 24),
            if (auth.isLoggingOut || auth.logoutNeedsRetry)
              OutlinedButton.icon(
                onPressed: auth.isLoggingOut
                    ? null
                    : () => _logout(context, auth),
                icon: const Icon(Icons.logout),
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
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
          ],
        ),
      ),
    );
  }

  void _showBackendConfigDialog(BuildContext context) {
    BackendApiConfig? config;
    try {
      config = context.read<BackendApiConfig>();
    } catch (_) {}

    final controller = TextEditingController(
      text: config?.effectiveBaseUrl ?? ApiConstants.baseUrl,
    );
    showDialog(
      context: context,
      builder: (ctx) {
        String? errorMessage;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text(
              'Cấu hình Máy chủ Backend',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhập URL Backend API (Hữu ích khi test trên thiết bị thật qua mạng Wi-Fi LAN hoặc máy chủ từ xa):',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.slate600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('backend-url-input'),
                    controller: controller,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      hintText: 'http://192.168.1.x:8080/api/v1',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (config?.persistenceError != null ||
                      errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage ?? config!.persistenceError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() {
                          isSubmitting = true;
                          errorMessage = null;
                        });
                        try {
                          if (config != null) {
                            await config.reset();
                          } else {
                            ApiConstants.overrideBaseUrl = null;
                          }
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã khôi phục URL API mặc định'),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            errorMessage = e is FormatException
                                ? e.message
                                : (e is StateError ? e.message : e.toString());
                          });
                        }
                      },
                child: const Text('Mặc định'),
              ),
              FilledButton(
                key: const ValueKey('backend-url-save'),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final raw = controller.text.trim();
                        setDialogState(() {
                          isSubmitting = true;
                          errorMessage = null;
                        });
                        try {
                          if (config != null) {
                            await config.setBaseUrl(raw);
                          } else {
                            ApiConstants.overrideBaseUrl =
                                BackendApiConfig.normalizeAndValidateUrl(raw);
                          }
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          final currentUrl =
                              config?.effectiveBaseUrl ?? ApiConstants.baseUrl;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã lưu URL API: $currentUrl'),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            errorMessage = e is FormatException
                                ? e.message
                                : (e is StateError ? e.message : e.toString());
                          });
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF086C61),
                ),
                child: isSubmitting
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
      },
    );
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

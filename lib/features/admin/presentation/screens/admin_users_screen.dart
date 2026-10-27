// Admin Users Screen: Lists users with filtering, search, and pagination.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_user_detail_screen.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_account_provider.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AdminAccountProvider>();
      if (provider.users.isEmpty && !provider.isLoadingUsers) {
        provider.loadUsers(nextPage: false);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<AdminAccountProvider>();
      if (provider.hasMoreUsers && !provider.isLoadingUsers) {
        provider.loadUsers(nextPage: true);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AdminAccountProvider>();
    if (_searchController.text != provider.query) {
      _searchController.value = TextEditingValue(
        text: provider.query,
        selection: TextSelection.collapsed(offset: provider.query.length),
      );
    }
    final users = provider.users;
    final isLoading = provider.isLoadingUsers;
    final error = provider.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý người dùng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: isLoading
                ? null
                : () => provider.loadUsers(nextPage: false),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Tìm theo tên hoặc email',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            _searchController.clear();
                            provider.setFilter(query: '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                onChanged: (text) => provider.setFilter(query: text),
              ),
            ),

            // Role and State Filter Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _FilterChip<String?>(
                    label: 'Tất cả vai trò',
                    isSelected: provider.roleFilter == null,
                    onSelected: () => provider.setFilter(role: null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip<String>(
                    label: 'Admin',
                    isSelected: provider.roleFilter == 'admin',
                    onSelected: () => provider.setFilter(role: 'admin'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip<String>(
                    label: 'Khách hàng',
                    isSelected: provider.roleFilter == 'customer',
                    onSelected: () => provider.setFilter(role: 'customer'),
                  ),
                  const SizedBox(width: 16),
                  const VerticalDivider(width: 1),
                  const SizedBox(width: 16),
                  _FilterChip<String?>(
                    label: 'Tất cả trạng thái',
                    isSelected: provider.stateFilter == null,
                    onSelected: () => provider.setFilter(state: null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip<String>(
                    label: 'Đang hoạt động',
                    isSelected: provider.stateFilter == 'enabled',
                    onSelected: () => provider.setFilter(state: 'enabled'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip<String>(
                    label: 'Đã khóa',
                    isSelected: provider.stateFilter == 'locked',
                    onSelected: () => provider.setFilter(state: 'locked'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip<String>(
                    label: 'Đang mở khóa',
                    isSelected: provider.stateFilter == 'unlocking',
                    onSelected: () => provider.setFilter(state: 'unlocking'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            if (error != null)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error.userMessage,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => provider.loadUsers(
                        nextPage: users.isNotEmpty && provider.hasMoreUsers,
                      ),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),

            // Users List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.loadUsers(nextPage: false),
                child: users.isEmpty && isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : users.isEmpty && error != null
                    ? const Center(
                        child: Text('Chưa tải được danh sách người dùng.'),
                      )
                    : users.isEmpty && !isLoading
                    ? const Center(
                        child: Text(
                          'Không tìm thấy người dùng nào phù hợp',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        itemCount:
                            users.length + (provider.hasMoreUsers ? 1 : 0),
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index >= users.length) {
                            return Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: isLoading
                                    ? const CircularProgressIndicator()
                                    : TextButton(
                                        onPressed: () =>
                                            provider.loadUsers(nextPage: true),
                                        child: const Text('Tải thêm'),
                                      ),
                              ),
                            );
                          }
                          final user = users[index];
                          return _UserTile(user: user);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip<T> extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserSummary user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final lastSignInText = user.lastSignInAt == null
        ? 'Chưa đăng nhập'
        : DateFormat('dd/MM/yyyy HH:mm').format(user.lastSignInAt!.toLocal());

    Color stateColor;
    String stateLabel;
    switch (user.state) {
      case 'locked':
        stateColor = Colors.red.shade700;
        stateLabel = 'Đã khóa';
        break;
      case 'unlocking':
        stateColor = Colors.orange.shade800;
        stateLabel = 'Đang mở khóa';
        break;
      default:
        stateColor = AppTheme.primaryColor;
        stateLabel = 'Hoạt động';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 4.0,
      ),
      leading: CircleAvatar(
        backgroundColor: user.isAdmin
            ? AppTheme.primaryColor
            : Colors.grey.shade300,
        foregroundColor: user.isAdmin ? Colors.white : Colors.black87,
        child: Icon(user.isAdmin ? Icons.admin_panel_settings : Icons.person),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.fullName.isNotEmpty ? user.fullName : '(Không tên)',
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: user.isAdmin
                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              user.isAdmin ? 'ADMIN' : 'USER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: user.isAdmin
                    ? AppTheme.primaryColor
                    : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: stateColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                stateLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: stateColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text('• $lastSignInText', style: const TextStyle(fontSize: 12)),
              if (!user.authSynced) ...[
                const SizedBox(width: 6),
                const Icon(Icons.sync_problem, size: 14, color: Colors.amber),
                const SizedBox(width: 2),
                const Text(
                  'Chưa đồng bộ xác thực',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        final accountProvider = context.read<AdminAccountProvider>();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider<AdminAccountProvider>.value(
              value: accountProvider,
              child: AdminUserDetailScreen(userId: user.id),
            ),
          ),
        );
      },
    );
  }
}

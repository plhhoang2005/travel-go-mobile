// Admin Shell Screen: Responsive administration container with navigation and access enforcement.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/constants/supabase_constants.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_account_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_account_service.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';

class AdminShellScreen extends StatefulWidget {
  final AdminAccountProvider? provider;

  const AdminShellScreen({super.key, this.provider});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  AdminAccountProvider? _ownedProvider;
  int _selectedIndex = 0;
  bool _isCheckingAccess = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAndCheckAccess());
  }

  Future<void> _initAndCheckAccess() async {
    final activeProvider = _getEffectiveProvider();
    setState(() => _isCheckingAccess = true);
    await activeProvider.enter();
    if (mounted) {
      setState(() => _isCheckingAccess = false);
    }
  }

  AdminAccountProvider _getEffectiveProvider() {
    if (widget.provider != null) return widget.provider!;
    if (_ownedProvider != null) return _ownedProvider!;

    final auth = context.read<AuthProvider>();
    Future<LocalAccountLifecycleService> Function()? lifecycleLoader;
    try {
      lifecycleLoader = context.read<Future<LocalAccountLifecycleService> Function()>();
    } catch (_) {
      lifecycleLoader = () => Future.error(StateError('Lifecycle loader not found in context.'));
    }

    final service = AdminAccountService(
      dio: Dio(),
      projectOrigin: Uri.parse(SupabaseConstants.projectUrl),
      publicKey: SupabaseConstants.publishableKey,
      lifecycleLoader: lifecycleLoader,
    );

    _ownedProvider = AdminAccountProvider(
      service: service,
      authProvider: auth,
    );
    return _ownedProvider!;
  }

  @override
  void dispose() {
    _ownedProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveProvider = _getEffectiveProvider();

    return ChangeNotifierProvider<AdminAccountProvider>.value(
      value: effectiveProvider,
      child: Consumer<AdminAccountProvider>(
        builder: (context, provider, _) {
          if (_isCheckingAccess) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang xác minh quyền quản trị...'),
                  ],
                ),
              ),
            );
          }

          if (!provider.hasAdminAccess) {
            final error = provider.error;
            return Scaffold(
              appBar: AppBar(title: const Text('Quản trị')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gpp_bad_outlined, size: 64, color: Colors.red.shade700),
                      const SizedBox(height: 16),
                      const Text(
                        'Truy cập bị từ chối',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error != null
                            ? 'Lỗi máy chủ (${error.code}): ${error.message}'
                            : 'Tài khoản của bạn không có quyền quản trị hoặc phiên đăng nhập không hợp lệ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Quay lại'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _initAndCheckAccess,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final width = MediaQuery.of(context).size.width;
          final isWide = width >= 840;

          final screens = const [
            AdminDashboardScreen(),
            AdminUsersScreen(),
          ];

          if (isWide) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Quay lại',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('Tổng quan'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.people_alt_outlined),
                        selectedIcon: Icon(Icons.people_alt),
                        label: Text('Người dùng'),
                      ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(child: screens[_selectedIndex]),
                ],
              ),
            );
          }

          return Scaffold(
            body: screens[_selectedIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Tổng quan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(Icons.people_alt),
                  label: 'Người dùng',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Admin Shell Screen: Responsive administration container with navigation and access enforcement.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/constants/supabase_constants.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_catalogue_screen.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_draft_history_screen.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_ai_management_screen.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_account_provider.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_catalogue_provider.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_publication_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_account_service.dart';
import 'package:travelgo_mobile/features/admin/services/admin_catalogue_service.dart';
import 'package:travelgo_mobile/features/admin/services/admin_publication_service.dart';
import 'package:travelgo_mobile/features/admin/services/demo_admin_services.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/explore/providers/public_catalogue_provider.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';

class AdminShellScreen extends StatefulWidget {
  final AdminAccountProvider? provider;
  final AdminCatalogueProvider? catalogueProvider;
  final AdminPublicationProvider? publicationProvider;

  const AdminShellScreen({
    super.key,
    this.provider,
    this.catalogueProvider,
    this.publicationProvider,
  });

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  AdminAccountProvider? _ownedProvider;
  AdminCatalogueProvider? _ownedCatalogueProvider;
  AdminPublicationProvider? _ownedPublicationProvider;
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
    if (auth.isDemoSession) {
      _ownedProvider = AdminAccountProvider(
        service: DemoAdminAccountService(),
        authProvider: auth,
      );
      return _ownedProvider!;
    }

    Future<LocalAccountLifecycleService> Function()? lifecycleLoader;
    try {
      lifecycleLoader = context
          .read<Future<LocalAccountLifecycleService> Function()>();
    } catch (_) {
      lifecycleLoader = () =>
          Future.error(StateError('Lifecycle loader not found in context.'));
    }

    final service = AdminAccountService(
      dio: Dio(),
      projectOrigin: Uri.parse(SupabaseConstants.projectUrl),
      publicKey: SupabaseConstants.publishableKey,
      lifecycleLoader: lifecycleLoader,
      callerContext: () =>
          (ownerId: auth.currentUser?.id, epoch: auth.authEpoch),
    );

    _ownedProvider = AdminAccountProvider(service: service, authProvider: auth);
    return _ownedProvider!;
  }

  AdminCatalogueProvider _getEffectiveCatalogueProvider() {
    if (widget.catalogueProvider != null) return widget.catalogueProvider!;
    if (_ownedCatalogueProvider != null) return _ownedCatalogueProvider!;

    final auth = context.read<AuthProvider>();
    if (auth.isDemoSession) {
      final pubProvider = _getEffectivePublicationProvider();
      _ownedCatalogueProvider = AdminCatalogueProvider(
        service: DemoAdminCatalogueService(),
        publicationService: pubProvider.service,
        authProvider: auth,
      );
      return _ownedCatalogueProvider!;
    }

    Future<LocalAccountLifecycleService> Function()? lifecycleLoader;
    try {
      lifecycleLoader = context
          .read<Future<LocalAccountLifecycleService> Function()>();
    } catch (_) {
      lifecycleLoader = () =>
          Future.error(StateError('Lifecycle loader not found in context.'));
    }

    final service = AdminCatalogueService(
      dio: Dio(),
      projectOrigin: Uri.parse(SupabaseConstants.projectUrl),
      publicKey: SupabaseConstants.publishableKey,
      lifecycleLoader: lifecycleLoader,
    );

    final pubProvider = _getEffectivePublicationProvider();
    _ownedCatalogueProvider = AdminCatalogueProvider(
      service: service,
      publicationService: pubProvider.service,
      authProvider: auth,
      onPublished: (operation) async {
        try {
          if (mounted) {
            final publicProvider = context.read<PublicCatalogueProvider>();
            await publicProvider.refresh(force: true);
          }
        } catch (e) {
          debugPrint('Local public catalogue refresh error: $e');
        }
      },
    );
    return _ownedCatalogueProvider!;
  }

  AdminPublicationProvider _getEffectivePublicationProvider() {
    if (widget.publicationProvider != null) return widget.publicationProvider!;
    if (_ownedPublicationProvider != null) return _ownedPublicationProvider!;

    final auth = context.read<AuthProvider>();
    if (auth.isDemoSession) {
      _ownedPublicationProvider = AdminPublicationProvider(
        service: DemoAdminPublicationService(),
        authProvider: auth,
      );
      return _ownedPublicationProvider!;
    }

    Future<LocalAccountLifecycleService> Function()? lifecycleLoader;
    try {
      lifecycleLoader = context
          .read<Future<LocalAccountLifecycleService> Function()>();
    } catch (_) {
      lifecycleLoader = () =>
          Future.error(StateError('Lifecycle loader not found in context.'));
    }

    final service = AdminPublicationService(
      dio: Dio(),
      projectOrigin: Uri.parse(SupabaseConstants.projectUrl),
      publicKey: SupabaseConstants.publishableKey,
      lifecycleLoader: lifecycleLoader,
    );

    _ownedPublicationProvider = AdminPublicationProvider(
      service: service,
      authProvider: auth,
    );
    return _ownedPublicationProvider!;
  }

  @override
  void dispose() {
    _ownedProvider?.dispose();
    _ownedCatalogueProvider?.dispose();
    _ownedPublicationProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final effectiveProvider = _getEffectiveProvider();
    final effectiveCatalogueProvider = _getEffectiveCatalogueProvider();
    final effectivePublicationProvider = _getEffectivePublicationProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminAccountProvider>.value(
          value: effectiveProvider,
        ),
        ChangeNotifierProvider<AdminCatalogueProvider>.value(
          value: effectiveCatalogueProvider,
        ),
        ChangeNotifierProvider<AdminPublicationProvider>.value(
          value: effectivePublicationProvider,
        ),
      ],
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
                      Icon(
                        Icons.gpp_bad_outlined,
                        size: 64,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Truy cập bị từ chối',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error != null ? error.userMessage : 'Tài khoản của bạn không có quyền quản trị hoặc phiên đăng nhập không hợp lệ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
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
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              await auth.switchToAdminDemoSession();
                              await _initAndCheckAccess();
                            },
                            icon: const Icon(Icons.science_outlined, size: 18),
                            label: const Text('Vào Demo Sandbox'),
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
            AdminUsersScreen(),
            AdminCatalogueScreen(),
            AdminDraftHistoryScreen(),
            AdminAiManagementScreen(),
          ];

          final demoBanner = auth.isDemoSession
              ? Container(
                  key: const ValueKey('admin-demo-sandbox-banner'),
                  width: double.infinity,
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined, size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chế độ Demo Quản Trị - Dữ liệu Sandbox (Ngoại tuyến)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : null;

          if (isWide) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (idx) =>
                        setState(() => _selectedIndex = idx),
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
                        icon: Icon(Icons.people_alt_outlined),
                        selectedIcon: Icon(Icons.people_alt),
                        label: Text('Người dùng'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.edit_note_outlined),
                        selectedIcon: Icon(Icons.edit_note),
                        label: Text('Danh mục'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history),
                        label: Text('Lịch sử'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.psychology_outlined),
                        selectedIcon: Icon(Icons.psychology),
                        label: Text('Quản trị AI'),
                      ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        ?demoBanner,
                        Expanded(
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: screens,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            body: Column(
              children: [
                ?demoBanner,
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) =>
                  setState(() => _selectedIndex = idx),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(Icons.people_alt),
                  label: 'Người dùng',
                ),
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note),
                  label: 'Danh mục',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'Lịch sử',
                ),
                NavigationDestination(
                  icon: Icon(Icons.psychology_outlined),
                  selectedIcon: Icon(Icons.psychology),
                  label: 'Quản trị AI',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

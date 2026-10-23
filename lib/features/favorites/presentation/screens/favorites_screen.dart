import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../explore/providers/discovery_provider.dart';
import '../../providers/favorites_provider.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final discovery = context.watch<DiscoveryProvider?>();
    final catalogue = discovery?.catalogue;
    final guest = auth.isGuest || auth.currentUser == null;
    // A stale provider response must not render another account's items.
    final owner = guest ? null : auth.currentUser!.id;
    final items = favorites.items
        .where(
          (item) => owner == null
              ? item.userId.isEmpty || item.userId == 'guest'
              : item.userId == owner,
        )
        .toList();
    final theme = Theme.of(context);
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Danh Sách Yêu Thích')),
      body: SafeArea(
        child: favorites.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Đang tải mục yêu thích',
                ),
              )
            : items.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có mục yêu thích nào',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Các mục bạn lưu sẽ xuất hiện ở đây để dễ xem lại.',
                        textAlign: TextAlign.center,
                      ),
                      if (guest) ...[
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.login),
                          label: const Text('Đăng nhập'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (item.imageUrl?.isNotEmpty == true) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Semantics(
                            image: true,
                            label: 'Ảnh đã lưu: ${item.title}',
                            child: ExcludeSemantics(
                              child: Image.network(
                                item.imageUrl!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) =>
                                    progress == null
                                    ? child
                                    : const SizedBox(
                                        height: 160,
                                        child: Center(
                                          child: Text('Đang tải ảnh'),
                                        ),
                                      ),
                                errorBuilder: (_, _, _) => ColoredBox(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: const SizedBox(
                                    height: 160,
                                    child: Center(
                                      child: Text('Ảnh chưa tải được'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(item.title, style: theme.textTheme.titleLarge),
                      if ((item.itemType == 'destination' || item.itemType == 'place') &&
                          catalogue != null &&
                          !(item.itemType == 'destination'
                              ? catalogue.destinations.any((d) => d.id == item.itemId)
                              : catalogue.destinations.any((d) => d.places.any((p) => p.id == item.itemId)))) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Mục không còn trong danh mục phát hành',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                      if (item.location?.isNotEmpty == true)
                        Text(item.location!),
                      // Existing records have a default rating without review provenance.
                      // Do not turn that default into a published customer score.
                      if (item.price > 0)
                        Text('Giá đã lưu: ${money.format(item.price)}'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final epoch = auth.authEpoch;
                            final ok = await favorites.toggleFavorite(item);
                            if (!context.mounted ||
                                epoch != auth.authEpoch ||
                                auth.currentUser?.id != owner) {
                              return;
                            }
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Chưa bỏ được mục yêu thích. Vui lòng thử lại.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.favorite),
                          label: const Text('Bỏ yêu thích'),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

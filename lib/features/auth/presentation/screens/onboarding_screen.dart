import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/travel_image.dart';
import '../../../../core/presentation/travel_media.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';
import '../../../navigation/presentation/screens/main_navigation_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  static const _slides = [
    (
      'ha-noi',
      'Khám phá Việt Nam',
      'Tìm trong 12 điểm đến, xem địa điểm và nguồn thông tin trước khi chọn nơi muốn đến.',
    ),
    (
      'da-nang',
      'Lịch trình theo cách của bạn',
      'Chọn ngày, thêm hoạt động và sắp xếp lịch trình theo từng ngày.',
    ),
    (
      'hue',
      'Theo dõi ngân sách rõ ràng',
      'Tách chi phí dự kiến và khoản đã chi. Khoản chưa biết giá luôn được ghi rõ.',
    ),
  ];
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _guest() {
    context.read<AuthProvider>().continueAsGuest();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('TravelGO'),
      actions: [TextButton(onPressed: _guest, child: const Text('Bỏ qua'))],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _slides.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) {
                final (id, title, body) = _slides[index];
                final media = TravelMediaCatalog.forDestination(id);
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TravelImage(
                        media: media,
                        semanticLabel: media!.caption,
                        height: MediaQuery.textScalerOf(context).scale(16) > 24
                            ? 140
                            : 240,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(body),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${_page + 1} / ${_slides.length}',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _page < _slides.length - 1
                      ? () {
                          if (MediaQuery.disableAnimationsOf(context)) {
                            _pages.jumpToPage(_page + 1);
                          } else {
                            _pages.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          }
                        }
                      : _guest,
                  child: Text(
                    _page < _slides.length - 1
                        ? 'Tiếp theo'
                        : 'Khám phá với Khách',
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('Đăng nhập / Đăng ký'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

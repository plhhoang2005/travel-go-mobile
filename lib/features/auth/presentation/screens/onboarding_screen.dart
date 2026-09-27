import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/app_button.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';
import '../../../navigation/presentation/screens/main_navigation_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'badge': '📍 20+ ĐIỂM ĐẾN NỔI BẬT',
      'title': 'Khám Phá Việt Nam Diệu Kỳ',
      'desc':
          'Hàng ngàn khách sạn, resort, vé xe khách, chuyến bay và tour trải nghiệm tại Đà Nẵng, Phú Quốc, Sa Pa, Đà Lạt và hơn thế nữa.',
      'image':
          'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&w=900&q=85',
      'accent': const Color(0xFF086C61),
    },
    {
      'badge': '⚡ TIẾT KIỆM 20% - 30% CHI PHÍ',
      'title': 'So Sánh & Tối Ưu Chi Phí',
      'desc':
          'Đánh giá đa tiêu chí, lọc phương án Pareto giữa chi phí và thời gian di chuyển, minh bạch 100% không phụ phí ẩn.',
      'image':
          'https://images.unsplash.com/photo-1549294413-26f195200c16?auto=format&fit=crop&w=900&q=85',
      'accent': const Color(0xFFFF7657),
    },
    {
      'badge': '✨ AI DECISION INTELLIGENCE',
      'title': 'Trợ Lý AI Đồng Hành',
      'desc':
          'Hệ thống AI tự động phân bổ ngân sách 3-5 triệu, phát hiện xung đột lịch trình và tạo timeline chi tiết từng ngày.',
      'image':
          'https://images.unsplash.com/photo-1609412058473-c199497c3c5d?auto=format&fit=crop&w=900&q=85',
      'accent': const Color(0xFF5A46C8),
    },
  ];

  void _onContinueAsGuest() {
    context.read<AuthProvider>().continueAsGuest();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
    );
  }

  void _onGoToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _onContinueAsGuest,
            child: const Text(
              'Bỏ qua',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF65726F),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              // Slide Carousel Card
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    final accentColor = slide['accent'] as Color;

                    return Column(
                      children: [
                        const SizedBox(height: 8),

                        // Image Card with rounded corners and subtle shadow
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF112F2B).withValues(alpha: 0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  slide['image'] as String,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: accentColor.withValues(alpha: 0.2),
                                    child: Center(
                                      child: Icon(Icons.photo, size: 64, color: accentColor),
                                    ),
                                  ),
                                ),
                                // Gradient Scrim
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.1),
                                        Colors.black.withValues(alpha: 0.6),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                // Overlay Badge
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      slide['badge'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: accentColor,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Title
                        Text(
                          slide['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF172422),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Description
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            slide['desc'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Color(0xFF65726F),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),

              // Page Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? const Color(0xFF086C61)
                          : const Color(0xFFDFE6E4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              AppButton(
                label: 'Khám phá ngay (Không cần đăng nhập)',
                width: double.infinity,
                icon: Icons.arrow_forward_rounded,
                backgroundColor: const Color(0xFF086C61),
                onPressed: _onContinueAsGuest,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Đăng nhập / Đăng ký',
                width: double.infinity,
                isOutlined: true,
                backgroundColor: const Color(0xFF086C61),
                foregroundColor: const Color(0xFF086C61),
                onPressed: _onGoToLogin,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

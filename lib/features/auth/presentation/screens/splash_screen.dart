import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'onboarding_screen.dart';
import '../../../navigation/presentation/screens/main_navigation_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _next();
    });
  }

  Future<void> _next() async {
    final auth = context.read<AuthProvider>();
    await auth.initialization;
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => auth.isAuthenticated || auth.isGuest
            ? const MainNavigationShell()
            : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'TravelGO Mobile',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Khám phá · Lập lịch trình · Theo dõi chi phí',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: const Text(
                'Đang chuẩn bị chuyến đi của bạn',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: MediaQuery.disableAnimationsOf(context)
            ? content
            : content.animate().fadeIn(
                duration: 250.ms,
                curve: Curves.easeInOut,
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Auth Lifecycle Background / Overview Tests', () {
    test('Simulating Android Overview (phim da nhiem) does NOT log out user', () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.customer);

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.id, 'usr-minh-01');
      expect(auth.isGuest, isFalse);

      // Nguoi dung an phim Overview (hinh chu nhat tren Android)
      // He dieu hanh Android chuyen app sang inactive roi paused
      await auth.handleAppLifecycleState(AppLifecycleState.inactive);
      await auth.handleAppLifecycleState(AppLifecycleState.paused);

      // PHIEN DANG NHAP KHONG DUOC BI MAT KHI AP DANG O NEN
      expect(auth.currentUser?.id, 'usr-minh-01',
          reason: 'User session must remain intact while in background/recent apps');
      expect(auth.isAuthenticated, isTrue);

      // Nguoi dung chon lai ung dung tu danh sach da nhiem
      await auth.handleAppLifecycleState(AppLifecycleState.resumed);

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.id, 'usr-minh-01');
      expect(auth.isGuest, isFalse);

      auth.dispose();
    });
  });
}

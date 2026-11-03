import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/features/ai_chat/services/local_ai_quota_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('new day starts with 0 used count', () async {
    final service = LocalAiQuotaService();
    final used = await service.getUsedCountToday();
    expect(used, 0);

    final remaining = await service.getRemainingQuota(dailyQuota: 10, isAdmin: false);
    expect(remaining, 10);

    final canSend = await service.canSend(dailyQuota: 10, isAdmin: false);
    expect(canSend, isTrue);
  });

  test('recordUsage increments count for regular users', () async {
    final service = LocalAiQuotaService();
    final count1 = await service.recordUsage(isAdmin: false);
    expect(count1, 1);
    expect(await service.getUsedCountToday(), 1);
    expect(await service.getRemainingQuota(dailyQuota: 10, isAdmin: false), 9);

    final count2 = await service.recordUsage(isAdmin: false);
    expect(count2, 2);
    expect(await service.getUsedCountToday(), 2);
    expect(await service.getRemainingQuota(dailyQuota: 10, isAdmin: false), 8);
  });

  test('recordUsage does not increment count for admin', () async {
    final service = LocalAiQuotaService();
    final count = await service.recordUsage(isAdmin: true);
    expect(count, 0);
    expect(await service.getUsedCountToday(), 0);
    expect(await service.getRemainingQuota(dailyQuota: 10, isAdmin: true), LocalAiQuotaService.unlimitedQuota);
    expect(await service.canSend(dailyQuota: 10, isAdmin: true), isTrue);
  });

  test('canSend returns false when dailyQuota reached for regular users', () async {
    final service = LocalAiQuotaService();
    for (int i = 0; i < 5; i++) {
      await service.recordUsage(isAdmin: false);
    }
    expect(await service.canSend(dailyQuota: 5, isAdmin: false), isFalse);
    expect(await service.getRemainingQuota(dailyQuota: 5, isAdmin: false), 0);

    // Admin can still send even when count >= dailyQuota
    expect(await service.canSend(dailyQuota: 5, isAdmin: true), isTrue);
  });

  test('past date resets used count automatically on new day', () async {
    SharedPreferences.setMockInitialValues({
      LocalAiQuotaService.dateKey: '2026-01-01',
      LocalAiQuotaService.countKey: 15,
    });

    final service = LocalAiQuotaService();
    // Since today is not 2026-01-01, it should treat as reset to 0
    expect(await service.getUsedCountToday(), 0);
    expect(await service.canSend(dailyQuota: 10, isAdmin: false), isTrue);

    // Recording new usage writes today's date and count 1
    final newCount = await service.recordUsage(isAdmin: false);
    expect(newCount, 1);
  });

  test('resetTodayQuota resets count to 0', () async {
    final service = LocalAiQuotaService();
    await service.recordUsage(isAdmin: false);
    await service.recordUsage(isAdmin: false);
    expect(await service.getUsedCountToday(), 2);

    await service.resetTodayQuota();
    expect(await service.getUsedCountToday(), 0);
  });
}

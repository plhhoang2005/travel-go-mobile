import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/widgets/empty_state_view.dart';
import 'package:travelgo_mobile/core/widgets/shimmer_loading.dart';
import 'package:travelgo_mobile/core/widgets/app_toast.dart';

void main() {
  group('UI/UX Polish Core Widgets Tests', () {
    testWidgets('EmptyStateView renders title, subtitle, icon and action button', (tester) async {
      var actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              icon: Icons.luggage_outlined,
              title: 'Chưa có chuyến đi nào',
              subtitle: 'Hãy bắt đầu tự thiết kế hoặc nhờ AI tạo lịch trình cho bạn!',
              actionLabel: 'Tạo chuyến đi mới',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.luggage_outlined), findsOneWidget);
      expect(find.text('Chưa có chuyến đi nào'), findsOneWidget);
      expect(find.text('Hãy bắt đầu tự thiết kế hoặc nhờ AI tạo lịch trình cho bạn!'), findsOneWidget);
      expect(find.text('Tạo chuyến đi mới'), findsOneWidget);

      await tester.tap(find.text('Tạo chuyến đi mới'));
      expect(actionTriggered, isTrue);
    });

    testWidgets('ShimmerLoadingCard renders placeholder with rounded corners', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerLoadingCard(height: 120, width: double.infinity),
          ),
        ),
      );

      expect(find.byType(ShimmerLoadingCard), findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(ShimmerLoadingCard), matching: find.byType(Container)),
      );
      expect(container.constraints?.maxHeight, 120);
    });

    testWidgets('AppToast can show toast without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => AppToast.showSuccess(context, 'Thao tác thành công!'),
                  child: const Text('Show Toast'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Toast'));
      await tester.pump();
      expect(find.text('Thao tác thành công!'), findsOneWidget);
    });
  });
}

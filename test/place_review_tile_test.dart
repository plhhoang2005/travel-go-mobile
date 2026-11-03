import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/reviews/models/place_review.dart';
import 'package:travelgo_mobile/features/reviews/presentation/widgets/place_review_tile.dart';

void main() {
  group('PlaceReviewTile - Expand / Collapse UX', () {
    testWidgets('Short review does not display "Xem thêm"', (tester) async {
      final shortReview = PlaceReview(
        id: 'rev-1',
        placeId: 'place-1',
        reviewerId: 'user-1',
        reviewerDisplayName: 'Minh Travel',
        rating: 5,
        content: 'Không gian rất đẹp!',
        createdAt: DateTime(2026, 11, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: PlaceReviewTile(review: shortReview),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không gian rất đẹp!'), findsOneWidget);
      expect(find.text('Xem thêm'), findsNothing);
      expect(find.text('Thu gọn'), findsNothing);
    });

    testWidgets('Long review displays "Xem thêm" and toggles to "Thu gọn"', (tester) async {
      final longReview = PlaceReview(
        id: 'rev-2',
        placeId: 'place-1',
        reviewerId: 'user-2',
        reviewerDisplayName: 'Hậu Trần',
        rating: 4,
        content:
            'Đây là một trải nghiệm tuyệt vời với phong cảnh thiên nhiên hùng vĩ và không khí trong lành. '
            'Chúng tôi đã có cơ hội đi dạo quanh hồ vào buổi chiều tà, ngắm nhìn hoàng hôn rực rỡ và thưởng thức các món ăn đặc sản địa phương vô cùng hấp dẫn. '
            'Chắc chắn tôi sẽ quay lại đây vào dịp cuối tuần cùng gia đình và bạn bè!',
        createdAt: DateTime(2026, 11, 2),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: PlaceReviewTile(review: longReview),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Xem thêm" is visible
      expect(find.text('Xem thêm'), findsOneWidget);
      expect(find.text('Thu gọn'), findsNothing);

      // Tap "Xem thêm"
      await tester.tap(find.text('Xem thêm'));
      await tester.pumpAndSettle();

      // Now "Thu gọn" is visible
      expect(find.text('Thu gọn'), findsOneWidget);
      expect(find.text('Xem thêm'), findsNothing);

      // Tap "Thu gọn"
      await tester.tap(find.text('Thu gọn'));
      await tester.pumpAndSettle();

      // Toggled back to "Xem thêm"
      expect(find.text('Xem thêm'), findsOneWidget);
      expect(find.text('Thu gọn'), findsNothing);
    });
  });
}

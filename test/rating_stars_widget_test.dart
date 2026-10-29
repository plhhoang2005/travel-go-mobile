import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/reviews/presentation/widgets/rating_stars_widget.dart';

void main() {
  testWidgets('interactive stars return the selected integer rating', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: RatingStarsWidget(
          rating: 0,
          interactive: true,
          onRatingChanged: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('5 sao'));
    expect(selected, 5);
  });

  testWidgets('read-only stars do not expose tap actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RatingStarsWidget(rating: 4.5)),
    );

    expect(find.bySemanticsLabel('4.5 trên 5 sao'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });
}

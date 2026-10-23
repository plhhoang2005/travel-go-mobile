// Widget and validation tests for AdminDestinationForm and AdminPlaceForm.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/admin/presentation/widgets/admin_destination_form.dart';
import 'package:travelgo_mobile/features/admin/presentation/widgets/admin_place_form.dart';

void main() {
  Widget buildApp(Widget child, {double width = 400, double textScale = 1.0}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1000),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    );
  }

  group('AdminDestinationForm Validation & Layout Tests', () {
    testWidgets('blank and 181-char names display validation errors and prevent submit', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AdminDestinationDraft? submittedDraft;
      String? submittedReason;

      await tester.pumpWidget(
        buildApp(
          AdminDestinationForm(
            onSubmit: (draft, reason) async {
              submittedDraft = draft;
              submittedReason = reason;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('destination_submit_button'));

      // 1. Submit blank form
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Tên điểm đến không được để trống'), findsOneWidget);
      expect(submittedDraft, isNull);

      // 2. Submit with 181-character name
      final longName = 'A' * 181;
      await tester.enterText(find.byKey(const Key('destination_name_field')), longName);
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Tên không được vượt quá 180 ký tự'), findsOneWidget);
      expect(submittedDraft, isNull);

      // 3. Submit with invalid image URL
      await tester.enterText(find.byKey(const Key('destination_name_field')), 'Đà Nẵng');
      await tester.enterText(find.byKey(const Key('destination_region_field')), 'Miền Trung');
      await tester.enterText(find.byKey(const Key('destination_desc_field')), 'Thành phố biển');
      await tester.enterText(find.byKey(const Key('destination_region_field')), 'Miền Trung');
      await tester.enterText(find.byKey(const Key('destination_desc_field')), 'Thành phố biển');
      await tester.enterText(find.byKey(const Key('destination_image_field')), 'not-a-valid-url');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('URL hình ảnh không hợp lệ'), findsOneWidget);
      expect(submittedDraft, isNull);

      // 4. Submit with valid data
      await tester.enterText(find.byKey(const Key('destination_image_field')), 'https://example.com/danang.jpg');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(submittedDraft, isNotNull);
      expect(submittedDraft!.name, 'Đà Nẵng');
      expect(submittedDraft!.slug, 'da-nang');
      expect(submittedDraft!.region, 'Miền Trung');
      expect(submittedReason, isNotEmpty);
    });

    testWidgets('renders cleanly at 320dp width and textScale 2.0 without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildApp(
          AdminDestinationForm(
            onSubmit: (draft, reason) async => true,
          ),
          width: 320,
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('destination_submit_button')), findsOneWidget);
    });
  });

  group('AdminPlaceForm Coordinate Pair & Validation Tests', () {
    final sampleDestinations = [
      const AdminDestinationDraft(
        id: 'da-nang',
        name: 'Đà Nẵng',
        slug: 'da-nang',
        region: 'Miền Trung',
        description: 'Thành phố biển',
      ),
    ];

    testWidgets('coordinate_pair_error_retains_form_text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var submitCalls = 0;

      await tester.pumpWidget(
        buildApp(
          AdminPlaceForm(
            destinations: sampleDestinations,
            onSubmit: (draft, reason) async {
              submitCalls++;
              return true;
            },
          ),
          width: 320,
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('place_submit_button'));

      // Enter name, description, but ONLY latitude (leaving longitude empty)
      await tester.enterText(find.byKey(const Key('place_name_field')), 'Bà Nà Hills');
      await tester.enterText(find.byKey(const Key('place_desc_field')), 'Khu du lịch trên núi');
      await tester.enterText(find.byKey(const Key('place_lat_field')), '15.998');

      // Attempt to submit
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Invariant: no command sent
      expect(submitCalls, 0);

      // Invariant: form displays field error
      expect(find.text('Cần nhập đủ cả toạ độ'), findsAtLeastNWidgets(1));

      // Invariant: text values retained unchanged
      expect(find.text('Bà Nà Hills'), findsOneWidget);
      expect(find.text('15.998'), findsOneWidget);

      // Invariant: layout at 320dp and textScale 2.0 has zero overflow exceptions
      expect(tester.takeException(), isNull);

      // Now enter invalid out-of-range coordinates
      await tester.enterText(find.byKey(const Key('place_lat_field')), '95.0');
      await tester.enterText(find.byKey(const Key('place_lng_field')), '190.0');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(submitCalls, 0);
      expect(find.text('Vĩ độ từ -90 đến 90'), findsOneWidget);
      expect(find.text('Kinh độ từ -180 đến 180'), findsOneWidget);

      // Now enter valid coordinates
      await tester.enterText(find.byKey(const Key('place_lat_field')), '15.998');
      await tester.enterText(find.byKey(const Key('place_lng_field')), '108.2');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(submitCalls, 1);
    });

    testWidgets('form displays accurate error message from errorMessageProvider when submit fails', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const errorMessage = 'Đã lưu nháp, chưa xuất bản: validation blocker';

      await tester.pumpWidget(
        buildApp(
          AdminDestinationForm(
            errorMessageProvider: () => errorMessage,
            onSubmit: (draft, reason) async => false, // Fails publication
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('destination_name_field')), 'Đà Nẵng');
      await tester.enterText(find.byKey(const Key('destination_region_field')), 'Miền Trung');
      await tester.enterText(find.byKey(const Key('destination_desc_field')), 'Thành phố biển');
      final submitBtn = find.byKey(const Key('destination_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text(errorMessage), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/ai_chat/presentation/widgets/ai_markdown_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiMarkdownText Widget Tests', () {
    testWidgets('renders bold text without raw asterisks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiMarkdownText(
              text: '1. **Bún chả** - Đặc sản Hà Nội',
              isUser: false,
            ),
          ),
        ),
      );

      // Raw asterisks must not be present in rendered text
      expect(find.textContaining('**'), findsNothing);

      // The selectable text rich must exist
      final selectableFinder = find.byType(SelectableText);
      expect(selectableFinder, findsOneWidget);

      final selectable = tester.widget<SelectableText>(selectableFinder);
      final textSpan = selectable.textSpan!;

      // Verify "Bún chả" is bold
      bool foundBold = false;
      textSpan.visitChildren((span) {
        if (span is TextSpan &&
            span.text == 'Bún chả' &&
            span.style?.fontWeight == FontWeight.bold) {
          foundBold = true;
        }
        return true;
      });

      expect(foundBold, isTrue);
    });

    testWidgets('trims trailing newlines to avoid bottom blank space', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiMarkdownText(
              text: 'Nội dung trả lời từ AI\n\n\n\n',
              isUser: false,
            ),
          ),
        ),
      );

      final selectableFinder = find.byType(SelectableText);
      expect(selectableFinder, findsOneWidget);
      final selectable = tester.widget<SelectableText>(selectableFinder);
      final textSpan = selectable.textSpan!;

      // Flatten span text
      final fullText = textSpan.toPlainText();
      expect(fullText, 'Nội dung trả lời từ AI');
      expect(fullText.endsWith('\n'), isFalse);
    });

    testWidgets('formats inline code and italic properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiMarkdownText(
              text: 'Dùng lệnh `flutter test` hoặc *xem bản đồ*',
              isUser: false,
            ),
          ),
        ),
      );

      expect(find.textContaining('`'), findsNothing);
      expect(find.textContaining('*xem'), findsNothing);

      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      final textSpan = selectable.textSpan!;

      bool foundCode = false;
      bool foundItalic = false;

      textSpan.visitChildren((span) {
        if (span is TextSpan) {
          if (span.text == 'flutter test' &&
              span.style?.fontFamily == 'monospace') {
            foundCode = true;
          }
          if (span.text == 'xem bản đồ' &&
              span.style?.fontStyle == FontStyle.italic) {
            foundItalic = true;
          }
        }
        return true;
      });

      expect(foundCode, isTrue);
      expect(foundItalic, isTrue);
    });

    testWidgets('applies user styling for isUser = true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          ),
          home: const Scaffold(
            body: AiMarkdownText(text: 'Câu hỏi của tôi', isUser: true),
          ),
        ),
      );

      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectable.textSpan?.text, 'Câu hỏi của tôi');
    });
  });
}

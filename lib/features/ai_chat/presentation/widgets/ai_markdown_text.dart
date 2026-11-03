import 'package:flutter/material.dart';

/// Lightweight, zero-dependency Markdown parser & renderer widget for AI Chat.
/// Formats bold, italics, inline code, headings, lists, and trims excess whitespace.
class AiMarkdownText extends StatelessWidget {
  final String text;
  final bool isUser;
  final TextStyle? style;

  const AiMarkdownText({
    super.key,
    required this.text,
    required this.isUser,
    this.style,
  });

  static final RegExp _inlineTokenRegex = RegExp(
    r'(\*\*(.+?)\*\*)|(__(.+?)__)|(\*([^*]+)\*)|(_([^_]+)_)|(`([^`]+)`)',
  );

  static final RegExp _bulletRegex = RegExp(r'^\s*[-*•]\s+');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultBaseStyle = TextStyle(
      fontSize: 14.5,
      height: 1.45,
      color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
    );

    final baseStyle = style ?? defaultBaseStyle;

    if (isUser) {
      return SelectableText.rich(
        TextSpan(text: trimmed, style: baseStyle),
        style: baseStyle,
      );
    }

    final spans = _parseMarkdownToSpans(trimmed, baseStyle, colorScheme);

    return SelectableText.rich(
      TextSpan(children: spans, style: baseStyle),
      style: baseStyle,
    );
  }

  List<InlineSpan> _parseMarkdownToSpans(
    String content,
    TextStyle baseStyle,
    ColorScheme colorScheme,
  ) {
    final lines = content.split('\n');
    final allSpans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];

      TextStyle lineStyle = baseStyle;

      // Handle Headings (#, ##, ###)
      if (line.startsWith('### ')) {
        line = line.substring(4);
        lineStyle = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14.5) * 1.15,
          fontWeight: FontWeight.bold,
        );
      } else if (line.startsWith('## ')) {
        line = line.substring(3);
        lineStyle = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14.5) * 1.25,
          fontWeight: FontWeight.bold,
        );
      } else if (line.startsWith('# ')) {
        line = line.substring(2);
        lineStyle = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 14.5) * 1.35,
          fontWeight: FontWeight.bold,
        );
      } else if (_bulletRegex.hasMatch(line)) {
        // Standardize bullet points
        line = line.replaceFirst(_bulletRegex, '• ');
      }

      final inlineSpans = _parseInlineSpans(line, lineStyle, colorScheme);
      allSpans.addAll(inlineSpans);

      // Append newline between lines except after the last line
      if (i < lines.length - 1) {
        allSpans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }

    return allSpans;
  }

  List<InlineSpan> _parseInlineSpans(
    String line,
    TextStyle lineStyle,
    ColorScheme colorScheme,
  ) {
    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;

    for (final match in _inlineTokenRegex.allMatches(line)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: line.substring(lastMatchEnd, match.start),
            style: lineStyle,
          ),
        );
      }

      final boldGroup = match.group(2) ?? match.group(4);
      final italicGroup = match.group(6) ?? match.group(8);
      final codeGroup = match.group(10);

      if (boldGroup != null) {
        spans.add(
          TextSpan(
            text: boldGroup,
            style: lineStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (italicGroup != null) {
        spans.add(
          TextSpan(
            text: italicGroup,
            style: lineStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (codeGroup != null) {
        spans.add(
          TextSpan(
            text: codeGroup,
            style: lineStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: (lineStyle.fontSize ?? 14.5) * 0.95,
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
            ),
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < line.length) {
      spans.add(
        TextSpan(
          text: line.substring(lastMatchEnd),
          style: lineStyle,
        ),
      );
    }

    return spans;
  }
}

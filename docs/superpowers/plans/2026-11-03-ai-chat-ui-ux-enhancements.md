# AI Chatbot UI/UX Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish TravelGO AI Chatbot UI/UX by resolving unparsed Markdown (`**bold**`, lists, code), eliminating excess vertical whitespace from trailing newlines, adding message timestamps, adding a regenerate reply action alongside copy, and enhancing micro-interactions (tactile border, copy confirmation checkmark).

**Architecture:** Create a zero-dependency `AiMarkdownText` renderer parsing bold, italics, inline code, numbered & bullet lists, and emoji without modifying `pubspec.yaml` (preserving Permission Boundary). Extend `AiChatProvider` with `regenerateAiReply` that verifies quota before re-requesting Ollama. Refactor `_buildMessageBubble` in `AiChatbotScreen` with trimmed content, structured footer row, tactile styling, and micro-interactions.

**Tech Stack:** Flutter, Dart, Provider, Material 3 Theme tokens (`colorScheme`), HapticFeedback.

**Spec:** In-chat bounded design approved by Tech Lead on 2026-11-03 ("đồng ý theo phương án a").

## Global Constraints
- Zero external package additions (do NOT touch `pubspec.yaml`).
- Strictly adhere to `Theme.of(context).colorScheme` (Anti-Slop rule: no hardcoded random colors).
- Preserve existing tests in `test/ai_chat_flow_test.dart` and `test/ai_chatbot_screen_quota_test.dart`.
- Verify with `flutter analyze` and `flutter test`.

## Review Focus
1. **Trailing newlines & spaces in Ollama responses**: Ollama models return `\n\n\n` at generation end. The renderer must `trim()` content so no empty vertical space is rendered.
2. **Bold markdown parsing**: `**Bún chả**` must render as bold text without displaying raw asterisks `**`.
3. **Numbered & bullet lists**: `1. `, `2. `, `- `, `* ` must format cleanly with proper indentation/spacing.
4. **Quota guard on regenerate**: Clicking "Trả lời lại" when daily quota is exhausted must display a friendly failure without deleting the existing AI response.
5. **Copy button tactile feedback**: Tapping copy copies trimmed text to clipboard, provides light haptic feedback, and temporarily swaps icon to checkmark (`Icons.check_rounded`) for 1.5s.

---

### Task 1: Create `AiMarkdownText` Zero-Dependency Parser Widget

**Files:**
- Create: `lib/features/ai_chat/presentation/widgets/ai_markdown_text.dart`
- Create: `test/ai_markdown_text_test.dart`

**Interfaces:**
- Produces: `class AiMarkdownText extends StatelessWidget`
  - Constructor: `const AiMarkdownText({super.key, required this.text, required this.isUser, this.style})`
  - Parses: Bold (`**text**` or `__text__`), Italic (`*text*` or `_text_`), Inline code (`` `code` ``), Bullet points (`- ` / `* `), Numbered lists (`1. `), Headings (`### `), and trims trailing whitespace.

- [ ] **Step 1: Write unit and widget tests for `AiMarkdownText`**
Create `test/ai_markdown_text_test.dart` testing:
- Raw asterisks `**` are parsed into bold `FontWeight.bold` TextSpans, not shown as literal `**`.
- Trailing newlines are trimmed.
- Numbered lists and bullets are rendered properly.
- User styling (`isUser: true`) applies `colorScheme.onPrimary`.

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/ai_markdown_text_test.dart`
Expected: FAIL (file does not exist yet).

- [ ] **Step 3: Implement `AiMarkdownText` in `lib/features/ai_chat/presentation/widgets/ai_markdown_text.dart`**
Implement the custom markdown/rich-text parser using `SelectableText.rich` and `TextSpan`.

- [ ] **Step 4: Run test to verify it passes**
Run: `flutter test test/ai_markdown_text_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**
`git add lib/features/ai_chat/presentation/widgets/ai_markdown_text.dart test/ai_markdown_text_test.dart`
`git commit -m "feat(ai_chat): add zero-dependency AiMarkdownText parser widget"`

---

### Task 2: Extend `AiChatProvider` with `regenerateAiReply`

**Files:**
- Modify: `lib/features/ai_chat/providers/ai_chat_provider.dart`
- Test: `test/ai_chat_flow_test.dart`

**Interfaces:**
- Produces: `Future<void> regenerateAiReply(String messageId)` in `AiChatProvider`
  - Validates `canSend` and checks `quotaService.canSend()`. If exhausted, sets failure and keeps message intact.
  - Locates the preceding user query for the targeted AI message.
  - Removes the old AI message and calls `_sendExisting(precedingMessage)`.

- [ ] **Step 1: Write test for `regenerateAiReply` in `test/ai_chat_flow_test.dart`**
Add test verifying that calling `regenerateAiReply(aiMessage.id)` re-requests reply and updates message list.

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/ai_chat_flow_test.dart`
Expected: FAIL (`regenerateAiReply` not defined).

- [ ] **Step 3: Implement `regenerateAiReply` in `lib/features/ai_chat/providers/ai_chat_provider.dart`**
Add the method with safety guards, quota check, and state synchronization.

- [ ] **Step 4: Run test to verify it passes**
Run: `flutter test test/ai_chat_flow_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**
`git add lib/features/ai_chat/providers/ai_chat_provider.dart test/ai_chat_flow_test.dart`
`git commit -m "feat(ai_chat): implement regenerateAiReply in AiChatProvider"`

---

### Task 3: Polish `AiChatbotScreen` Message Bubbles, Footer & Micro-Interactions

**Files:**
- Modify: `lib/features/ai_chat/presentation/screens/ai_chatbot_screen.dart`
- Test: `test/ai_chatbot_ui_polish_test.dart`

**Interfaces:**
- Refactors `_buildMessageBubble`:
  - Replaces `SelectableText(msg.content)` with `AiMarkdownText(text: msg.content, isUser: isUser)`.
  - Content trimmed before rendering, eliminating bottom gap.
  - Footer row:
    - Left: Timestamp formatted as `HH:mm` (using string formatting or intl).
    - Right: Action buttons (`Icons.refresh_rounded` for regenerate + `_CopyButton` with animated checkmark feedback).
  - Tactile bubble styling: Subtle border for AI bubble (`Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4))`).

- [ ] **Step 1: Write widget test for polished bubble UI**
Create `test/ai_chatbot_ui_polish_test.dart` verifying:
- Timestamp is rendered inside the bubble.
- Copy button and Regenerate button are present on AI bubbles.
- Tapping copy changes icon to checkmark and copies to clipboard.
- Tapping regenerate triggers `regenerateAiReply`.

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/ai_chatbot_ui_polish_test.dart`
Expected: FAIL.

- [ ] **Step 3: Update `AiChatbotScreen` in `lib/features/ai_chat/presentation/screens/ai_chatbot_screen.dart`**
Apply the new bubble layout, footer row, `_CopyButton` widget with stateful checkmark feedback, and `AiMarkdownText`.

- [ ] **Step 4: Run test to verify it passes**
Run: `flutter test test/ai_chatbot_ui_polish_test.dart test/ai_chat_flow_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**
`git add lib/features/ai_chat/presentation/screens/ai_chatbot_screen.dart test/ai_chatbot_ui_polish_test.dart`
`git commit -m "feat(ai_chat): polish message bubbles with markdown, timestamp, regenerate and copy feedback"`

---

### Task 4: Final Verification & Analyzer Check

**Files:**
- All touched files

- [ ] **Step 1: Run full test suite for AI chat**
Run: `flutter test test/ai_markdown_text_test.dart test/ai_chat_flow_test.dart test/ai_chatbot_screen_quota_test.dart test/ai_chatbot_ui_polish_test.dart`
Expected: ALL PASS.

- [ ] **Step 2: Run `flutter analyze`**
Run: `flutter analyze`
Expected: `No issues found!`.

- [ ] **Step 3: Final Handover Report preparation**
Provide clear explanation for Owner as required by `AGENTS.md` and complete handover sections.

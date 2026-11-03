import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../auth/models/user_model.dart';
import '../../../auth/providers/auth_provider.dart';

import '../../models/ai_chat_session.dart';
import '../../providers/ai_chat_provider.dart';
import '../widgets/ai_chat_drawer.dart';
import '../widgets/ai_prompt_chips.dart';

/// Chat interface for the local Ollama service.
class AiChatbotScreen extends StatefulWidget {
  const AiChatbotScreen({super.key});

  @override
  State<AiChatbotScreen> createState() => _AiChatbotScreenState();
}

class _AiChatbotScreenState extends State<AiChatbotScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AiChatProvider>();
      final auth = context.read<AuthProvider?>();
      provider.updateRole(isAdmin: auth?.currentUser?.role == UserRole.admin);
      if (provider.sessions.isEmpty) {
        provider.init();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final provider = Provider.of<AiChatProvider>(context, listen: false);
    provider.updateRole(isAdmin: auth?.currentUser?.role == UserRole.admin);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(AiChatProvider provider) {
    final text = _inputController.text.trim();
    if (text.isEmpty || !provider.canSend) return;
    _inputController.clear();
    provider.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiChatProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final messages = provider.messages;
    final currentSession = provider.currentSession;

    return Scaffold(
      drawer: const AiChatDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          key: const ValueKey('ai_chat_back_button'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Quay lại',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                const Text(
                  'TravelGO AI',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ollama · ${provider.selectedModel}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                Container(
                  key: const Key('ai_chat_quota_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: provider.isAdmin
                        ? colorScheme.secondaryContainer
                        : (provider.isQuotaExhausted
                            ? colorScheme.errorContainer
                            : colorScheme.surfaceContainerHighest),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    provider.isAdmin
                        ? 'Admin · Không giới hạn'
                        : 'Còn ${provider.remainingQuota}/${provider.settings.dailyQuota} lượt',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: provider.isAdmin
                          ? colorScheme.onSecondaryContainer
                          : (provider.isQuotaExhausted
                              ? colorScheme.onErrorContainer
                              : colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              currentSession?.title ?? 'Cuộc trò chuyện mới',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              key: const ValueKey('ai_chat_history_button'),
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Lịch sử trò chuyện',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Cuộc trò chuyện mới',
            onPressed: () => provider.createNewSession(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (provider.settingsWarning != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(provider.settingsWarning!),
              ),

            // Khung hiển thị tin nhắn
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyState(context, provider)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: messages.length + (provider.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && provider.isLoading) {
                          return _buildLoadingBubble(context);
                        }
                        final msg = messages[index];
                        return _buildMessageBubble(context, msg);
                      },
                    ),
            ),

            // Hàng Prompt gợi ý động
            if (messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AiPromptChips(
                  onSelectPrompt: (prompt) {
                    _inputController.text = prompt;
                    _handleSend(provider);
                  },
                ),
              ),

            if (provider.lastFailure != null)
              Flexible(
                flex: 0,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.lastFailure!.message,
                            style: TextStyle(color: colorScheme.error),
                          ),
                          TextButton(
                            onPressed: provider.isLoading
                                ? null
                                : provider.retryFailedMessage,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (provider.isLoading)
              TextButton(
                onPressed: provider.cancelPendingReply,
                child: const Text('Hủy yêu cầu'),
              ),
            // Khung nhập tin nhắn
            _buildInputBar(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AiChatProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Trợ Lý Du Lịch TravelGO',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Hỏi đáp du lịch với mô hình chạy trên máy tính của bạn. Thông tin chưa được kiểm chứng bằng catalogue hoặc tìm kiếm web.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 32),
            AiPromptChips(
              isStarter: true,
              onSelectPrompt: (prompt) {
                _inputController.text = prompt;
                _handleSend(provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, AiChatMessage msg) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.auto_awesome,
                size: 16,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.8,
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    msg.content,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: isUser
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                  if (!isUser) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Sao chép',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: msg.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép vào bộ nhớ tạm'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.auto_awesome,
              size: 16,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.8,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Đang chờ Ollama trả lời…',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, AiChatProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExhausted = provider.isQuotaExhausted;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              enabled: !isExhausted,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(provider),
              decoration: InputDecoration(
                hintText: isExhausted
                    ? 'Đã hết ${provider.settings.dailyQuota} lượt hỏi hôm nay...'
                    : 'Hỏi Trợ lý AI TravelGO...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isExhausted
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _inputController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      tooltip: 'Xóa nội dung',
                      onPressed: () => _inputController.clear(),
                    );
                  },
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: provider.canSend ? () => _handleSend(provider) : null,
            icon: const Icon(Icons.arrow_upward_rounded),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

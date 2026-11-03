import 'package:flutter/material.dart';

/// Hàng gợi ý Prompt thông minh theo ngữ cảnh hội thoại
class AiPromptChips extends StatelessWidget {
  final ValueChanged<String> onSelectPrompt;
  final bool isStarter;

  const AiPromptChips({
    super.key,
    required this.onSelectPrompt,
    this.isStarter = false,
  });

  static const List<Map<String, String>> starterPrompts = [
    {
      'icon': '🌲',
      'label': 'Lịch trình Đà Lạt 3 ngày',
      'prompt': 'Hãy lên giúp tôi lịch trình du lịch Đà Lạt 3 ngày 2 đêm chi tiết cho 2 người với ngân sách vừa phải.',
    },
    {
      'icon': '🏔️',
      'label': 'Kinh nghiệm du lịch Sa Pa',
      'prompt': 'Tôi sắp đi Sa Pa, hãy gợi ý các điểm tham quan đẹp nhất và kinh nghiệm chuẩn bị trang phục.',
    },
    {
      'icon': '🍜',
      'label': 'Ẩm thực phố cổ Hà Nội',
      'prompt': 'Gợi ý cho tôi danh sách các quán ăn đặc sản ngon nức tiếng tại khu vực phố cổ Hà Nội.',
    },
    {
      'icon': '💰',
      'label': 'Mẹo tiết kiệm chi phí',
      'prompt': 'Chia sẻ cho tôi các mẹo tối ưu chi phí lưu trú và ăn uống khi đi du lịch tự túc.',
    },
  ];

  static const List<String> followupPrompts = [
    'Chi tiết hơn nữa 📝',
    'Ước tính chi phí 💵',
    'Tìm thêm quán ăn ngon 🍜',
    'Địa điểm chụp ảnh đẹp 📸',
    'Phương tiện di chuyển 🛵',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isStarter) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gợi ý câu hỏi phổ biến:',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: starterPrompts.map((item) {
                return ActionChip(
                  avatar: Text(item['icon']!, style: const TextStyle(fontSize: 16)),
                  label: Text(
                    item['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onPressed: () => onSelectPrompt(item['prompt']!),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: followupPrompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = followupPrompts[index];
          return ActionChip(
            label: Text(
              prompt,
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
            ),
            backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
            side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onPressed: () => onSelectPrompt(prompt),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../trips/models/trip_evidence_envelope.dart';
import '../../models/ai_web_advice.dart';
import 'evidence_details_sheet.dart';

class WebAdviceSheet extends StatelessWidget {
  final AiWebAdviceReply reply;

  const WebAdviceSheet({
    super.key,
    required this.reply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.language, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tư vấn từ Internet (Google Search)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thông tin từ Internet, chưa được Admin kiểm duyệt: kiểm tra lại trước khi thực hiện.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              reply.summary,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            if (reply.searchQueries.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: reply.searchQueries.map((q) {
                  return Chip(
                    label: Text(q, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (reply.hasEvidence)
                  OutlinedButton.icon(
                    key: const ValueKey('web-advice-view-evidence'),
                    icon: const Icon(Icons.verified_outlined, size: 16),
                    label: const Text('Xem căn cứ'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => EvidenceDetailsSheet(
                        records: reply.evidence,
                        claim: reply.claims.isEmpty
                            ? EvidenceClaim(
                                id: 'web-advice',
                                text: 'Thông tin từ Internet',
                                kind: ClaimKind.fact,
                                evidenceIds: reply.evidence.map((e) => e.id).toList(),
                              )
                            : reply.claims.first,
                        claims: reply.claims,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


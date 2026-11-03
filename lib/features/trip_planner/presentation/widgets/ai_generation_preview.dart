import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../trips/models/trip_evidence_envelope.dart';
import '../../models/ai_grounded_proposal.dart';
import '../../services/ai_generation_service.dart';
import '../../services/editable_trip_validator.dart';
import 'evidence_details_sheet.dart';

class AiGenerationPreview extends StatefulWidget {
  final AiGenerationContext input;
  final Future<Object> Function(String requestId) generate;
  final Listenable authority;
  final bool Function() isCurrent;
  final bool isLocalAi;

  const AiGenerationPreview({
    super.key,
    required this.input,
    required this.generate,
    required this.authority,
    required this.isCurrent,
    this.isLocalAi = false,
  });

  @override
  State<AiGenerationPreview> createState() => _AiGenerationPreviewState();
}

class _AiGenerationPreviewState extends State<AiGenerationPreview> {
  bool _consent = false, _loading = false, _closing = false;
  String? _requestId, _error;
  Object? _prepared;

  AiItineraryProposal? get _proposal {
    final p = _prepared;
    if (p is AiGroundedProposal) return p.proposal;
    if (p is AiPreparedProposal) return p.proposal;
    return null;
  }

  bool get _canApply {
    final p = _prepared;
    if (p is AiGroundedProposal) return p.canApply;
    if (p is AiPreparedProposal) return p.canApply;
    return false;
  }

  List<EditableValidationIssue> get _issues {
    final p = _prepared;
    if (p is AiGroundedProposal) return p.issues;
    if (p is AiPreparedProposal) return p.issues;
    return const [];
  }

  TripEvidenceEnvelope? get _envelope {
    final p = _prepared;
    if (p is AiGroundedProposal) return p.envelope;
    return null;
  }

  Future<void> _generate() async {
    if (!_consent || _loading || !widget.isCurrent()) {
      return;
    }
    _requestId ??= const Uuid().v4();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prepared = await widget.generate(_requestId!);
      if (!mounted || !widget.isCurrent()) {
        return;
      }
      setState(() => _prepared = prepared);
    } on Object catch (error) {
      if (!mounted || !widget.isCurrent()) {
        return;
      }
      final failure = error is AiGenerationFailure
          ? error
          : const AiGenerationFailure('invalid_result');
      if (!failure.retrySameRequest) {
        _requestId = null;
      }
      setState(() => _error = failure.message);
    } finally {
      if (mounted && widget.isCurrent()) {
        setState(() => _loading = false);
      }
    }
  }

  String _clock(int? minute) => minute == null
      ? 'chưa rõ'
      : '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  List<Widget> _buildGroupedActivities(
    BuildContext context,
    List<AiProposedActivity> activities,
  ) {
    final byDay = <int, List<AiProposedActivity>>{};
    for (final a in activities) {
      byDay.putIfAbsent(a.day, () => []).add(a);
    }
    final days = byDay.keys.toList()..sort();
    final widgets = <Widget>[];

    for (final day in days) {
      final dayActivities = byDay[day]!;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Ngày $day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );

      for (final a in dayActivities) {
        widgets.add(
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_clock(a.startMinute)} – ${_clock(a.endMinute)} · ${a.costVnd == null ? 'Chi phí chưa rõ' : 'Ước tính ${a.costVnd} VND'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.authority,
    builder: (context, _) {
      if (!widget.isCurrent()) {
        if (!_closing) {
          _closing = true;
          final route = ModalRoute.of(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && route != null && route.isActive) {
              Navigator.of(context).removeRoute(route);
            }
          });
        }
        return const SizedBox.shrink();
      }
      final proposal = _proposal;
      final envelope = _envelope;

      return AlertDialog(
        title: widget.isLocalAi
            ? Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Text('Đề xuất lịch từ AI'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Ollama · Qwen',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ],
              )
            : const Text('Đề xuất lịch từ AI'),
        scrollable: true,
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Điểm đến: ${widget.input.destinationId} · ${widget.input.numDays} ngày · ${widget.input.numPeople} người',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ngân sách gửi AI: ${widget.input.budgetVnd} VND',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.interests_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Sở thích gửi AI: ${widget.input.interests.isEmpty ? 'chưa đặt' : widget.input.interests.join(', ')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(

                      'Lưu ý bảo mật & dữ liệu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'AI chỉ đề xuất thêm hoạt động và ước tính vào bản nháp. Chưa lưu lên tài khoản; hoạt động và khoản đã chi hiện có được giữ nguyên.',
                      style: TextStyle(fontSize: 11, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isLocalAi
                          ? 'Mô hình Local AI (Ollama - Qwen) xử lý dữ liệu trực tiếp trên máy tính. Hoàn toàn riêng tư và không gửi ra internet.'
                          : 'Kết quả AI được lưu tạm trên máy chủ tối đa 24 giờ để kiểm tra lại yêu cầu. Hệ thống AI xử lý thông tin bạn đồng ý gửi.',
                      style: const TextStyle(fontSize: 11, height: 1.3),

                    ),
                  ],
                ),
              ),
              if (proposal == null) ...[
                CheckboxListTile(
                  key: const ValueKey('ai-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _consent = v == true),
                  title: Text(
                    widget.isLocalAi
                        ? 'Đồng ý tạo lịch trình bằng Local AI (Ollama - Qwen)'
                        : 'Đồng ý gửi các thông tin trên đến Hệ thống AI',
                  ),
                  subtitle: Text(
                    widget.isLocalAi
                        ? 'Tự động kết hợp sở thích từ Hồ sơ cá nhân và thông số chuyến đi để tạo lịch trình tối ưu.'
                        : 'Không gửi tên chuyến đi, ghi chú, khoản đã chi, GPS, thông tin liên hệ hay hồ sơ tài khoản. Vùng xuất phát chưa xác định.',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('ai-generate'),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    onPressed: _consent && !_loading ? _generate : null,
                    label: Text(
                      _loading
                          ? (widget.isLocalAi ? 'Local AI đang lập lịch…' : 'Đang tạo đề xuất…')
                          : _error == null
                          ? (widget.isLocalAi ? 'Tạo lịch bằng Local AI ⚡' : 'Tạo đề xuất')
                          : (widget.isLocalAi ? 'Thử lại với Local AI ⚡' : 'Thử lại'),

                    ),
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              if (proposal != null) ...[
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          proposal.summary,
                          style: const TextStyle(fontSize: 13, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (envelope != null) ...[
                  if (envelope.evidence.any((e) => e.origin == EvidenceOrigin.web)) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.public, size: 18, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Thông tin từ Internet, chưa được Admin kiểm duyệt (${envelope.evidence.length} nguồn)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.verified, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Đã đối chiếu Catalogue (${envelope.evidence.length} nguồn)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  OutlinedButton.icon(
                    key: const ValueKey('ai-view-evidence'),
                    icon: Icon(
                      envelope.evidence.any((e) => e.origin == EvidenceOrigin.web)
                          ? Icons.public
                          : Icons.verified_outlined,
                      size: 16,
                    ),
                    label: Text('Xem căn cứ (${envelope.evidence.length})'),
                    onPressed: () => showTripEvidence(
                      context,
                      envelope,
                      authority: widget.authority,
                      isCurrent: widget.isCurrent,
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Chưa xác minh giá, địa điểm, giờ mở cửa, đường đi và thời tiết. Kiểm tra trước khi sử dụng.',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ..._buildGroupedActivities(context, proposal.activities),
                ...proposal.warnings.map(
                  (w) => Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            w,
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ..._issues
                    .take(12)
                    .map(
                      (i) => Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (i.isBlocking
                                  ? Theme.of(context).colorScheme.errorContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHighest)
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (i.isBlocking
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.outlineVariant)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              i.isBlocking ? Icons.error_outline : Icons.info_outline,
                              size: 16,
                              color: i.isBlocking
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                i.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: i.isBlocking
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (!_canApply)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.block, size: 16, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Đề xuất còn lỗi chặn. Hủy để chỉnh lịch hiện tại rồi tạo đề xuất mới.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('ai-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          if (proposal != null)
            FilledButton(
              key: const ValueKey('ai-apply'),
              onPressed: _canApply
                  ? () => Navigator.of(context).pop(_prepared)
                  : null,
              child: const Text('Xác nhận thêm vào bản nháp'),
            ),
        ],
      );
    },
  );
}

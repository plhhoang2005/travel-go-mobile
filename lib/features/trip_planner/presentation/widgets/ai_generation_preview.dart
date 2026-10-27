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

  const AiGenerationPreview({
    super.key,
    required this.input,
    required this.generate,
    required this.authority,
    required this.isCurrent,
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
        title: const Text('Đề xuất lịch từ AI'),
        scrollable: true,
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Điểm đến: ${widget.input.destinationId} · ${widget.input.numDays} ngày · ${widget.input.numPeople} người',
              ),
              Text('Ngân sách gửi AI: ${widget.input.budgetVnd} VND'),
              Text(
                'Sở thích gửi AI: ${widget.input.interests.isEmpty ? 'chưa đặt' : widget.input.interests.join(', ')}',
              ),
              const SizedBox(height: 12),
              const Text(
                'AI chỉ đề xuất thêm hoạt động và ước tính vào bản nháp. Chưa lưu lên tài khoản; hoạt động và khoản đã chi hiện có được giữ nguyên.',
              ),
              const Text(
                'Kết quả AI được lưu tạm trên máy chủ tối đa 24 giờ để kiểm tra lại yêu cầu. Gemini xử lý thông tin bạn đồng ý gửi.',
              ),
              if (proposal == null) ...[
                CheckboxListTile(
                  key: const ValueKey('ai-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _consent = v == true),
                  title: const Text('Đồng ý gửi các thông tin trên đến Gemini'),
                  subtitle: const Text(
                    'Không gửi tên chuyến đi, ghi chú, khoản đã chi, GPS, thông tin liên hệ hay hồ sơ tài khoản. Vùng xuất phát chưa xác định.',
                  ),
                ),
                FilledButton(
                  key: const ValueKey('ai-generate'),
                  onPressed: _consent && !_loading ? _generate : null,
                  child: Text(
                    _loading
                        ? 'Đang tạo đề xuất…'
                        : _error == null
                        ? 'Tạo đề xuất'
                        : 'Thử lại',
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
                Text(proposal.summary),
                const SizedBox(height: 4),
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
                        Text(
                          'Đã đối chiếu Catalogue (${envelope.evidence.length} nguồn)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                ] else
                  const Text(
                    'Chưa xác minh giá, địa điểm, giờ mở cửa, đường đi và thời tiết. Kiểm tra trước khi sử dụng.',
                  ),
                ...proposal.activities.map(
                  (a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Ngày ${a.day}: ${a.title}\n${_clock(a.startMinute)}–${_clock(a.endMinute)} · ${a.costVnd == null ? 'Chi phí chưa rõ' : 'Ước tính ${a.costVnd} VND'}',
                    ),
                  ),
                ),
                ...proposal.warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(w),
                  ),
                ),
                ..._issues
                    .take(12)
                    .map(
                      (i) => Text(
                        i.message,
                        style: TextStyle(
                          color: i.isBlocking
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                if (!_canApply)
                  const Text(
                    'Đề xuất còn lỗi chặn. Hủy để chỉnh lịch hiện tại rồi tạo đề xuất mới.',
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

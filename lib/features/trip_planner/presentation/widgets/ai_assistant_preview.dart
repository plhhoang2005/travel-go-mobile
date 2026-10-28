import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/ai_context_grounding.dart';
import '../../models/ai_grounded_assistant.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/ai_generation_service.dart';
import '../../../trips/models/trip_evidence_envelope.dart';
import 'evidence_details_sheet.dart';
import 'web_advice_sheet.dart';
export 'web_advice_sheet.dart';

class AiAssistantPreview extends StatefulWidget {
  final AiAssistantContext input;
  final AiAssistantGenerator generate;
  final Listenable authority;
  final bool Function() isCurrent;
  final Future<AiWebAdviceReply> Function(String prompt, String requestId)? onWebAdvice;

  const AiAssistantPreview({
    super.key,
    required this.input,
    required this.generate,
    required this.authority,
    required this.isCurrent,
    this.onWebAdvice,
  });
  @override
  State<AiAssistantPreview> createState() => _AiAssistantPreviewState();
}

class _AiAssistantPreviewState extends State<AiAssistantPreview> {
  final _prompt = TextEditingController();
  String _intent = 'advice';
  String? _requestId, _askedPrompt, _error;
  List<Map<String, Object?>>? _requestHistory;
  final List<Map<String, Object?>> _history = [];
  bool _consent = false, _loading = false, _closing = false, _estimateReviewAck = false;
  bool _showContextDetails = false;
  bool _useWebAdvice = false;
  AiWebAdviceReply? _webAdviceResult;
  Object? _reply;

  AiAssistantResult? get _assistantResult {
    final r = _reply;
    if (r is AiGroundedAssistantReply) return r.result;
    if (r is AiAssistantReply) return r.result;
    return null;
  }

  AiModificationPreview? get _modification {
    final r = _reply;
    if (r is AiGroundedAssistantReply) return r.modification;
    if (r is AiAssistantReply) return r.modification;
    return null;
  }

  TripEvidenceEnvelope? get _envelope {
    final r = _reply;
    if (r is AiGroundedAssistantReply) return r.envelope;
    return null;
  }
  String _source(AiRecommendation recommendation) {
    final reference = widget.input.places
        .where((p) => p['id'] == recommendation.placeId)
        .firstOrNull;
    if (reference == null) {
      return 'Địa điểm chưa xác minh.';
    }
    final fact = widget.input.grounding?.facts[recommendation.placeId];
    if (fact != null && fact.isReviewed) {
      final availText = fact.availability == AvailabilityState.open
          ? 'Đang mở cửa theo lịch'
          : fact.availability == AvailabilityState.closed
              ? 'Đang đóng cửa'
              : 'Giờ mở cửa chưa rõ';
      final priceText = fact.priceStatus == 'free'
          ? 'Miễn phí vé vào'
          : fact.amountVnd != null
              ? 'Giá tham khảo: ${fact.amountVnd} VND'
              : 'Giá vé chưa xác minh';
      return 'Tham chiếu: ${reference['name']} · $availText · $priceText.';
    }
    return 'Tên tham chiếu từ danh mục TravelGO: ${reference['name']}. Giờ, giá và tính khả thi chưa xác minh.';
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (!_consent || _loading || !widget.isCurrent()) {
      return;
    }
    final prompt =
        _askedPrompt ??
        (_prompt.text.trim().isEmpty && _intent == 'recommendations'
            ? 'Gợi ý hoạt động phù hợp với lịch ngày đang chọn.'
            : _prompt.text.trim());
    final id = _requestId ?? const Uuid().v4();
    final history =
        _requestHistory ??
        _history.map((h) => Map<String, Object?>.from(h)).toList();
    try {
      assistantRequest(widget.input, _intent, prompt, history, id);
    } on Object {
      setState(
        () => _error = 'Nhập câu hỏi tối đa 600 ký tự, không có thông tin liên hệ hoặc URL. Ngữ cảnh ngày cần nằm trong giới hạn gửi AI.',
      );
      return;
    }
    _requestId = id;
    _askedPrompt = prompt;
    _requestHistory = history;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_useWebAdvice && widget.onWebAdvice != null) {
        final webReply = await widget.onWebAdvice!(prompt, id);
        if (!mounted || !widget.isCurrent()) {
          return;
        }
        setState(() {
          _webAdviceResult = webReply;
          _reply = null;
          _history.addAll([
            {'role': 'user', 'text': prompt},
            {'role': 'model', 'text': webReply.summary},
          ]);
          while (_history.length > 4) {
            _history.removeRange(0, 2);
          }
          _requestId = null;
          _askedPrompt = null;
          _requestHistory = null;
          _prompt.clear();
          _consent = false;
        });
        return;
      }
      final reply = await widget.generate(_intent, prompt, history, id);
      if (!mounted || !widget.isCurrent()) {
        return;
      }
      final result = reply is AiGroundedAssistantReply
          ? reply.result
          : (reply as AiAssistantReply).result;
      final modification = reply is AiGroundedAssistantReply
          ? reply.modification
          : (reply as AiAssistantReply).modification;

      setState(() {
        _reply = reply;
        _webAdviceResult = null;
        _estimateReviewAck = false;
        if (modification == null) {
          _history.addAll([
            {'role': 'user', 'text': prompt},
            {'role': 'model', 'text': result.summary},
          ]);
          while (_history.length > 4) {
            _history.removeRange(0, 2);
          }
          _requestId = null;
          _askedPrompt = null;
          _requestHistory = null;
          _prompt.clear();
          _consent = false;
        }
      });
    } on Object catch (error) {
      if (!mounted || !widget.isCurrent()) {
        return;
      }
      final failure = error is AiGenerationFailure
          ? error
          : const AiGenerationFailure('invalid_result');
      setState(() {
        _error = failure.message;
        if (!failure.retrySameRequest) {
          _requestId = null;
          _askedPrompt = null;
          _requestHistory = null;
        }
      });
    } finally {
      if (mounted && widget.isCurrent()) {
        setState(() => _loading = false);
      }
    }
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
      final modification = _modification, result = _assistantResult, envelope = _envelope, body = widget.input.toJson();
      final editable = !_loading && _requestId == null && modification == null;
      return AlertDialog(
        title: Text('AI cho ngày ${widget.input.selectedDay}'),
        scrollable: true,
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Scope Card
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.input.destinationId.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        Text(
                          '${body['date'] ?? 'chưa đặt ngày'} · ưu tiên ${body['priority']}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => setState(() => _showContextDetails = !_showContextDetails),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showContextDetails ? Icons.expand_less : Icons.info_outline,
                                  size: 15,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _showContextDetails ? 'Đóng' : 'Chi tiết',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_showContextDetails) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Text(
                        'Gửi ${widget.input.activities.length} hoạt động của ngày này; ${widget.input.places.length} tên địa điểm tham chiếu, số người, ngân sách và sở thích.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Không gửi tên chuyến đi, ghi chú, khoản đã chi, GPS hay hồ sơ. Câu hỏi và tối đa 2 cặp chat gần nhất chỉ ở RAM của app. Gemini xử lý dữ liệu được đồng ý gửi.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('ai-assistant-mode'),
                initialValue: _intent,
                decoration: const InputDecoration(
                  labelText: 'Bạn muốn AI hỗ trợ gì?',
                ),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'advice',
                    child: Text('Tư vấn theo ngày'),
                  ),
                  DropdownMenuItem(
                    value: 'recommendations',
                    child: Text('Gợi ý hoạt động'),
                  ),
                  DropdownMenuItem(
                    value: 'modify',
                    child: Text('Đề xuất chỉnh lịch'),
                  ),
                ],
                onChanged: editable
                    ? (value) => setState(() {
                        _intent = value!;
                        _reply = null;
                        _webAdviceResult = null;
                        _error = null;
                        _consent = false;
                        _estimateReviewAck = false;
                      })
                    : null,
              ),
              if (widget.onWebAdvice != null) ...[
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: _useWebAdvice
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _useWebAdvice
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                          : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: CheckboxListTile(
                    key: const ValueKey('ai-assistant-web-search-toggle'),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    value: _useWebAdvice,
                    onChanged: editable
                        ? (v) => setState(() {
                              _useWebAdvice = v == true;
                              _consent = false;
                            })
                        : null,
                    secondary: Icon(Icons.travel_explore, size: 20, color: Theme.of(context).colorScheme.primary),
                    title: const Text(
                      'Tra cứu thông tin Internet (Google Search)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Tìm kiếm nguồn thông tin thực tế từ Internet khi địa điểm chưa có trong danh mục.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('ai-assistant-prompt'),
                controller: _prompt,
                enabled: editable,
                minLines: 2,
                maxLines: 4,
                maxLength: 600,
                decoration: const InputDecoration(
                  labelText: 'Câu hỏi hoặc yêu cầu chỉnh lịch',
                  helperText: 'Không nhập số liên hệ, email hoặc URL.',
                ),
                onChanged: (_) => setState(() {
                  _consent = false;
                  _estimateReviewAck = false;
                }),
              ),
              if (modification == null) ...[
                CheckboxListTile(
                  key: const ValueKey('ai-assistant-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _consent = v == true),
                  title: const Text(
                    'Đồng ý gửi câu hỏi và ngữ cảnh trên đến Gemini',
                  ),
                ),
                FilledButton(
                  key: const ValueKey('ai-assistant-send'),
                  onPressed: _consent && !_loading ? _ask : null,
                  child: Text(
                    _loading
                        ? 'Đang chờ AI…'
                        : _requestId != null
                        ? 'Kiểm tra lại kết quả'
                        : 'Gửi AI',
                  ),
                ),
                if (_requestId != null && !_loading)
                  const Text(
                    'Nội dung đang chờ kết quả được giữ nguyên khi kiểm tra lại. Bạn có thể Hủy để rời màn hình.',
                  ),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
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
              for (final h in _history)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: h['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 380),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: h['role'] == 'user'
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: Radius.circular(h['role'] == 'user' ? 12 : 2),
                          bottomRight: Radius.circular(h['role'] == 'user' ? 2 : 12),
                        ),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                h['role'] == 'user' ? Icons.person : Icons.auto_awesome,
                                size: 13,
                                color: h['role'] == 'user'
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                h['role'] == 'user' ? 'Bạn' : 'AI · chưa xác minh',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: h['role'] == 'user'
                                      ? Theme.of(context).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${h['text']}',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: h['role'] == 'user'
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_webAdviceResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.travel_explore, size: 18, color: Colors.blue),
                          const SizedBox(width: 6),
                          const Text(
                            'Dẫn chứng thực tế từ Google Search',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                          ),
                          const Spacer(),
                          Text(
                            '${_webAdviceResult!.evidence.length} nguồn',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _webAdviceResult!.summary,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                      if (_webAdviceResult!.evidence.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text('Xem chi tiết dẫn chứng'),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => WebAdviceSheet(reply: _webAdviceResult!),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (result != null) ...[
                const Divider(height: 24),
                if (modification != null) Text(result.summary),
                if (envelope != null && envelope.evidence.isNotEmpty) ...[
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
                  OutlinedButton.icon(
                    key: const ValueKey('ai-assistant-view-evidence'),
                    icon: const Icon(Icons.verified_outlined, size: 16),
                    label: Text('Xem căn cứ (${envelope.evidence.length})'),
                    onPressed: () => showTripEvidence(
                      context,
                      envelope,
                      authority: widget.authority,
                      isCurrent: widget.isCurrent,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                for (final r in result.recommendations)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  r.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.reason,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _source(r),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              icon: const Icon(Icons.add_circle_outline, size: 15),
                              label: const Text('Thêm vào lịch'),
                              onPressed: () {
                                setState(() {
                                  _intent = 'modify';
                                  _prompt.text = 'Thêm hoạt động ghé "${r.title}" vào thời gian thích hợp trong ngày.';
                                  _consent = false;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (result.warnings.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: const ValueKey('ai-assistant-warnings-accordion'),
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                        title: Text(
                          'Lưu ý & Căn cứ tham khảo (${result.warnings.length})',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final w in result.warnings)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      w,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            'Tư vấn không tự thay đổi chuyến đi. Giá, giờ mở cửa, đường đi và thời tiết không được coi là verified.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (modification != null) ...[
                const Divider(height: 24),
                const Text(
                  'Xem thay đổi trước khi xác nhận',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...(() {
                  final actionDiffs = modification.differences
                      .where((d) => !d.startsWith('Lưu ý dữ liệu:'))
                      .toList();
                  final diffsToRender = actionDiffs.isNotEmpty
                      ? actionDiffs
                      : modification.differences;
                  return diffsToRender.map(
                    (d) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            d.startsWith('Thêm')
                                ? Icons.add_circle_outline
                                : (d.startsWith('Xóa')
                                    ? Icons.delete_outline
                                    : (d.startsWith('Sửa')
                                        ? Icons.edit_outlined
                                        : Icons.swap_vert)),
                            color: d.startsWith('Thêm')
                                ? Colors.green
                                : (d.startsWith('Xóa')
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d,
                              style: const TextStyle(fontSize: 12, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })(),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dự toán: ${modification.beforeBudget.knownEstimate} → ${modification.afterBudget.knownEstimate} VND · Đã chi: ${modification.beforeBudget.actualTotal} VND (giữ nguyên)${modification.afterBudget.unknownEstimateCount > 0 ? ' · còn ${modification.afterBudget.unknownEstimateCount} khoản chưa rõ giá' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...(() {
                  final blockingIssues = modification.issues
                      .where((i) => i.isBlocking)
                      .toList();
                  return blockingIssues.map(
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              i.message,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })(),
                if (!modification.canApply)
                  Text(
                    'Có lỗi chặn; Hủy để chỉnh lịch trước khi tạo đề xuất mới.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ...(() {
                  final dataNotes = modification.differences
                      .where((d) => d.startsWith('Lưu ý dữ liệu:'))
                      .map((d) => d.replaceFirst('Lưu ý dữ liệu: ', ''))
                      .toList();
                  final advisoryIssues = modification.issues
                      .where((i) => !i.isBlocking)
                      .map((i) => i.message)
                      .toList();
                  final allAdvisories = [...dataNotes, ...advisoryIssues];
                  if (allAdvisories.isEmpty) return <Widget>[];

                  return <Widget>[
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding:
                            const EdgeInsets.only(left: 8, bottom: 8),
                        dense: true,
                        leading: const Icon(Icons.info_outline,
                            size: 16, color: Colors.amber),
                        title: Text(
                          'Lưu ý dữ liệu & kiểm tra (${allAdvisories.length})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: allAdvisories
                            .take(8)
                            .map(
                              (note) => Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    '• $note',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ];
                })(),
                if (modification.requiresEstimateReview)
                  CheckboxListTile(
                    key: const ValueKey('ai-assistant-estimate-review-ack'),
                    contentPadding: EdgeInsets.zero,
                    value: _estimateReviewAck,
                    onChanged: (v) =>
                        setState(() => _estimateReviewAck = v == true),
                    title: const Text(
                      'Tôi đã rà soát dự toán cũ của các hoạt động thay đổi.',
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Xác nhận chỉ sửa bản nháp hiện tại. Chưa lưu lên tài khoản.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('ai-assistant-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          if (modification != null)
            FilledButton(
              key: const ValueKey('ai-assistant-apply'),
              onPressed: (modification.canApply &&
                      (!modification.requiresEstimateReview ||
                          _estimateReviewAck))
                  ? () => Navigator.of(context).pop(_reply is AiGroundedAssistantReply ? _reply : modification)
                  : null,
              child: const Text('Xác nhận chỉnh bản nháp'),
            ),
        ],
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../services/ai_assistant_service.dart';
import '../../services/ai_generation_service.dart';

class AiAssistantPreview extends StatefulWidget {
  final AiAssistantContext input;
  final AiAssistantGenerator generate;
  final Listenable authority;
  final bool Function() isCurrent;
  const AiAssistantPreview({
    super.key,
    required this.input,
    required this.generate,
    required this.authority,
    required this.isCurrent,
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
  AiAssistantReply? _reply;
  String _source(AiRecommendation recommendation) {
    final reference = widget.input.places
        .where((p) => p['id'] == recommendation.placeId)
        .firstOrNull;
    return reference == null
        ? 'Địa điểm chưa xác minh.'
        : 'Tên tham chiếu từ danh mục TravelGO: ${reference['name']}. Giờ, giá và tính khả thi chưa xác minh.';
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
      final reply = await widget.generate(_intent, prompt, history, id);
      if (!mounted || !widget.isCurrent()) {
        return;
      }
      setState(() {
        _reply = reply;
        _estimateReviewAck = false;
        if (reply.modification == null) {
          _history.addAll([
            {'role': 'user', 'text': prompt},
            {'role': 'model', 'text': reply.result.summary},
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
      final modification = _reply?.modification, body = widget.input.toJson();
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
              Text(
                '${widget.input.destinationId} · ${body['date'] ?? 'chưa đặt ngày'} · ưu tiên ${body['priority']}',
              ),
              Text(
                'Gửi ${widget.input.activities.length} hoạt động của ngày này; ${widget.input.places.length} tên địa điểm tham chiếu, số người, ngân sách và sở thích. Giờ mở cửa, đường đi, thời tiết chưa biết khi chưa có dữ liệu.',
              ),
              const Text(
                'Không gửi tên chuyến đi, ghi chú, khoản đã chi, GPS hay hồ sơ. Câu hỏi và tối đa 2 cặp chat gần nhất chỉ ở RAM của app; kết quả AI lưu tạm trên máy chủ tối đa 24 giờ để kiểm tra lại yêu cầu. Gemini xử lý dữ liệu được đồng ý gửi.',
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
                        _error = null;
                        _consent = false;
                        _estimateReviewAck = false;
                      })
                    : null,
              ),
              const SizedBox(height: 12),
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
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${h['role'] == 'user' ? 'Bạn' : 'AI · chưa xác minh'}: ${h['text']}',
                  ),
                ),
              if (_reply != null) ...[
                const Divider(height: 24),
                if (modification != null) Text(_reply!.result.summary),
                for (final r in _reply!.result.recommendations)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${r.title}\n${r.reason}\n${_source(r)}'),
                  ),
                for (final w in _reply!.result.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(w),
                  ),
                const Text(
                  'Tư vấn không tự thay đổi chuyến đi. Giá, giờ mở cửa, đường đi và thời tiết không được coi là verified.',
                ),
              ],
              if (modification != null) ...[
                const Divider(height: 24),
                const Text('Xem thay đổi trước khi xác nhận'),
                ...modification.differences.map(
                  (d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(d),
                  ),
                ),
                Text(
                  'Dự toán đã biết: ${modification.beforeBudget.knownEstimate} → ${modification.afterBudget.knownEstimate} VND; còn ${modification.afterBudget.unknownEstimateCount} khoản chưa rõ giá.',
                ),
                Text(
                  'Đã chi được giữ nguyên: ${modification.beforeBudget.actualTotal} VND.',
                ),
                ...modification.issues
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
                if (!modification.canApply)
                  const Text(
                    'Có lỗi chặn; Hủy để chỉnh lịch trước khi tạo đề xuất mới.',
                  ),
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
                const Text(
                  'Xác nhận chỉ sửa bản nháp hiện tại. Chưa lưu lên tài khoản.',
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
                  ? () => Navigator.of(context).pop(modification)
                  : null,
              child: const Text('Xác nhận chỉnh bản nháp'),
            ),
        ],
      );
    },
  );
}

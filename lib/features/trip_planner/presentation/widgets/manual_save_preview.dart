import 'package:flutter/material.dart';

import '../../../trips/models/editable_trip_codec.dart';
import '../../models/editable_trip_command.dart';
import '../../models/editable_trip_document.dart';
import '../../providers/manual_planner_provider.dart';
import '../../services/editable_trip_validator.dart';
import 'manual_budget_panel.dart';
import 'manual_expense_form.dart';
import 'manual_itinerary_timeline.dart';

class ManualSavePreview extends StatefulWidget {
  final ManualPlannerProvider planner;
  final SavePreview preview;
  final ValueChanged<EditableValidationIssue> onResolveIssue;
  const ManualSavePreview({
    super.key,
    required this.planner,
    required this.preview,
    required this.onResolveIssue,
  });
  @override
  State<ManualSavePreview> createState() => _ManualSavePreviewState();
}

class _ManualSavePreviewState extends State<ManualSavePreview> {
  final _reason = TextEditingController();
  final _reasonKey = GlobalKey<FormState>();
  final _reasonFocus = FocusNode();
  EditableValidationIssue? _issue;
  bool _submitted = false;
  String? _error;
  late final List<_PreviewChange> _changes;
  ManualPlannerProvider get planner => widget.planner;
  SavePreview get preview => widget.preview;
  bool get _workspace =>
      planner.document != null &&
      planner.draftId == preview.draftId &&
      planner.currentOwnerId == preview.proof?.ownerId;
  bool get _current =>
      _workspace &&
      planner.editorGeneration == preview.generation &&
      EditableTripCodec.digest(planner.document!) == preview.digest;
  @override
  void initState() {
    super.initState();
    _changes = _previewChanges(preview);
  }

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  void _back() {
    if (_workspace) planner.cancelPreview();
    Navigator.maybePop(context);
  }

  Future<void> _confirm() async {
    if (!_current || _submitted || planner.isSaving || !preview.canConfirm) {
      return;
    }
    setState(() {
      _submitted = true;
      _error = null;
    });
    final saved = await planner.confirmSave(preview);
    if (!mounted || !_workspace) return;
    if (saved) {
      Navigator.maybePop(context);
      return;
    }
    setState(
      () => _error =
          planner.errorMessage ??
          'Chưa thể xác nhận lưu. Quay lại để kiểm tra nội dung.',
    );
  }

  void _resolve(EditableValidationIssue issue) {
    if (!_current || planner.isSaving) return;
    widget.onResolveIssue(issue);
    _back();
  }

  void _selectIssue(EditableValidationIssue issue) => setState(() {
    _issue = issue;
    _reason.clear();
  });
  void _acknowledge() {
    final issue = _issue;
    if (!_current || issue == null || issue.fingerprint == null) return;
    if (!(_reasonKey.currentState?.validate() ?? false)) {
      _reasonFocus.requestFocus();
      return;
    }
    try {
      planner.dispatch(
        AcknowledgeIssueCommand(
          ValidationException(
            issueCode: issue.code,
            itemIds: issue.itemIds,
            reason: _reason.text.trim(),
            fingerprint: issue.fingerprint!,
          ),
        ),
      );
      setState(() => _issue = null);
    } on Object {
      setState(
        () =>
            _error = 'Cảnh báo đã thay đổi. Quay lại và xem lại trước khi lưu.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planner,
    builder: (context, _) {
      if (!_workspace) {
        return Scaffold(
          appBar: AppBar(title: const Text('Xem lại chuyến đi')),
          body: const SafeArea(
            child: Center(child: Text('Phiên chỉnh sửa không còn khả dụng.')),
          ),
        );
      }
      return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: BackButton(onPressed: _back),
          title: const Text('Xem lại chuyến đi'),
        ),
        body: SafeArea(child: _PreviewBody(state: this)),
      );
    },
  );
}

class _PreviewBody extends StatelessWidget {
  final _ManualSavePreviewState state;
  const _PreviewBody({required this.state});
  @override
  Widget build(BuildContext context) {
    final p = state.preview, planner = state.planner;
    return CustomScrollView(
      key: const ValueKey('manual.preview'),
      slivers: [
        SliverToBoxAdapter(child: _PreviewOverview(state: state)),
        SliverList.builder(
          itemCount: state._changes.length,
          itemBuilder: (context, index) =>
              _ChangeRow(change: state._changes[index]),
        ),
        SliverList.builder(
          itemCount: p.issues.length,
          itemBuilder: (context, index) =>
              _IssueRow(state: state, issue: p.issues[index]),
        ),
        if (state._issue != null)
          SliverToBoxAdapter(child: _IssueReason(state: state)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Chỉ lưu nội dung bạn vừa xem. Thay đổi mới cần được xem lại.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed:
                      state._current &&
                          !state._submitted &&
                          !planner.isSaving &&
                          p.canConfirm
                      ? state._confirm
                      : null,
                  child: Text(
                    p.isAccount ? 'Lưu vào tài khoản' : 'Lưu bản nháp trên máy',
                  ),
                ),
                TextButton(
                  onPressed: state._back,
                  child: const Text('Quay lại chỉnh sửa'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewOverview extends StatelessWidget {
  final _ManualSavePreviewState state;
  const _PreviewOverview({required this.state});
  @override
  Widget build(BuildContext context) {
    final p = state.preview, planner = state.planner;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p.document.input.title.isEmpty
                ? 'Chuyến đi chưa đặt tên'
                : p.document.input.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            '${p.document.input.destinationName ?? 'Chưa chọn điểm đến'} · ${p.document.input.origin}',
          ),
          Text(
            '${p.document.input.startDate ?? 'Chưa chọn ngày'} – ${p.document.input.endDate ?? 'Chưa chọn ngày'}',
          ),
          Text(
            '${p.document.days.length} ngày · ${p.document.input.travelerCount} người',
          ),
          Text('Sở thích: ${p.document.input.interests.join(', ')}'),
          Text(
            'Ưu tiên: ${switch (p.document.input.priority) {
              'cheapest' => 'Rẻ nhất',
              'fastest' => 'Nhanh nhất',
              'comfortable' => 'Thoải mái',
              _ => 'Cân bằng',
            }}',
          ),
          const SizedBox(height: 16),
          ManualBudgetSummary(
            totals: p.totals,
            budget: p.document.input.totalBudgetVnd,
          ),
          if (!state._current)
            const Text(
              'Nội dung đã thay đổi. Quay lại và xem lại trước khi lưu.',
            ),
          if (planner.isSaving)
            const Text('Đang lưu… Bạn có thể quay lại để tiếp tục chỉnh sửa.'),
          if (state._error != null)
            Text(
              state._error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final _ManualSavePreviewState state;
  final EditableValidationIssue issue;
  const _IssueRow({required this.state, required this.issue});
  @override
  Widget build(BuildContext context) {
    final titles = state.preview.document.items
        .where((i) => issue.itemIds.contains(i.id))
        .map((i) => i.title);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${issue.acknowledged
                ? 'Đã ghi lý do'
                : issue.isBlocking
                ? 'Cần xử lý'
                : 'Lưu ý'}: ${issue.message}',
          ),
          if (titles.isNotEmpty) Text(titles.join(' · ')),
          if (state._current &&
              !state.planner.isSaving &&
              (issue.itemIds.isNotEmpty ||
                  issue.path.startsWith('items.') ||
                  issue.path.startsWith('input.')))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => state._resolve(issue),
                child: const Text('Đi sửa nội dung'),
              ),
            ),
          if (state._current &&
              !state.planner.isSaving &&
              !issue.acknowledged &&
              {'overlap', 'time_order'}.contains(issue.code))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  state._selectIssue(issue);
                },
                child: const Text('Ghi lý do chấp nhận'),
              ),
            ),
        ],
      ),
    );
  }
}

class _IssueReason extends StatelessWidget {
  final _ManualSavePreviewState state;
  const _IssueReason({required this.state});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Form(
      key: state._reasonKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(state._issue!.message),
          TextFormField(
            key: const ValueKey('preview.reason'),
            controller: state._reason,
            focusNode: state._reasonFocus,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Lý do cho cảnh báo này',
            ),
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Nhập lý do chấp nhận.'
                : v!.runes.length > 2000
                ? 'Tối đa 2000 ký tự Unicode.'
                : null,
          ),
          TextButton(
            onPressed: state._current ? state._acknowledge : null,
            child: const Text('Áp dụng lý do và xem lại sau'),
          ),
        ],
      ),
    ),
  );
}

class _PreviewChange {
  final String text;
  final bool heading;
  const _PreviewChange(this.text, {this.heading = false});
}

class _ChangeRow extends StatelessWidget {
  final _PreviewChange change;
  const _ChangeRow({required this.change});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, change.heading ? 24 : 8, 16, 0),
    child: Text(
      change.text,
      style: change.heading ? Theme.of(context).textTheme.titleMedium : null,
    ),
  );
}

List<_PreviewChange> _previewChanges(SavePreview preview) {
  final before = preview.beforeDocument, after = preview.document;
  bool different(Map<String, Object?> a, Map<String, Object?> b) =>
      EditableTripCodec.canonicalJson(a) != EditableTripCodec.canonicalJson(b);
  final rows = <_PreviewChange>[
    const _PreviewChange('Thông tin và lịch trình', heading: true),
  ];
  if (before == null ||
      different(before.input.toJson(), after.input.toJson())) {
    rows.add(
      _PreviewChange(
        before == null ? 'Tạo chuyến đi mới' : 'Cập nhật thông tin chuyến đi',
      ),
    );
  }
  final oldDays = {for (final day in before?.days ?? <TripDay>[]) day.id: day};
  final newDays = {for (final day in after.days) day.id: day};
  for (final day in after.days) {
    final old = oldDays[day.id];
    if (old == null || different(old.toJson(), day.toJson())) {
      rows.add(
        _PreviewChange(
          '${old == null ? 'Thêm' : 'Sửa'} ${manualDayLabel(day)}\n${day.notes}',
        ),
      );
    }
  }
  for (final old in oldDays.values.where((d) => !newDays.containsKey(d.id))) {
    rows.add(_PreviewChange('Bỏ ${manualDayLabel(old)}'));
  }
  final oldItems = {for (final i in before?.items ?? <TripItem>[]) i.id: i};
  final newItems = {for (final i in after.items) i.id: i};
  String itemText(TripItem i) =>
      '${i.title} · ${manualDayLabel(newDays[i.dayId] ?? oldDays[i.dayId]!)}\n'
      'Thứ tự ${i.position + 1} · ${manualTimeLabel(i)}\n${i.notes}';
  for (final i in after.items) {
    final old = oldItems[i.id];
    if (old == null || different(old.toJson(), i.toJson())) {
      rows.add(
        _PreviewChange(
          '${old == null ? 'Thêm' : 'Sửa/chuyển'} hoạt động: ${itemText(i)}',
        ),
      );
    }
  }
  for (final old in oldItems.values.where((i) => !newItems.containsKey(i.id))) {
    rows.add(_PreviewChange('Xóa hoạt động: ${itemText(old)}'));
  }
  rows.add(const _PreviewChange('Các khoản dự kiến', heading: true));
  final oldEstimates = {
    for (final e in before?.estimates ?? <EstimatedExpense>[]) e.id: e,
  };
  for (final e in after.estimates) {
    final old = oldEstimates[e.id];
    if (old == null || different(old.toJson(), e.toJson())) {
      rows.add(
        _PreviewChange(
          '${e.active ? 'Tính dự kiến' : 'Ngừng tính dự kiến'}: ${manualExpenseCategories[e.category]} · '
          '${e.unitAmountVnd == null ? 'Chưa biết giá' : manualMoney(e.unitAmountVnd!)} · ${manualExpenseBases[e.basis]}'
          '${e.customQuantity == null ? '' : ' × ${e.customQuantity}'}\n${e.description}',
        ),
      );
    }
  }
  rows.add(const _PreviewChange('Các khoản đã chi', heading: true));
  final oldActuals = {
    for (final e in before?.actualExpenses ?? <ActualExpense>[]) e.id: e,
  };
  final newActuals = {for (final e in after.actualExpenses) e.id: e};
  for (final e in after.actualExpenses) {
    final old = oldActuals[e.id];
    if (old == null || different(old.toJson(), e.toJson())) {
      rows.add(
        _PreviewChange(
          '${old != null && old.itemId != null && e.itemId == null
              ? 'Giữ khoản đã chi; bỏ liên kết hoạt động'
              : old == null
              ? 'Thêm khoản đã chi'
              : 'Sửa khoản đã chi'}: '
          '${manualMoney(e.amountVnd)} · ${manualExpenseCategories[e.category]} · ${e.paidOn}\n${e.description}'
          '${e.sourceItemSnapshot == null ? '' : '\nHoạt động đã ghi: ${e.sourceItemSnapshot!.title} · ${e.sourceItemSnapshot!.date ?? 'Chưa chọn ngày'}'}',
        ),
      );
    }
  }
  for (final e in oldActuals.values.where(
    (e) => !newActuals.containsKey(e.id),
  )) {
    rows.add(
      _PreviewChange(
        'Xóa khoản đã chi: ${manualMoney(e.amountVnd)} · ${e.paidOn}\n${e.description}',
      ),
    );
  }
  if (!preview.actualChanges.any(
        (c) => c is PutActualCommand || c is DeleteActualCommand,
      ) &&
      oldActuals.isNotEmpty &&
      oldActuals.values.every(
        (e) =>
            newActuals[e.id] != null &&
            !different(e.toJson(), newActuals[e.id]!.toJson()),
      )) {
    rows.add(const _PreviewChange('Không sửa khoản đã chi.'));
  }
  for (final e in after.exceptions.where(
    (e) => !((before?.exceptions ?? []).any(
      (old) => old.fingerprint == e.fingerprint && old.reason == e.reason,
    )),
  )) {
    rows.add(_PreviewChange('Lý do chấp nhận cảnh báo: ${e.reason}'));
  }
  return List.unmodifiable(rows);
}

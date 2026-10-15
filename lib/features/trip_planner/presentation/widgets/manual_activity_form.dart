import 'package:flutter/material.dart';

import '../../../explore/models/catalogue_reference.dart' as catalogue;
import '../../models/editable_trip_document.dart';

/// Shared by manual forms. The route owner supplies live workspace authority.
class ManualFormScope extends InheritedWidget {
  final bool canApply;
  const ManualFormScope({
    super.key,
    required this.canApply,
    required super.child,
  });
  static bool allows(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ManualFormScope>()?.canApply ??
      true;
  @override
  bool updateShouldNotify(ManualFormScope oldWidget) =>
      canApply != oldWidget.canApply;
}

/// A scrollable native form page. Applying edits and persisting are separate.
class ManualEditFormPage extends StatefulWidget {
  final String title, applyLabel;
  final bool dirty;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final VoidCallback? onApply;
  const ManualEditFormPage({
    super.key,
    required this.title,
    required this.dirty,
    required this.formKey,
    required this.fields,
    required this.onApply,
    this.applyLabel = 'Áp dụng thay đổi',
  });
  @override
  State<ManualEditFormPage> createState() => _ManualEditFormPageState();
}

class _ManualEditFormPageState extends State<ManualEditFormPage> {
  bool _asking = false;
  Future<void> _cancel() async {
    if (_asking) return;
    if (!widget.dirty) {
      Navigator.pop(context);
      return;
    }
    _asking = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ thay đổi đang nhập?'),
        content: const Text(
          'Phần đang nhập trong form chưa được áp dụng vào lịch trình.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục sửa'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    _asking = false;
    if (mounted && discard == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ManualFormScope.allows(context);
    return PopScope(
      canPop: !widget.dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 26
              ? 88
              : 56,
          leading: BackButton(onPressed: _cancel),
          title: Text(widget.title, maxLines: 2),
          actions: [TextButton(onPressed: _cancel, child: const Text('Hủy'))],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            key: const ValueKey('manual.form.scroll'),
            padding: const EdgeInsets.all(16),
            child: Form(
              key: widget.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!allowed)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Dữ liệu chuyến đi đã thay đổi. Đóng form và mở lại để cập nhật.',
                      ),
                    ),
                  for (final field in widget.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: field,
                    ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: allowed ? widget.onApply : null,
                    child: Text(widget.applyLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ManualActivityForm extends StatefulWidget {
  final TripItem initialItem;
  final List<catalogue.PlaceReference> places;
  const ManualActivityForm({
    super.key,
    required this.initialItem,
    required this.places,
  });
  @override
  State<ManualActivityForm> createState() => _ManualActivityFormState();
}

class _ManualActivityFormState extends State<ManualActivityForm> {
  final _key = GlobalKey<FormState>();
  final _titleFocus = FocusNode(),
      _startFocus = FocusNode(),
      _endFocus = FocusNode(),
      _notesFocus = FocusNode();
  late final TextEditingController _title, _start, _end, _notes;
  String? _place;
  bool _dirty = false, _unlinked = false;
  String _time(int? minute) => minute == null
      ? ''
      : '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _place = item.placeId;
    _title = TextEditingController(text: item.title);
    _start = TextEditingController(text: _time(item.startMinute));
    _end = TextEditingController(text: _time(item.endMinute));
    _notes = TextEditingController(text: item.notes);
  }

  @override
  void dispose() {
    for (final c in [_title, _start, _end, _notes]) {
      c.dispose();
    }
    for (final f in [_titleFocus, _startFocus, _endFocus, _notesFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  int? _minute(String text) {
    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(text.trim())) {
      return null;
    }
    final parts = text.trim().split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String? _titleError(String? raw) {
    if ((raw ?? '').trim().isEmpty) return 'Nhập tên hoạt động.';
    return raw!.trim().runes.length > 200 ? 'Tối đa 200 ký tự Unicode.' : null;
  }

  String? _timeError(String? raw, {bool end = false}) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final minute = _minute(value);
    if (minute == null) return 'Nhập giờ theo HH:mm, từ 00:00 đến 23:59.';
    final start = _minute(_start.text);
    if (end && start != null && minute <= start) {
      return 'Giờ kết thúc phải sau giờ bắt đầu.';
    }
    return null;
  }

  void _changed() {
    setState(() => _dirty = true);
  }

  void _titleChanged(String value) {
    final selected = widget.places.where((p) => p.id == _place);
    if (selected.isNotEmpty && selected.first.name != value.trim()) {
      _place = null;
      _unlinked = true;
    }
    _changed();
  }

  void _apply() {
    if (!ManualFormScope.allows(context)) return;
    if (!(_key.currentState?.validate() ?? false)) {
      final focus = _titleError(_title.text) != null
          ? _titleFocus
          : _timeError(_start.text) != null
          ? _startFocus
          : _timeError(_end.text, end: true) != null
          ? _endFocus
          : _notesFocus;
      focus.requestFocus();
      return;
    }
    final item = widget.initialItem;
    if (!_dirty) {
      Navigator.pop(context, item);
      return;
    }
    final selected = widget.places.where((p) => p.id == _place);
    final edited = TripItem.fromJson({
      ...item.toJson(),
      'title': _title.text.trim(),
      'startMinute': _minute(_start.text),
      'endMinute': _minute(_end.text),
      'notes': _notes.text,
      'placeId': _place,
      'provenance': FieldProvenance(
        quality: 'user_provided',
        sourceRefs: selected.isEmpty ? [] : [selected.first.sourceId],
        observedAt: null,
      ).toJson(),
    });
    Navigator.pop(context, edited);
  }

  void _selectPlace(String? value) => setState(() {
    _place = value;
    _dirty = true;
    if (value != null) {
      _title.text = widget.places.firstWhere((p) => p.id == value).name;
    }
  });
  @override
  Widget build(BuildContext context) => ManualEditFormPage(
    title: 'Hoạt động',
    dirty: _dirty,
    formKey: _key,
    onApply: _apply,
    fields: [
      _ActivityIdentity(form: this),
      _ActivityTiming(form: this),
    ],
  );
}

class _ActivityIdentity extends StatelessWidget {
  final _ManualActivityFormState form;
  const _ActivityIdentity({required this.form});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        key: const ValueKey('activity.title'),
        controller: form._title,
        focusNode: form._titleFocus,
        decoration: const InputDecoration(labelText: 'Tên hoạt động'),
        validator: form._titleError,
        onChanged: form._titleChanged,
      ),
      DropdownButtonFormField<String>(
        itemHeight: null,
        isExpanded: true,
        initialValue: form.widget.places.any((p) => p.id == form._place)
            ? form._place
            : null,
        decoration: const InputDecoration(
          labelText: 'Địa điểm tham khảo (tùy chọn)',
        ),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('Tự nhập')),
          for (final place in form.widget.places)
            DropdownMenuItem(value: place.id, child: Text(place.name)),
        ],
        onChanged: form._selectPlace,
      ),
      if (form._unlinked)
        const Text('Đã bỏ liên kết địa điểm vì tên hoạt động đã thay đổi.'),
      if (form._place != null &&
          !form.widget.places.any((p) => p.id == form._place))
        const Text(
          'Liên kết cũ ngoài danh mục hiện tại. Giữ nguyên nếu không thay đổi.',
        ),
    ],
  );
}

class _ActivityTiming extends StatelessWidget {
  final _ManualActivityFormState form;
  const _ActivityTiming({required this.form});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        key: const ValueKey('activity.start'),
        controller: form._start,
        focusNode: form._startFocus,
        keyboardType: TextInputType.datetime,
        decoration: const InputDecoration(
          labelText: 'Bắt đầu (HH:mm)',
          helperText: 'Không bắt buộc',
        ),
        validator: form._timeError,
        onChanged: (_) => form._changed(),
      ),
      TextFormField(
        key: const ValueKey('activity.end'),
        controller: form._end,
        focusNode: form._endFocus,
        keyboardType: TextInputType.datetime,
        decoration: const InputDecoration(
          labelText: 'Kết thúc (HH:mm)',
          helperText: 'Qua nửa đêm: tách hoạt động sang hai ngày.',
        ),
        validator: (v) => form._timeError(v, end: true),
        onChanged: (_) => form._changed(),
      ),
      TextFormField(
        key: const ValueKey('activity.notes'),
        controller: form._notes,
        focusNode: form._notesFocus,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'Ghi chú'),
        validator: (v) =>
            (v ?? '').runes.length > 2000 ? 'Tối đa 2000 ký tự Unicode.' : null,
        onChanged: (_) => form._changed(),
      ),
    ],
  );
}

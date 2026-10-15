import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../explore/models/catalogue_reference.dart' as catalogue;
import '../../../trips/models/editable_trip_codec.dart';
import '../../models/editable_trip_command.dart';
import '../../models/editable_trip_document.dart';
import '../../services/budget_calculator.dart';
import '../../services/editable_trip_mutator.dart';
import 'manual_activity_form.dart';

class ManualTripInputResult {
  final TripInput input;
  final List<TripDay> days;
  final List<ItemMove> moves;
  final List<String> removedItemIds;
  final String baseDigest;
  ManualTripInputResult({
    required this.input,
    required List<TripDay> days,
    required List<ItemMove> moves,
    required List<String> removedItemIds,
    required this.baseDigest,
  }) : days = List.unmodifiable(days),
       moves = List.unmodifiable(moves),
       removedItemIds = List.unmodifiable(removedItemIds);
  List<EditableCommand> get commands => [
    SetTripInputCommand(input),
    ResizeDaysCommand(days: days, moves: moves, removedItemIds: removedItemIds),
  ];
}

class ManualTripInputForm extends StatefulWidget {
  final EditableTripDocumentV2 initialDocument;
  final List<catalogue.DestinationReference> destinations;
  final String Function() newId;
  const ManualTripInputForm({
    super.key,
    required this.initialDocument,
    required this.destinations,
    required this.newId,
  });
  @override
  State<ManualTripInputForm> createState() => _ManualTripInputFormState();
}

class _ManualTripInputFormState extends State<ManualTripInputForm> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late final Map<String, FocusNode> _focus;
  String? _destination;
  late String _priority;
  bool _dirty = false;
  TripInput? _input;
  List<TripDay>? _days;
  List<TripItem> _affected = [];
  final Map<String, String> _choices = {};
  int _affectedIndex = 0;
  EditableTripDocumentV2? _candidate;
  String? _error;
  @override
  void initState() {
    super.initState();
    final input = widget.initialDocument.input;
    final values = {
      'title': input.title,
      'origin': input.origin,
      'start': input.startDate ?? '',
      'end': input.endDate ?? '',
      'days': '${widget.initialDocument.days.length}',
      'travelers': '${input.travelerCount}',
      'budget': '${input.totalBudgetVnd}',
      'interests': input.interests.join('\n'),
    };
    _fields = values.map((k, v) => MapEntry(k, TextEditingController(text: v)));
    _focus = values.map((k, v) => MapEntry(k, FocusNode()));
    _destination = input.destinationId;
    _priority = input.priority;
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  String _text(String key) => _fields[key]!.text.trim();
  void _changed() {
    final start = _date(_text('start')), end = _date(_text('end'));
    if (start != null && end != null) {
      final count = end.difference(start).inDays + 1;
      if (count >= 1 && count <= 366) _fields['days']!.text = '$count';
    }
    setState(() => _dirty = true);
  }

  void _backToInputs() => setState(() {
    _input = null;
    _days = null;
    _candidate = null;
    _choices.clear();
  });
  void _stepAffected(int delta) => setState(() => _affectedIndex += delta);

  DateTime? _date(String raw) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return null;
    final parsed = DateTime.tryParse('${raw}T00:00:00Z');
    return parsed != null && parsed.toIso8601String().substring(0, 10) == raw
        ? parsed
        : null;
  }

  String? _validate(String name, String? value) {
    final raw = (value ?? '').trim();
    if (name == 'title' || name == 'origin') {
      return raw.runes.length > 200 ? 'Tối đa 200 ký tự Unicode.' : null;
    }
    if (name == 'interests') {
      final list = raw.split('\n').where((s) => s.trim().isNotEmpty).toList();
      return list.length > 20 || list.any((s) => s.trim().runes.length > 80)
          ? 'Tối đa 20 sở thích, mỗi dòng tối đa 80 ký tự Unicode.'
          : null;
    }
    if (name == 'start' || name == 'end') {
      if (raw.isEmpty &&
          (_text('start').isNotEmpty || _text('end').isNotEmpty)) {
        return 'Nhập đủ hai ngày hoặc xóa khoảng ngày.';
      }
      if (raw.isEmpty) return null;
      final date = _date(raw);
      if (date == null) return 'Nhập ngày có thật theo YYYY-MM-DD.';
      if (name == 'end') {
        final start = _date(_text('start'));
        if (start != null && date.isBefore(start)) {
          return 'Ngày kết thúc phải từ ngày bắt đầu trở đi.';
        }
        if (start != null && date.difference(start).inDays + 1 > 366) {
          return 'Chuyến đi tối đa 366 ngày.';
        }
      }
      return null;
    }
    if (name == 'days' &&
        (_text('start').isNotEmpty || _text('end').isNotEmpty)) {
      return null;
    }
    final valueInt = RegExp(r'^\d+$').hasMatch(raw) ? int.tryParse(raw) : null;
    final max = name == 'days'
        ? 366
        : name == 'budget'
        ? EditableTripCodec.maxMoney
        : EditableTripCodec.maxCount;
    final min = name == 'budget' ? 0 : 1;
    if (valueInt == null || valueInt < min || valueInt > max) {
      if (name == 'days') return 'Nhập số ngày từ 1 đến 366.';
      if (name == 'budget') {
        return 'Nhập ngân sách VND nguyên, từ 0 đến 9007199254740991.';
      }
      return 'Nhập số người nguyên, từ 1 đến 2147483647.';
    }
    return null;
  }

  void _prepare() {
    if (!ManualFormScope.allows(context)) return;
    if (!(_key.currentState?.validate() ?? false)) {
      for (final name in _fields.keys) {
        if (_validate(name, _fields[name]!.text) != null) {
          _focus[name]!.requestFocus();
          break;
        }
      }
      return;
    }
    final original = widget.initialDocument;
    final start = _date(_text('start')), end = _date(_text('end'));
    final count = start != null && end != null
        ? end.difference(start).inDays + 1
        : int.parse(_text('days'));
    final selected = widget.destinations.where((d) => d.id == _destination);
    _input = TripInput.fromJson({
      ...original.input.toJson(),
      'title': _text('title'),
      'origin': _text('origin'),
      'destinationId': _destination,
      'destinationName': selected.isEmpty ? null : selected.single.name,
      'startDate': start == null ? null : _text('start'),
      'endDate': end == null ? null : _text('end'),
      'travelerCount': int.parse(_text('travelers')),
      'totalBudgetVnd': int.parse(_text('budget')),
      'interests': _text('interests')
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'priority': _priority,
    });
    _days = List.generate(
      count,
      (index) => TripDay(
        id: index < original.days.length
            ? original.days[index].id
            : widget.newId(),
        ordinal: index + 1,
        date: start
            ?.add(Duration(days: index))
            .toIso8601String()
            .substring(0, 10),
        notes: index < original.days.length ? original.days[index].notes : '',
      ),
    );
    final preview = EditableTripMutator.previewResize(
      original,
      _input!,
      _days!,
    );
    _affected = preview.affectedItemIds
        .map((id) => original.items.firstWhere((i) => i.id == id))
        .toList();
    _choices.clear();
    _affectedIndex = 0;
    _candidate = null;
    _error = null;
    _refreshCandidate();
    setState(() {});
  }

  ManualTripInputResult _result() {
    final moves = <ItemMove>[], removed = <String>[];
    final positions = {
      for (final day in _days!)
        day.id: widget.initialDocument.items
            .where((i) => i.dayId == day.id)
            .length,
    };
    for (final item in _affected) {
      final choice = _choices[item.id];
      if (choice == 'delete') {
        removed.add(item.id);
      } else if (choice != null) {
        moves.add(ItemMove(item.id, choice, positions[choice]!));
        positions[choice] = positions[choice]! + 1;
      }
    }
    return ManualTripInputResult(
      input: _input!,
      days: _days!,
      moves: moves,
      removedItemIds: removed,
      baseDigest: EditableTripCodec.digest(widget.initialDocument),
    );
  }

  void _refreshCandidate() {
    _candidate = null;
    _error = null;
    if (_choices.length != _affected.length) return;
    try {
      _candidate = EditableTripMutator.apply(
        widget.initialDocument,
        _result().commands,
      );
    } on Object {
      _error = 'Không thể áp dụng thay đổi. Kiểm tra ngày, số người và giới hạn chi phí dự kiến.';
    }
  }

  Future<void> _choose(String? value) async {
    if (value == null) return;
    final id = _affected[_affectedIndex].id;
    if (value == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xóa hoạt động này?'),
          content: const Text('Các khoản đã chi vẫn được giữ.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận xóa'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true || !ManualFormScope.allows(context)) {
        return;
      }
    }
    if (!mounted || !ManualFormScope.allows(context)) return;
    setState(() {
      _choices[id] = value;
      _refreshCandidate();
    });
  }

  void _apply() {
    if (_candidate == null || !ManualFormScope.allows(context)) return;
    Navigator.pop(context, _result());
  }

  @override
  Widget build(BuildContext context) => ManualEditFormPage(
    title: 'Thông tin chuyến đi',
    dirty: _dirty,
    formKey: _key,
    applyLabel: _input == null ? 'Xem thay đổi' : 'Áp dụng thay đổi',
    onApply: _input == null
        ? _prepare
        : _candidate == null
        ? null
        : _apply,
    fields: _input == null
        ? [_TripMainFields(form: this), _TripExtraFields(form: this)]
        : [_InputReview(form: this)],
  );
}

class _TripMainFields extends StatelessWidget {
  final _ManualTripInputFormState form;
  const _TripMainFields({required this.form});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _InputField(form: form, name: 'title', label: 'Tên chuyến đi'),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          itemHeight: null,
          isExpanded: true,
          initialValue: form._destination,
          decoration: const InputDecoration(labelText: 'Điểm đến'),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Chưa chọn điểm đến'),
            ),
            for (final d in form.widget.destinations)
              DropdownMenuItem(value: d.id, child: Text(d.name)),
          ],
          onChanged: (v) {
            form._destination = v;
            form._changed();
          },
        ),
      ),
      _InputField(form: form, name: 'origin', label: 'Nơi xuất phát'),
      _InputField(
        form: form,
        name: 'start',
        label: 'Ngày bắt đầu (YYYY-MM-DD)',
        date: true,
      ),
      _InputField(
        form: form,
        name: 'end',
        label: 'Ngày kết thúc (YYYY-MM-DD)',
        date: true,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () {
            form._fields['start']!.clear();
            form._fields['end']!.clear();
            form._changed();
          },
          child: const Text('Xóa khoảng ngày'),
        ),
      ),
      _InputField(
        form: form,
        name: 'days',
        label: 'Số ngày khi chưa chọn ngày',
        number: true,
        enabled: form._text('start').isEmpty && form._text('end').isEmpty,
      ),
      _InputField(
        form: form,
        name: 'travelers',
        label: 'Số người',
        number: true,
      ),
      _InputField(
        form: form,
        name: 'budget',
        label: 'Ngân sách cả chuyến (VND)',
        number: true,
      ),
    ],
  );
}

class _TripExtraFields extends StatelessWidget {
  final _ManualTripInputFormState form;
  const _TripExtraFields({required this.form});
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Thông tin khác'),
    children: [
      _InputField(
        form: form,
        name: 'interests',
        label: 'Sở thích (mỗi dòng một sở thích)',
        multiline: true,
      ),
      DropdownButtonFormField<String>(
        itemHeight: null,
        isExpanded: true,
        initialValue: form._priority,
        decoration: const InputDecoration(labelText: 'Ưu tiên'),
        items: const [
          DropdownMenuItem(value: 'balanced', child: Text('Cân bằng')),
          DropdownMenuItem(value: 'cheapest', child: Text('Rẻ nhất')),
          DropdownMenuItem(value: 'fastest', child: Text('Nhanh nhất')),
          DropdownMenuItem(value: 'comfortable', child: Text('Thoải mái')),
        ],
        onChanged: (v) {
          if (v != null) {
            form._priority = v;
            form._changed();
          }
        },
      ),
    ],
  );
}

class _InputField extends StatelessWidget {
  final _ManualTripInputFormState form;
  final String name, label;
  final bool number, date, multiline, enabled;
  const _InputField({
    required this.form,
    required this.name,
    required this.label,
    this.number = false,
    this.date = false,
    this.multiline = false,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('trip.$name'),
      controller: form._fields[name],
      focusNode: form._focus[name],
      enabled: enabled,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 5 : 1,
      keyboardType: number
          ? TextInputType.number
          : date
          ? TextInputType.datetime
          : multiline
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) => form._validate(name, v),
      onChanged: (_) => form._changed(),
    ),
  );
}

class _InputReview extends StatelessWidget {
  final _ManualTripInputFormState form;
  const _InputReview({required this.form});
  @override
  Widget build(BuildContext context) {
    final before = BudgetCalculator.calculate(form.widget.initialDocument);
    final after = form._candidate == null
        ? null
        : BudgetCalculator.calculate(form._candidate!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Xem thay đổi thông tin',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${form.widget.initialDocument.days.length} ngày → ${form._days!.length} ngày',
        ),
        Text(
          '${form.widget.initialDocument.input.startDate ?? 'Chưa chọn ngày'} → ${form._input!.startDate ?? 'Chưa chọn ngày'}',
        ),
        Text(
          '${form.widget.initialDocument.input.travelerCount} người → ${form._input!.travelerCount} người',
        ),
        if (form._input!.destinationId !=
            form.widget.initialDocument.input.destinationId)
          const Text(
            'Điểm đến thay đổi. Các hoạt động cũ vẫn được giữ; hãy kiểm tra lại địa điểm.',
          ),
        if (form._affected.isNotEmpty) _AffectedActivity(form: form),
        if (form._affected.length > form._choices.length)
          Text(
            'Còn ${form._affected.length - form._choices.length} hoạt động cần xử lý',
          ),
        if (after != null) ...[
          const SizedBox(height: 16),
          Text(
            'Dự kiến đã biết: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(before.knownEstimate)} → ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(after.knownEstimate)}',
          ),
          Text(
            'Khoản chưa có giá: ${before.unknownEstimateCount} → ${after.unknownEstimateCount}',
          ),
          Text(
            'Đã chi được giữ: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(after.actualTotal)}',
          ),
          const Text(
            'Xóa hoạt động không xóa khoản đã chi. Khoản dự kiến liên quan sẽ ngừng tính.',
          ),
        ],
        if (form._error != null)
          Text(
            form._error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: form._backToInputs,
          child: const Text('Quay lại thông tin'),
        ),
      ],
    );
  }
}

class _AffectedActivity extends StatelessWidget {
  final _ManualTripInputFormState form;
  const _AffectedActivity({required this.form});
  @override
  Widget build(BuildContext context) {
    final item = form._affected[form._affectedIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'Hoạt động ${form._affectedIndex + 1}/${form._affected.length}: ${item.title}',
        ),
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Cách xử lý'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              itemHeight: null,
              key: const ValueKey('resize.choice'),
              isExpanded: true,
              value: form._choices[item.id],
              hint: const Text('Chọn chuyển hoặc xóa'),
              items: [
                for (final day in form._days!)
                  DropdownMenuItem(
                    value: day.id,
                    child: Text('Chuyển đến ngày ${day.ordinal}'),
                  ),
                const DropdownMenuItem(
                  value: 'delete',
                  child: Text('Xóa hoạt động này'),
                ),
              ],
              onChanged: form._choose,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: form._affectedIndex > 0
                  ? () => form._stepAffected(-1)
                  : null,
              child: const Text('Hoạt động trước'),
            ),
            TextButton(
              onPressed: form._affectedIndex < form._affected.length - 1
                  ? () => form._stepAffected(1)
                  : null,
              child: const Text('Hoạt động sau'),
            ),
          ],
        ),
      ],
    );
  }
}

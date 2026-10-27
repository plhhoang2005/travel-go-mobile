import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../trips/models/editable_trip_codec.dart';
import '../../models/editable_trip_command.dart';
import '../../models/editable_trip_document.dart';
import '../../services/editable_trip_mutator.dart';
import 'manual_activity_form.dart';

enum ManualExpenseKind { estimate, actual }

String manualMoney(int amount) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: 'đ',
  decimalDigits: 0,
).format(amount);
const manualExpenseCategories = {
  'transport': 'Di chuyển',
  'accommodation': 'Lưu trú',
  'food': 'Ăn uống',
  'attractions': 'Tham quan',
  'shopping': 'Mua sắm',
  'other': 'Khác',
};
const manualExpenseBases = {
  'trip_total': 'Toàn chuyến',
  'per_person': 'Mỗi người',
  'per_day': 'Mỗi ngày',
  'per_person_day': 'Mỗi người mỗi ngày',
  'custom_quantity': 'Số lượng tự nhập',
};

class ManualExpenseForm extends StatefulWidget {
  final EditableTripDocumentV2 document;
  final ManualExpenseKind kind;
  final String Function() newId;
  final String? expenseId;
  const ManualExpenseForm({
    super.key,
    required this.document,
    required this.kind,
    required this.newId,
    this.expenseId,
  });
  @override
  State<ManualExpenseForm> createState() => _ManualExpenseFormState();
}

class _ManualExpenseFormState extends State<ManualExpenseForm> {
  final _key = GlobalKey<FormState>();
  final _moneyFocus = FocusNode(),
      _dateFocus = FocusNode(),
      _quantityFocus = FocusNode(),
      _descriptionFocus = FocusNode();
  late final TextEditingController _amount, _date, _quantity, _description;
  late final String _id;
  String _category = 'other', _basis = 'trip_total';
  String? _itemId, _error;
  bool _active = true, _dirty = false;
  EstimatedExpense? _oldEstimate;
  ActualExpense? _oldActual;
  bool get estimate => widget.kind == ManualExpenseKind.estimate;
  @override
  void initState() {
    super.initState();
    _oldEstimate = estimate
        ? widget.document.estimates
              .where((e) => e.id == widget.expenseId)
              .firstOrNull
        : null;
    _oldActual = !estimate
        ? widget.document.actualExpenses
              .where((e) => e.id == widget.expenseId)
              .firstOrNull
        : null;
    final e = _oldEstimate, a = _oldActual;
    _id = widget.expenseId ?? widget.newId();
    _category = e?.category ?? a?.category ?? 'other';
    _itemId = e?.itemId ?? a?.itemId;
    _basis = e?.basis ?? 'trip_total';
    _active = e?.active ?? true;
    _amount = TextEditingController(
      text: (e?.unitAmountVnd ?? a?.amountVnd)?.toString() ?? '',
    );
    _date = TextEditingController(text: a?.paidOn ?? '');
    _quantity = TextEditingController(
      text: e?.customQuantity?.toString() ?? '',
    );
    _description = TextEditingController(
      text: e?.description ?? a?.description ?? '',
    );
  }

  @override
  void dispose() {
    for (final c in [_amount, _date, _quantity, _description]) {
      c.dispose();
    }
    for (final f in [
      _moneyFocus,
      _dateFocus,
      _quantityFocus,
      _descriptionFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {
    _dirty = true;
    _error = null;
  });
  void _selectPaidDate(DateTime date) {
    _date.text = DateFormat('yyyy-MM-dd').format(date);
    _changed();
  }

  int? _integer(String text, int max, {int min = 0}) {
    final raw = text.trim();
    final n = RegExp(r'^\d+$').hasMatch(raw) ? int.tryParse(raw) : null;
    return n != null && n >= min && n <= max ? n : null;
  }

  String? _amountError(String? raw) {
    if (estimate && (raw ?? '').trim().isEmpty) return null;
    return _integer(raw ?? '', EditableTripCodec.maxMoney) == null
        ? 'Nhập số tiền VND nguyên trong giới hạn hỗ trợ.'
        : null;
  }

  String? _dateError(String? raw) {
    final text = (raw ?? '').trim();
    final date = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)
        ? DateTime.tryParse('${text}T00:00:00Z')
        : null;
    return date == null || date.toIso8601String().substring(0, 10) != text
        ? 'Nhập ngày có thật theo YYYY-MM-DD.'
        : null;
  }

  String? _quantityError(String? raw) =>
      _basis != 'custom_quantity' ||
          _integer(raw ?? '', EditableTripCodec.maxCount, min: 1) != null
      ? null
      : 'Nhập số lượng nguyên dương trong giới hạn hỗ trợ.';
  String? _descriptionError(String? text) =>
      (text ?? '').runes.length > 2000 ? 'Tối đa 2000 ký tự Unicode.' : null;
  void _apply() {
    if (!ManualFormScope.allows(context)) return;
    if (!(_key.currentState?.validate() ?? false)) {
      final focus = _amountError(_amount.text) != null
          ? _moneyFocus
          : !estimate && _dateError(_date.text) != null
          ? _dateFocus
          : estimate && _quantityError(_quantity.text) != null
          ? _quantityFocus
          : _descriptionFocus;
      focus.requestFocus();
      return;
    }
    if (!_dirty && (_oldEstimate != null || _oldActual != null)) {
      Navigator.pop(context);
      return;
    }
    final amount = _integer(_amount.text, EditableTripCodec.maxMoney);
    final provenance = FieldProvenance(
      quality: amount == null ? 'unknown' : 'user_provided',
      sourceRefs: [],
      observedAt: null,
    );
    final item = widget.document.items
        .where((i) => i.id == _itemId)
        .firstOrNull;
    final EditableCommand command = estimate
        ? PutEstimateCommand(
            EstimatedExpense(
              id: _id,
              itemId: _itemId,
              category: _category,
              unitAmountVnd: amount,
              basis: _basis,
              customQuantity: _basis == 'custom_quantity'
                  ? _integer(_quantity.text, EditableTripCodec.maxCount, min: 1)
                  : null,
              active: _active,
              description: _description.text,
              provenance: provenance,
            ),
          )
        : PutActualCommand(
            ActualExpense(
              id: _id,
              itemId: _itemId,
              amountVnd: amount!,
              category: _category,
              paidOn: _date.text.trim(),
              description: _description.text,
              sourceItemSnapshot: _oldActual?.itemId == _itemId
                  ? _oldActual?.sourceItemSnapshot
                  : item == null
                  ? _oldActual?.sourceItemSnapshot
                  : ItemSnapshot(
                      title: item.title,
                      dayId: item.dayId,
                      date: widget.document.days
                          .firstWhere((d) => d.id == item.dayId)
                          .date,
                    ),
              provenance: provenance,
            ),
          );
    try {
      EditableTripMutator.apply(widget.document, [command]);
      Navigator.pop(context, command);
    } on Object {
      setState(
        () => _error = 'Không thể áp dụng. Kiểm tra tổng tiền, giới hạn khoản và liên kết hoạt động; mỗi hoạt động chỉ có một khoản dự kiến đang tính.',
      );
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa khoản đã chi?'),
        content: const Text(
          'Khoản chi này sẽ bị xóa khi bạn xác nhận lưu chuyến đi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ khoản đã chi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận xóa khoản chi'),
          ),
        ],
      ),
    );
    if (mounted && yes == true && ManualFormScope.allows(context)) {
      Navigator.pop(context, DeleteActualCommand(_id));
    }
  }

  @override
  Widget build(BuildContext context) => ManualEditFormPage(
    title: estimate ? 'Khoản dự kiến' : 'Khoản đã chi',
    dirty: _dirty,
    formKey: _key,
    onApply: _apply,
    fields: [
      if (!estimate)
        const Text(
          'Nhập tổng số tiền thực tế của khoản này. Không nhân theo người hoặc ngày.',
        ),
      _ExpenseMoneyFields(form: this),
      _ExpenseDetails(form: this),
      if (estimate)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tính vào tổng dự kiến'),
          value: _active,
          onChanged: (v) {
            _active = v;
            _changed();
          },
        ),
      if (!estimate && _oldActual != null)
        TextButton(onPressed: _delete, child: const Text('Xóa khoản đã chi')),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}

class _ExpenseMoneyFields extends StatelessWidget {
  final _ManualExpenseFormState form;
  const _ExpenseMoneyFields({required this.form});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('1. Số tiền', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      TextFormField(
        key: const ValueKey('expense.amount'),
        controller: form._amount,
        focusNode: form._moneyFocus,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: form.estimate
              ? 'Đơn giá dự kiến (VND)'
              : 'Tổng đã chi (VND)',
          helperText: form.estimate
              ? 'Để trống khi chưa biết giá; nhập 0 nếu miễn phí.'
              : null,
        ),
        validator: form._amountError,
        onChanged: (_) => form._changed(),
      ),
      const SizedBox(height: 8),
      if (form._integer(form._amount.text, EditableTripCodec.maxMoney)
          case final amount?)
        Text(
          'Bạn đang nhập ${manualMoney(amount)}',
          style: Theme.of(context).textTheme.titleMedium,
        )
      else if (form.estimate && form._amount.text.trim().isEmpty)
        const Text('Khoản này chưa có giá, chưa được cộng vào tổng đã biết.'),
      if (form.estimate) ...[
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          itemHeight: null,
          initialValue: form._basis,
          decoration: const InputDecoration(labelText: 'Cơ sở tính'),
          items: [
            for (final e in manualExpenseBases.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null) {
              form._basis = v;
              form._changed();
            }
          },
        ),
        if (form._basis == 'custom_quantity')
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TextFormField(
              key: const ValueKey('expense.quantity'),
              controller: form._quantity,
              focusNode: form._quantityFocus,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số lượng đơn vị tính',
              ),
              validator: form._quantityError,
              onChanged: (_) => form._changed(),
            ),
          ),
      ] else ...[
        ExpansionTile(
          title: const Text('Chọn ngày đã chi trên lịch'),
          leading: const Icon(Icons.calendar_month_outlined),
          children: [
            CalendarDatePicker(
              key: ValueKey('expense.calendar.${form._date.text}'),
              initialDate: form._dateError(form._date.text) == null
                  ? DateTime.parse(form._date.text)
                  : DateTime.now(),
              firstDate: DateTime(0),
              lastDate: DateTime(9999, 12, 31),
              onDateChanged: form._selectPaidDate,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TextFormField(
            key: const ValueKey('expense.paidOn'),
            controller: form._date,
            focusNode: form._dateFocus,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Ngày đã chi (YYYY-MM-DD)',
            ),
            validator: form._dateError,
            onChanged: (_) => form._changed(),
          ),
        ),
      ],
    ],
  );
}

class _ExpenseDetails extends StatelessWidget {
  final _ManualExpenseFormState form;
  const _ExpenseDetails({required this.form});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '2. Nhóm và liên kết',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        isExpanded: true,
        itemHeight: null,
        initialValue: form._category,
        decoration: const InputDecoration(labelText: 'Nhóm chi phí'),
        items: [
          for (final e in manualExpenseCategories.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) {
          if (v != null) {
            form._category = v;
            form._changed();
          }
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        isExpanded: true,
        itemHeight: null,
        initialValue: form._itemId,
        decoration: const InputDecoration(
          labelText: 'Liên kết hoạt động (tùy chọn)',
        ),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Khoản riêng của chuyến đi'),
          ),
          for (final item in form.widget.document.items)
            DropdownMenuItem(value: item.id, child: Text(item.title)),
        ],
        onChanged: (v) {
          form._itemId = v;
          form._changed();
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        key: const ValueKey('expense.description'),
        controller: form._description,
        focusNode: form._descriptionFocus,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'Mô tả khoản chi'),
        validator: form._descriptionError,
        onChanged: (_) => form._changed(),
      ),
    ],
  );
}

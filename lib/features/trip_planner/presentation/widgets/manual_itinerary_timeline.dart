import 'package:flutter/material.dart';

import '../../models/editable_trip_command.dart';
import '../../models/editable_trip_document.dart';
import '../../providers/manual_planner_provider.dart';

String manualDayLabel(TripDay day) =>
    'Ngày ${day.ordinal} · ${day.date == null ? 'Chưa chọn ngày' : day.date!.split('-').reversed.join('/')}';
String manualTimeLabel(TripItem item) {
  String at(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  if (item.startMinute == null && item.endMinute == null) return 'Chưa có giờ';
  return '${item.startMinute == null ? 'Chưa có giờ bắt đầu' : at(item.startMinute!)} – ${item.endMinute == null ? 'Chưa có giờ kết thúc' : at(item.endMinute!)}';
}

class ManualItineraryTimeline extends StatelessWidget {
  final ManualPlannerProvider planner;
  final Widget? header;
  final int selectedDayOrdinal;
  final ValueChanged<int> onSelectDay;
  final VoidCallback onChooseDay;
  final ValueChanged<TripDay> onAdd, onEditDayNotes;
  final ValueChanged<TripItem> onEdit, onMove, onDelete;
  const ManualItineraryTimeline({
    super.key,
    this.header,
    required this.planner,
    required this.selectedDayOrdinal,
    required this.onSelectDay,
    required this.onChooseDay,
    required this.onAdd,
    required this.onEdit,
    required this.onMove,
    required this.onDelete,
    required this.onEditDayNotes,
  });
  void _reorder(String id, int delta, int generation) {
    final doc = planner.document;
    if (doc == null ||
        !planner.isEditable ||
        generation != planner.editorGeneration) {
      return;
    }
    final found = doc.items.where((i) => i.id == id);
    if (found.isEmpty) return;
    final item = found.single;
    final ordered = doc.items.where((i) => i.dayId == item.dayId).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final index = ordered.indexWhere((i) => i.id == id), target = index + delta;
    if (target < 0 || target >= ordered.length) return;
    final moving = ordered.removeAt(index);
    ordered.insert(target, moving);
    planner.dispatch(
      ReorderDayCommand(item.dayId, ordered.map((i) => i.id).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = planner.document;
    if (doc == null) return const SizedBox.shrink();
    final ordinal = selectedDayOrdinal.clamp(1, doc.days.length);
    final day = doc.days.firstWhere((d) => d.ordinal == ordinal);
    final items = doc.items.where((i) => i.dayId == day.id).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final editable = planner.isEditable, generation = planner.editorGeneration;
    return CustomScrollView(
      key: const ValueKey('manual.timeline'),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        SliverToBoxAdapter(
          child: _TimelineDayHeader(
            timeline: this,
            day: day,
            isEmpty: items.isEmpty,
          ),
        ),
        SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, index) => _ActivityRow(
            item: items[index],
            isCurrent: () =>
                planner.isEditable && planner.editorGeneration == generation,
            onEdit: editable ? () => onEdit(items[index]) : null,
            onMove: editable ? () => onMove(items[index]) : null,
            onDelete: editable ? () => onDelete(items[index]) : null,
            onUp: editable && index > 0
                ? () => _reorder(items[index].id, -1, generation)
                : null,
            onDown: editable && index < items.length - 1
                ? () => _reorder(items[index].id, 1, generation)
                : null,
          ),
        ),
        SliverToBoxAdapter(
          child: _TimelineAddButton(timeline: this, day: day),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final TripItem item;
  final bool Function() isCurrent;
  final VoidCallback? onEdit, onUp, onDown, onMove, onDelete;
  const _ActivityRow({
    required this.item,
    required this.isCurrent,
    this.onEdit,
    this.onUp,
    this.onDown,
    this.onMove,
    this.onDelete,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Text(
          manualTimeLabel(item),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(item.title, style: Theme.of(context).textTheme.titleMedium),
        Text(
          item.placeId == null ? 'Tự nhập' : 'Có liên kết địa điểm tham khảo',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (item.notes.isNotEmpty) Text(item.notes),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onEdit,
            child: Tooltip(
              message: 'Sửa: ${item.title}',
              child: const Text('Sửa hoạt động'),
            ),
          ),
        ),
        _ActivityActions(
          item: item,
          isCurrent: isCurrent,
          onUp: onUp,
          onDown: onDown,
          onMove: onMove,
          onDelete: onDelete,
          enabled: onEdit != null,
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _ReorderButton extends StatelessWidget {
  final String label, tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  const _ReorderButton({
    required this.label,
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: tooltip,
    button: true,
    enabled: onPressed != null,
    onTap: onPressed,
    excludeSemantics: true,
    child: Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    ),
  );
}

class _ActivityActions extends StatelessWidget {
  final TripItem item;
  final bool Function() isCurrent;
  final VoidCallback? onUp, onDown, onMove, onDelete;
  final bool enabled;
  const _ActivityActions({
    required this.item,
    required this.isCurrent,
    required this.enabled,
    this.onUp,
    this.onDown,
    this.onMove,
    this.onDelete,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _ReorderButton(
        label: 'Lên',
        tooltip: 'Lên: ${item.title}',
        icon: Icons.arrow_upward,
        onPressed: onUp,
      ),
      _ReorderButton(
        label: 'Xuống',
        tooltip: 'Xuống: ${item.title}',
        icon: Icons.arrow_downward,
        onPressed: onDown,
      ),
      MenuAnchor(
        menuChildren: [
          MenuItemButton(
            onPressed: enabled
                ? () {
                    if (isCurrent()) onMove?.call();
                  }
                : null,
            child: Semantics(
              label: 'Chuyển ngày: ${item.title}',
              excludeSemantics: true,
              child: const Text('Chuyển ngày'),
            ),
          ),
          MenuItemButton(
            onPressed: enabled
                ? () {
                    if (isCurrent()) onDelete?.call();
                  }
                : null,
            child: const Text('Xóa hoạt động'),
          ),
        ],
        builder: (context, controller, child) => TextButton(
          onPressed: enabled
              ? () {
                  if (!isCurrent()) return;
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                }
              : null,
          child: const Text('Thêm thao tác'),
        ),
      ),
    ],
  );
}

class _TimelineDayHeader extends StatelessWidget {
  final ManualItineraryTimeline timeline;
  final TripDay day;
  final bool isEmpty;
  const _TimelineDayHeader({
    required this.timeline,
    required this.day,
    required this.isEmpty,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayNavigation(timeline: timeline, day: day),
        if (day.notes.isNotEmpty) Text(day.notes),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: timeline.planner.isEditable
                ? () => timeline.onEditDayNotes(day)
                : null,
            child: const Text('Sửa ghi chú ngày'),
          ),
        ),
        if (isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Ngày này chưa có hoạt động'),
          ),
      ],
    ),
  );
}

class _DayNavigation extends StatelessWidget {
  final ManualItineraryTimeline timeline;
  final TripDay day;
  const _DayNavigation({required this.timeline, required this.day});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Ngày trước',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: day.ordinal > 1
            ? () => timeline.onSelectDay(day.ordinal - 1)
            : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Tooltip(
          message: 'Chọn ngày',
          child: TextButton(
            onPressed: timeline.onChooseDay,
            child: Text(manualDayLabel(day), textAlign: TextAlign.center),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Ngày sau',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: day.ordinal < (timeline.planner.document?.days.length ?? 0)
            ? () => timeline.onSelectDay(day.ordinal + 1)
            : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _TimelineAddButton extends StatelessWidget {
  final ManualItineraryTimeline timeline;
  final TripDay day;
  const _TimelineAddButton({required this.timeline, required this.day});
  @override
  Widget build(BuildContext context) {
    final count = timeline.planner.document?.items.length ?? 1000;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (count >= 1000)
            const Text('Đã đủ 1000 hoạt động trong chuyến đi.'),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: timeline.planner.isEditable && count < 1000
                ? () => timeline.onAdd(day)
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Thêm hoạt động'),
          ),
        ],
      ),
    );
  }
}

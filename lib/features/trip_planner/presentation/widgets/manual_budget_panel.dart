import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/editable_trip_document.dart';
import '../../providers/manual_planner_provider.dart';
import '../../services/budget_calculator.dart';
import 'manual_expense_form.dart';

class ManualBudgetPanel extends StatelessWidget {
  final ManualPlannerProvider planner;
  final void Function(ManualExpenseKind kind, String? expenseId) onEditExpense;
  final Widget? header;
  const ManualBudgetPanel({
    super.key,
    required this.planner,
    required this.onEditExpense,
    this.header,
  });
  @override
  Widget build(BuildContext context) {
    final doc = planner.document, totals = planner.totals;
    if (doc == null || totals == null) return const SizedBox.shrink();
    final generation = planner.editorGeneration;
    void edit(ManualExpenseKind kind, String? id) {
      if (planner.isEditable && planner.editorGeneration == generation) {
        onEditExpense(kind, id);
      }
    }

    return CustomScrollView(
      key: const ValueKey('manual.budget'),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ManualBudgetSummary(
              totals: totals,
              budget: doc.input.totalBudgetVnd,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _LedgerHeader(
            title: 'Các khoản dự kiến',
            label: 'Thêm khoản dự kiến',
            empty: doc.estimates.isEmpty,
            onAdd: planner.isEditable && doc.estimates.length < 1000
                ? () => edit(ManualExpenseKind.estimate, null)
                : null,
          ),
        ),
        SliverList.builder(
          itemCount: doc.estimates.length,
          itemBuilder: (context, index) => _estimateRow(doc, index, edit),
        ),
        SliverToBoxAdapter(
          child: _LedgerHeader(
            title: 'Các khoản đã chi',
            label: 'Thêm khoản đã chi',
            empty: doc.actualExpenses.isEmpty,
            onAdd: planner.isEditable && doc.actualExpenses.length < 1000
                ? () => edit(ManualExpenseKind.actual, null)
                : null,
          ),
        ),
        SliverList.builder(
          itemCount: doc.actualExpenses.length,
          itemBuilder: (context, index) => _actualRow(doc, index, edit),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _estimateRow(
    EditableTripDocumentV2 doc,
    int index,
    void Function(ManualExpenseKind, String?) edit,
  ) {
    final e = doc.estimates[index];
    return _ExpenseRow(
      title: e.description.isEmpty
          ? manualExpenseCategories[e.category]!
          : e.description,
      detail:
          '${e.active ? 'Đang tính' : 'Ngừng tính'} · ${manualExpenseBases[e.basis]} · ${e.customQuantity ?? BudgetCalculator.multiplier(e, doc)} đơn vị\n'
          '${e.unitAmountVnd == null ? 'Chưa biết đơn giá' : manualMoney(e.unitAmountVnd!)}\n${_link(doc, e.itemId)}',
      label: 'Sửa dự kiến',
      onEdit: planner.isEditable
          ? () => edit(ManualExpenseKind.estimate, e.id)
          : null,
    );
  }

  Widget _actualRow(
    EditableTripDocumentV2 doc,
    int index,
    void Function(ManualExpenseKind, String?) edit,
  ) {
    final e = doc.actualExpenses[index];
    return _ExpenseRow(
      title: e.description.isEmpty
          ? manualExpenseCategories[e.category]!
          : e.description,
      detail:
          '${manualMoney(e.amountVnd)} · ${e.paidOn}\n${_link(doc, e.itemId)}'
          '${e.itemId == null && e.sourceItemSnapshot != null ? '\nHoạt động trước đây: ${e.sourceItemSnapshot!.title}' : ''}',
      label: 'Sửa khoản đã chi',
      onEdit: planner.isEditable
          ? () => edit(ManualExpenseKind.actual, e.id)
          : null,
    );
  }

  static String _link(EditableTripDocumentV2 doc, String? id) => id == null
      ? 'Khoản riêng của chuyến đi'
      : doc.items.firstWhere((i) => i.id == id).title;
}

class ManualBudgetSummary extends StatelessWidget {
  final BudgetTotals totals;
  final int budget;
  const ManualBudgetSummary({
    super.key,
    required this.totals,
    required this.budget,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Ngân sách toàn chuyến: ${manualMoney(budget)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 16),
      _BudgetComparison(budget: budget, totals: totals),
      const SizedBox(height: 24),
      Text('Dự kiến đã biết: ${manualMoney(totals.knownEstimate)}'),
      Text('Còn theo dự kiến: ${manualMoney(totals.estimateRemaining)}'),
      if (totals.estimateRemaining < 0)
        Text(
          'Vượt ngân sách theo dự kiến: ${manualMoney(-totals.estimateRemaining)}',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (totals.unknownEstimateCount > 0)
        Text('Chưa gồm ${totals.unknownEstimateCount} khoản chưa biết giá'),
      const Divider(height: 32),
      Text('Đã chi: ${manualMoney(totals.actualTotal)}'),
      Text('Còn theo đã chi: ${manualMoney(totals.actualRemaining)}'),
      if (totals.actualRemaining < 0)
        Text(
          'Vượt ngân sách theo đã chi: ${manualMoney(-totals.actualRemaining)}',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      const SizedBox(height: 8),
      const Text('Tiền dự kiến và tiền đã chi được theo dõi riêng.'),
    ],
  );
}

class _BudgetComparison extends StatelessWidget {
  final int budget;
  final BudgetTotals totals;
  const _BudgetComparison({required this.budget, required this.totals});
  @override
  Widget build(BuildContext context) {
    final values = [budget, totals.knownEstimate, totals.actualTotal];
    const labels = ['Ngân sách', 'Dự kiến đã biết', 'Đã chi'];
    final scheme = Theme.of(context).colorScheme;
    final colors = [scheme.outline, scheme.primary, scheme.secondary];
    return Column(
      children: [
        Semantics(
          label: 'Biểu đồ so sánh ngân sách, dự kiến đã biết và đã chi. Số tiền chi tiết ở bên dưới.',
          child: ExcludeSemantics(
            child: SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: values.fold<int>(1, (a, b) => a > b ? a : b).toDouble(),
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < values.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: values[i].toDouble(),
                            width: 32,
                            color: colors[i],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                  ],
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                            '${labels[group.x]}\n${manualMoney(values[group.x])}',
                            TextStyle(
                              color: scheme.onInverseSurface,
                              fontSize: 14,
                            ),
                          ),
                    ),
                  ),
                ),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _BudgetLegend(labels: labels, colors: colors),
      ],
    );
  }
}

class _BudgetLegend extends StatelessWidget {
  final List<String> labels;
  final List<Color> colors;
  const _BudgetLegend({required this.labels, required this.colors});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(
          child: Column(
            children: [
              Icon(Icons.square, size: 12, color: colors[i]),
              const SizedBox(height: 4),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
    ],
  );
}

class _LedgerHeader extends StatelessWidget {
  final String title, label;
  final bool empty;
  final VoidCallback? onAdd;
  const _LedgerHeader({
    required this.title,
    required this.label,
    required this.empty,
    this.onAdd,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (empty) const Text('Chưa có khoản nào.'),
        if (!empty && onAdd == null)
          const Text(
            'Không thể thêm khoản trong trạng thái hiện tại hoặc đã đủ 1000 khoản.',
          ),
        if (onAdd != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(label),
            ),
          ),
      ],
    ),
  );
}

class _ExpenseRow extends StatelessWidget {
  final String title, detail, label;
  final VoidCallback? onEdit;
  const _ExpenseRow({
    required this.title,
    required this.detail,
    required this.label,
    this.onEdit,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(detail),
        if (onEdit != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onEdit, child: Text(label)),
          ),
      ],
    ),
  );
}

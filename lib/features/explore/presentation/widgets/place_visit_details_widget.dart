import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/catalogue_reference.dart';
import '../../models/place_visit_details.dart';
import '../../services/place_visit_details_repository.dart';

class VisitCatalogueStatus extends StatelessWidget {
  final VisitSnapshot? snapshot;
  final bool isRefreshing;
  final String? errorCode;
  final VoidCallback? onRefresh;
  const VisitCatalogueStatus({
    super.key,
    required this.snapshot,
    this.isRefreshing = false,
    this.errorCode,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final value = snapshot;
    final origin = switch (value?.origin) {
      'cache' => 'Bản đã lưu trên máy',
      'remote' => 'Đã tải bản cập nhật',
      _ => 'Bản đi kèm ứng dụng',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value == null
              ? 'Chưa có dữ liệu tham quan'
              : '$origin · phiên bản ${value.catalogue.version}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (value?.lastFetchedAt != null)
          Text(
            'Lần tải dữ liệu: ${DateFormat('dd/MM/yyyy HH:mm').format(value!.lastFetchedAt!.toUtc().add(const Duration(hours: 7)))} (giờ Việt Nam)',
          ),
        if (value != null && !value.catalogue.isComplete)
          const Text(
            'Dữ liệu đang hoàn thiện. Xem trạng thái xác minh của từng mục.',
          ),
        if (value?.warningCode == 'cache_unavailable')
          const Text(
            'Chưa đọc được bản lưu trên máy; đang dùng dữ liệu đi kèm.',
          ),
        if (errorCode != null)
          Text(
            value == null
                ? 'Chưa tải được thông tin tham quan.'
                : 'Chưa cập nhật được; đang giữ bản dữ liệu hiện có.',
          ),
        if (isRefreshing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(
              semanticsLabel: 'Đang cập nhật thông tin',
            ),
          ),
        if (onRefresh != null)
          TextButton.icon(
            onPressed: isRefreshing ? null : onRefresh,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.refresh),
            label: const Text('Cập nhật thông tin'),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class PlaceVisitDetailsWidget extends StatelessWidget {
  final PlaceReference place;
  final SourceReference? referenceSource;
  final PlaceVisitDetails? details;
  final VisitSnapshot? snapshot;
  final bool isRefreshing, showReleaseInfo;
  final String? errorCode;
  final VoidCallback? onRefresh;
  final DateTime? now;
  const PlaceVisitDetailsWidget({
    super.key,
    required this.place,
    required this.details,
    required this.snapshot,
    this.referenceSource,
    this.isRefreshing = false,
    this.errorCode,
    this.onRefresh,
    this.showReleaseInfo = true,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final data = details;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showReleaseInfo)
            VisitCatalogueStatus(
              snapshot: snapshot,
              isRefreshing: isRefreshing,
              errorCode: errorCode,
              onRefresh: onRefresh,
            ),
          Text(place.name, style: Theme.of(context).textTheme.titleMedium),
          if (data != null) Text(data.visitScopeLabel),
          const SizedBox(height: 12),
          Text(
            'Giá vé',
            key: ValueKey('visit-price-${place.id}'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ..._price(data),
          const SizedBox(height: 12),
          Text(
            'Giờ tham quan',
            key: ValueKey('visit-hours-${place.id}'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ..._hours(data),
          if (data != null) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              key: ValueKey('visit-conditions-${place.id}'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Điều kiện & phạm vi áp dụng'),
              children: [_lines(_conditions(data))],
            ),
          ],
          ExpansionTile(
            key: ValueKey('visit-source-${place.id}'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Nguồn & ngày kiểm'),
            children: [
              if (data != null) ...[
                _source(context, 'price', 'giá vé', data.price.evidence),
                _source(context, 'hours', 'giờ tham quan', data.hours.evidence),
              ],
              if (referenceSource case final SourceReference source)
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nguồn tên địa điểm: ${source.title} · ${source.publisher}',
                      ),
                      SelectableText(source.url),
                      Text('Ngày kiểm tên/nguồn: ${source.checkedAt.trim().isEmpty ? 'Chưa rõ' : source.checkedAt}'),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
        ],
      ),
    );
  }

  List<Widget> _price(PlaceVisitDetails? data) {
    if (data == null ||
        !data.price.evidence.isReviewed ||
        data.price.status == 'unverified') {
      return [const Text('Chưa xác minh giá vé')];
    }
    final price = data.price;
    return [
      if (price.status == 'bundled')
        const Text(
          'Vé theo gói/tuyến; xem phạm vi, không cộng vé cho từng điểm trong cùng gói.',
        ),
      if (price.status == 'variable') const Text('Giá thay đổi theo điều kiện'),
      for (final option in price.options) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${option.label}: ${option.amountVnd == null
                ? 'Xem điều kiện giá'
                : option.amountVnd == 0
                ? 'Miễn phí'
                : '${NumberFormat.decimalPattern('vi_VN').format(option.amountVnd)} ₫'} / ${option.unit}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text('Áp dụng: ${option.audience}'),
      ],
    ];
  }

  List<Widget> _hours(PlaceVisitDetails? data) {
    if (data == null ||
        !data.hours.evidence.isReviewed ||
        data.hours.status == 'unverified') {
      return [const Text('Chưa xác minh giờ tham quan')];
    }
    final hours = data.hours;
    return [
      if (hours.status == 'temporarily_closed')
        const Text('Tạm đóng cửa theo nguồn'),
      if (hours.status == 'event_based')
        const Text('Theo lịch chương trình/sự kiện'),
      if (hours.status == 'no_fixed_hours')
        const Text('Không có khung giờ tham quan cố định theo nguồn'),
      for (final rule in hours.rules) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${rule.label}${rule.seasonStart == null ? '' : ' · ${_monthDay(rule.seasonStart!)}–${_monthDay(rule.seasonEnd!)}'}',
          ),
        ),
        Text(
          '${_weekdays(rule.weekdays)}: ${_time(rule.startMinutes)}–${_time(rule.endMinutes)}${rule.endDayOffset == 1 ? ' (ngày hôm sau)' : ''}',
        ),
        if (rule.effectiveFrom != null || rule.effectiveTo != null)
          Text(
            'Thời gian áp dụng: ${_date(rule.effectiveFrom)} – ${_date(rule.effectiveTo)}',
          ),
        if (rule.admissionCutoffMinutes != null)
          Text('Nhận khách cuối: ${_time(rule.admissionCutoffMinutes!)}'),
        if (rule.lastReturnMinutes != null)
          Text('Chuyến về cuối: ${_time(rule.lastReturnMinutes!)}'),
      ],
      for (final note in hours.notes)
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(note)),
    ];
  }

  List<String> _conditions(PlaceVisitDetails data) => [
    ...data.notes,
    ...data.price.evidence.conditions,
    ...data.hours.evidence.conditions,
    for (final option in data.price.options) ...[
      ...option.conditions.map((c) => '${option.label}: $c'),
      if (option.included.isNotEmpty)
        '${option.label} · Bao gồm: ${option.included.join('; ')}',
      if (option.excluded.isNotEmpty)
        '${option.label} · Không gồm: ${option.excluded.join('; ')}',
    ],
    for (final id
        in data.price.options
            .map((o) => o.packageId)
            .whereType<String>()
            .toSet())
      if (snapshot?.catalogue.packages[id] case final VisitPackage package) ...[
        '${package.label}: ${package.scope}',
        ...package.conditions,
        if (package.included.isNotEmpty)
          'Gói bao gồm: ${package.included.join('; ')}',
        if (package.excluded.isNotEmpty)
          'Gói không gồm: ${package.excluded.join('; ')}',
      ],
    ...data.price.evidence.unresolvedIssues,
    ...data.hours.evidence.unresolvedIssues,
  ];

  Widget _lines(List<String> lines) => SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines.toSet())
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line)),
        if (lines.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Chưa có điều kiện bổ sung từ nguồn.'),
          ),
      ],
    ),
  );

  Widget _source(
    BuildContext context,
    String field,
    String label,
    VisitEvidence evidence,
  ) => SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nguồn $label', style: Theme.of(context).textTheme.titleSmall),
          Text(
            'Kiểm nguồn: ${_date(evidence.checkedAt)}${evidence.isReviewed ? '' : ' · Chưa xác minh'}',
          ),
          if (evidence.needsReview(now ?? DateTime.now()))
            Text(
              'Thông tin cần kiểm tra lại',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (evidence.sourceIds.isEmpty)
            const Text('Chưa có nguồn xác minh cho mục này.'),
          for (final id in evidence.sourceIds)
            if (snapshot?.catalogue.sources[id]
                case final VisitSource source) ...[
              Text('${source.title} · ${source.publisher}'),
              SelectableText(source.url),
              TextButton.icon(
                key: ValueKey('copy-source-${place.id}-$field-$id'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: source.url));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép đường dẫn nguồn'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined),
                label: Text('Sao chép nguồn $label'),
              ),
            ],
        ],
      ),
    ),
  );

  static String _date(DateTime? value) => value == null
      ? 'Chưa có ngày kiểm'
      : DateFormat('dd/MM/yyyy').format(value);
  static String _time(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  static String _monthDay(String value) =>
      '${value.substring(3)}/${value.substring(0, 2)}';
  static String _weekdays(List<int> days) => days.length == 7
      ? 'Hằng ngày'
      : days.map((d) => d == 7 ? 'Chủ nhật' : 'Thứ ${d + 1}').join(', ');
}

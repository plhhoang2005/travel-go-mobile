import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../trips/models/trip_evidence_envelope.dart';
import '../../services/evidence_source_launcher.dart';

Future<void> showTripEvidence(
  BuildContext context,
  TripEvidenceEnvelope envelope, {
  Listenable? authority,
  bool Function()? isCurrent,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => EvidenceDetailsSheet(
    records: envelope.evidence,
    claim: envelope.claims.isEmpty
        ? EvidenceClaim(
            id: 'display-only',
            text: 'Nguồn của chuyến đi; chưa có nhận định được liên kết.',
            kind: ClaimKind.unknown,
            evidenceIds: const [],
          )
        : envelope.claims.first,
    claims: envelope.claims,
    authority: authority,
    isCurrent: isCurrent,
  ),
);

class EvidenceDetailsSheet extends StatefulWidget {
  final List<EvidenceRecord> records;
  final EvidenceClaim claim;
  final List<EvidenceClaim> claims;
  final Future<bool> Function(Uri)? openSource;
  final Listenable? authority;
  final bool Function()? isCurrent;
  const EvidenceDetailsSheet({
    super.key,
    required this.records,
    required this.claim,
    this.claims = const [],
    this.openSource,
    this.authority,
    this.isCurrent,
  });
  @override
  State<EvidenceDetailsSheet> createState() => _EvidenceDetailsSheetState();
}

class _EvidenceDetailsSheetState extends State<EvidenceDetailsSheet> {
  String? _error;
  bool _opening = false;
  bool get _current => widget.isCurrent?.call() ?? true;
  @override
  void initState() {
    super.initState();
    widget.authority?.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant EvidenceDetailsSheet old) {
    super.didUpdateWidget(old);
    if (old.authority != widget.authority) {
      old.authority?.removeListener(_refresh);
      widget.authority?.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.authority?.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _open(EvidenceRecord record) async {
    final url = record.url;
    if (!_current || _opening || url == null) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    var opened = false;
    try {
      opened = await (widget.openSource ?? openEvidenceSource)(url);
    } on Object {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (_current && !opened) {
        _error = 'Không mở được nguồn. Bạn có thể sao chép liên kết.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_current) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Phiên chuyến đi đã thay đổi.'),
        ),
      );
    }
    final claims = widget.claims.isEmpty ? [widget.claim] : widget.claims;
    final ids = widget.records.map((r) => r.id).toSet();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Xem căn cứ',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng căn cứ',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              for (final claim in claims) ...[
                const SizedBox(height: 16),
                Text(switch (claim.kind) {
                  ClaimKind.fact => 'Dữ kiện có nguồn',
                  ClaimKind.inference => 'Suy luận',
                  ClaimKind.unknown => 'Chưa đủ căn cứ',
                }, style: Theme.of(context).textTheme.titleSmall),
                Text(claim.text),
                if (claim.evidenceIds.any((id) => !ids.contains(id)))
                  const Text('Một số nguồn không còn khả dụng.'),
              ],
              if (widget.records.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Chưa có nguồn được lưu cho nội dung này.'),
                ),
              for (final record in widget.records) ...[
                const Divider(height: 32),
                Text(
                  record.title ?? 'Nguồn chưa có tiêu đề',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(switch (record.origin) {
                  EvidenceOrigin.web =>
                    'Thông tin từ Internet, chưa được Admin kiểm duyệt',
                  EvidenceOrigin.user =>
                    'Thông tin do người dùng nhập, chưa được xác minh',
                  EvidenceOrigin.catalogue =>
                    record.reviewed
                        ? 'Catalogue • Được đánh dấu kiểm duyệt'
                        : 'Catalogue • Chưa được kiểm duyệt',
                }),
                Text('Đơn vị cung cấp: ${record.publisher ?? 'Chưa rõ'}'),
                const SizedBox(height: 8),
                Text(
                  record.factKey,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  record.factValue.isEmpty
                      ? 'Chưa rõ dữ kiện'
                      : record.factValue,
                ),
                const SizedBox(height: 8),
                Text('Truy xuất: ${record.retrievedAt ?? 'Chưa rõ'}'),
                Text('Ngày kiểm tra: ${record.checkedAt ?? 'Chưa rõ'}'),
                Text('Ngày xuất bản: ${record.publishedAt ?? 'Chưa rõ'}'),
                if (record.effectiveFrom != null || record.effectiveTo != null)
                  Text(
                    'Hiệu lực: ${record.effectiveFrom ?? 'Chưa rõ'} – ${record.effectiveTo ?? 'Chưa rõ'}',
                  ),
                if (record.url != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(record.toJson()['url'] as String),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _opening ? null : () => _open(record),
                        child: const Text('Mở nguồn'),
                      ),
                      TextButton(
                        onPressed: () => _current
                            ? Clipboard.setData(
                                ClipboardData(
                                  text: record.toJson()['url'] as String,
                                ),
                              )
                            : null,
                        child: const Text('Sao chép liên kết'),
                      ),
                    ],
                  ),
                ],
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

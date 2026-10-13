import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../providers/guest_drafts_provider.dart';
import '../../providers/saved_trips_provider.dart';
import '../../services/guest_import_service.dart';

/// Explicit, owner-bound consent surface. Opening or reloading never imports.
class GuestDraftImportSheet extends StatefulWidget {
  final GuestDraftsProvider drafts;
  final String expectedOwnerId;

  const GuestDraftImportSheet({
    super.key,
    required this.drafts,
    required this.expectedOwnerId,
  });

  @override
  State<GuestDraftImportSheet> createState() => _GuestDraftImportSheetState();
}

class _GuestDraftImportSheetState extends State<GuestDraftImportSheet> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.drafts.reload());
    });
  }

  bool _sameOwner(AuthProvider auth) =>
      auth.isAuthenticated &&
      !auth.isDemoSession &&
      auth.currentUser?.id == widget.expectedOwnerId &&
      widget.drafts.currentOwnerId == widget.expectedOwnerId;

  Future<bool> _confirm(AuthProvider auth, String action, String detail) async {
    if (!_sameOwner(auth)) return false;
    final email = auth.currentUser!.email;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action),
        content: Text(
          '$detail\nTài khoản nhận: $email (${widget.expectedOwnerId}). '
          'Bản nháp chưa được xác nhận vẫn ở trên máy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    return approved == true && mounted && _sameOwner(auth);
  }

  Future<void> _import(AuthProvider auth) async {
    if (_busy ||
        widget.drafts.isImporting ||
        widget.drafts.selectedSources.isEmpty ||
        !_sameOwner(auth)) {
      return;
    }
    final count = widget.drafts.selectedSources.length;
    if (!await _confirm(
      auth,
      'Chuyển $count bản nháp?',
      'Chỉ chuyển các bản nháp bạn đã chọn.',
    )) {
      return;
    }
    if (!mounted || !_sameOwner(auth)) return;
    setState(() => _busy = true);
    try {
      final outcomes = await widget.drafts.confirmAndImport();
      if (!mounted || !_sameOwner(auth)) return;
      if (outcomes.any(
        (outcome) =>
            outcome.status == GuestImportStatus.committed ||
            outcome.status == GuestImportStatus.alreadyCommitted,
      )) {
        try {
          await context.read<SavedTripsProvider>().loadTrips(
            widget.expectedOwnerId,
          );
        } catch (_) {
          // Import receipt is already authoritative; list refresh is separate.
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry(AuthProvider auth, ImportSource source) async {
    if (_busy || widget.drafts.isImporting || !_sameOwner(auth)) return;
    if (!await _confirm(
      auth,
      'Thử lại bản nháp ${source.draftId}?',
      'Thử lại yêu cầu cũ; nếu server đã nhận, app sẽ đối chiếu kết quả cũ.',
    )) {
      return;
    }
    if (!mounted || !_sameOwner(auth)) return;
    setState(() => _busy = true);
    try {
      final outcome = await widget.drafts.retry(source);
      if (!mounted || !_sameOwner(auth)) return;
      if (outcome.status == GuestImportStatus.committed ||
          outcome.status == GuestImportStatus.alreadyCommitted) {
        try {
          await context.read<SavedTripsProvider>().loadTrips(
            widget.expectedOwnerId,
          );
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _outcomeLabel(GuestImportOutcome outcome) => switch (outcome.status) {
    GuestImportStatus.committed => 'Đã chuyển sau xác nhận của server.',
    GuestImportStatus.alreadyCommitted =>
      'Đã chuyển trước đó; không tạo trùng.',
    GuestImportStatus.pendingRetry =>
      'Chưa nhận được xác nhận; bản nháp vẫn ở trên máy.',
    GuestImportStatus.deletedNeedsAttention =>
      'Chuyến đi đã bị xóa; giữ bản nháp để bạn xử lý.',
    GuestImportStatus.deploymentBlocked =>
      'Máy chủ chưa hỗ trợ chuyển bản nháp.',
    GuestImportStatus.rejected => outcome.reason ?? 'Chưa thể chuyển bản nháp.',
    GuestImportStatus.sessionInvalidated =>
      'Phiên tài khoản đã thay đổi; chưa chuyển bản nháp.',
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return AnimatedBuilder(
      animation: Listenable.merge([auth, widget.drafts]),
      builder: (context, _) {
        final sameOwner = _sameOwner(auth);
        final provider = widget.drafts;
        final available = provider.drafts;
        final pending = provider.attempts
            .where(
              (attempt) =>
                  attempt.state == 'staged' ||
                  attempt.state == 'pending_ack' ||
                  attempt.state == 'quarantined',
            )
            .toList();
        return PopScope(
          canPop: !_busy,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.78,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Chuyển bản nháp Guest',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (!sameOwner)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Tài khoản đã thay đổi. Đóng cửa sổ này rồi đăng nhập lại.',
                        ),
                      )
                    else ...[
                      Text('Tài khoản nhận: ${auth.currentUser!.email}'),
                      const SizedBox(height: 8),
                      const Text(
                        'Chọn từng bản nháp. App không tự chuyển khi đăng nhập.',
                      ),
                      if (provider.isLoading) const LinearProgressIndicator(),
                      if (provider.errorMessage != null)
                        Text(
                          provider.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      Expanded(
                        child: ListView(
                          children: [
                            if (!provider.isLoading && available.isEmpty)
                              const ListTile(
                                title: Text(
                                  'Chưa có bản nháp Guest để chuyển.',
                                ),
                              ),
                            for (final draft in available)
                              Builder(
                                builder: (context) {
                                  final source = provider.sourceFor(draft);
                                  return CheckboxListTile(
                                    title: Text(draft.title ?? 'Bản nháp'),
                                    subtitle: Text(
                                      '${draft.destinationName ?? 'Điểm đến chưa rõ'} · phiên bản ${draft.currentRevision}',
                                    ),
                                    value:
                                        source != null &&
                                        provider.selectedSources.contains(
                                          source,
                                        ),
                                    onChanged:
                                        source == null ||
                                            _busy ||
                                            provider.isImporting
                                        ? null
                                        : (value) => provider.select(
                                            source,
                                            value == true,
                                          ),
                                  );
                                },
                              ),
                            if (pending.isNotEmpty)
                              const ListTile(
                                title: Text('Lần chuyển cần kiểm tra'),
                              ),
                            for (final attempt in pending)
                              ListTile(
                                title: Text(
                                  '${attempt.draftId} · phiên bản ${attempt.sourceRevision}',
                                ),
                                subtitle: Text(
                                  'Trạng thái: ${attempt.state}; bản nháp vẫn được giữ.',
                                ),
                                trailing: TextButton(
                                  onPressed: _busy || provider.isImporting
                                      ? null
                                      : () => _retry(
                                          auth,
                                          ImportSource(
                                            deviceScope: attempt.deviceScope,
                                            draftId: attempt.draftId,
                                            revision: attempt.sourceRevision,
                                            digest: attempt.contentDigest,
                                          ),
                                        ),
                                  child: const Text('Thử lại'),
                                ),
                              ),
                            for (final outcome in provider.outcomes)
                              ListTile(
                                title: Text(
                                  'Bản nháp ${outcome.source.draftId}',
                                ),
                                subtitle: Text(_outcomeLabel(outcome)),
                              ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed:
                            _busy ||
                                provider.isImporting ||
                                provider.selectedSources.isEmpty
                            ? null
                            : () => _import(auth),
                        child: Text(
                          'Chuyển ${provider.selectedSources.length} bản nháp đã chọn',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../main.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../explore/models/catalogue_reference.dart' as catalogue;
import '../../../explore/services/catalogue_repository.dart';
import '../../../trip_planner/models/editable_trip_document.dart';
import '../../../trip_planner/models/trip_request.dart';
import '../../../trip_planner/presentation/screens/manual_planner_screen.dart';
import '../../../trip_planner/presentation/widgets/manual_expense_form.dart';
import '../../../trip_planner/providers/manual_planner_provider.dart';
import '../../../trip_planner/services/budget_calculator.dart';
import '../../models/editable_remote_records.dart';
import '../../models/local_trip_records.dart';
import '../../models/trip_payload_codec.dart';
import '../../providers/saved_trips_provider.dart';
import '../../services/editable_trip_service.dart';
import '../../services/legacy_trip_copy_adapter.dart';
import '../../services/local_account_lifecycle_service.dart';

bool _owner(BuildContext context, String id) {
  final auth = context.read<AuthProvider>();
  return auth.isAuthenticated &&
      !auth.isDemoSession &&
      auth.currentUser?.id == id &&
      context.read<SavedTripsProvider>().currentUserId == id;
}

/// Replacing the shared editor requires a separate confirmation for dirty work.
Future<bool> confirmManualReplacement(
  BuildContext context,
  ManualPlannerProvider planner,
  bool Function() current,
) async {
  if (!current() || planner.isSaving || planner.hasPendingSave) return false;
  if (planner.document == null || !planner.dirty) return true;
  final generation = planner.editorGeneration, draftId = planner.draftId;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Thay bản chỉnh sửa đang mở?'),
      content: const Text(
        'Các thay đổi chưa lưu sẽ bị bỏ. Bản đã lưu vẫn được giữ.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Giữ bản đang sửa'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Thay bản chỉnh sửa'),
        ),
      ],
    ),
  );
  return context.mounted &&
      current() &&
      accepted == true &&
      planner.editorGeneration == generation &&
      planner.draftId == draftId &&
      !planner.isSaving &&
      !planner.hasPendingSave;
}

class EditableTripDetailScreen extends StatefulWidget {
  final String tripId, expectedOwnerId;
  const EditableTripDetailScreen({
    super.key,
    required this.tripId,
    required this.expectedOwnerId,
  });
  @override
  State<EditableTripDetailScreen> createState() =>
      _EditableTripDetailScreenState();
}

class _EditableTripDetailScreenState extends State<EditableTripDetailScreen> {
  ManualPlannerResources? _resources;
  AccountSessionProof? _proof;
  EditableTripView? _view;
  String? _error;
  bool _started = false, _busy = false, _deleted = false, _conflict = false;
  int _generation = 0;
  bool get _current =>
      mounted &&
      _owner(context, widget.expectedOwnerId) &&
      (_proof == null ||
          _resources?.repository.lifecycle.isCurrentProof(_proof!) == true);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    if (!_current || _busy) return;
    final generation = ++_generation;
    final epoch = context.read<SavedTripsProvider>().sessionEpoch;
    setState(() {
      _busy = true;
      _error = null;
      _view = null;
    });
    try {
      final bundle = await context.read<ManualPlannerRuntime>().getResources();
      if (!mounted ||
          !_current ||
          epoch != context.read<SavedTripsProvider>().sessionEpoch) {
        return;
      }
      final proof = bundle.repository.lifecycle.captureProof();
      if (proof.ownerId != widget.expectedOwnerId) return;
      setState(() {
        _resources = bundle;
        _proof = proof;
      });
      final view = await bundle.repository.readTrip(widget.tripId);
      if (!_current || generation != _generation) return;
      if (view.head != null &&
          (view.head!.ownerId != proof.ownerId ||
              view.head!.tripId != widget.tripId)) {
        throw StateError('Trip identity changed');
      }
      setState(() {
        _view = view;
        _conflict = false;
      });
    } catch (error) {
      if (_current) setState(() => _error = _failure(error));
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  String _failure(Object error) {
    if (error is EditableRemoteException) {
      if (error.code == 'unauthorized') {
        _resources?.repository.lifecycle.invalidateAccountContext();
        return 'Phiên đăng nhập cần được kiểm tra lại.';
      }
      if (error.kind == EditableRemoteFailure.deploymentBlocked) {
        return 'Chức năng lịch trình tự lập chưa sẵn sàng trên máy chủ.';
      }
      if (error.code == 'version_conflict') {
        return 'Chuyến đi đã thay đổi ở nơi khác. Tải lại để xem bản mới; chưa xóa chuyến đi.';
      }
      if (error.kind == EditableRemoteFailure.uncertain) {
        return 'Chưa xác nhận được kết quả xóa. Kiểm tra lại chuyến trước khi thao tác tiếp.';
      }
    }
    return 'Không thể kiểm tra chuyến đi an toàn. Hãy thử lại.';
  }

  Future<void> _edit() async {
    final bundle = _resources, view = _view;
    if (!_current ||
        _busy ||
        _conflict ||
        bundle == null ||
        view?.state != EditableTripViewState.online) {
      return;
    }
    setState(() => _busy = true);
    try {
      final catalogue = await CatalogueRepository().load();
      if (!mounted ||
          !_current ||
          !await confirmManualReplacement(
            context,
            bundle.planner,
            () => _current,
          )) {
        return;
      }
      if (!mounted || !_current) return;
      bundle.planner.openSaved(view!);
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ManualPlannerScreen(
            planner: bundle.planner,
            destinations: catalogue.destinations,
            enableBudget: true,
          ),
        ),
      );
    } catch (error) {
      if (_current) setState(() => _error = _failure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (_current) await _load();
  }

  Future<void> _delete() async {
    final base = _view?.head, bundle = _resources;
    if (!_current ||
        _busy ||
        _conflict ||
        base == null ||
        bundle == null ||
        _view?.state != EditableTripViewState.online) {
      return;
    }
    final generation = _generation;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Xóa toàn bộ chuyến đi?'),
        content: const Text(
          'Lịch trình, các khoản dự kiến và toàn bộ chi thực tế của chuyến sẽ bị xóa khỏi tài khoản và bản lưu trên máy. Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Giữ chuyến đi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xóa toàn bộ chuyến'),
          ),
        ],
      ),
    );
    if (accepted != true || !_current || generation != _generation || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await bundle.repository.deleteTrip(base);
      if (!mounted || !_current) return;
      if (result.status != EditableMutationStatus.deleted) {
        throw StateError('Deletion unconfirmed');
      }
      final planner = bundle.planner;
      if (planner.currentOwnerId == base.ownerId &&
          planner.baseHead?.tripId == base.tripId) {
        planner.invalidate();
      }
      setState(() {
        _deleted = true;
        _view = null;
      });
      await context.read<SavedTripsProvider>().loadTrips(
        widget.expectedOwnerId,
      );
      if (mounted && _current) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa chuyến đi và sổ chi.')),
        );
      }
    } catch (error) {
      if (_current) {
        setState(() {
          _error = _failure(error);
          _conflict = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    context.watch<SavedTripsProvider>();
    final lifecycle = _resources?.repository.lifecycle;
    if (lifecycle == null) return _build(context);
    return ListenableBuilder(
      listenable: lifecycle,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    if (!_current) {
      return const _DetailMessage(
        'Phiên đã thay đổi. Quay lại danh sách chuyến đi.',
      );
    }
    if (_deleted) return const _DetailMessage('Đã xóa chuyến đi và sổ chi.');
    final view = _view, head = view?.head;
    if (head == null) {
      return _DetailMessage(
        _busy
            ? 'Đang tải lịch trình…'
            : _error ?? 'Không có bản lưu khả dụng cho chuyến đi này.',
        loading: _busy,
        onRetry: _busy ? null : _load,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch trình tự lập')),
      body: SafeArea(
        child: _SavedDocument(
          document: head.document,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                view!.state == EditableTripViewState.cachedReadOnly
                    ? 'Ngoại tuyến · bản trên máy chỉ đọc'
                    : 'Đã kiểm tra với máy chủ · phiên bản ${head.version}',
              ),
              Text(
                'Lấy lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(head.fetchedAt.toLocal())}',
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        !_busy &&
                            !_conflict &&
                            view.state == EditableTripViewState.online
                        ? _edit
                        : null,
                    child: const Text('Chỉnh sửa lịch trình'),
                  ),
                  OutlinedButton(
                    onPressed:
                        !_busy &&
                            !_conflict &&
                            view.state == EditableTripViewState.online
                        ? _delete
                        : null,
                    child: const Text('Xóa chuyến và sổ chi'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: Text(_busy ? 'Đang xử lý…' : 'Kiểm tra lại'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  final String message;
  final bool loading;
  final VoidCallback? onRetry;
  const _DetailMessage(this.message, {this.loading = false, this.onRetry});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch trình đã lưu')),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) const CircularProgressIndicator(),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Lazily renders every saved activity and ledger entry, including unlinked actuals.
class _SavedDocument extends StatefulWidget {
  final EditableTripDocumentV2 document;
  final Widget header;
  const _SavedDocument({required this.document, required this.header});
  @override
  State<_SavedDocument> createState() => _SavedDocumentState();
}

class _SavedDocumentState extends State<_SavedDocument> {
  String _section = 'Lịch trình';
  List<Widget Function()> _rows(EditableTripDocumentV2 doc) {
    final rows = <Widget Function()>[];
    if (_section == 'Lịch trình') {
      for (final day in doc.days) {
        rows.add(
          () => ListTile(
            title: Text(
              'Ngày ${day.ordinal} · ${day.date ?? 'Chưa chọn ngày'}',
            ),
            subtitle: day.notes.isEmpty ? null : Text(day.notes),
          ),
        );
        final items = doc.items.where((item) => item.dayId == day.id).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
        if (items.isEmpty) {
          rows.add(() => const ListTile(title: Text('Chưa có hoạt động.')));
        }
        for (final item in items) {
          rows.add(
            () => ListTile(
              title: Text(item.title),
              subtitle: Text(
                '${_time(item.startMinute)} – ${_time(item.endMinute)}\n${item.notes}',
              ),
            ),
          );
        }
      }
    } else if (_section == 'Dự kiến') {
      for (final e in doc.estimates) {
        rows.add(
          () => ListTile(
            title: Text(
              e.description.isEmpty
                  ? manualExpenseCategories[e.category]!
                  : e.description,
            ),
            subtitle: Text(
              '${manualExpenseCategories[e.category]} · ${manualExpenseBases[e.basis]} · ${BudgetCalculator.multiplier(e, doc)} đơn vị\n${e.active ? 'Đang tính' : 'Ngừng tính'}',
            ),
            trailing: Text(
              e.unitAmountVnd == null
                  ? 'Chưa biết giá'
                  : manualMoney(e.unitAmountVnd!),
            ),
          ),
        );
      }
    } else {
      for (final e in doc.actualExpenses) {
        rows.add(
          () => ListTile(
            title: Text(
              e.description.isEmpty
                  ? manualExpenseCategories[e.category]!
                  : e.description,
            ),
            subtitle: Text(
              '${e.paidOn} · ${manualExpenseCategories[e.category]}\n${e.itemId == null ? 'Không gắn hoạt động' : e.sourceItemSnapshot?.title ?? 'Có hoạt động liên quan'}',
            ),
            trailing: Text(manualMoney(e.amountVnd)),
          ),
        );
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document,
        totals = BudgetCalculator.calculate(widget.document);
    final rows = _rows(doc);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  doc.input.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${doc.input.destinationName ?? 'Chưa chọn điểm đến'} · ${doc.days.length} ngày · ${doc.input.travelerCount} người',
                ),
                Text('Xuất phát: ${doc.input.origin}'),
                Text(
                  'Ngày đi: ${doc.input.startDate ?? 'Chưa rõ'} – ${doc.input.endDate ?? 'Chưa rõ'}',
                ),
                if (doc.source.kind == 'manual_v1_copy')
                  const Text('Bản sao từ chuyến cũ · bản gốc được giữ nguyên'),
                const SizedBox(height: 16),
                widget.header,
                const Divider(height: 32),
                Text('Ngân sách: ${manualMoney(doc.input.totalBudgetVnd)}'),
                Text(
                  'Dự kiến đã biết: ${manualMoney(totals.knownEstimate)} · ${totals.unknownEstimateCount} khoản chưa biết giá',
                ),
                Text('Đã chi: ${manualMoney(totals.actualTotal)}'),
                Text(
                  'Còn theo dự kiến: ${manualMoney(totals.estimateRemaining)}',
                ),
                Text(
                  'Còn sau chi thực tế: ${manualMoney(totals.actualRemaining)}',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final section in [
                      'Lịch trình',
                      'Dự kiến',
                      'Chi thực tế',
                    ])
                      ChoiceChip(
                        label: Text(section),
                        selected: _section == section,
                        onSelected: (_) => setState(() => _section = section),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (rows.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chưa có khoản chi trong mục này.'),
            ),
          ),
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) => rows[index](),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  String _time(int? minute) => minute == null
      ? 'Chưa rõ giờ'
      : '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
}

/// Previewing and canceling never writes a trip or mutates the V1 snapshot.
class LegacyTripCopyScreen extends StatefulWidget {
  final AccountTripSnapshotRecord snapshot;
  const LegacyTripCopyScreen({super.key, required this.snapshot});
  @override
  State<LegacyTripCopyScreen> createState() => _LegacyTripCopyScreenState();
}

class _LegacyTripCopyScreenState extends State<LegacyTripCopyScreen> {
  ManualPlannerResources? _resources;
  AccountSessionProof? _proof;
  catalogue.CatalogueReference? _catalogue;
  LegacyCopyPreview? _preview;
  String? _destination, _error;
  final _inputFields = <String, TextEditingController>{
    for (final name in ['origin', 'days', 'travelers', 'budget'])
      name: TextEditingController(),
  };
  PlanTripRequest? _inputOverride;
  @override
  void dispose() {
    for (final field in _inputFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _checkInput() {
    final origin = _inputFields['origin']!.text.trim();
    final days = int.tryParse(_inputFields['days']!.text);
    final people = int.tryParse(_inputFields['travelers']!.text);
    final budget = int.tryParse(_inputFields['budget']!.text);
    setState(() {
      if (origin.isEmpty ||
          days == null ||
          days < 1 ||
          days > 366 ||
          people == null ||
          people < 1 ||
          people > 1000 ||
          budget == null ||
          budget < 0) {
        _error = 'Nhập nơi xuất phát, 1–366 ngày, số người và ngân sách VND nguyên không âm.';
        _inputOverride = null;
      } else {
        _inputOverride = PlanTripRequest(
          origin: origin,
          numDays: days,
          numPeople: people,
          budgetVnd: budget,
          preferences: [],
          priority: 'balanced',
        );
        _error = null;
      }
      _makePreview();
    });
  }

  bool _started = false, _busy = false;
  bool get _current =>
      mounted &&
      _owner(context, widget.snapshot.ownerId) &&
      context.read<SavedTripsProvider>().accountSnapshots.any(
        (s) =>
            s.tripId == widget.snapshot.tripId &&
            s.digest == widget.snapshot.digest,
      ) &&
      (_proof == null ||
          _resources?.repository.lifecycle.isCurrentProof(_proof!) == true);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    if (!_current) return;
    setState(() => _busy = true);
    try {
      final bundle = await context.read<ManualPlannerRuntime>().getResources();
      if (!_current) return;
      final proof = bundle.repository.lifecycle.captureProof();
      if (proof.ownerId != widget.snapshot.ownerId) return;
      final catalog = await CatalogueRepository().load();
      if (!_current || !bundle.repository.lifecycle.isCurrentProof(proof)) {
        return;
      }
      setState(() {
        _resources = bundle;
        _proof = proof;
        _catalogue = catalog;
        _makePreview();
      });
    } catch (_) {
      if (_current) {
        setState(() => _error = 'Không mở được bản sao. Bản gốc vẫn được giữ.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _makePreview() {
    final snapshot = widget.snapshot,
        metadata = snapshot.cachedPayload.metadata;
    final destination = _destination == null
        ? null
        : _catalogue!.destinations.firstWhere((d) => d.id == _destination);
    _preview = LegacyTripCopyAdapter().preview(
      snapshot.cachedPayload,
      sourceTripId: snapshot.tripId,
      sourceDigest: snapshot.digest,
      inputOverride: _inputOverride,
      metadataOverride: destination == null
          ? null
          : TripMetadataV1(
              title: metadata.title,
              destinationId: destination.id,
              destinationName: destination.name,
              startDate: metadata.startDate,
              endDate: metadata.endDate,
              timezone: metadata.timezone,
            ),
    );
  }

  Future<void> _open() async {
    final bundle = _resources, preview = _preview;
    if (!_current || _busy || bundle == null || preview?.canProceed != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (!mounted ||
          !await confirmManualReplacement(
            context,
            bundle.planner,
            () => _current,
          ) ||
          !_current) {
        return;
      }
      if (!mounted || !_current) {
        return;
      }
      bundle.planner.openNew(
        preview!.document!,
        source: SourceBinding.copy(
          sourceTripId: widget.snapshot.tripId,
          sourceDigest: widget.snapshot.digest,
        ),
      );
      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) => ManualPlannerScreen(
            planner: bundle.planner,
            destinations: _catalogue!.destinations,
            enableBudget: true,
          ),
        ),
      );
    } catch (_) {
      if (_current) {
        setState(
          () => _error = 'Không mở được bản chỉnh sửa. Bản gốc vẫn được giữ.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    context.watch<SavedTripsProvider>();
    final lifecycle = _resources?.repository.lifecycle;
    return lifecycle == null
        ? _build(context)
        : ListenableBuilder(
            listenable: lifecycle,
            builder: (context, _) => _build(context),
          );
  }

  Widget _build(BuildContext context) {
    if (!_current) {
      return const _DetailMessage(
        'Phiên hoặc bản gốc đã thay đổi. Quay lại danh sách chuyến đi.',
      );
    }
    final preview = _preview, doc = preview?.document;
    return Scaffold(
      appBar: AppBar(title: const Text('Xem lại bản sao')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('copy.preview'),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Bản sao là lịch trình mới. Chỉ lưu sau khi bạn xem lại và xác nhận; bản gốc được giữ nguyên.',
            ),
            const Text(
              'Sao chép hoạt động và ước tính cũ; không sao chép chi thực tế hoặc cộng lại tổng phân bổ.',
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (widget.snapshot.cachedPayload.request == null)
              _CopyInputFields(
                fields: _inputFields,
                busy: _busy,
                onChanged: () => setState(() {
                  _preview = null;
                  _inputOverride = null;
                }),
                onCheck: _checkInput,
              ),
            if ((preview?.needsDestination == true || _destination != null) &&
                _catalogue != null)
              DropdownButtonFormField<String>(
                key: const ValueKey('copy.destination'),
                initialValue: _destination,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Chọn điểm đến cho bản sao',
                ),
                items: [
                  for (final d in _catalogue!.destinations)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: _busy
                    ? null
                    : (id) => setState(() {
                        _destination = id;
                        _makePreview();
                      }),
              ),
            for (final issue in preview?.issues ?? [])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(issue.message),
              ),
            if (doc != null) ...[
              Text(
                '${doc.days.length} ngày · ${doc.items.length} hoạt động · ${doc.estimates.length} khoản dự kiến',
              ),
              const Text('Chi thực tế của bản sao: 0 khoản'),
              for (final item in doc.items)
                ListTile(title: Text(item.title), subtitle: Text(item.notes)),
              for (final estimate in doc.estimates)
                ListTile(
                  title: Text(estimate.description),
                  subtitle: Text(
                    estimate.unitAmountVnd == null
                        ? 'Chưa biết giá'
                        : manualMoney(estimate.unitAmountVnd!),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: !_busy && preview?.canProceed == true ? _open : null,
              child: Text(_busy ? 'Đang mở…' : 'Mở bản sao để chỉnh sửa'),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Hủy bản sao'),
            ),
            if (_error != null)
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Thử lại'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CopyInputFields extends StatelessWidget {
  final Map<String, TextEditingController> fields;
  final bool busy;
  final VoidCallback onChanged, onCheck;
  const _CopyInputFields({
    required this.fields,
    required this.busy,
    required this.onChanged,
    required this.onCheck,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Bản gốc thiếu đầu vào. Nhập thông tin cho bản sao; bạn có thể chỉnh tiếp trước khi lưu.',
      ),
      for (final field in const {
        'origin': 'Nơi xuất phát',
        'days': 'Số ngày',
        'travelers': 'Số người',
        'budget': 'Ngân sách toàn chuyến (VND)',
      }.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextField(
            key: ValueKey('copy.input.${field.key}'),
            controller: fields[field.key],
            enabled: !busy,
            decoration: InputDecoration(labelText: field.value),
            keyboardType: field.key == 'origin'
                ? TextInputType.text
                : TextInputType.number,
            onChanged: (_) => onChanged(),
          ),
        ),
      OutlinedButton(
        onPressed: busy ? null : onCheck,
        child: const Text('Kiểm tra đầu vào bản sao'),
      ),
    ],
  );
}

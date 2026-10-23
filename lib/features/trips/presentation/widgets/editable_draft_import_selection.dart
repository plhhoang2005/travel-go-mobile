import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../main.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../explore/models/public_catalogue_snapshot.dart';
import '../../../explore/providers/public_catalogue_provider.dart';
import '../../../explore/services/catalogue_repository.dart';
import '../../../trip_planner/presentation/screens/manual_planner_screen.dart';
import '../../../trip_planner/presentation/widgets/manual_expense_form.dart';
import '../../../trip_planner/services/editable_trip_validator.dart';
import '../../models/editable_local_records.dart';
import '../../models/editable_remote_records.dart';
import '../../providers/saved_trips_provider.dart';
import '../../services/local_account_lifecycle_service.dart';
import '../../services/local_trip_store.dart';
import '../screens/editable_trip_detail_screen.dart';

bool _account(BuildContext context, String owner) {
  final auth = context.read<AuthProvider>();
  return auth.isAuthenticated &&
      !auth.isDemoSession &&
      auth.currentUser?.id == owner;
}

class EditableDraftImportSelection extends StatefulWidget {
  final String expectedOwnerId;
  const EditableDraftImportSelection({
    super.key,
    required this.expectedOwnerId,
  });
  @override
  State<EditableDraftImportSelection> createState() =>
      _EditableDraftImportSelectionState();
}

class _EditableDraftImportSelectionState
    extends State<EditableDraftImportSelection> {
  ManualPlannerResources? _resources;
  AccountSessionProof? _proof;
  bool _started = false, _busy = false;
  String? _error, _result;
  bool get _current =>
      mounted &&
      _account(context, widget.expectedOwnerId) &&
      (_proof == null ||
          _resources?.repository.lifecycle.isCurrentProof(_proof!) == true);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _load();
        }
      });
    }
  }

  Future<void> _load() async {
    if (!_current || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bundle = await context.read<ManualPlannerRuntime>().getResources();
      if (!_current) {
        return;
      }
      final proof = bundle.repository.lifecycle.captureProof();
      if (proof.ownerId != widget.expectedOwnerId) {
        return;
      }
      setState(() {
        _resources = bundle;
        _proof = proof;
      });
      await bundle.drafts.load();
    } catch (_) {
      if (_current) {
        setState(
          () =>
              _error = 'Không mở được danh sách bản nháp tự lập. Hãy thử lại.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool _sameSelection(List<EditableDraftRecord> frozen) {
    final selected = _resources?.drafts.selected ?? [];
    return selected.length == frozen.length &&
        frozen.every(
          (source) => selected.any(
            (s) =>
                s.draftId == source.draftId &&
                s.deviceScope == source.deviceScope &&
                s.revision == source.revision &&
                s.contentDigest == source.contentDigest,
          ),
        );
  }

  Future<void> _review({bool retry = false}) async {
    final bundle = _resources, proof = _proof;
    if (!_current || _busy || bundle == null || proof == null) {
      return;
    }
    final frozen = List<EditableDraftRecord>.unmodifiable(
      bundle.drafts.selected,
    );
    if (frozen.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => _ImportConsent(
          resources: bundle,
          proof: proof,
          sources: frozen,
          retry: retry,
          current: () => _current && _sameSelection(frozen),
        ),
      );
      if (accepted != true || !_current || !_sameSelection(frozen)) {
        return;
      }
      var count = 0;
      if (retry) {
        // The same immutable source recreates the exact stable request identity.
        // Do not read a newer disk revision into this already-confirmed request.
        for (final source in frozen) {
          if (!_current) {
            return;
          }
          final reply = await bundle.repository.importGuest(source);
          if (!_current) {
            return;
          }
          if (reply.status != EditableMutationStatus.committed) {
            throw StateError('Import not acknowledged');
          }
          count++;
        }
        bundle.drafts.invalidate();
        await bundle.drafts.load();
      } else {
        final outcomes = await bundle.drafts.importSelected();
        count = outcomes
            .where((r) => r.status == EditableMutationStatus.committed)
            .length;
      }
      if (!mounted || !_current) {
        return;
      }
      if (count > 0) {
        setState(() => _result = 'Đã xác nhận chuyển $count bản nháp tự lập.');
        try {
          await context.read<SavedTripsProvider>().loadTrips(
            widget.expectedOwnerId,
          );
        } catch (_) {
          if (_current) {
            setState(
              () =>
                  _error = 'Đã chuyển; danh sách chuyến đi chưa làm mới được.',
            );
          }
        }
      }
    } catch (_) {
      if (_current) {
        setState(
          () => _error = 'Chưa xác nhận đủ kết quả. Bản nháp vẫn được giữ; kiểm tra lại đúng lần chuyển này.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final bundle = _resources;
    return bundle == null
        ? _page(context)
        : ListenableBuilder(
            listenable: Listenable.merge([
              bundle.drafts,
              bundle.repository.lifecycle,
            ]),
            builder: (context, _) => _page(context),
          );
  }

  Widget _page(BuildContext context) {
    final drafts = _resources?.drafts;
    return PopScope(
      canPop: !_busy || !_current,
      child: Scaffold(
        appBar: AppBar(title: const Text('Chuyển bản nháp tự lập')),
        body: SafeArea(
          child: !_current
              ? const Center(
                  child: Text('Tài khoản đã thay đổi. Đóng cửa sổ rồi mở lại.'),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tài khoản nhận: ${context.read<AuthProvider>().currentUser?.email ?? widget.expectedOwnerId}',
                          ),
                          const Text(
                            'Chỉ chuyển bản nháp đã chọn và xác nhận. Đăng nhập không tự chuyển dữ liệu.',
                          ),
                          if (_busy) const Text('Đang xử lý bản nháp…'),
                          if (_error != null)
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          if (drafts?.errorMessage != null)
                            Text(drafts!.errorMessage!),
                          if (_result != null) Text(_result!),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: drafts?.drafts.length ?? 0,
                        itemBuilder: (context, index) {
                          final source = drafts!.drafts[index];
                          return CheckboxListTile(
                            key: ValueKey('import.v2.${source.draftId}'),
                            title: Text(source.document.input.title),
                            subtitle: Text(
                              '${source.document.input.destinationName ?? 'Chưa chọn điểm đến'} · phiên bản ${source.revision}',
                            ),
                            value: drafts.selected.any(
                              (s) => s.draftId == source.draftId,
                            ),
                            onChanged:
                                _busy || drafts.isImporting || drafts.uncertain
                                ? null
                                : (value) => drafts.select(
                                    source.draftId,
                                    value == true,
                                  ),
                          );
                        },
                      ),
                    ),
                    if (!_busy && drafts != null && drafts.drafts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Chưa có bản nháp tự lập trên máy.'),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (drafts?.uncertain == true)
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _review(retry: true),
                              child: const Text('Kiểm tra lại lần chuyển'),
                            )
                          else
                            FilledButton(
                              onPressed:
                                  _busy ||
                                      drafts == null ||
                                      drafts.selected.isEmpty
                                  ? null
                                  : () => _review(),
                              child: Text(
                                'Xem lại ${drafts?.selected.length ?? 0} bản nháp tự lập',
                              ),
                            ),
                          TextButton(
                            onPressed: _busy || drafts?.uncertain == true
                                ? null
                                : _load,
                            child: const Text('Tải lại bản nháp tự lập'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ImportConsent extends StatelessWidget {
  final ManualPlannerResources resources;
  final AccountSessionProof proof;
  final List<EditableDraftRecord> sources;
  final bool retry;
  final bool Function() current;
  const _ImportConsent({
    required this.resources,
    required this.proof,
    required this.sources,
    required this.retry,
    required this.current,
  });
  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    return ListenableBuilder(
      listenable: Listenable.merge([
        resources.drafts,
        resources.repository.lifecycle,
      ]),
      builder: (context, _) {
        final allowed =
            current() &&
            _account(context, proof.ownerId) &&
            resources.repository.lifecycle.isCurrentProof(proof);
        final issues = [
          for (final source in sources)
            ...EditableTripValidator.validate(
              source.document,
              mode: ValidationMode.accountSave,
            ).where((i) => i.isBlocking),
        ];
        return AlertDialog(
          title: Text(
            retry
                ? 'Kiểm tra lại lần chuyển đã xác nhận?'
                : 'Xem lại bản nháp đã chọn',
          ),
          scrollable: true,
          content: !allowed
              ? const Text(
                  'Tài khoản đã thay đổi hoặc lựa chọn đã hết hiệu lực.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tài khoản nhận: ${context.read<AuthProvider>().currentUser?.email ?? proof.ownerId}',
                    ),
                    for (final source in sources)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${source.document.input.title} · phiên bản ${source.revision}\n'
                          '${source.document.input.destinationName ?? 'Chưa chọn điểm đến'} · ${source.document.input.startDate ?? 'Chưa chọn ngày đi'} – ${source.document.input.endDate ?? 'Chưa chọn ngày về'}\n'
                          '${source.document.days.length} ngày · ${source.document.input.travelerCount} người · ngân sách ${manualMoney(source.document.input.totalBudgetVnd)}\n'
                          '${source.document.items.length} hoạt động · ${source.document.actualExpenses.length} khoản đã chi',
                        ),
                      ),
                    if (issues.isNotEmpty)
                      const Text(
                        'Hoàn thiện ngày, điểm đến và lỗi trong bản nháp ở chế độ Guest trước khi chuyển.',
                      ),
                    for (final issue in issues) Text(issue.message),
                    const Text(
                      'Chỉ bỏ bản nháp đã xác nhận sau khi nhận kết quả máy chủ. Phiên bản mới hơn trên máy vẫn được giữ.',
                    ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: allowed && issues.isEmpty
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(
                retry ? 'Xác nhận kiểm tra lại' : 'Xác nhận chuyển bản tự lập',
              ),
            ),
          ],
        );
      },
    );
  }
}

class EditableGuestDraftList extends StatefulWidget {
  final Widget fallback;
  const EditableGuestDraftList({super.key, required this.fallback});
  @override
  State<EditableGuestDraftList> createState() => _EditableGuestDraftListState();
}

class _EditableGuestDraftListState extends State<EditableGuestDraftList> {
  ManualPlannerResources? _resources;
  bool _started = false, _busy = false;
  int? _epoch;
  String? _error;
  bool get _guest {
    if (!mounted) {
      return false;
    }
    final auth = context.read<AuthProvider>();
    return mounted &&
        !auth.isAuthenticated &&
        !auth.isDemoSession &&
        auth.currentUser == null;
  }

  bool get _current =>
      _guest &&
      (_resources == null ||
          (_resources!.repository.lifecycle.epoch == _epoch &&
              _resources!.repository.lifecycle.handle == null));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _load();
        }
      });
    }
  }

  Future<void> _load() async {
    if (!_guest || _busy) {
      return;
    }
    final runtime = context.read<ManualPlannerRuntime?>();
    if (runtime == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final bundle = await runtime.getResources();
      if (!_guest || bundle.repository.lifecycle.handle != null) {
        return;
      }
      setState(() {
        _resources = bundle;
        _epoch = bundle.repository.lifecycle.epoch;
      });
      await bundle.drafts.load();
    } catch (_) {
      if (mounted && _guest) {
        setState(
          () =>
              _error = 'Không đọc được bản nháp tự lập trên máy. Hãy thử lại.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _open(EditableDraftRecord source) async {
    final bundle = _resources;
    if (!_current || _busy || bundle == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final latest = await bundle.repository.store.readEditableDraft(
        deviceScope: source.deviceScope,
        draftId: source.draftId,
      );
      if (!_current) {
        return;
      }
      if (latest?.revision != source.revision ||
          latest?.contentDigest != source.contentDigest) {
        throw StateError('Draft changed');
      }
      PublicCatalogueSnapshot? snapshot;
      try {
        final pub = Provider.of<PublicCatalogueProvider>(context, listen: false);
        if (pub.snapshot == null) await pub.load();
        snapshot = pub.snapshot;
      } catch (_) {}
      final catalogue = snapshot != null
          ? snapshot.catalogue
          : await CatalogueRepository().load();
      if (!mounted ||
          !_current ||
          !await confirmManualReplacement(
            context,
            bundle.planner,
            () => _current,
          )) {
        return;
      }
      if (!mounted || !_current) {
        return;
      }
      bundle.planner.openDraft(latest!);
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ManualPlannerScreen(
            planner: bundle.planner,
            destinations: catalogue.destinations,
            snapshot: snapshot,
            enableBudget: true,
          ),
        ),
      );
      if (_current) {
        await bundle.drafts.load();
      }
    } catch (_) {
      if (_current) {
        setState(
          () => _error = 'Bản nháp hoặc phiên đã thay đổi. Tải lại danh sách trước khi mở.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final bundle = _resources;
    if (bundle == null) {
      return _body(context);
    }
    return ListenableBuilder(
      listenable: Listenable.merge([
        bundle.drafts,
        bundle.repository.lifecycle,
      ]),
      builder: (context, _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (!_current) {
      return const Center(
        child: Text('Phiên đã thay đổi. Mở lại danh sách bản nháp.'),
      );
    }
    final drafts = _resources?.drafts;
    if (drafts == null && !_busy && _error == null) {
      return SingleChildScrollView(child: widget.fallback);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bản nháp tự lập trên máy',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'Chưa chuyển vào tài khoản. Mở để sửa và lưu tiếp trên thiết bị này.',
              ),
              if (_busy) const Text('Đang mở bản nháp…'),
              if (_error != null) Text(_error!),
              if (drafts?.errorMessage != null) Text(drafts!.errorMessage!),
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Tải lại bản nháp'),
              ),
            ],
          ),
        ),
        if (drafts != null && drafts.drafts.isNotEmpty)
          Expanded(
            child: ListView.separated(
              itemCount: drafts.drafts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final source = drafts.drafts[index];
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.document.input.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${source.document.input.destinationName ?? 'Chưa chọn điểm đến'} · ${source.document.days.length} ngày · phiên bản ${source.revision}',
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _open(source),
                        child: const Text('Mở bản nháp tự lập'),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        else
          Expanded(child: SingleChildScrollView(child: widget.fallback)),
      ],
    );
  }
}

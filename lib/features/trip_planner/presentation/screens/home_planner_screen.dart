import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../main.dart';
import '../../models/trip_request.dart';
import '../../services/manual_trip_factory.dart';
import '../../../trips/models/trip_payload_codec.dart';
import '../../../explore/providers/discovery_provider.dart';
import '../../../explore/models/catalogue_reference.dart' as catalogue;
import '../../providers/manual_planner_provider.dart';
import 'manual_planner_screen.dart';

import '../../providers/trip_provider.dart';
import 'dashboard_result_screen.dart';
import '../../../trips/models/local_trip_records.dart';
import '../widgets/selected_destination_controls.dart';

/// Shared local save entry point; the state owns and disposes its title controller.
Future<void> showGuestDraftSaveDialog(BuildContext context) async {
  final provider = context.read<TripProvider>();
  if (!provider.canPersistGuestDraft) return;
  final row = await showDialog<GuestDraftRevisionRecord>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _GuestDraftSaveDialog(),
  );
  if (!context.mounted || row == null || !provider.canPersistGuestDraft) return;
  if (provider.activeDraftId != row.draftId ||
      provider.activeDraftRevision != row.revision ||
      provider.isDraftDirty) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Đã lưu bản nháp trên máy — phiên bản ${row.revision}.'),
    ),
  );
}

class _GuestDraftSaveDialog extends StatefulWidget {
  const _GuestDraftSaveDialog();
  @override
  State<_GuestDraftSaveDialog> createState() => _GuestDraftSaveDialogState();
}

class _GuestDraftSaveDialogState extends State<_GuestDraftSaveDialog> {
  final TextEditingController _title = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Lưu bản nháp trên máy'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Tên bản nháp (không bắt buộc)',
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  final provider = context.read<TripProvider>();
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  final row = await provider.saveGuestDraft(title: _title.text);
                  if (!mounted || !context.mounted) return;
                  if (row != null) {
                    Navigator.pop(context, row);
                  } else {
                    setState(() {
                      _saving = false;
                      _error = provider.draftErrorMessage ?? 'Nội dung đã thay đổi; bản nháp hiện tại chưa được xác nhận lưu.';
                    });
                  }
                },
          child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
        ),
      ],
    ),
  );
}

class HomePlannerScreen extends StatefulWidget {
  const HomePlannerScreen({super.key});

  @override
  State<HomePlannerScreen> createState() => _HomePlannerScreenState();
}

class _HomePlannerScreenState extends State<HomePlannerScreen> {
  final List<String> availablePreferences = [
    'biển',
    'ẩm thực',
    'nghỉ dưỡng',
    'núi',
    'văn hóa',
    'khám phá',
  ];

  final Map<String, String> priorityLabels = {
    'balanced': 'Cân bằng',
    'cheapest': 'Rẻ nhất',
    'fastest': 'Nhanh nhất',
    'comfortable': 'Thoải mái',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final trip = context.read<TripProvider>();
      if (!trip.hasSelectedDestination) trip.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final req = provider.currentRequest;
    final currencyFmt = NumberFormat.currency(
      locale: 'vi',
      symbol: 'đ',
      decimalDigits: 0,
    );
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (!provider.hasPlannerInput) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bản nháp trên máy')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Bản nháp này chỉ có kết quả đã lưu, chưa có thông tin đầu vào.',
                ),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DashboardResultScreen(),
                    ),
                  ),
                  child: Text(
                    provider.isRestoredLocalDraft
                        ? 'Xem kết quả đã lưu'
                        : 'Xem kết quả',
                  ),
                ),
                OutlinedButton(
                  onPressed: provider.canPersistGuestDraft
                      ? () => _newDraft(provider)
                      : null,
                  child: const Text('Bản nháp mới'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('TravelGO Mobile', overflow: TextOverflow.ellipsis),
        actions: [
          if (!provider.hasSelectedDestination)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: provider.isBackendOnline
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: provider.isBackendOnline
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.isBackendOnline
                        ? 'API Sẵn Sàng'
                        : 'Chế Độ Dự Phòng',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: provider.isBackendOnline
                          ? const Color(0xFF047857)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectedDestinationControls(
              onManualPlanner: () => openManualPlanner(context),
            ),
            if (provider.hasSelectedDestination) ...[
              Text('Nơi xuất phát: ${req.origin}'),
              const SizedBox(height: 8),
            ],
            // Intro Header
            Text(
              provider.hasSelectedDestination
                  ? 'Thông tin chuyến đi'
                  : 'Lập Kế Hoạch Chuyến Đi Thông Minh',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              provider.hasSelectedDestination
                  ? 'Điều chỉnh ngân sách, số ngày và sở thích trước khi lưu bản nháp.'
                  : 'Được tính toán bởi mô hình MCDA & Tối ưu hóa Pareto (Spring Boot Backend)',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Quick Presets
            if (!provider.hasSelectedDestination)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gợi ý kịch bản mẫu:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(
                              Icons.person,
                              size: 16,
                              color: Color(0xFF0284C7),
                            ),
                            label: const Text('Persona Minh (4 triệu - 3N2Đ)'),
                            onPressed: () => provider.applyPreset(1),
                          ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.beach_access,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                            label: const Text('Phú Quốc (8 triệu - 4 ngày)'),
                            onPressed: () => provider.applyPreset(2),
                          ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.directions_bus,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                            label: const Text('Vũng Tàu (1.5 triệu - 2 ngày)'),
                            onPressed: () => provider.applyPreset(3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Sliders Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Budget Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Ngân sách tối đa:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          currencyFmt.format(req.budgetVnd),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: req.budgetVnd.toDouble().clamp(1000000, 15000000),
                      min: 1000000,
                      max: 15000000,
                      divisions: 28,
                      onChanged: (val) {
                        provider.updateRequest(
                          req.copyWith(budgetVnd: val.toInt()),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Num Days Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Số ngày đi:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${req.numDays} ngày',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: req.numDays.toDouble().clamp(1, 7),
                      min: 1,
                      max: 7,
                      divisions: 6,
                      onChanged: (val) {
                        provider.updateRequest(
                          req.copyWith(numDays: val.toInt()),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Num People Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Số lượng người:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${req.numPeople} người',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: req.numPeople.toDouble().clamp(1, 8),
                      min: 1,
                      max: 8,
                      divisions: 7,
                      onChanged: (val) {
                        provider.updateRequest(
                          req.copyWith(numPeople: val.toInt()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Preferences
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sở thích du lịch:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availablePreferences.map((pref) {
                        final isSelected = req.preferences.contains(pref);
                        return FilterChip(
                          label: Text(pref),
                          selected: isSelected,
                          onSelected: (selected) {
                            final currentList = List<String>.from(
                              req.preferences,
                            );
                            if (selected) {
                              currentList.add(pref);
                            } else {
                              currentList.remove(pref);
                            }
                            provider.updateRequest(
                              req.copyWith(preferences: currentList),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Priority
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mục tiêu ưu tiên:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: priorityLabels.entries.map((entry) {
                        final isSelected = req.priority == entry.key;
                        return ChoiceChip(
                          label: Text(entry.value),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              provider.updateRequest(
                                req.copyWith(priority: entry.key),
                              );
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (req.budgetVnd < 1000000 ||
                req.budgetVnd > 15000000 ||
                req.numDays > 7 ||
                req.numPeople > 8)
              const Text(
                'Giá trị đã lưu nằm ngoài khoảng thanh trượt; chỉ thay đổi khi bạn điều chỉnh.',
              ),
            if (provider.canPersistGuestDraft) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: provider.isSavingDraft
                        ? null
                        : () => showGuestDraftSaveDialog(context),
                    child: const Text('Lưu bản nháp trên máy'),
                  ),
                  OutlinedButton(
                    onPressed: provider.isLoadingDraft
                        ? null
                        : () => _openDraftList(provider),
                    child: const Text('Bản nháp trên máy'),
                  ),
                  TextButton(
                    onPressed: () => _newDraft(provider),
                    child: const Text('Bản nháp mới'),
                  ),
                ],
              ),
              if (provider.currentResponse == null)
                const Text('Chưa có kết quả lập lịch'),
              if (provider.currentResponse != null)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DashboardResultScreen(),
                    ),
                  ),
                  child: Text(
                    provider.isRestoredLocalDraft
                        ? 'Xem kết quả đã lưu'
                        : 'Xem kết quả',
                  ),
                ),
              if (provider.draftErrorMessage != null)
                Text(
                  provider.draftErrorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: provider.isLoading || provider.hasSelectedDestination
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        final accepted = await provider.submitPlan();
                        if (!mounted) return;
                        if (accepted && provider.currentResponse != null) {
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => const DashboardResultScreen(),
                            ),
                          );
                        }
                      },
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.bolt),
                label: Text(
                  provider.isLoading
                      ? 'Đang phân tích tối ưu...'
                      : 'Tối Ưu Hóa & Lập Kế Hoạch',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmReplace(TripProvider provider) async {
    if (!provider.isDraftDirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Thay nội dung chưa lưu?'),
            content: const Text(
              'Nội dung đang sửa chưa được lưu. Bạn có muốn thay thế không?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Thay thế'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _newDraft(TripProvider provider) async {
    final generation = provider.workspaceGeneration;
    if (!await _confirmReplace(provider) || !mounted) return;
    provider.startNewGuestDraft(expectedWorkspaceGeneration: generation);
  }

  Future<void> _openDraftList(TripProvider provider) async {
    final rows = await provider.listGuestDrafts();
    if (!mounted) return;
    if (provider.draftErrorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(provider.draftErrorMessage!)));
      return;
    }
    if (!provider.canPersistGuestDraft) return;
    final selected = await showModalBottomSheet<GuestDraftSummaryRecord>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * 0.65,
          child: rows.isEmpty
              ? const Center(child: Text('Chưa có bản nháp trên máy.'))
              : ListView(
                  children: rows
                      .map(
                        (row) => ListTile(
                          title: Text(row.title ?? 'Bản nháp'),
                          subtitle: Text(
                            'Phiên bản ${row.currentRevision} · ${row.updatedAt.toLocal()}',
                          ),
                          trailing: const Icon(Icons.folder_open),
                          onTap: () => Navigator.pop(sheet, row),
                        ),
                      )
                      .toList(),
                ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final generation = provider.workspaceGeneration;
    if (!await _confirmReplace(provider) || !mounted) return;
    final opened = await provider.openGuestDraft(
      draftId: selected.draftId,
      revision: selected.currentRevision,
      expectedWorkspaceGeneration: generation,
    );
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.draftErrorMessage ??
                'Nội dung đã thay đổi; hãy chọn lại bản nháp.',
          ),
        ),
      );
      return;
    }
    if (!provider.hasPlannerInput) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DashboardResultScreen()),
      );
    }
  }
}

Future<void> openManualPlanner(BuildContext context) async {
  final trip = context.read<TripProvider>();
  if (!trip.canReplaceWorkspace) return;
  await Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const _ManualPlannerEntry()));
}

class _ManualPlannerEntry extends StatefulWidget {
  const _ManualPlannerEntry();
  @override
  State<_ManualPlannerEntry> createState() => _ManualPlannerEntryState();
}

class _ManualPlannerEntryState extends State<_ManualPlannerEntry> {
  late final TripProvider _trip;
  late final PlanTripRequest _request;
  late final TripMetadataV1 _metadata;
  late final int _generation;
  late final String? _draftId;
  late final int? _revision;
  ManualPlannerProvider? _planner;
  catalogue.CatalogueReference? _catalogue;
  bool _loading = true, _confirming = false;
  String? _error;
  bool get _current =>
      mounted &&
      _trip.canReplaceWorkspace &&
      _trip.workspaceGeneration == _generation &&
      identical(_request, _trip.currentRequest) &&
      identical(_metadata, _trip.currentMetadata) &&
      _trip.activeDraftId == _draftId &&
      _trip.activeDraftRevision == _revision;
  @override
  void initState() {
    super.initState();
    _trip = context.read<TripProvider>();
    _request = _trip.currentRequest;
    _metadata = _trip.currentMetadata;
    _generation = _trip.workspaceGeneration;
    _draftId = _trip.activeDraftId;
    _revision = _trip.activeDraftRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  Future<bool> _replace(ManualPlannerProvider planner) async {
    if (planner.isSaving || planner.hasPendingSave) return false;
    if (planner.document == null || !planner.dirty) return true;
    final generation = planner.editorGeneration,
        draftId = planner.draftId,
        version = planner.baseHead?.version;
    setState(() => _confirming = true);
    bool? accepted;
    try {
      accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Thay bản chỉnh sửa đang mở?'),
          content: const Text(
            'Các thay đổi chưa lưu của lịch trình trước sẽ bị bỏ. Bản đã lưu vẫn được giữ.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Giữ bản đang sửa'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Tạo bản chỉnh sửa mới'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
    return accepted == true &&
        _current &&
        planner.editorGeneration == generation &&
        planner.draftId == draftId &&
        planner.baseHead?.version == version &&
        !planner.isSaving &&
        !planner.hasPendingSave;
  }

  Future<void> _start({bool retry = false}) async {
    if (!_current) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final discovery = context.read<DiscoveryProvider>();
    final runtime = context.read<ManualPlannerRuntime>();
    try {
      if (discovery.state != DiscoveryLoadState.ready) {
        await discovery.load(
          force: retry || discovery.state == DiscoveryLoadState.error,
        );
      }
      if (!_current) return;
      final catalogue = discovery.catalogue;
      if (discovery.state != DiscoveryLoadState.ready || catalogue == null) {
        setState(
          () => _error = 'Không tải được danh mục địa điểm. Hãy thử lại.',
        );
        return;
      }
      final resources = await runtime.getResources();
      if (!_current) return;
      if (!await _replace(resources.planner)) {
        if (mounted && _current) {
          setState(
            () => _error = 'Chưa thay bản chỉnh sửa. Quay lại hoặc thử lại sau khi xử lý lần lưu trước.',
          );
        }
        return;
      }
      if (!_current) return;
      final document = ManualTripFactory().fromInput(_request, _metadata);
      resources.planner.openNew(document);
      setState(() {
        _planner = resources.planner;
        _catalogue = catalogue;
      });
    } on Object {
      if (mounted && _current) {
        setState(
          () =>
              _error = 'Không mở được lịch trình. Kiểm tra dữ liệu và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _trip,
    builder: (context, _) {
      final planner = _planner;
      if (planner != null) {
        return ManualPlannerScreen(
          planner: planner,
          destinations: _catalogue!.destinations,
          enableBudget: true,
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Tự lập lịch trình')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_current)
                    const Text(
                      'Thông tin hoặc phiên đã thay đổi. Quay lại và mở lại lịch trình.',
                    )
                  else if (_confirming)
                    const Text('Chờ xác nhận thay bản chỉnh sửa.')
                  else if (_loading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Đang mở lịch trình…'),
                  ] else ...[
                    Text(_error ?? 'Không mở được lịch trình.'),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _start(retry: true),
                      child: const Text('Thử lại'),
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

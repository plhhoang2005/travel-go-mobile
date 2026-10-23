import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../explore/models/catalogue_reference.dart' as catalogue;
import '../../../explore/models/public_catalogue_snapshot.dart';
import '../../../explore/providers/discovery_provider.dart';
import '../../../explore/providers/public_catalogue_provider.dart';
import '../../../explore/services/catalogue_repository.dart';
import '../../../trips/models/trip_payload_codec.dart';
import '../../models/trip_request.dart';
import '../../providers/manual_planner_provider.dart';
import '../../providers/trip_provider.dart';
import '../../../../main.dart';
import '../../services/manual_trip_factory.dart';
import 'manual_planner_screen.dart';

enum ManualPlannerEntryIntent {
  edit,
  aiAssistant,
}

class ManualPlannerEntryScreen extends StatefulWidget {
  final ManualPlannerEntryIntent intent;

  const ManualPlannerEntryScreen({
    super.key,
    this.intent = ManualPlannerEntryIntent.edit,
  });

  @override
  State<ManualPlannerEntryScreen> createState() => _ManualPlannerEntryScreenState();
}

class _ManualPlannerEntryScreenState extends State<ManualPlannerEntryScreen> {
  late final TripProvider _trip;
  late final PlanTripRequest _request;
  late final TripMetadataV1 _metadata;
  late final int _generation;
  late final String? _draftId;
  late final int? _revision;
  ManualPlannerProvider? _planner;
  PublicCatalogueSnapshot? _snapshot;
  List<catalogue.DestinationReference>? _destinations;
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

    final runtime = context.read<ManualPlannerRuntime>();

    try {
      PublicCatalogueSnapshot? snapshot;
      List<catalogue.DestinationReference>? destinations;

      try {
        final pub = Provider.of<PublicCatalogueProvider>(context, listen: false);
        if (pub.snapshot == null) {
          await pub.load();
        }
        snapshot = pub.snapshot;
        if (snapshot != null) {
          destinations = snapshot.catalogue.destinations;
        }
      } catch (_) {
        // Fall through to discovery or repository fallback
      }

      if (destinations == null || destinations.isEmpty) {
        try {
          final discovery = Provider.of<DiscoveryProvider>(context, listen: false);
          if (discovery.state != DiscoveryLoadState.ready) {
            await discovery.load(force: retry || discovery.state == DiscoveryLoadState.error);
          }
          if (discovery.catalogue != null) {
            destinations = discovery.catalogue!.destinations;
          }
        } catch (_) {}
      }

      if (destinations == null || destinations.isEmpty) {
        final cat = await CatalogueRepository().load();
        destinations = cat.destinations;
      }

      if (!_current) return;

      if (destinations.isEmpty) {
        setState(() => _error = 'Không tải được danh mục địa điểm. Hãy thử lại.');
        return;
      }

      final resources = await runtime.getResources();
      if (!_current) return;

      if (!await _replace(resources.planner)) {
        if (mounted && _current) {
          setState(
            () => _error =
                'Chưa thay bản chỉnh sửa. Quay lại hoặc thử lại sau khi xử lý lần lưu trước.',
          );
        }
        return;
      }

      if (!_current) return;

      final document = ManualTripFactory().fromInput(_request, _metadata);
      resources.planner.openNew(document);

      setState(() {
        _planner = resources.planner;
        _snapshot = snapshot;
        _destinations = destinations;
      });
    } on Object {
      if (mounted && _current) {
        setState(
          () => _error = 'Không mở được lịch trình. Kiểm tra dữ liệu và thử lại.',
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
          final destinations = _destinations;
          if (planner != null && destinations != null) {
            return ManualPlannerScreen(
              planner: planner,
              destinations: destinations,
              snapshot: _snapshot,
              enableBudget: true,
              openAssistantOnReady:
                  widget.intent == ManualPlannerEntryIntent.aiAssistant,
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

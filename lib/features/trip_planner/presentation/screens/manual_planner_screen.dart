import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart' show Uuid;
import 'package:provider/provider.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../explore/models/public_catalogue_snapshot.dart';
import '../../../explore/models/place_visit_details.dart';
import '../../../explore/models/catalogue_reference.dart' as catalogue;
import '../../../explore/providers/place_visit_details_provider.dart';
import '../../../trips/models/editable_trip_codec.dart';
import '../../models/editable_trip_command.dart';
import '../../models/editable_trip_document.dart';
import '../../providers/manual_planner_provider.dart';
import '../../providers/planner_input_provider.dart';
import '../../services/editable_trip_validator.dart';
import '../../services/ai_generation_service.dart';
import '../../services/ai_assistant_service.dart';
import '../widgets/ai_generation_preview.dart';
import '../widgets/ai_assistant_preview.dart';
import '../widgets/manual_activity_form.dart';
import '../widgets/manual_budget_panel.dart';
import '../widgets/manual_expense_form.dart';
import '../widgets/manual_itinerary_timeline.dart';
import '../widgets/manual_save_preview.dart';
import '../widgets/manual_trip_input_form.dart';

class ManualPlannerScreen extends StatefulWidget {
  final ManualPlannerProvider planner;
  final List<catalogue.DestinationReference> destinations;
  final PublicCatalogueSnapshot? snapshot;
  final String Function()? newId;
  final bool enableBudget;
  // Product routes require account saves; legacy draft readers stay compatible.
  final bool accountSaveOnly;
  final bool enableMapNetworkTiles;
  final Widget Function(BuildContext, ManualPlannerProvider)? budgetBuilder;
  final Future<void> Function(BuildContext, ManualPlannerProvider)?
  onReviewSave;
  final Future<AiPreparedProposal> Function(EditableTripDocumentV2, String)?
  generateAi;
  final AiAssistantGenerator? assistantGenerate;
  final bool openAssistantOnReady;
  const ManualPlannerScreen({
    super.key,
    required this.planner,
    required this.destinations,
    this.snapshot,
    this.newId,
    this.enableBudget = false,
    this.accountSaveOnly = false,
    this.enableMapNetworkTiles = true,
    this.budgetBuilder,
    this.onReviewSave,
    this.generateAi,
    this.assistantGenerate,
    this.openAssistantOnReady = false,
  });
  @override
  State<ManualPlannerScreen> createState() => _ManualPlannerScreenState();
}

class _ManualStamp {
  final int generation;
  final String digest;
  final String? owner, draftId;
  final int? baseVersion;
  _ManualStamp(ManualPlannerProvider planner)
    : generation = planner.editorGeneration,
      digest = EditableTripCodec.digest(planner.document!),
      owner = planner.currentOwnerId,
      draftId = planner.draftId,
      baseVersion = planner.baseHead?.version;
  bool workspace(ManualPlannerProvider planner) =>
      planner.document != null &&
      planner.currentOwnerId == owner &&
      planner.draftId == draftId;
  bool current(ManualPlannerProvider planner) =>
      workspace(planner) &&
      planner.editorGeneration == generation &&
      planner.baseHead?.version == baseVersion &&
      EditableTripCodec.digest(planner.document!) == digest;
}

class _ManualPlannerScreenState extends State<ManualPlannerScreen> {
  String? _dayId;
  bool _assistantOpenedOnReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.openAssistantOnReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_assistantOpenedOnReady) {
          _assistantOpenedOnReady = true;
          _aiAssistant();
        }
      });
    }
  }

  bool get supportsAi {
    final destId = planner.document?.input.destinationId;
    if (destId == null) return false;
    if (widget.snapshot != null) {
      return PlannerInputProvider.isAiEligibleDestination(destId, widget.snapshot!);
    }
    if (widget.destinations.isNotEmpty) {
      return PlannerInputProvider.destinationIdRegex.hasMatch(destId) &&
          widget.destinations.any((d) => d.id == destId);
    }
    return PlannerInputProvider.supportedAiDestinationIds.contains(destId);
  }

  catalogue.DestinationReference? get _currentDestination {
    final doc = planner.document;
    if (doc == null) return null;
    final destId = doc.input.destinationId;
    if (destId == null) return null;
    final list = widget.snapshot?.catalogue.destinations ?? widget.destinations;
    final found = list.where((d) => d.id == destId).firstOrNull;
    if (found != null) return found;
    final inputName = doc.input.destinationName;
    if (PlannerInputProvider.supportedAiDestinationIds.contains(destId)) {
      return catalogue.DestinationReference(
        id: destId,
        name: inputName?.isNotEmpty == true ? inputName! : destId,
        region: 'unknown',
        places: const [],
        sample: catalogue.SampleReference.unavailable(id: destId),
      );
    }
    return null;
  }

  bool get showUnavailableWarning {
    final doc = planner.document;
    if (doc == null) return false;
    final currentDestId = doc.input.destinationId;
    if (currentDestId == null) return false;
    final activeDestinations = widget.snapshot?.catalogue.destinations ?? widget.destinations;
    if (activeDestinations.isEmpty) return false;
    final isDestActive = activeDestinations.any((d) => d.id == currentDestId);
    final isNewTrip = doc.source.kind == 'new';
    return !isDestActive && isNewTrip;
  }
  bool _budget = false, _askingLeave = false;
  ManualPlannerProvider get planner => widget.planner;
  void _selectDay(int ordinal) =>
      setState(() => _dayId = planner.document!.days[ordinal - 1].id);
  void _setBudget(bool value) => setState(() => _budget = value);
  String _newId() => widget.newId?.call() ?? const Uuid().v4();
  int get _ordinal {
    final doc = planner.document;
    if (doc == null) return 1;
    return doc.days.where((d) => d.id == _dayId).firstOrNull?.ordinal ?? 1;
  }

  Future<T?> _route<T>(Widget child, {bool dialog = false}) async {
    if (!planner.isEditable &&
        child is! _DayPicker) {
      return null;
    }
    if (planner.document == null) return null;
    final stamp = _ManualStamp(planner);
    Widget guarded(BuildContext context) =>
        _GuardedManualRoute(planner: planner, stamp: stamp, child: child);
    final result = dialog
        ? await showDialog<T>(context: context, builder: guarded)
        : await Navigator.of(context)
              .push<T>(MaterialPageRoute(builder: guarded));
    if (!mounted || !stamp.current(planner)) return null;
    return result;
  }

  void _dispatch(EditableCommand command) {
    if (!planner.isEditable) return;
    try {
      planner.dispatch(command);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể áp dụng thay đổi. Kiểm tra lại nội dung và giới hạn chuyến đi.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _aiHelp() async {
    if (!supportsAi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tính năng AI chưa khả dụng cho điểm đến này. Bạn có thể tự chỉnh hoạt động.',
          ),
        ),
      );
      return;
    }
    if (!planner.isEditable ||
        planner.isSaving ||
        planner.hasPendingSave ||
        planner.state == ManualPlannerState.conflict) {
      return;
    }
    final AuthProvider auth;
    try {
      auth = context.read<AuthProvider>();
    } on ProviderNotFoundException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI chưa khả dụng. Bạn có thể tự chỉnh hoạt động và xem vị trí tham khảo theo ngày.',
          ),
        ),
      );
      return;
    }
    final snapshot = planner.document!,
        stamp = _ManualStamp(planner),
        epoch = auth.authEpoch,
        authOwner = auth.currentUser?.id,
        authGuest = auth.isGuest,
        authDemo = auth.isDemoSession;
    final dest = _currentDestination;
    final AiGenerationContext input;
    try {
      input = AiGenerationContext.fromDocument(snapshot, destination: dest);
    } on Object {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chọn điểm đến và kiểm tra sở thích trước khi gửi AI. Không đưa thông tin liên hệ vào sở thích.',
          ),
        ),
      );
      return;
    }
    bool current() =>
        mounted &&
        auth.authEpoch == epoch &&
        auth.currentUser?.id == authOwner &&
        auth.isGuest == authGuest &&
        auth.isDemoSession == authDemo &&
        stamp.current(planner);
    final result = await _route<AiPreparedProposal>(
      AiGenerationPreview(
        input: input,
        authority: Listenable.merge([planner, auth]),
        isCurrent: current,
        generate: (requestId) =>
            widget.generateAi?.call(snapshot, requestId) ??
            generateAiForDraft(
              auth: auth,
              document: snapshot,
              requestId: requestId,
              newId: _newId,
              workspaceCurrent: current,
              destination: dest,
            ),
      ),
      dialog: true,
    );
    if (result == null || !current() || !result.canApply) {
      return;
    }
    try {
      planner.dispatchAll(result.commands);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa áp dụng đề xuất AI. Hãy kiểm tra lại bản nháp hiện tại.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _aiAssistant() async {
    if (!supportsAi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tính năng AI chưa khả dụng cho điểm đến này. Bạn có thể tự chỉnh hoạt động và xem vị trí tham khảo.',
          ),
        ),
      );
      return;
    }
    if (!planner.isEditable ||
        planner.isSaving ||
        planner.hasPendingSave ||
        planner.state == ManualPlannerState.conflict) {
      return;
    }
    final AuthProvider auth;
    try {
      auth = context.read<AuthProvider>();
    } on ProviderNotFoundException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI chưa khả dụng. Bạn vẫn có thể tự chỉnh lịch.'),
        ),
      );
      return;
    }
    final snapshot = planner.document!,
        stamp = _ManualStamp(planner),
        epoch = auth.authEpoch,
        owner = auth.currentUser?.id,
        guest = auth.isGuest,
        demo = auth.isDemoSession;
    bool current() =>
        mounted &&
        stamp.current(planner) &&
        auth.authEpoch == epoch &&
        auth.currentUser?.id == owner &&
        auth.isGuest == guest &&
        auth.isDemoSession == demo;
    final dest = _currentDestination;
    final visitsCatalogue = widget.snapshot?.visits ??
        context.read<PlaceVisitDetailsProvider?>()?.snapshot?.catalogue;
    final visitDetails =
        visitsCatalogue?.places ?? const <String, PlaceVisitDetails>{};
    final packages =
        visitsCatalogue?.packages ?? const <String, VisitPackage>{};

    final AiAssistantContext input;
    try {
      input = AiAssistantContext.fromDocument(
        snapshot,
        destination: dest,
        selectedDay: _ordinal,
        places: _places,
        visitDetails: visitDetails,
        packages: packages,
      );
    } on Object {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa thể gửi ngữ cảnh ngày này. Kiểm tra điểm đến, số hoạt động và bỏ thông tin liên hệ khỏi tiêu đề/sở thích.',
          ),
        ),
      );
      return;
    }
    final result = await _route<AiModificationPreview>(
      AiAssistantPreview(
        input: input,
        authority: Listenable.merge([planner, auth]),
        isCurrent: current,
        generate:
            widget.assistantGenerate ??
            (intent, prompt, history, requestId) => askAiForDraft(
              auth: auth,
              document: snapshot,
              context: input,
              intent: intent,
              prompt: prompt,
              history: history,
              requestId: requestId,
              newId: _newId,
              workspaceCurrent: current,
            ),
      ),
      dialog: true,
    );
    if (result == null || !current() || !result.canApply) {
      return;
    }
    try {
      planner.dispatchAll(result.commands);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa áp dụng thay đổi AI. Hãy kiểm tra lại bản nháp hiện tại.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _input() async {
    final doc = planner.document;
    if (doc == null) return;
    final result = await _route<ManualTripInputResult>(
      ManualTripInputForm(
        initialDocument: doc,
        destinations: widget.snapshot?.catalogue.destinations ?? widget.destinations,
        newId: _newId,
      ),
    );
    if (result == null ||
        !mounted ||
        planner.document == null ||
        result.baseDigest != EditableTripCodec.digest(planner.document!)) {
      return;
    }
    try {
      planner.dispatchAll(result.commands);
    } on Object {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thông tin chưa được áp dụng. Hãy mở lại form và kiểm tra.',
          ),
        ),
      );
    }
  }

  List<catalogue.PlaceReference> get _places =>
      (widget.snapshot?.catalogue.destinations ?? widget.destinations)
          .where((d) => d.id == planner.document?.input.destinationId)
          .firstOrNull
          ?.places ??
      [];
  Future<void> _activity(TripDay day, {TripItem? item}) async {
    final doc = planner.document;
    if (doc == null || !planner.isEditable) return;
    final initial =
        item ??
        TripItem(
          id: _newId(),
          dayId: day.id,
          position: doc.items.where((i) => i.dayId == day.id).length,
          title: '',
          placeId: null,
          startMinute: null,
          endMinute: null,
          notes: '',
          provenance: FieldProvenance(
            quality: 'user_provided',
            sourceRefs: [],
            observedAt: null,
          ),
        );
    final result = await _route<TripItem>(
      ManualActivityForm(initialItem: initial, places: _places),
    );
    if (result == null) return;
    _dispatch(
      item == null ? AddItemCommand(result) : EditItemCommand.fromItem(result),
    );
  }

  Future<void> _notes(TripDay day) async {
    final result = await _route<String>(_DayNotesForm(day: day));
    if (result != null) _dispatch(DayNotesCommand(day.id, result));
  }

  Future<void> _expense(ManualExpenseKind kind, String? expenseId) async {
    final doc = planner.document;
    if (doc == null || !planner.isEditable) return;
    final result = await _route<EditableCommand>(
      ManualExpenseForm(
        document: doc,
        kind: kind,
        expenseId: expenseId,
        newId: _newId,
      ),
    );
    if (result != null) _dispatch(result);
  }

  Future<void> _review() async {
    if (!planner.isEditable ||
        planner.isSaving ||
        planner.hasPendingSave ||
        planner.state == ManualPlannerState.conflict) {
      return;
    }
    if (widget.accountSaveOnly && !planner.isAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập để lưu chuyến đi vào tài khoản.')),
      );
      return;
    }
    final preview = planner.previewSave();
    EditableValidationIssue? resolution;
    await _route<void>(
      ManualSavePreview(
        planner: planner,
        preview: preview,
        onResolveIssue: (issue) => resolution = issue,
      ),
    );
    if (!mounted ||
        planner.document == null ||
        planner.draftId != preview.draftId ||
        planner.currentOwnerId != preview.proof?.ownerId) {
      return;
    }
    planner.cancelPreview();
    final issue = resolution;
    if (issue == null) return;
    final doc = planner.document!;
    final item = doc.items
        .where(
          (i) =>
              issue.itemIds.contains(i.id) ||
              issue.path.startsWith('items.${i.id}'),
        )
        .firstOrNull;
    if (item != null) {
      final day = doc.days.firstWhere((d) => d.id == item.dayId);
      setState(() {
        _budget = false;
        _dayId = day.id;
      });
      await _activity(day, item: item);
    } else if (issue.path.startsWith('input.')) {
      await _input();
    } else {
      _setBudget(true);
    }
  }

  Future<void> _chooseDay({TripItem? moving}) async {
    final doc = planner.document;
    if (doc == null) return;
    final day = await _route<String>(
      _DayPicker(
        days: doc.days,
        selectedId: moving?.dayId ?? _dayId ?? doc.days.first.id,
      ),
      dialog: true,
    );
    if (day == null || !mounted) return;
    if (moving == null) {
      setState(() => _dayId = day);
      return;
    }
    if (day == moving.dayId) return;
    final current = planner.document;
    if (current == null) return;
    _dispatch(
      MoveItemCommand(
        moving.id,
        day,
        current.items.where((i) => i.dayId == day).length,
      ),
    );
  }

  Future<void> _delete(TripItem item) async {
    final confirmed = await _route<bool>(
      Builder(
        // showDialog uses the root navigator; the editor may live below it.
        builder: (dialogContext) => AlertDialog(
          title: const Text('Xóa hoạt động?'),
          content: Text(
            '${item.title}\n\nKhoản dự kiến liên quan sẽ ngừng tính. Các khoản đã chi vẫn được giữ.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận xóa'),
            ),
          ],
        ),
      ),
      dialog: true,
    );
    if (confirmed == true) _dispatch(RemoveItemCommand(item.id));
  }

  Future<void> _leave() async {
    if (_askingLeave) return;
    if (!planner.dirty && !planner.isSaving && !planner.hasPendingSave) {
      Navigator.pop(context);
      return;
    }
    _askingLeave = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời bản chỉnh sửa?'),
        content: const Text(
          'Các thay đổi chưa lưu trên màn hình sẽ không được giữ. Yêu cầu lưu đã xác nhận vẫn có thể đang được xử lý.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rời màn hình'),
          ),
        ],
      ),
    );
    _askingLeave = false;
    if (mounted && leave == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planner,
    builder: (context, _) {
      final doc = planner.document;
      return PopScope(
        canPop: !planner.dirty && !planner.isSaving && !planner.hasPendingSave,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: _leave),
            title: const Text('Chỉnh lịch trình'),
            actions: [
              if (doc != null && planner.isEditable)
                IconButton(
                  key: const ValueKey('ai-assistant-open'),
                  tooltip: 'Chat, gợi ý và chỉnh lịch AI',
                  onPressed: supportsAi ? _aiAssistant : null,
                  icon: const Icon(Icons.chat_bubble_outline),
                ),
            ],
          ),
          body: doc == null
              ? const _ManualUnavailable()
              : SafeArea(
                  child: _EditorSections(screen: this, doc: doc),
                ),
        ),
      );
    },
  );
}

class _EditorSections extends StatelessWidget {
  final _ManualPlannerScreenState screen;
  final EditableTripDocumentV2 doc;
  const _EditorSections({required this.screen, required this.doc});
  @override
  Widget build(BuildContext context) {
    final planner = screen.planner, settings = screen.widget;
    final generation = planner.editorGeneration;
    void run(VoidCallback action) {
      if (planner.document != null && planner.editorGeneration == generation) {
        action();
      }
    }

    return Column(
      children: [
        if (settings.enableBudget || settings.budgetBuilder != null)
          _EditorModes(screen: screen),
        if (screen.showUnavailableWarning)
          Container(
            key: const ValueKey('destination-unavailable-warning'),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Điểm đến này không còn trong danh mục hiện tại. Hãy chọn điểm đến mới để lưu.',
                    style: TextStyle(color: Colors.brown.shade900, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: screen._input,
                  child: const Text('Đổi điểm đến'),
                ),
              ],
            ),
          ),
        Expanded(
          child: screen._budget
              ? settings.budgetBuilder != null
                    ? Column(
                        children: [
                          _EditorHeader(
                            planner: planner,
                            onInput: screen._input,
                            onAiHelp: screen._aiHelp,
                            supportsAi: screen.supportsAi,
                          ),
                          Expanded(
                            child: settings.budgetBuilder!(context, planner),
                          ),
                        ],
                      )
                    : ManualBudgetPanel(
                        planner: planner,
                        header: _EditorHeader(
                          planner: planner,
                          onInput: screen._input,
                          onAiHelp: screen._aiHelp,
                          supportsAi: screen.supportsAi,
                        ),
                        onEditExpense: (kind, id) =>
                            run(() => screen._expense(kind, id)),
                      )
              : ManualItineraryTimeline(
                  header: _EditorHeader(
                    planner: planner,
                    onInput: screen._input,
                    onAiHelp: screen._aiHelp,
                    supportsAi: screen.supportsAi,
                  ),
                  planner: planner,
                  selectedDayOrdinal: screen._ordinal,
                  onSelectDay: (n) => run(() => screen._selectDay(n)),
                  onChooseDay: () => run(() => screen._chooseDay()),
                  onAdd: (d) => run(() => screen._activity(d)),
                  onEdit: (i) => run(
                    () => screen._activity(
                      doc.days.firstWhere((d) => d.id == i.dayId),
                      item: i,
                    ),
                  ),
                  onMove: (i) => run(() => screen._chooseDay(moving: i)),
                  onDelete: (i) => run(() => screen._delete(i)),
                  onEditDayNotes: (d) => run(() => screen._notes(d)),
                ),
        ),
        if (planner.isEditable &&
            (settings.enableBudget || settings.onReviewSave != null))
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed:
                  planner.isSaving ||
                      planner.hasPendingSave ||
                      planner.state == ManualPlannerState.conflict
                  ? null
                  : () => run(() {
                      if (settings.onReviewSave != null) {
                        settings.onReviewSave!(context, planner);
                      } else {
                        screen._review();
                      }
                    }),
              child: const Text('Xem lại trước khi lưu'),
            ),
          ),
      ],
    );
  }
}

class _EditorModes extends StatelessWidget {
  final _ManualPlannerScreenState screen;
  const _EditorModes({required this.screen});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Lịch trình'),
          selected: !screen._budget,
          onSelected: (_) => screen._setBudget(false),
        ),
        ChoiceChip(
          label: const Text('Ngân sách'),
          selected: screen._budget,
          onSelected: (_) => screen._setBudget(true),
        ),
      ],
    ),
  );
}

class _EditorHeader extends StatelessWidget {
  final ManualPlannerProvider planner;
  final VoidCallback onInput;
  final VoidCallback? onAiHelp;
  final bool supportsAi;
  const _EditorHeader({
    required this.planner,
    required this.onInput,
    this.onAiHelp,
    this.supportsAi = false,
  });
  String get _status {
    if (planner.state == ManualPlannerState.readOnly) {
      return 'Bản lưu ngoại tuyến · Chỉ xem';
    }
    if (planner.isSaving) return 'Đang lưu…';
    if (planner.state == ManualPlannerState.uncertain) {
      return 'Chưa xác nhận được kết quả lưu';
    }
    if (planner.state == ManualPlannerState.conflict) {
      return 'Chuyến đi đã có thay đổi trên tài khoản';
    }
    if (planner.dirty) return 'Có thay đổi chưa lưu';
    return planner.isAccount
        ? 'Đã lưu vào tài khoản'
        : 'Đã lưu bản nháp trên máy';
  }

  @override
  Widget build(BuildContext context) {
    final input = planner.document!.input;
    final generation = planner.editorGeneration;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            input.title.isEmpty ? 'Chuyến đi chưa đặt tên' : input.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${input.destinationName ?? 'Chưa chọn điểm đến'} · ${input.travelerCount} người',
          ),
          Text(
            input.startDate == null
                ? 'Chưa chọn ngày'
                : '${input.startDate} – ${input.endDate ?? 'Chưa chọn ngày kết thúc'}',
          ),
          Semantics(liveRegion: true, child: Text(_status)),
          if (planner.errorMessage != null)
            Text(
              planner.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (planner.state == ManualPlannerState.uncertain)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: planner.isSaving
                    ? null
                    : () {
                        if (planner.editorGeneration == generation &&
                            planner.state == ManualPlannerState.uncertain) {
                          planner.retrySave();
                        }
                      },
                child: const Text('Thử lại lần lưu trước'),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: planner.isEditable ? onInput : null,
                child: const Text('Sửa thông tin'),
              ),
              if (onAiHelp != null)
                TextButton.icon(
                  onPressed: supportsAi ? onAiHelp : null,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Trợ giúp AI'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuardedManualRoute extends StatefulWidget {
  final ManualPlannerProvider planner;
  final _ManualStamp stamp;
  final Widget child;
  const _GuardedManualRoute({
    required this.planner,
    required this.stamp,
    required this.child,
  });
  @override
  State<_GuardedManualRoute> createState() => _GuardedManualRouteState();
}

class _GuardedManualRouteState extends State<_GuardedManualRoute> {
  bool _revoked = false;
  @override
  void initState() {
    super.initState();
    widget.planner.addListener(_changed);
  }

  void _changed() {
    if (!widget.stamp.workspace(widget.planner)) _revoked = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.planner.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_revoked || !widget.stamp.workspace(widget.planner)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phiên chỉnh sửa')),
        body: const SafeArea(child: _ManualUnavailable()),
      );
    }
    return ManualFormScope(
      canApply: widget.stamp.current(widget.planner),
      child: widget.child,
    );
  }
}

class _ManualUnavailable extends StatelessWidget {
  const _ManualUnavailable();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('Phiên chỉnh sửa không còn khả dụng.'),
    ),
  );
}

class _DayPicker extends StatelessWidget {
  final List<TripDay> days;
  final String selectedId;
  const _DayPicker({required this.days, required this.selectedId});
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Chọn ngày'),
    content: SizedBox(
      width: double.maxFinite,
      height: 320,
      child: ListView.builder(
        itemCount: days.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(manualDayLabel(days[index])),
          selected: days[index].id == selectedId,
          onTap: () => Navigator.pop(context, days[index].id),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
    ],
  );
}

class _DayNotesForm extends StatefulWidget {
  final TripDay day;
  const _DayNotesForm({required this.day});
  @override
  State<_DayNotesForm> createState() => _DayNotesFormState();
}

class _DayNotesFormState extends State<_DayNotesForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _notes;
  bool _dirty = false;
  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.day.notes);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManualEditFormPage(
    title: 'Ghi chú ngày ${widget.day.ordinal}',
    dirty: _dirty,
    formKey: _key,
    fields: [
      TextFormField(
        key: const ValueKey('day.notes'),
        controller: _notes,
        minLines: 3,
        maxLines: 8,
        decoration: const InputDecoration(labelText: 'Ghi chú ngày'),
        validator: (v) =>
            (v ?? '').runes.length > 2000 ? 'Tối đa 2000 ký tự Unicode.' : null,
        onChanged: (_) => setState(() => _dirty = true),
      ),
    ],
    onApply: () {
      if (ManualFormScope.allows(context) &&
          (_key.currentState?.validate() ?? false)) {
        Navigator.pop(context, _notes.text);
      }
    },
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/trip_request.dart';
import 'manual_planner_entry_screen.dart';

import '../../providers/planner_input_provider.dart';
import '../../providers/trip_provider.dart';
import '../../../trips/models/local_trip_records.dart';
import '../../../trips/models/trip_payload_codec.dart';
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

abstract class _HomePlannerInputState {
  PlanTripRequest get currentRequest;
  bool get hasPlannerInput;
  bool get hasSelectedDestination;
  bool get canReplaceWorkspace;
  TripMetadataV1 get currentMetadata;
  void updateRequest(PlanTripRequest req);
  void setCalendarRange(String start, String end);
  void applyPreset(int index);
  void setDuration(int days);
  void init();
}

class _ProviderHomeInputState implements _HomePlannerInputState {
  final PlannerInputProvider provider;
  _ProviderHomeInputState(this.provider);

  @override
  PlanTripRequest get currentRequest => provider.currentRequest;

  @override
  bool get hasPlannerInput => provider.hasPlannerInput;

  @override
  bool get hasSelectedDestination => provider.hasSelectedDestination;

  @override
  bool get canReplaceWorkspace => provider.canReplaceWorkspace;

  @override
  TripMetadataV1 get currentMetadata => provider.currentMetadata;

  @override
  void updateRequest(PlanTripRequest req) {
    provider.updateRequest(req);
  }

  @override
  void setCalendarRange(String start, String end) {
    provider.setCalendarRange(start, end);
  }

  @override
  void applyPreset(int index) {
    provider.applyPreset(index);
  }

  @override
  void setDuration(int days) {
    provider.setDuration(days);
  }

  @override
  void init() {
    provider.init();
  }
}

class _TripHomeInputState implements _HomePlannerInputState {
  final TripProvider trip;
  _TripHomeInputState(this.trip);

  @override
  PlanTripRequest get currentRequest => trip.currentRequest;

  @override
  bool get hasPlannerInput => trip.hasPlannerInput;

  @override
  bool get hasSelectedDestination => trip.hasSelectedDestination;

  @override
  bool get canReplaceWorkspace => trip.canReplaceWorkspace;

  @override
  TripMetadataV1 get currentMetadata => trip.currentMetadata;

  @override
  void updateRequest(PlanTripRequest req) {
    trip.updateRequest(req);
  }

  @override
  void setCalendarRange(String start, String end) {
    trip.setCalendarRange(start, end);
  }

  @override
  void applyPreset(int index) {
    trip.applyPreset(index);
  }

  @override
  void setDuration(int days) {
    trip.setDuration(days);
  }

  @override
  void init() {}
}

class _DefaultHomeInputState implements _HomePlannerInputState {
  @override
  PlanTripRequest get currentRequest => PlanTripRequest.presetMinh();

  @override
  bool get hasPlannerInput => true;

  @override
  bool get hasSelectedDestination => false;

  @override
  bool get canReplaceWorkspace => true;

  @override
  TripMetadataV1 get currentMetadata => TripMetadataV1();

  @override
  void updateRequest(PlanTripRequest req) {}

  @override
  void setCalendarRange(String start, String end) {}

  @override
  void applyPreset(int index) {}

  @override
  void setDuration(int days) {}

  @override
  void init() {}
}

class HomePlannerScreen extends StatefulWidget {
  const HomePlannerScreen({super.key});

  @override
  State<HomePlannerScreen> createState() => _HomePlannerScreenState();
}

class _HomePlannerScreenState extends State<HomePlannerScreen> {
  final List<String> popularOrigins = [
    'TP. Hồ Chí Minh',
    'Hà Nội',
    'Đà Nẵng',
    'Cần Thơ',
    'Hải Phòng',
  ];

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

  final Map<String, String> companionLabels = {
    'group': 'Nhóm bạn',
    'couple': 'Cặp đôi',
    'family': 'Gia đình',
    'solo': 'Một mình',
  };

  Future<void> _pickDateRange(
    BuildContext context,
    _HomePlannerInputState provider,
    PlanTripRequest req,
  ) async {
    final now = DateTime.now();
    final initialRange = req.startDate != null && req.endDate != null
        ? DateTimeRange(
            start: DateTime.tryParse(req.startDate!) ?? now,
            end: DateTime.tryParse(req.endDate!) ?? now.add(const Duration(days: 3)),
          )
        : DateTimeRange(
            start: now,
            end: now.add(Duration(days: (req.numDays - 1).clamp(0, 365))),
          );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: initialRange,
      helpText: 'Chọn khoảng ngày khởi hành',
      saveText: 'Chọn',
    );

    if (picked != null) {
      final start = DateFormat('yyyy-MM-dd').format(picked.start);
      final end = DateFormat('yyyy-MM-dd').format(picked.end);
      try {
        provider.setCalendarRange(start, end);
      } on FormatException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCustomOriginDialog(
    BuildContext context,
    _HomePlannerInputState provider,
    PlanTripRequest req,
  ) async {
    final controller = TextEditingController(text: req.origin);
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Nhập nơi xuất phát'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tỉnh / Thành phố khởi hành',
            hintText: 'Ví dụ: Nha Trang, Vũng Tàu, Huế...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      provider.updateRequest(req.copyWith(origin: result));
    }
  }

  Future<void> _showAddCustomInterestDialog(
    BuildContext context,
    _HomePlannerInputState provider,
    PlanTripRequest req,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Thêm sở thích mới'),
        content: TextField(
          key: const ValueKey('custom-interest-input'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Sở thích của bạn',
            hintText: 'Ví dụ: trekking, cà phê chill, tâm linh...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && !req.preferences.contains(result)) {
      final updated = List<String>.from(req.preferences)..add(result);
      provider.updateRequest(req.copyWith(preferences: updated));
    }
  }

  @override
  Widget build(BuildContext context) {
    PlannerInputProvider? inputProvider;
    try {
      inputProvider = context.watch<PlannerInputProvider>();
    } catch (_) {}
    TripProvider? tripProvider;
    if (inputProvider == null) {
      try {
        tripProvider = context.watch<TripProvider>();
      } catch (_) {}
    }

    final _HomePlannerInputState provider = inputProvider != null
        ? _ProviderHomeInputState(inputProvider)
        : (tripProvider != null
            ? _TripHomeInputState(tripProvider)
            : _DefaultHomeInputState());

    final req = provider.currentRequest;
    final currencyFmt = NumberFormat.currency(
      locale: 'vi',
      symbol: 'đ',
      decimalDigits: 0,
    );
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (!provider.hasPlannerInput) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lập chuyến đi')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Chưa có thông tin đầu vào cho chuyến đi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => provider.init(),
                  child: const Text('Bắt đầu chuyến đi mới'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lập chuyến đi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectedDestinationControls(
              onManualPlanner: () => openManualPlanner(context),
            ),
            // Origin Selector Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nơi xuất phát: ${req.origin}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...popularOrigins.map((city) {
                          final isSelected = req.origin == city;
                          return ChoiceChip(
                            label: Text(city),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                provider.updateRequest(req.copyWith(origin: city));
                              }
                            },
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(Icons.edit_location_alt, size: 16),
                          label: const Text('Nơi khác...'),
                          onPressed: () => _showCustomOriginDialog(context, provider, req),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Intro Header
            Text(
              provider.hasSelectedDestination
                  ? 'Thông tin chuyến đi'
                  : 'Gợi ý điểm đến tự động',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              provider.hasSelectedDestination
                  ? 'Điều chỉnh ngân sách, số ngày và sở thích trước khi bắt đầu lập lịch trình.'
                  : 'Điều chỉnh ngân sách và sở thích. Bạn có thể chọn điểm đến cụ thể ở trên hoặc để trống để tự tạo.',
              style: Theme.of(context).textTheme.bodyMedium,
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
                        'Điền nhanh thông số chuyến đi',
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
                            label: const Text('3 ngày · 4 triệu'),
                            onPressed: () => provider.applyPreset(1),
                          ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.beach_access,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                            label: const Text('4 ngày · 8 triệu'),
                            onPressed: () => provider.applyPreset(2),
                          ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.directions_bus,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                            label: const Text('2 ngày · 1,5 triệu'),
                            onPressed: () => provider.applyPreset(3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Parameters Section (Budget, Duration, Travelers)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Budget Control
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Ngân sách tối đa:',
                          style: TextStyle(fontWeight: FontWeight.w600),
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
                      value: req.budgetVnd.toDouble().clamp(500000, 100000000),
                      min: 500000,
                      max: 100000000,
                      divisions: 99,
                      onChanged: (val) {
                        provider.updateRequest(
                          req.copyWith(budgetVnd: val.toInt()),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Num Days & Calendar Date Range
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Thời gian chuyến đi:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          req.startDate != null && req.endDate != null
                              ? '${req.startDate} – ${req.endDate} (${req.numDays} ngày)'
                              : '${req.numDays} ngày',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        req.startDate != null && req.endDate != null
                            ? 'Đổi khoảng ngày trên lịch'
                            : 'Chọn khoảng ngày trên lịch',
                      ),
                      onPressed: () => _pickDateRange(context, provider, req),
                    ),
                    Slider(
                      value: req.numDays.toDouble().clamp(1, 30),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      onChanged: (val) {
                        try {
                          provider.setDuration(val.toInt());
                        } on FormatException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.message),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // Num People Slider
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Số lượng người:',
                          style: TextStyle(fontWeight: FontWeight.w600),
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
                      value: req.numPeople.toDouble().clamp(1, 20),
                      min: 1,
                      max: 20,
                      divisions: 19,
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

            // Companion Type
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đối tượng đồng hành:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: companionLabels.entries.map((entry) {
                        final isSelected = req.companionType == entry.key;
                        return ChoiceChip(
                          label: Text(entry.value),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              int people = req.numPeople;
                              if (entry.key == 'solo') people = 1;
                              if (entry.key == 'couple' && people < 2) people = 2;
                              provider.updateRequest(
                                req.copyWith(
                                  companionType: entry.key,
                                  numPeople: people,
                                ),
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
                      children: [
                        ...availablePreferences.map((pref) {
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
                        }),
                        ...req.preferences
                            .where((p) => !availablePreferences.contains(p))
                            .map((customPref) {
                          return FilterChip(
                            label: Text(customPref),
                            selected: true,
                            onSelected: (selected) {
                              final currentList = List<String>.from(req.preferences);
                              currentList.remove(customPref);
                              provider.updateRequest(
                                req.copyWith(preferences: currentList),
                              );
                            },
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('+ Thêm sở thích'),
                          onPressed: () => _showAddCustomInterestDialog(context, provider, req),
                        ),
                      ],
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

            // Primary Planning CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.canReplaceWorkspace
                    ? () => openManualPlanner(context)
                    : null,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text(
                  provider.hasSelectedDestination
                      ? 'Lập lịch trình cho ${provider.currentMetadata.destinationName ?? "điểm đến"}'
                      : 'Bắt đầu lập lịch trình',
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
}

Future<void> openManualPlanner(BuildContext context) async {
  PlannerInputProvider? input;
  try {
    input = context.read<PlannerInputProvider>();
  } catch (_) {}
  TripProvider? trip;
  if (input == null) {
    try {
      trip = context.read<TripProvider>();
    } catch (_) {}
  }
  final canReplace = input?.canReplaceWorkspace ?? trip?.canReplaceWorkspace ?? true;
  if (!canReplace) return;
  await Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const ManualPlannerEntryScreen()));
}

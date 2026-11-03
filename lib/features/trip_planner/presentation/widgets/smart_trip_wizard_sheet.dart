import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/go_ai_mascot.dart';
import '../../providers/planner_input_provider.dart';
import '../../providers/trip_provider.dart';
import '../screens/manual_planner_entry_screen.dart';

class SmartTripWizardSheet extends StatefulWidget {
  final String? initialDestinationId;
  final String? initialDestinationName;

  const SmartTripWizardSheet({
    super.key,
    this.initialDestinationId,
    this.initialDestinationName,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialDestinationId,
    String? initialDestinationName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmartTripWizardSheet(
        initialDestinationId: initialDestinationId,
        initialDestinationName: initialDestinationName,
      ),
    );
  }

  @override
  State<SmartTripWizardSheet> createState() => _SmartTripWizardSheetState();
}

class _SmartTripWizardSheetState extends State<SmartTripWizardSheet> {
  int _currentStep = 0;

  late String _destinationId;
  late String _destinationName;
  int _numDays = 3;
  String _companion = 'couple';
  int _budgetVnd = 5000000;
  final Set<String> _selectedStyles = {'Nghỉ dưỡng', 'Ẩm thực'};

  final List<Map<String, String>> _popularDestinations = const [
    {
      'id': 'da-lat',
      'name': 'Đà Lạt',
      'desc': 'Ngàn hoa & sương mù',
      'icon': '🌸',
    },
    {
      'id': 'ha-noi',
      'name': 'Hà Nội',
      'desc': '36 Phố cổ & ẩm thực',
      'icon': '🏛️',
    },
    {
      'id': 'da-nang',
      'name': 'Đà Nẵng',
      'desc': 'Cầu Vàng & biển Mỹ Khê',
      'icon': '🌉',
    },
    {
      'id': 'sa-pa',
      'name': 'Sa Pa',
      'desc': 'Săn mây & đỉnh Fansipan',
      'icon': '⛰️',
    },
    {
      'id': 'ha-long',
      'name': 'Hạ Long',
      'desc': 'Vịnh biển kỳ quan',
      'icon': '⛵',
    },
    {
      'id': 'phu-quoc',
      'name': 'Phú Quốc',
      'desc': 'Biển xanh & hoàng hôn',
      'icon': '🏝️',
    },
  ];

  @override
  void initState() {
    super.initState();
    _destinationId = widget.initialDestinationId ?? 'da-lat';
    _destinationName = widget.initialDestinationName ?? 'Đà Lạt';
    if (widget.initialDestinationId != null) {
      _currentStep = 1;
    }
  }

  void _applyToProviderAndLaunch(
    BuildContext context, {
    required bool useAiAssistant,
  }) {
    HapticFeedback.mediumImpact();

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

    int people = 2;
    if (_companion == 'solo') people = 1;
    if (_companion == 'family') people = 4;
    if (_companion == 'friends') people = 4;

    if (input != null) {
      final req = input.currentRequest.copyWith(
        numDays: _numDays,
        companionType: _companion,
        numPeople: people,
        budgetVnd: _budgetVnd,
        preferences: _selectedStyles.toList(),
      );
      input.updateRequest(req);
      input.setDestination(id: _destinationId, name: _destinationName);
    } else if (trip != null) {
      final req = trip.currentRequest.copyWith(
        numDays: _numDays,
        companionType: _companion,
        numPeople: people,
        budgetVnd: _budgetVnd,
        preferences: _selectedStyles.toList(),
      );
      trip.updateRequest(req);
      trip.prepareDestinationWorkspace(
        destinationId: _destinationId,
        destinationName: _destinationName,
        expectedWorkspaceGeneration: trip.workspaceGeneration,
      );
    }

    Navigator.pop(context);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManualPlannerEntryScreen(
          intent: useAiAssistant
              ? ManualPlannerEntryIntent.aiAssistant
              : ManualPlannerEntryIntent.edit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Stepper indicator
            _buildStepperHeader(colorScheme),

            const Divider(height: 1),

            // Content per step
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: _buildCurrentStepContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader(ColorScheme colorScheme) {
    final steps = ['Điểm đến', 'Thời gian', 'Khởi tạo'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (i) {
          final isDone = i < _currentStep;
          final isCurrent = i == _currentStep;
          final stepColor = isCurrent
              ? colorScheme.primary
              : (isDone ? colorScheme.primary.withValues(alpha: 0.8) : colorScheme.outline);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? colorScheme.primary
                      : (isDone
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest),
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check, size: 14, color: colorScheme.primary)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                steps[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: stepColor,
                ),
              ),
              if (i < steps.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    width: 20,
                    height: 1,
                    color: colorScheme.outlineVariant,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Destination(context);
      case 1:
        return _buildStep2DurationAndWho(context);
      case 2:
      default:
        return _buildStep3Launch(context);
    }
  }

  Widget _buildStep1Destination(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bạn muốn đi đâu?',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Chọn một điểm đến yêu thích để bắt đầu hành trình',
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemCount: _popularDestinations.length,
          itemBuilder: (context, index) {
            final dest = _popularDestinations[index];
            final isSelected = dest['id'] == _destinationId;

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _destinationId = dest['id']!;
                  _destinationName = dest['name']!;
                  _currentStep = 1;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                      : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dest['icon'] ?? '📍',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dest['name']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      dest['desc']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep2DurationAndWho(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencyFmt = NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thời gian & Đồng hành',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Điểm đến: $_destinationName',
          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Duration
        const Text('Số ngày đi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [2, 3, 4, 5].map((days) {
            final isSelected = _numDays == days;
            return ChoiceChip(
              label: Text('$days ngày (${days}N${days - 1}Đ)'),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _numDays = days);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Companions
        const Text('Đi cùng ai:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            {'key': 'couple', 'label': 'Cặp đôi 👩‍❤️‍👨'},
            {'key': 'friends', 'label': 'Bạn bè ⛺'},
            {'key': 'family', 'label': 'Gia đình 👨‍👩‍👧‍👦'},
            {'key': 'solo', 'label': 'Một mình 🎒'},
          ].map((entry) {
            final isSelected = _companion == entry['key'];
            return ChoiceChip(
              label: Text(entry['label']!),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _companion = entry['key']!);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Budget preset
        const Text('Ngân sách dự kiến:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            {'val': 2500000, 'label': 'Tiết kiệm (~2.5tr)'},
            {'val': 5000000, 'label': 'Tiêu chuẩn (~5.0tr)'},
            {'val': 10000000, 'label': 'Thoải mái (~10tr)'},
          ].map((tier) {
            final val = tier['val'] as int;
            final isSelected = _budgetVnd == val;
            return ChoiceChip(
              label: Text(tier['label'] as String),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _budgetVnd = val);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Navigation actions
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('Quay lại'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => setState(() => _currentStep = 2),
                child: const Text('Tiếp theo'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3Launch(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencyFmt = NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cách bạn muốn lên lịch?',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const GoAiMascot(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_destinationName · $_numDays ngày',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Dự toán: ${currencyFmt.format(_budgetVnd)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Option 1: AI Auto-Draft
        InkWell(
          onTap: () => _applyToProviderAndLaunch(context, useAiAssistant: true),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colorScheme.primary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome, color: colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Khởi tạo cùng GoAI 🪄',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI tự lên khung lịch trình sáng - trưa - tối với điểm đến nổi tiếng. Bạn chỉ việc tinh chỉnh.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colorScheme.primary),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Option 2: Manual Custom
        InkWell(
          onTap: () => _applyToProviderAndLaunch(context, useAiAssistant: false),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_calendar_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tự lên lịch trình ✏️',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mở không gian lịch trình trống để bạn tự do thêm các điểm yêu thích theo ý muốn.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colorScheme.outline),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        OutlinedButton(
          onPressed: () => setState(() => _currentStep = 1),
          child: const Text('Quay lại bước 2'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/map/models/itinerary_map_context.dart';

class ItineraryMapPanel extends StatelessWidget {
  final ItineraryMapContext itinerary;
  final int selectedDay;
  final ValueChanged<int> onDaySelected;
  final void Function(String activityKey, String placeId) onPlaceBound;
  final VoidCallback? onOpenEditor;

  const ItineraryMapPanel({
    super.key,
    required this.itinerary,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPlaceBound,
    this.onOpenEditor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = itinerary.dayNumbers;
    final activities = itinerary.activitiesForDay(selectedDay);
    final locatedCount = activities.where((a) => a.isLocated).length;
    final hasUnlocated = activities.any((a) => !a.isLocated);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Destination & Day Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lộ trình ${itinerary.destinationName}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$locatedCount/${activities.length} hoạt động có vị trí tham khảo',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onOpenEditor != null)
                  TextButton.icon(
                    onPressed: onOpenEditor,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Mở editor'),
                  ),
              ],
            ),
          ),

          // Day chips
          if (days.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: days.map((day) {
                  final isSelected = day == selectedDay;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Ngày $day'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) onDaySelected(day);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

          // Gap warning banner if some activities on this day are unlocated
          if (hasUnlocated && locatedCount >= 2) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tuyến qua các điểm có vị trí, chưa đầy đủ',
                        style: TextStyle(fontSize: 12, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Activities list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: activities.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final act = activities[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: act.isLocated
                        ? theme.colorScheme.primary
                        : Colors.grey.shade400,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    act.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        act.time,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 8),
                      if (act.resolution == 'catalogueName')
                        Text(
                          'Ghép theo tên danh mục',
                          style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                        )
                      else if (act.resolution == 'user')
                        Text(
                          'Đã liên kết thủ công',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                        )
                      else
                        Text(
                          'Chưa xác định vị trí',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                  trailing: act.isLocated
                      ? const Icon(Icons.check_circle_outline, color: Colors.green, size: 18)
                      : TextButton(
                          onPressed: () => _showPlacePicker(context, act),
                          child: const Text('Chọn địa điểm', style: TextStyle(fontSize: 12)),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPlacePicker(BuildContext context, ItineraryMapActivity act) {
    DestinationReference? matchedDestination;
    for (final dest in itinerary.snapshot.catalogue.destinations) {
      if (dest.id == itinerary.destinationId) {
        matchedDestination = dest;
        break;
      }
    }

    final availablePlaces = (matchedDestination?.places ?? const <PlaceReference>[])
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Chọn địa điểm cho "${act.title}"',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              if (availablePlaces.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Không có địa điểm nào có tọa độ trong điểm đến này.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availablePlaces.length,
                    itemBuilder: (ctx, idx) {
                      final place = availablePlaces[idx];
                      return ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(place.name),
                        subtitle: Text('${place.latitude}, ${place.longitude}'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          onPlaceBound(act.key, place.id);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

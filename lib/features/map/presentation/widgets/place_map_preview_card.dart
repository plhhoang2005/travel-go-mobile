import 'package:flutter/material.dart';
import '../../models/catalogue_map_marker.dart';

class PlaceMapPreviewCard extends StatelessWidget {
  final CatalogueMapMarker marker;
  final VoidCallback? onDetailsPressed;
  final VoidCallback? onClosePressed;

  const PlaceMapPreviewCard({
    super.key,
    required this.marker,
    this.onDetailsPressed,
    this.onClosePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: marker.isTopRated
            ? const BorderSide(color: Colors.amber, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: marker.markerColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    marker.iconData,
                    color: marker.markerColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marker.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (marker.subtitle != null && marker.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          marker.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onClosePressed != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onClosePressed,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (marker.type == MarkerType.place) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        marker.averageRating > 0
                            ? marker.averageRating.toStringAsFixed(1)
                            : 'Mới',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (marker.reviewCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${marker.reviewCount} đánh giá)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                  if (marker.isTopRated) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '⭐ Nổi Bật',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                  ],
                ] else if (marker.type == MarkerType.destination) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Điểm đến du lịch',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Lãnh thổ Việt Nam',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onDetailsPressed,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(
                    marker.type == MarkerType.destination ? 'Xem các điểm' : 'Xem chi tiết',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: marker.isTopRated ? Colors.amber.shade700 : colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

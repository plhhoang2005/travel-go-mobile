import 'package:flutter/material.dart';

import '../../../../core/presentation/travel_image.dart';
import '../../../../core/presentation/travel_media.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/catalogue_reference.dart';

class DestinationReferenceListTile extends StatelessWidget {
  final DestinationReference destination;
  final VoidCallback onTap;
  final List<String> matchingPlaces;

  const DestinationReferenceListTile({
    super.key,
    required this.destination,
    required this.onTap,
    this.matchingPlaces = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border, width: 1),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                TravelImage(
                  media: TravelMediaCatalog.fromPublished(
                        imageUrl: destination.imageUrl,
                        rights: destination.imageRights,
                        caption: destination.name,
                      ) ??
                      TravelMediaCatalog.forDestination(destination.id),
                  semanticLabel: 'Ảnh ${destination.name}',
                  height: 180,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                matchingPlaces.isEmpty
                                    ? '${destination.region} · ${destination.places.length} địa điểm tham khảo'
                                    : '${destination.region} · Khớp địa điểm: ${matchingPlaces.join(', ')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

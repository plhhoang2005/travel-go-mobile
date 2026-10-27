import 'package:flutter/material.dart';

import '../../../../core/presentation/travel_image.dart';
import '../../../../core/presentation/travel_media.dart';
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
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TravelImage(
            media:
                TravelMediaCatalog.fromPublished(
                  imageUrl: destination.imageUrl,
                  rights: destination.imageRights,
                  caption: destination.name,
                ) ??
                TravelMediaCatalog.forDestination(destination.id),
            semanticLabel: 'Ảnh ${destination.name}',
            height: 180,
          ),
          ListTile(
            contentPadding: const EdgeInsets.only(top: 8),
            title: Text(
              destination.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            subtitle: Text(
              matchingPlaces.isEmpty
                  ? '${destination.region} · ${destination.places.length} địa điểm tham khảo'
                  : '${destination.region} · Khớp địa điểm: ${matchingPlaces.join(', ')}',
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: onTap,
          ),
        ],
      ),
    ),
  );
}

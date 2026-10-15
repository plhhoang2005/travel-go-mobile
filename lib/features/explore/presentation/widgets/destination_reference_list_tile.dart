import 'package:flutter/material.dart';

import '../../models/catalogue_reference.dart';

class DestinationReferenceListTile extends StatelessWidget {
  final DestinationReference destination;
  final VoidCallback onTap;
  const DestinationReferenceListTile({
    super.key,
    required this.destination,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    leading: Icon(
      Icons.place_outlined,
      color: Theme.of(context).colorScheme.primary,
    ),
    title: Text(
      destination.name,
      style: Theme.of(context).textTheme.titleMedium,
    ),
    subtitle: Text(
      '${destination.region} · ${destination.places.length} địa điểm tham khảo',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

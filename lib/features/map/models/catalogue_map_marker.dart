import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum MarkerType {
  destination,
  place,
  sovereignty,
}

class CatalogueMapMarker {
  final String id;
  final String title;
  final LatLng point;
  final MarkerType type;
  final double averageRating;
  final int reviewCount;
  final String? subtitle;
  final String? imageUrl;
  final String? destinationId;

  const CatalogueMapMarker({
    required this.id,
    required this.title,
    required this.point,
    required this.type,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.subtitle,
    this.imageUrl,
    this.destinationId,
  });

  bool get isTopRated => type == MarkerType.place && averageRating >= 4.5;

  Color get markerColor {
    if (type == MarkerType.sovereignty) {
      return Colors.redAccent;
    }
    if (type == MarkerType.destination) {
      return Colors.deepPurple;
    }
    if (isTopRated) {
      return Colors.amber;
    }
    if (averageRating >= 3.5) {
      return Colors.teal;
    }
    return Colors.grey;
  }

  double get markerSize {
    if (type == MarkerType.destination) {
      return 42.0;
    }
    if (type == MarkerType.sovereignty) {
      return 36.0;
    }
    if (isTopRated) {
      return 38.0;
    }
    if (averageRating >= 3.5) {
      return 32.0;
    }
    return 26.0;
  }

  IconData get iconData {
    if (type == MarkerType.destination) {
      return Icons.location_city;
    }
    if (type == MarkerType.sovereignty) {
      return Icons.flag;
    }
    if (isTopRated) {
      return Icons.star;
    }
    return Icons.place;
  }
}

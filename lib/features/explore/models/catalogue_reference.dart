/// Reference inventory, separate from canonical trip payload V1 and engine DTOs.
class CatalogueReference {
  final String checkedAt;
  final List<SourceReference> sources;
  final List<DestinationReference> destinations;
  CatalogueReference({
    required this.checkedAt,
    required List<SourceReference> sources,
    required List<DestinationReference> destinations,
  }) : sources = List.unmodifiable(sources),
       destinations = List.unmodifiable(destinations);
  SourceReference source(String id) => sources.firstWhere((s) => s.id == id);
}

class SourceReference {
  final String id, title, url, publisher, checkedAt;
  const SourceReference({
    required this.id,
    required this.title,
    required this.url,
    required this.publisher,
    required this.checkedAt,
  });
}

class DestinationReference {
  final String id, name, region;
  final List<PlaceReference> places;
  final SampleReference sample;
  final String? description;
  final String? imageUrl;
  final Map<String, dynamic>? imageRights;
  final List<String> sourceRefs;

  DestinationReference({
    required this.id,
    required this.name,
    required this.region,
    required List<PlaceReference> places,
    required this.sample,
    this.description,
    this.imageUrl,
    this.imageRights,
    this.sourceRefs = const [],
  }) : places = List.unmodifiable(places);

  PlaceReference place(String id) => places.firstWhere((p) => p.id == id);
}

class PlaceReference {
  final String id, name, sourceId;
  final String? destinationId;
  final String? slug;
  final String? description;
  final String? imageUrl;
  final Map<String, dynamic>? imageRights;
  final double? latitude;
  final double? longitude;
  final List<String> sourceRefs;

  // P3.1 intentionally does not turn unknown operational facts into estimates.
  final int? priceVnd = null, durationMinutes = null;
  final String? openingHours = null;
  final Object? coordinates = null;
  final String operationalStatus = 'unknown';

  const PlaceReference({
    required this.id,
    required this.name,
    required this.sourceId,
    this.destinationId,
    this.slug,
    this.description,
    this.imageUrl,
    this.imageRights,
    this.latitude,
    this.longitude,
    this.sourceRefs = const [],
  });
}

class SampleReference {
  final String id;
  final String status = 'not_feasibility_verified';
  final EditorialReview editorialReview;
  final List<SampleDay> days;
  final List<String> warnings;

  SampleReference({
    required this.id,
    required this.editorialReview,
    required List<SampleDay> days,
    required List<String> warnings,
  }) : days = List.unmodifiable(days),
       warnings = List.unmodifiable(warnings);

  SampleReference.unavailable({this.id = 'unavailable'})
      : editorialReview = EditorialReview(
          status: 'unverified',
          reviewedAt: null,
          sourceIds: const [],
          conditions: const [],
          reviewNotes: const ['Hành trình mẫu không khả dụng'],
        ),
        days = const [],
        warnings = const ['Chưa có hành trình mẫu'];

  bool get canPreview => editorialReview.status == 'reviewed_with_conditions';
}

class EditorialReview {
  final String status;
  final String? reviewedAt;
  final List<String> sourceIds, conditions, reviewNotes;
  EditorialReview({
    required this.status,
    required this.reviewedAt,
    required List<String> sourceIds,
    required List<String> conditions,
    required List<String> reviewNotes,
  }) : sourceIds = List.unmodifiable(sourceIds),
       conditions = List.unmodifiable(conditions),
       reviewNotes = List.unmodifiable(reviewNotes);
}

class SampleDay {
  final int day;
  final List<String> placeIds;
  SampleDay({required this.day, required List<String> placeIds})
    : placeIds = List.unmodifiable(placeIds);
}

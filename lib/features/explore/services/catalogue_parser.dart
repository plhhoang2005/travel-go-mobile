import 'dart:convert';

import '../models/catalogue_reference.dart';

class CatalogueParser {
  static const regions = <String, String>{
    'ha-noi': 'Bắc',
    'ha-long': 'Bắc',
    'sa-pa': 'Bắc',
    'ninh-binh': 'Bắc',
    'hue': 'Trung',
    'da-nang': 'Trung',
    'hoi-an': 'Trung',
    'nha-trang': 'Trung',
    'da-lat': 'Tây Nguyên',
    'ho-chi-minh': 'Nam',
    'phu-quoc': 'Nam',
    'can-tho': 'Nam',
  };
  static const _publishers = <String, String>{
    'vietnam.travel': 'Viet Nam National Authority of Tourism',
    'www.vietnam.travel': 'Viet Nam National Authority of Tourism',
    'sapanapro.com': 'SAPANAPRO',
    'danangfantasticity.com': 'Da Nang Tourism Promotion Center',
    'halongbay.com.vn': 'Ha Long Bay Management Board',
  };

  CatalogueReference parse(String text) {
    final root = _map(jsonDecode(text));
    _require(
      root['schemaVersion'] is int && root['schemaVersion'] == 1,
      'schema',
    );
    _require(
      root['status'] == 'reference_data_not_deployed',
      'inventory status',
    );
    final checkedAt = _date(root['checkedAt']);
    final rights = _map(root['rights']);
    _require(
      rights['copiedDescriptions'] == false &&
          rights['copiedImages'] == false &&
          rights['distributionLicence'] == 'not_assigned' &&
          rights['sourceLicence'] == 'publisher_all_rights_reserved' &&
          rights['contentScope'] == 'factual_names_and_source_links_only',
      'rights',
    );
    final sourceIds = <String>{};
    final sources = _list(root['sources']).map((raw) {
      final source = _map(raw);
      final id = _string(source['id']);
      _require(sourceIds.add(id), 'duplicate source');
      final url = _string(source['url']);
      final uri = Uri.tryParse(url);
      _require(
        uri != null &&
            uri.scheme == 'https' &&
            _publishers.containsKey(uri.host) &&
            uri.userInfo.isEmpty &&
            uri.port == 443,
        'source URL',
      );
      final publisher = _string(source['publisher']);
      _require(publisher == _publishers[uri!.host], 'source publisher');
      return SourceReference(
        id: id,
        title: _string(source['title']),
        url: url,
        publisher: publisher,
        checkedAt: _date(source['checkedAt']),
      );
    }).toList();
    _require(sources.isNotEmpty, 'sources');
    final destinationIds = <String>{},
        placeIds = <String>{},
        sampleIds = <String>{};
    final destinations = _list(root['destinations']).map((raw) {
      final destination = _map(raw);
      final id = _string(destination['id']);
      _require(
        regions.containsKey(id) && destinationIds.add(id),
        'destination ID',
      );
      _require(
        destination['scope'] == 'destination_region' &&
            destination['routingReady'] == false,
        'destination scope',
      );
      final places = _list(destination['places']).map((rawPlace) {
        final place = _map(rawPlace);
        final placeId = _string(place['id']),
            sourceId = _string(place['sourceId']);
        _require(
          placeId.startsWith('$id/') && placeIds.add(placeId),
          'place ID',
        );
        _require(sourceIds.contains(sourceId), 'place source');
        _require(
          place['referenceStatus'] == 'name_in_official_source' &&
              place['operationalStatus'] == 'unknown',
          'place status',
        );
        for (final field in [
          'coordinates',
          'openingHours',
          'priceVnd',
          'durationMinutes',
        ]) {
          _require(
            place.containsKey(field) && place[field] == null,
            'unknown $field',
          );
        }
        return PlaceReference(
          id: placeId,
          name: _string(place['name']),
          sourceId: sourceId,
        );
      }).toList();
      _require(places.isNotEmpty, 'places');
      final localIds = places.map((p) => p.id).toSet();
      final sample = _map(destination['sample']);
      final sampleId = _string(sample['id']);
      _require(
        sampleId.startsWith('$id/') && sampleIds.add(sampleId),
        'sample ID',
      );
      _require(
        sample['kind'] == 'authored_example' &&
            sample['status'] == 'not_feasibility_verified',
        'sample status',
      );
      final days = <SampleDay>[];
      for (final rawDay in _list(sample['days'])) {
        final day = _map(rawDay);
        _require(
          day['day'] is int && day['day'] == days.length + 1,
          'sample day',
        );
        final ids = _strings(day['placeIds'], min: 1);
        _require(
          ids.toSet().length == ids.length && ids.every(localIds.contains),
          'sample places',
        );
        days.add(SampleDay(day: day['day'] as int, placeIds: ids));
      }
      _require(days.isNotEmpty, 'sample days');
      return DestinationReference(
        id: id,
        name: _string(destination['name']),
        region: regions[id]!,
        places: places,
        sample: SampleReference(
          id: sampleId,
          editorialReview: _review(sample, sourceIds),
          days: days,
          warnings: _strings(sample['warnings'], min: 2),
        ),
      );
    }).toList();
    _require(destinationIds.length == regions.length, 'missing destinations');
    return CatalogueReference(
      checkedAt: checkedAt,
      sources: sources,
      destinations: destinations,
    );
  }

  EditorialReview _review(Map<String, dynamic> sample, Set<String> sources) {
    if (!sample.containsKey('editorialReview')) {
      return EditorialReview(
        status: 'pending',
        reviewedAt: null,
        sourceIds: [],
        conditions: [],
        reviewNotes: [],
      );
    }
    final review = _map(sample['editorialReview']);
    final status = _string(review['status']);
    _require(
      status == 'pending' || status == 'reviewed_with_conditions',
      'review status',
    );
    final sourceIds = _strings(review['sourceIds']);
    final conditions = _strings(review['conditions']),
        notes = _strings(review['reviewNotes']);
    _require(
      sourceIds.toSet().length == sourceIds.length &&
          sourceIds.every(sources.contains),
      'review sources',
    );
    String? reviewedAt;
    if (status == 'pending') {
      _require(
        review.containsKey('reviewedAt') &&
            review['reviewedAt'] == null &&
            sourceIds.isEmpty &&
            conditions.isEmpty,
        'pending review',
      );
    } else {
      reviewedAt = _date(review['reviewedAt']);
      _require(
        sourceIds.isNotEmpty && conditions.isNotEmpty && notes.isNotEmpty,
        'review evidence',
      );
    }
    return EditorialReview(
      status: status,
      reviewedAt: reviewedAt,
      sourceIds: sourceIds,
      conditions: conditions,
      reviewNotes: notes,
    );
  }

  void _require(bool valid, String field) {
    if (!valid) throw FormatException('Invalid catalogue: $field');
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected object');
    }
    return value;
  }

  List<dynamic> _list(Object? value) {
    if (value is! List) throw const FormatException('Expected list');
    return value;
  }

  String _string(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Expected nonblank text');
    }
    return value;
  }

  List<String> _strings(Object? value, {int min = 0}) {
    final result = _list(value).map(_string).toList();
    _require(result.length >= min, 'list length');
    return result;
  }

  String _date(Object? value) {
    final text = _string(value);
    _require(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text), 'date format');
    final parsed = DateTime.tryParse('${text}T00:00:00Z');
    _require(
      parsed != null && parsed.toIso8601String().substring(0, 10) == text,
      'calendar date',
    );
    return text;
  }
}

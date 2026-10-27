import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/presentation/travel_media.dart';

void main() {
  group('TravelMediaCatalog.fromPublished', () {
    test('owned_media_does_not_invent_a_license_url: expect null licenseUrl', () {
      final reference = TravelMediaCatalog.fromPublished(
        imageUrl: 'https://example.com/owned-photo.jpg',
        rights: {
          'sourceUrl': 'https://example.com/gallery/1',
          'permission': 'owned',
          'credit': 'Nhiếp ảnh gia Tuấn',
          'licenseUrl': null,
        },
        caption: 'Bình minh trên đỉnh Fansipan',
      );

      expect(reference, isNotNull);
      expect(reference!.licenseUrl, isNull);
      expect(reference.author, 'Nhiếp ảnh gia Tuấn');
      expect(reference.sourceUrl, 'https://example.com/gallery/1');
      expect(reference.declaredPermission, 'owned');
      expect(reference.license, contains('Bản quyền tác giả'));
      expect(reference.caption, 'Bình minh trên đỉnh Fansipan');
    });

    test('licensed without licenseUrl yields null', () {
      final reference = TravelMediaCatalog.fromPublished(
        imageUrl: 'https://example.com/licensed-photo.jpg',
        rights: {
          'sourceUrl': 'https://example.com/photo/2',
          'permission': 'licensed',
          'credit': 'Stock Photo Co',
          'licenseUrl': null, // missing required licenseUrl for licensed media
        },
        caption: 'Biển Mỹ Khê',
      );

      expect(reference, isNull);
    });

    test('licensed with valid licenseUrl populates licenseUrl correctly', () {
      final reference = TravelMediaCatalog.fromPublished(
        imageUrl: 'https://example.com/licensed-photo.jpg',
        rights: {
          'sourceUrl': 'https://example.com/photo/2',
          'permission': 'licensed',
          'credit': 'Creative Commons Author',
          'licenseUrl': 'https://creativecommons.org/licenses/by/4.0/',
        },
        caption: 'Cầu Rồng Đà Nẵng',
      );

      expect(reference, isNotNull);
      expect(reference!.licenseUrl, 'https://creativecommons.org/licenses/by/4.0/');
      expect(reference.author, 'Creative Commons Author');
      expect(reference.declaredPermission, 'licensed');
    });

    test('public domain permission populates attribution cleanly', () {
      final reference = TravelMediaCatalog.fromPublished(
        imageUrl: 'https://example.com/pd-photo.jpg',
        rights: {
          'sourceUrl': 'https://commons.wikimedia.org/wiki/File:Example.jpg',
          'permission': 'public_domain',
          'credit': 'Lưu trữ quốc gia',
          'licenseUrl': null,
        },
        caption: 'Hồ Hoàn Kiếm xưa',
      );

      expect(reference, isNotNull);
      expect(reference!.declaredPermission, 'public_domain');
      expect(reference.license, contains('Phạm vi công cộng'));
    });

    test('missing imageUrl or rights returns null placeholder signal', () {
      expect(
        TravelMediaCatalog.fromPublished(
          imageUrl: null,
          rights: {
            'sourceUrl': 'https://example.com',
            'permission': 'owned',
            'credit': 'Author',
          },
          caption: 'Caption',
        ),
        isNull,
      );

      expect(
        TravelMediaCatalog.fromPublished(
          imageUrl: 'https://example.com/photo.jpg',
          rights: null,
          caption: 'Caption',
        ),
        isNull,
      );

      expect(
        TravelMediaCatalog.fromPublished(
          imageUrl: '',
          rights: {},
          caption: 'Caption',
        ),
        isNull,
      );
    });
  });
}

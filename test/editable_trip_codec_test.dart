import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';

void main() {
  final vectors = (jsonDecode(
    File('test/fixtures/editable_trip_v2_vectors.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  for (final vector in vectors) {
    test('contract vector ${vector['id']}', () {
      final text = vector['rawText'] as String;
      if (vector.containsKey('expectedError')) {
        expect(
          () => EditableTripCodec.decode(text),
          throwsA(
            isA<EditableCodecException>().having(
              (e) => e.code,
              'code',
              vector['expectedError'],
            ),
          ),
        );
      } else {
        final doc = EditableTripCodec.decode(text);
        expect(EditableTripCodec.encode(doc), vector['canonicalText']);
        expect(
          EditableTripCodec.digestText(text),
          sha256.convert(utf8.encode(text)).toString(),
        );
        expect(EditableTripCodec.digestText(text), vector['expectedDigest']);
        expect(doc.estimates.last.unitAmountVnd, isNull);
        expect(doc.input.totalBudgetVnd, 500000);
        expect(() => doc.days.clear(), throwsUnsupportedError);
        expect(() => doc.input.interests.clear(), throwsUnsupportedError);
        expect(
          () => TripPayloadCodec.decode(text),
          throwsA(isA<TripPayloadException>()),
        );
      }
    });
  }
  final text = vectors.first['rawText'] as String;
  test(
    'reject integer lexical tricks, duplicate nested keys and bad Unicode',
    () {
      for (final bad in [
        text.replaceFirst('"totalBudgetVnd":500000', '"totalBudgetVnd":5e5'),
        text.replaceFirst('"totalBudgetVnd":500000', '"totalBudgetVnd":-1'),
        text.replaceFirst('"title":"Chuyến đi Huế"', '"title":"A","title":"B"'),
        text.replaceFirst('"title":"Chuyến đi Huế"', r'"title":"\ud800"'),
        text.replaceFirst('"timezone":"Asia/Ho_Chi_Minh"', '"timezone":"UTC"'),
        text.replaceFirst(
          '"totalBudgetVnd":500000',
          '"totalBudgetVnd":9007199254740992',
        ),
      ]) {
        expect(
          () => EditableTripCodec.decode(bad),
          throwsA(isA<EditableCodecException>()),
        );
      }
      expect(
        () => EditableTripCodec.decode(' ' * (1024 * 1024 + 1)),
        throwsA(isA<EditableCodecException>()),
      );
    },
  );
  test('zero stays known and boundary integer is preserved', () {
    final zero = EditableTripCodec.decode(
      text.replaceFirst('"totalBudgetVnd":500000', '"totalBudgetVnd":0'),
    );
    expect(zero.input.totalBudgetVnd, 0);
    final max = EditableTripCodec.decode(
      text.replaceFirst(
        '"totalBudgetVnd":500000',
        '"totalBudgetVnd":9007199254740991',
      ),
    );
    expect(max.input.totalBudgetVnd, 9007199254740991);
  });
  test('strict request parser rejects depth and signed integer overflow', () {
    expect(
      () => EditableTripCodec.parseStrict('-9223372036854775808'),
      throwsA(isA<EditableCodecException>()),
    );
    expect(
      () => EditableTripCodec.parseStrict('${'[' * 34}0${']' * 34}'),
      throwsA(isA<EditableCodecException>()),
    );
    expect(
      () => EditableTripCodec.decode(
        text.replaceFirst(
          '"schemaVersion":2',
          '"extra":true,"schemaVersion":2',
        ),
      ),
      throwsA(isA<EditableCodecException>()),
    );
  });

  test('dynamic destination support accepts arbitrary valid slug IDs beyond initial 12 seed', () {
    expect(EditableTripCodec.isValidDestinationId('quy-nhon'), isTrue);
    expect(EditableTripCodec.isValidDestinationId('vung-tau'), isTrue);
    expect(EditableTripCodec.isValidDestinationId('phan-thiet'), isTrue);
    expect(EditableTripCodec.isValidDestinationId('con-dao'), isTrue);
    expect(EditableTripCodec.isValidDestinationId('ha-noi'), isTrue);
    expect(EditableTripCodec.destinations.contains('ha-noi'), isTrue);
    expect(EditableTripCodec.isValidDestinationId('INVALID UPPERCASE'), isFalse);
    expect(EditableTripCodec.isValidDestinationId('has space'), isFalse);
    expect(EditableTripCodec.isValidDestinationId(''), isFalse);
  });
}

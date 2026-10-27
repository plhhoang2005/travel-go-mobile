import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';

void main() {
  const sampleLiveJson = {
    'winnerId': 'mang-den',
    'topDestinations': [],
    'transportOptions': [
      {
        'mode': 'may_bay',
        'displayName': 'Máy bay khứ hồi (Vietnam Airlines / Vietjet Air)',
        'priceTotalVnd': 1542492,
        'durationHours': 1.6,
        'comfortScore': 9,
        'tradeoffType': 'fastest',
        'recommendationReason': 'Nhanh nhất, tiết kiệm thời gian di chuyển.',
        'paretoOptimal': true,
      },
      {
        'mode': 'tau_lua',
        'displayName': 'Tàu hỏa (Ghế mềm điều hòa Đường Sắt Việt Nam)',
        'priceTotalVnd': 601160,
        'durationHours': 10.1,
        'comfortScore': 8,
        'tradeoffType': 'balanced',
        'recommendationReason': 'Cân bằng hoàn hảo giữa giá tiền, thời gian và sự thoải mái.',
        'paretoOptimal': true,
      },
      {
        'mode': 'xe_khach',
        'displayName': 'Xe khách giường nằm Limousine cao cấp',
        'priceTotalVnd': 382662,
        'durationHours': 11.3,
        'comfortScore': 7,
        'tradeoffType': 'cheapest',
        'recommendationReason': 'Giá rẻ nhất, tiết kiệm tối đa ngân sách di chuyển.',
        'paretoOptimal': true,
      },
    ],
    'itineraryDays': [],
    'aiExplanation': 'Thuyết minh mẫu',
    'dataSources': {'weather': 'LIVE: Open-Meteo API', 'prices': 'TravelGO Reference Dataset'},
    'assumptions': ['Mẫu giả định'],
  };

  group('Decision Engine TransportOption Parser (DE-01)', () {
    test('live server paretoOptimal: true survives parsing', () {
      final res = PlanTripResponse.fromJson(sampleLiveJson);
      expect(res.transportOptions.length, 3);
      expect(res.transportOptions.map((o) => o.isParetoOptimal).toList(), [true, true, true]);
    });

    test('reads from live captured JSON file if present on disk', () {
      const livePath = 'C:/Users/ASUS/.codex/visualizations/2026/10/08/01a11ade-4b35-7870-bd4f-33e3eb3f9a57/DECISION_ENGINE_LIVE_0ee468f.json';
      final file = File(livePath);
      if (file.existsSync()) {
        final content = file.readAsStringSync().replaceFirst('\uFEFF', '');
        final raw = jsonDecode(content) as Map<String, dynamic>;
        final parsed = PlanTripResponse.fromJson(raw);
        final rawFlags = (raw['transportOptions'] as List)
            .map((v) {
              final m = v as Map;
              return m['paretoOptimal'] ?? m['isParetoOptimal'];
            })
            .toList();
        expect(parsed.transportOptions.map((v) => v.isParetoOptimal).toList(), rawFlags);
      }
    });

    test('preserves explicit paretoOptimal: false and does not force true', () {
      final opt = TransportOption.fromJson({
        'mode': 'xe_om',
        'displayName': 'Xe ôm công nghệ',
        'priceTotalVnd': 500000,
        'durationHours': 5.0,
        'comfortScore': 3,
        'paretoOptimal': false,
      });
      expect(opt.isParetoOptimal, isFalse);
    });

    test('backward compatibility: supports legacy isParetoOptimal: true', () {
      final opt = TransportOption.fromJson({
        'mode': 'tau_thuy',
        'displayName': 'Tàu cao tốc',
        'priceTotalVnd': 350000,
        'durationHours': 2.0,
        'comfortScore': 8,
        'isParetoOptimal': true,
      });
      expect(opt.isParetoOptimal, isTrue);
    });

    test('precedence: paretoOptimal wire format takes precedence over legacy key', () {
      final opt1 = TransportOption.fromJson({
        'mode': 'may_bay',
        'displayName': 'Chuyến bay A',
        'priceTotalVnd': 1000000,
        'durationHours': 2.0,
        'comfortScore': 9,
        'paretoOptimal': false,
        'isParetoOptimal': true,
      });
      expect(opt1.isParetoOptimal, isFalse, reason: 'paretoOptimal: false must take precedence');

      final opt2 = TransportOption.fromJson({
        'mode': 'may_bay',
        'displayName': 'Chuyến bay B',
        'priceTotalVnd': 1000000,
        'durationHours': 2.0,
        'comfortScore': 9,
        'paretoOptimal': true,
        'isParetoOptimal': false,
      });
      expect(opt2.isParetoOptimal, isTrue, reason: 'paretoOptimal: true must take precedence');
    });

    test('missing or null fields default safely to false', () {
      final optMissing = TransportOption.fromJson({
        'mode': 'di_bo',
        'displayName': 'Đi bộ',
      });
      expect(optMissing.isParetoOptimal, isFalse);

      final optNull = TransportOption.fromJson({
        'mode': 'di_bo',
        'displayName': 'Đi bộ',
        'paretoOptimal': null,
        'isParetoOptimal': null,
      });
      expect(optNull.isParetoOptimal, isFalse);
    });
  });
}

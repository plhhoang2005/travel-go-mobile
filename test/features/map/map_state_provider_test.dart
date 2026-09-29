import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/map/providers/map_state_provider.dart';

void main() {
  test('Initial state should have owl mascot', () {
    final provider = MapStateProvider();
    expect(provider.activeMascot, MascotType.owl);
  });
}

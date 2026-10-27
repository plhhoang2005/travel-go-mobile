import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/constants/supabase_constants.dart';

void main() {
  test('build target selects one project and never borrows the other key', () {
    const target = String.fromEnvironment(
      'TRAVELGO_ENV',
      defaultValue: 'staging',
    );
    const stagingKey = String.fromEnvironment(
      'TRAVELGO_STAGING_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_Rs5bXpcVG848C2bxgWZVRQ_x8g-rSK-',
    );
    switch (target) {
      case 'production':
        expect(SupabaseConstants.isStaging, isFalse);
        expect(
          SupabaseConstants.projectUrl,
          'https://oavbymauorhmrjcustzw.supabase.co',
        );
        expect(SupabaseConstants.publishableKey.isNotEmpty, isTrue);
      case 'staging':
        expect(SupabaseConstants.isStaging, isTrue);
        expect(
          SupabaseConstants.projectUrl,
          'https://bkocylxbuyvdgxccpixx.supabase.co',
        );
        if (RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(stagingKey)) {
          // Boolean comparison avoids including a configured key in diagnostics.
          expect(SupabaseConstants.publishableKey == stagingKey, isTrue);
        } else {
          expect(() => SupabaseConstants.publishableKey, throwsStateError);
        }
      default:
        expect(() => SupabaseConstants.projectUrl, throwsStateError);
        expect(() => SupabaseConstants.publishableKey, throwsStateError);
    }
  });
}

class SupabaseConstants {
  SupabaseConstants._();

  /// Supabase Project URL for TravelGO Mobile
  static const String _productionUrl =
      'https://oavbymauorhmrjcustzw.supabase.co';
  static const String _stagingUrl = 'https://bkocylxbuyvdgxccpixx.supabase.co';
  static const String _target = String.fromEnvironment(
    'TRAVELGO_ENV',
    defaultValue: 'production',
  );
  static const String _stagingPublishableKey = String.fromEnvironment(
    'TRAVELGO_STAGING_PUBLISHABLE_KEY',
  );

  static bool get isStaging => _target == 'staging';

  static String get projectUrl => switch (_target) {
    'production' => _productionUrl,
    'staging' => _stagingUrl,
    _ => throw StateError('Unsupported Supabase build target.'),
  };

  static String get publishableKey {
    switch (_target) {
      case 'production':
        return _productionPublishableKey;
      case 'staging':
        if (!RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$')
            .hasMatch(_stagingPublishableKey)) {
          throw StateError('Staging publishable key is missing or invalid.');
        }
        return _stagingPublishableKey;
      default:
        throw StateError('Unsupported Supabase build target.');
    }
  }

  /// Supabase Client-safe Publishable (anon) API Key
  static const String _productionPublishableKey =
      'sb_publishable_AjJEOG5jNVHkpdd1Tu-gmQ_jbJn93xB';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:thumb_biomech_monitor_glove/core/config/supabase_config.dart';
import 'package:thumb_biomech_monitor_glove/core/errors/supabase_exceptions.dart';

void main() {
  group('SupabaseConfig', () {
    test('1. Rejects missing Supabase URL', () {
      const config = SupabaseConfig(url: '', anonKey: 'anon-key-sample');

      expect(config.isConfigured, isFalse);
      expect(
        () => config.validate(),
        throwsA(
          isA<SupabaseConfigException>().having(
            (e) => e.message,
            'message',
            contains('Missing Supabase URL'),
          ),
        ),
      );
    });

    test('2. Rejects missing publishable/anon key', () {
      const config = SupabaseConfig(
        url: 'https://example.supabase.co',
        anonKey: '',
      );

      expect(config.isConfigured, isFalse);
      expect(
        () => config.validate(),
        throwsA(
          isA<SupabaseConfigException>().having(
            (e) => e.message,
            'message',
            contains('Missing Supabase publishable/anon key'),
          ),
        ),
      );
    });

    test('2b. Rejects malformed URL', () {
      const config = SupabaseConfig(
        url: 'not-a-valid-url',
        anonKey: 'sample-key',
      );

      expect(config.isConfigured, isFalse);
      expect(
        () => config.validate(),
        throwsA(
          isA<SupabaseConfigException>().having(
            (e) => e.message,
            'message',
            contains('Invalid Supabase URL'),
          ),
        ),
      );
    });

    test('3. Accepts valid configuration', () {
      const config = SupabaseConfig(
        url: 'https://xyzcompany.supabase.co',
        anonKey: 'valid-public-anon-key-12345',
      );

      expect(config.isConfigured, isTrue);
      expect(config.url, 'https://xyzcompany.supabase.co');
      expect(config.anonKey, 'valid-public-anon-key-12345');
      expect(() => config.validate(), returnsNormally);
    });

    test('4. Defaults to unconfigured when environment defines are absent', () {
      const config = SupabaseConfig();
      expect(config.isConfigured, isFalse);
      expect(config.url, SupabaseConfig.defaultProjectUrl);
      expect(config.url, 'https://sbwpabepmshbxsbxjddf.supabase.co');
      expect(config.anonKey, isEmpty);
    });

    test('5. Accepts publishableKey parameter alias', () {
      const config = SupabaseConfig(
        publishableKey: 'sb_pub_test_key_123',
      );
      expect(config.url, SupabaseConfig.defaultProjectUrl);
      expect(config.anonKey, 'sb_pub_test_key_123');
      expect(config.publishableKey, 'sb_pub_test_key_123');
      expect(config.isConfigured, isTrue);
    });
  });
}

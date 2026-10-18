/// The badge has to tell whoever holds the phone which server it is talking to.
///
/// WHAT THIS CLOSES
/// ----------------
/// The label was derived from whichever non-production marker matched, by
/// stripping dots and upper-casing it. That reads correctly for exactly one
/// marker -- 'dev.' was special-cased to 'QA' -- and produces nonsense for
/// the rest.
///
/// Observed on an Android 14 emulator running the QA build against the real
/// QA backend: the badge read **RAILWAYAPP**. A tester seeing that cannot
/// tell whether they are on QA or production, which is the single question
/// the badge exists to answer. A loopback build would have announced itself
/// as '127001'.
///
/// The markers themselves are asserted too: the QA backend is served from a
/// railway.app hostname, and 'qa.' does not match 'backend-qa-811d' -- hyphen,
/// not dot -- so a release build aimed at the real QA server was classified as
/// production by both the guard and the badge.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/core/app_config.dart';

void main() {
  group('a railway.app host is recognised as non-production', () {
    test('a release build pointed at the QA backend is refused', () {
      final refusal = AppConfig.evaluate(
        isProduction: true,
        allowNonProductionHost: false,
        api: 'https://backend-qa-811d.up.railway.app/api/v1',
        ws: 'wss://backend-qa-811d.up.railway.app/ws',
      );

      expect(refusal, isNotNull,
          reason: 'this is the real QA server; shipping it would be a '
              'release build talking to QA data');
      expect(refusal, contains('non-production'));
    });

    test('the opt-in still allows a deliberate QA build', () {
      expect(
        AppConfig.evaluate(
          isProduction: true,
          allowNonProductionHost: true,
          api: 'https://backend-qa-811d.up.railway.app/api/v1',
          ws: 'wss://backend-qa-811d.up.railway.app/ws',
        ),
        isNull,
      );
    });

    test('production is still accepted', () {
      expect(
        AppConfig.evaluate(
          isProduction: true,
          allowNonProductionHost: false,
          api: 'https://api.saaradhigo.in/api/v1',
          ws: 'wss://api.saaradhigo.in/ws',
        ),
        isNull,
      );
    });
  });

  group('the badge label is something a tester can act on', () {
    test('every non-production marker maps to a readable label', () {
      // The mapping is what the badge renders. Anything derived from the
      // marker string itself is how 'RAILWAYAPP' happened.
      const expected = <String, String>{
        'dev.': 'QA',
        'qa.': 'QA',
        'railway.app': 'QA',
        'staging.': 'STAGING',
        'localhost': 'LOCAL',
        '127.0.0.1': 'LOCAL',
        '10.0.2.2': 'LOCAL',
      };

      for (final entry in expected.entries) {
        expect(
          AppConfig.labelForHost('https://host-${entry.key}-x/api/v1'),
          entry.value,
          reason: '${entry.key} should read as ${entry.value}',
        );
      }
    });

    test('no label is a mangled marker', () {
      for (final host in const [
        'https://backend-qa-811d.up.railway.app/api/v1',
        'http://127.0.0.1:8000/api/v1',
        'http://10.0.2.2:8000/api/v1',
      ]) {
        final label = AppConfig.labelForHost(host);
        expect(label, isNot('RAILWAYAPP'));
        expect(label, isNot('127001'));
        expect(label, isNot('10022'));
        expect(label, isNot(contains('.')));
      }
    });

    test('a production host reads PRODUCTION', () {
      expect(
        AppConfig.labelForHost('https://api.saaradhigo.in/api/v1'),
        'PRODUCTION',
      );
    });

    test('an unconfigured build says so rather than claiming production', () {
      expect(AppConfig.labelForHost(''), 'UNCONFIGURED');
    });
  });
}

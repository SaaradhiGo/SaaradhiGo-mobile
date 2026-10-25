/// A release build must know which server it talks to, or refuse to run —
/// and a QA acceptance build must still be possible.
///
/// `AppConfig.misconfiguration` already refused a release build with no
/// `BASE_URL`, and one pointed at a non-production host. That second rule had
/// a consequence nobody had hit yet: a **QA acceptance APK is a release build
/// pointed at QA**, so the guard refused exactly the artifact QA needs to
/// certify. The alternative — certifying a debug binary — tests different
/// code: no minification, no shrinking, no release signing.
///
/// `ALLOW_NON_PRODUCTION_HOST` is the compile-time opt-in for that one case.
/// These tests cover it, and cover what it must NOT excuse.
///
/// `evaluate()` takes its inputs explicitly because `misconfiguration` reads
/// compile-time constants — `dart.vm.product` is false under `flutter test` —
/// so the release branches could otherwise only be exercised by building a
/// release binary and looking at it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/core/app_config.dart';

const _prodApi = 'https://api.saaradhigo.com/api/v1';
const _prodWs = 'wss://api.saaradhigo.com/ws';
const _qaApi = 'https://backend-qa-811d.up.railway.app/api/v1';
const _qaWs = 'wss://backend-qa-811d.up.railway.app/ws';

String? evaluate({
  bool isProduction = true,
  bool allowNonProductionHost = false,
  String api = _prodApi,
  String ws = _prodWs,
}) =>
    AppConfig.evaluate(
      isProduction: isProduction,
      allowNonProductionHost: allowNonProductionHost,
      api: api,
      ws: ws,
    );

void main() {
  group('a debug build may point anywhere', () {
    test('no complaint, whatever it is pointed at', () {
      expect(evaluate(isProduction: false, api: _qaApi, ws: _qaWs), isNull);
      expect(evaluate(isProduction: false, api: '', ws: ''), isNull);
    });
  });

  group('a release build with nothing configured', () {
    test('is refused, and names the defines it wants', () {
      final problem = evaluate(api: '', ws: '');

      expect(problem, isNotNull);
      expect(problem, contains('BASE_URL'));
      expect(problem, contains('WS_BASE_URL'));
    });

    test('is refused when only the websocket is missing', () {
      expect(evaluate(ws: ''), isNotNull);
    });

    test('is refused even with the QA opt-in set', () {
      // The opt-in means "QA on purpose", not "no host at all". An
      // unconfigured release build is a mistake in every environment.
      expect(evaluate(allowNonProductionHost: true, api: '', ws: ''),
          contains('BASE_URL'));
    });
  });

  group('a release build pointed at a non-production host', () {
    test('is refused for every marker', () {
      for (final host in const [
        'https://dev.api.saaradhigo.com/api/v1',
        'https://staging.api.saaradhigo.com/api/v1',
        'https://qa.api.saaradhigo.com/api/v1',
        'http://localhost:8000/api/v1',
        'http://127.0.0.1:8000/api/v1',
        'http://10.0.2.2:8000/api/v1',
      ]) {
        expect(evaluate(api: host), isNotNull,
            reason: 'a store build must not ship pointed at $host');
      }
    });

    test('is refused when only the websocket is non-production', () {
      // Checked as a pair: production REST with a dev socket is a real and
      // very confusing half-configuration.
      expect(evaluate(ws: _qaWs), isNotNull);
    });

    test('names the marker it objected to', () {
      // It used to assert 'dev.', which was the marker that matched the old
      // QA host dev.api.saaradhigo.in. QA now answers on a Railway hostname,
      // so the marker is 'railway.app'. The point of the test is that the
      // message names WHY the build was refused rather than just refusing --
      // an engineer reading a crash needs to know which rule they tripped.
      expect(evaluate(api: _qaApi), contains('railway.app'));
      // And a host matching an older marker still names that one.
      expect(evaluate(api: 'https://dev.api.saaradhigo.com/api/v1'),
          contains('dev.'));
    });
  });

  group('the deliberate QA release build', () {
    test('is allowed when the opt-in is set', () {
      expect(evaluate(allowNonProductionHost: true, api: _qaApi, ws: _qaWs),
          isNull);
    });

    test('a production build is unaffected either way', () {
      expect(evaluate(), isNull);
      expect(evaluate(allowNonProductionHost: true), isNull);
    });
  });

  group('the opt-in cannot be acquired after the build', () {
    test('it is off unless compiled in', () {
      // bool.fromEnvironment is compile-time: nothing at runtime can set it,
      // which is what makes shipping the flag safe at all.
      expect(AppConfig.allowNonProductionHost, isFalse);
    });
  });

  group('the badge still says QA', () {
    test('a QA host is labelled QA, so the opt-in cannot hide itself', () {
      // The whole safety of the opt-in rests on the build being visibly
      // non-production on every screen.
      expect(AppConfig.environmentLabel, 'QA');
      expect(AppConfig.showEnvironmentBadge, isTrue);
    });
  });
}

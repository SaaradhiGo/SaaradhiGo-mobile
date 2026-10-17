/// Nothing a log line carries may be a credential.
///
/// THE DEFECT THIS CLOSES
/// ----------------------
/// `ride_service.dart` called `debugPrint(response.body)` on the response
/// from `POST /payments/create-order/`. That body carries the Cashfree
/// **`payment_session_id`** -- the credential the checkout SDK opens a
/// payment with -- so a payment session was written into logcat, where any
/// app with log access on a rooted or shared handset can read it. Two more
/// call sites interpolated `${response.body}` for payment and wallet
/// top-up errors.
///
/// Matching is by key-name SUBSTRING on purpose. The driver app's
/// interceptor used an exact list, it did not contain `fcm_token`, and a push
/// token was logged in full the moment the app began registering rotated
/// tokens. The backend's own filter says the same: exact enumeration "would
/// inevitably miss one".
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/utils/log_redaction.dart';

void main() {
  group('keys that must never be logged', () {
    test('the payment session id -- the one that was leaking', () {
      expect(isSensitiveLogKey('payment_session_id'), isTrue);
      expect(isSensitiveLogKey('paymentSessionId'), isTrue);
    });

    test('every token-shaped key', () {
      for (final key in [
        'token',
        'access_token',
        'refresh_token',
        'fcm_token',
        'device_token',
        'order_token',
        'id_token',
      ]) {
        expect(isSensitiveLogKey(key), isTrue, reason: '"$key" would leak');
      }
    });

    test('credentials and secrets', () {
      for (final key in [
        'password',
        'otp',
        'authorization',
        'client_secret',
        'api_key',
        'signature',
        'cvv',
        'card_number',
      ]) {
        expect(isSensitiveLogKey(key), isTrue, reason: '"$key" would leak');
      }
    });
  });

  group('what must still be loggable', () {
    test('ordinary fields survive, because diagnostics are the point', () {
      for (final key in [
        'trip_id',
        'order_id',
        'status',
        'amount',
        'currency',
        'estimated_fare',
        'distance_km',
      ]) {
        expect(
          isSensitiveLogKey(key),
          isFalse,
          reason: '"$key" carries no credential',
        );
      }
    });

    test('a rate card id is not mistaken for a payment card', () {
      // Over-redaction looks like privacy while destroying the provenance a
      // fare dispute needs.
      expect(isSensitiveLogKey('rate_card_id'), isFalse);
      expect(isSensitiveLogKey('rate_card_version'), isFalse);
    });
  });

  group('redacting a body', () {
    test('a payment order response keeps its ids and loses its session', () {
      final body = jsonEncode({
        'status': 'success',
        'data': {
          'order_id': 'order_8831',
          'payment_session_id': 'session_SECRETVALUE_123',
          'amount': '192.00',
          'currency': 'INR',
        },
      });

      final redacted = redactedBody(body);

      expect(redacted, isNot(contains('session_SECRETVALUE_123')));
      expect(redacted, contains('[REDACTED]'));
      // The diagnostics worth having are still there.
      expect(redacted, contains('order_8831'));
      expect(redacted, contains('192.00'));
    });

    test('nested credentials are reached', () {
      final body = jsonEncode({
        'data': {
          'gateway': {
            'payment_session_id': 'deep_SECRET',
            'order_id': 'order_1',
          },
        },
      });

      final redacted = redactedBody(body);

      expect(redacted, isNot(contains('deep_SECRET')));
      expect(redacted, contains('order_1'));
    });

    test('credentials inside a list are reached', () {
      final body = jsonEncode({
        'results': [
          {'token': 'LIST_SECRET', 'id': 1},
        ],
      });

      expect(redactedBody(body), isNot(contains('LIST_SECRET')));
    });

    test('a non-JSON body is not logged verbatim', () {
      // An unparseable body is exactly the case where logging it is most
      // likely to spill something -- an HTML error page from a proxy, for
      // instance, which can carry a session cookie.
      final redacted = redactedBody('<html>Set-Cookie: session=abc</html>');

      expect(redacted, isNot(contains('abc')));
      expect(redacted, contains('not JSON'));
    });

    test('an empty or null body says so', () {
      expect(redactedBody(null), '<empty>');
      expect(redactedBody(''), '<empty>');
    });

    test('a very long body is truncated', () {
      final body = jsonEncode({
        'results': List.generate(200, (i) => {'id': i, 'name': 'row $i'}),
      });

      final redacted = redactedBody(body, maxLength: 200);

      expect(redacted.length, lessThan(260));
      expect(redacted, contains('truncated'));
    });

    test('deep nesting cannot recurse forever', () {
      Map<String, Object> nest(int depth) =>
          depth == 0 ? {'leaf': 1} : {'next': nest(depth - 1)};

      expect(() => redactedBody(jsonEncode(nest(50))), returnsNormally);
    });
  });

  group('no raw body reaches a log line anywhere in the app', () {
    test('lib/ interpolates no response body into a log', () {
      // A structural guard: the defect was three separate call sites, and
      // the fourth would have been just as easy to add.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('log_redaction.dart')) continue;
        final lines = entity.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          final logsRawBody =
              (line.contains('debugPrint') || line.contains('print(')) &&
              (line.contains(r'${response.body}') ||
                  line.contains('debugPrint(response.body)'));
          if (logsRawBody) offenders.add('${entity.path}:${i + 1}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'these log a raw response body, which can carry a payment '
            'session or a token: $offenders',
      );
    });
  });
}

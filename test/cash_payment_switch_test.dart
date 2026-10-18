/// Choosing cash is a server action, and it is not a payment.
///
/// THE DEFECT THIS CLOSES
/// ----------------------
/// "Pay with Cash instead?" was `context.push('/rate-driver')` and nothing
/// else. No API call: the trip's payment stayed exactly as it was -- usually
/// an online payment row in `pending` -- while the rider was moved on as
/// though the fare were handled. Nobody owed anything on the record, the
/// driver had no cash payment to confirm, and the trip never settled.
///
/// WHAT "DONE" MEANS HERE
/// ---------------------
/// `POST /payments/switch/` writes a PENDING cash payment. The money has not
/// moved; the DRIVER confirms collection afterwards. So the best outcome this
/// code can report is `awaitingCollection` -- never "paid".
///
/// AND WHY RETRIES ARE THE DELICATE PART
/// -------------------------------------
/// The endpoint is NOT idempotent: each accepted call marks the current
/// payment row failed and creates a replacement. A blind retry after a
/// timeout that had actually succeeded leaves two payment rows behind. So a
/// retry is only ever sent after a READ has proven the first attempt did not
/// land, and several tests below exist purely to pin that down.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `{status: success, data: {...}}`, the envelope `success_response` sends.
http.Response _ok(Map<String, dynamic> data) => http.Response(
  jsonEncode({'status': 'success', 'data': data}),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _error(int status, String code, String message) => http.Response(
  jsonEncode({
    'status': 'error',
    'error': {'code': code, 'message': message},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

/// A client that answers the switch POST and the verification GET separately,
/// and records every request it was given.
MockClient _client({
  required List<http.BaseRequest> log,
  required Future<http.Response> Function(int attempt) onSwitch,
  Future<http.Response> Function(int attempt)? onVerify,
}) {
  var switches = 0;
  var verifies = 0;
  return MockClient((request) async {
    log.add(request);
    if (request.url.path.endsWith('/payments/switch/')) {
      switches++;
      return onSwitch(switches);
    }
    verifies++;
    if (onVerify == null) {
      return _error(404, 'NOT_FOUND', 'no verification stubbed');
    }
    return onVerify(verifies);
  });
}

int _countSwitches(List<http.BaseRequest> log) => log
    .where((r) => r.url.path.endsWith('/payments/switch/'))
    .length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('the request that gets sent', () {
    test('it posts cash to the switch endpoint, authenticated', () async {
      final log = <http.BaseRequest>[];
      final service = RideService(
        client: _client(
          log: log,
          onSwitch: (_) async => _ok({'payment_id': 7, 'status': 'pending'}),
        ),
      );

      await service.selectCashPayment('token-aaa', '991');

      final request = log.single as http.Request;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/payments/switch/'));
      expect(request.headers['Authorization'], 'Bearer token-aaa');

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['new_method'], 'cash');
      // The server reads trip_id straight into a lookup; an int is what the
      // documented contract says and what every other caller sends.
      expect(body['trip_id'], 991);
      expect(body['trip_id'], isA<int>());
    });

    test('a trip id that is not a number is refused without a request',
        () async {
      final log = <http.BaseRequest>[];
      final service = RideService(
        client: _client(
          log: log,
          onSwitch: (_) async => _ok({'payment_id': 7, 'status': 'pending'}),
        ),
      );

      final outcome = await service.selectCashPayment('t', 'not-an-id');

      expect(outcome.status, CashSwitchStatus.refused);
      expect(log, isEmpty, reason: 'nothing to ask the server about');
    });
  });

  group('what the server says, and what we conclude', () {
    test('a pending cash payment means the rider now OWES cash', () async {
      final service = RideService(
        client: _client(
          log: [],
          onSwitch: (_) async => _ok({'payment_id': 42, 'status': 'pending'}),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      expect(outcome.status, CashSwitchStatus.awaitingCollection);
      expect(outcome.paymentId, 42);
    });

    test('awaitingCollection is NOT a claim that the trip is paid', () async {
      // The whole point: selection is not settlement. Nothing in the enum
      // may be read as "paid" except alreadyPaid.
      final service = RideService(
        client: _client(
          log: [],
          onSwitch: (_) async => _ok({'payment_id': 42, 'status': 'pending'}),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      expect(outcome.status, isNot(CashSwitchStatus.alreadyPaid));
      expect(outcome.isSettledOrOwed, isTrue, reason: 'actionable either way');
    });

    test('an unwrapped body is read too', () async {
      final service = RideService(
        client: _client(
          log: [],
          onSwitch: (_) async => http.Response(
            jsonEncode({'payment_id': 5, 'status': 'pending'}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      expect(outcome.status, CashSwitchStatus.awaitingCollection);
      expect(outcome.paymentId, 5);
    });

    test('409 ALREADY_PAID means do not collect cash as well', () async {
      // The rider finished the online checkout moments before tapping cash.
      final service = RideService(
        client: _client(
          log: [],
          onSwitch: (_) async => _error(
            409,
            'ALREADY_PAID',
            'Your previous payment has already succeeded at the gateway',
          ),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      expect(outcome.status, CashSwitchStatus.alreadyPaid);
      expect(outcome.message, contains('already succeeded'));
    });

    test('a refusal carries the server own reason and changes nothing',
        () async {
      for (final probe in [
        [400, 'INVALID_STATE', 'Payment method can only be switched at trip completion'],
        [403, 'FORBIDDEN', 'You can only modify payment for your own trips'],
        [404, 'NO_PAYMENT', 'No payment found for this trip'],
      ]) {
        final service = RideService(
          client: _client(
            log: [],
            onSwitch: (_) async => _error(
              probe[0] as int,
              probe[1] as String,
              probe[2] as String,
            ),
          ),
        );

        final outcome = await service.selectCashPayment('t', '991');

        expect(outcome.status, CashSwitchStatus.refused,
            reason: '${probe[0]} is a definite no');
        expect(outcome.code, probe[1]);
        expect(outcome.message, probe[2]);
        expect(outcome.isSettledOrOwed, isFalse);
      }
    });

    test('a 500 is unknown, not a refusal', () async {
      // The server may or may not have switched the trip. Reporting "no"
      // would be a guess, and the rider would be told the wrong thing.
      final log = <http.BaseRequest>[];
      final service = RideService(
        client: _client(
          log: log,
          onSwitch: (_) async => _error(500, 'SERVER_ERROR', 'boom'),
          onVerify: (_) async =>
              _ok({'payment_method': 'online', 'payment_status': 'pending'}),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      expect(outcome.status, CashSwitchStatus.unconfirmed);
      expect(outcome.isSettledOrOwed, isFalse);
    });

    test('a 200 we cannot read is not a confirmation', () async {
      final log = <http.BaseRequest>[];
      final service = RideService(
        client: _client(
          log: log,
          onSwitch: (_) async =>
              http.Response('not json at all', 200),
          onVerify: (_) async =>
              _ok({'payment_method': 'cash', 'payment_status': 'pending'}),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      // It went and asked instead of assuming.
      expect(outcome.status, CashSwitchStatus.awaitingCollection);
      expect(log.any((r) => r.url.path.contains('/ride/trip/991/')), isTrue);
    });
  });

  group('an unanswered switch is verified, never blindly repeated', () {
    test('when the read says the switch landed, no second POST is sent',
        () async {
      // The dangerous case: the POST succeeded and the response was lost.
      // Sending it again would fail the new cash row and create another.
      final log = <http.BaseRequest>[];
      final service = RideService(
        client: _client(
          log: log,
          onSwitch: (_) async => throw TimeoutException('lost'),
          onVerify: (_) async =>
              _ok({'payment_method': 'cash', 'payment_status': 'pending'}),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      expect(outcome.status, CashSwitchStatus.awaitingCollection);
      expect(_countSwitches(log), 1, reason: 'exactly one switch, ever');
    });

    test('when the read says it did NOT land, one retry is sent', () async {
      final log = <http.BaseRequest>[];
      final service = RideService(
        client: _client(
          log: log,
          onSwitch: (attempt) async {
            if (attempt == 1) throw TimeoutException('lost');
            return _ok({'payment_id': 9, 'status': 'pending'});
          },
          onVerify: (_) async =>
              _ok({'payment_method': 'online', 'payment_status': 'pending'}),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      expect(outcome.status, CashSwitchStatus.awaitingCollection);
      expect(outcome.paymentId, 9);
      expect(_countSwitches(log), 2);
    });

    test('the read is what decides, so it runs before the retry', () async {
      final order = <String>[];
      final service = RideService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/payments/switch/')) {
            order.add('switch');
            if (order.where((e) => e == 'switch').length == 1) {
              throw TimeoutException('lost');
            }
            return _ok({'payment_id': 9, 'status': 'pending'});
          }
          order.add('verify');
          return _ok({
            'payment_method': 'online',
            'payment_status': 'pending',
          });
        }),
      );

      await service.selectCashPayment('t', '991');

      expect(order, ['switch', 'verify', 'switch']);
    });

    test('it never sends more switches than maxAttempts', () async {
      final log = <http.BaseRequest>[];
      final service = RideService(
        client: _client(
          log: log,
          onSwitch: (_) async => throw TimeoutException('lost'),
          onVerify: (_) async =>
              _ok({'payment_method': 'online', 'payment_status': 'pending'}),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      expect(outcome.status, CashSwitchStatus.unconfirmed);
      expect(_countSwitches(log), lessThanOrEqualTo(2));
    });

    test('a read that finds the trip already paid reports exactly that',
        () async {
      final service = RideService(
        client: _client(
          log: [],
          onSwitch: (_) async => throw TimeoutException('lost'),
          onVerify: (_) async =>
              _ok({'payment_method': 'online', 'payment_status': 'completed'}),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      expect(outcome.status, CashSwitchStatus.alreadyPaid,
          reason: 'asking this rider for cash would charge them twice');
    });

    test('settled beats selected even when the method says cash', () async {
      final service = RideService(
        client: _client(
          log: [],
          onSwitch: (_) async => throw TimeoutException('lost'),
          onVerify: (_) async =>
              _ok({'payment_method': 'cash', 'payment_status': 'completed'}),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      expect(outcome.status, CashSwitchStatus.alreadyPaid);
    });

    test('when nothing can be confirmed, it says so rather than guessing',
        () async {
      final service = RideService(
        client: _client(
          log: [],
          onSwitch: (_) async => throw TimeoutException('lost'),
          onVerify: (_) async => throw TimeoutException('also lost'),
        ),
      );

      final outcome = await service.selectCashPayment('t', '991');

      expect(outcome.status, CashSwitchStatus.unconfirmed);
      expect(outcome.isSettledOrOwed, isFalse,
          reason: 'the rider must not be shown a success screen');
    });
  });

  group('the verification read on its own', () {
    test('cash and not settled means collection is owed', () async {
      final service = RideService(
        client: MockClient(
          (_) async =>
              _ok({'payment_method': 'cash', 'payment_status': 'pending'}),
        ),
      );

      expect(
        (await service.verifyCashSelection('t', '991')).status,
        CashSwitchStatus.awaitingCollection,
      );
    });

    test('it reads the trip the rider is actually on', () async {
      final log = <http.BaseRequest>[];
      final service = RideService(
        client: MockClient((request) async {
          log.add(request);
          return _ok({'payment_method': 'cash', 'payment_status': 'pending'});
        }),
      );

      await service.verifyCashSelection('t', '991');

      expect(log.single.url.path, endsWith('/ride/trip/991/'));
      expect(log.single.method, 'GET');
      expect(log.single.headers['Authorization'], 'Bearer t');
    });

    test('a non-200 proves nothing', () async {
      final service = RideService(
        client: MockClient((_) async => _error(404, 'NOT_FOUND', 'gone')),
      );

      expect(
        (await service.verifyCashSelection('t', '991')).status,
        CashSwitchStatus.unconfirmed,
      );
    });
  });

  group('the timeouts are bounded', () {
    test('an unanswered switch gives up on its own', () async {
      final service = RideService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/payments/switch/')) {
            await Future<void>.delayed(const Duration(seconds: 40));
            return _ok({'payment_id': 1, 'status': 'pending'});
          }
          return _ok({
            'payment_method': 'online',
            'payment_status': 'pending',
          });
        }),
      );

      final stopwatch = Stopwatch()..start();
      final outcome = await service.selectCashPayment(
        't',
        '991',
        maxAttempts: 1,
      );
      stopwatch.stop();

      expect(outcome.status, CashSwitchStatus.unconfirmed);
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 35)),
        reason: 'it must not hold the rider on a spinner',
      );
    });

    test('the bounds are short, because the fare is outstanding meanwhile',
        () {
      expect(RideService.cashSwitchTimeout.inSeconds, lessThanOrEqualTo(15));
      expect(RideService.cashSwitchTimeout.inSeconds, greaterThanOrEqualTo(5));
      expect(
        RideService.cashVerifyTimeout,
        lessThanOrEqualTo(RideService.cashSwitchTimeout),
        reason: 'a single indexed read should not wait longer than the write',
      );
    });
  });
}

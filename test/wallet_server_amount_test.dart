/// A wallet trip payment sends only the trip; the SERVER sets the amount.
///
/// Fixtures mirror POST /rider/wallet/payment/ in the backend
/// (servers/rider/trip_wallet_payment.py). Nothing calls a real server.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/providers/wallet_provider.dart';
import 'package:saaradhigo_rider/services/wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(int status, Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _success({bool duplicate = false}) => {
  'status': 'success',
  'data': {
    'transaction_id': 77,
    'trip_id': 123,
    'amount': '184.00',
    'currency': 'INR',
    'new_balance': '316.00',
    'reference_id': 'TRIP_123',
    'duplicate': duplicate,
    'message': 'Payment successful',
  },
};

Map<String, dynamic> _refusal(String code, {Map<String, dynamic>? details}) => {
  'status': 'error',
  'error': {
    'code': code,
    'message': 'refused',
    'details': {'field': 'trip_id', ...?details},
  },
};

Future<WalletPayOutcome> _pay(
  http.Response Function(http.Request) reply, {
  List<http.Request>? seen,
}) async {
  SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
  final provider = WalletProvider(
    walletService: WalletService(
      client: MockClient((request) async {
        seen?.add(request);
        return reply(request);
      }),
    ),
  );
  return provider.payForRide(tripId: 123);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // WalletProvider builds the Cashfree PaymentService, which registers a
  // native callback on construction; answer it so no platform call escapes.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter_cashfree_pg_sdk'),
        (_) async => null,
      );

  test('request carries trip_id and no amount or idempotency key', () async {
    final seen = <http.Request>[];
    await _pay((_) => _json(201, _success()), seen: seen);
    final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
    expect(seen.single.url.path, endsWith('/rider/wallet/payment/'));
    expect(body['trip_id'], 123);
    expect(body.containsKey('amount'), isFalse);
    expect(body.containsKey('idempotency_key'), isFalse);
    expect(body.containsKey('purpose'), isFalse);
  });

  test('success reports the server amount, not the local fare', () async {
    final out = await _pay((_) => _json(201, _success()));
    expect(out.paid, isTrue);
    expect(out.duplicate, isFalse);
    expect(out.serverAmount, 184.0);
    expect(out.transactionId, 77);
  });

  test('a 200 duplicate is success on the same transaction', () async {
    final out = await _pay((_) => _json(200, _success(duplicate: true)));
    expect(out.paid, isTrue);
    expect(out.duplicate, isTrue);
    expect(out.transactionId, 77);
  });

  test('ALREADY_PAID says so and is not a success', () async {
    final out = await _pay((_) => _json(409, _refusal('ALREADY_PAID')));
    expect(out.paid, isFalse);
    expect(out.alreadyPaid, isTrue);
    expect(out.failureMessage, 'This trip has already been paid.');
  });

  test('INSUFFICIENT_BALANCE is recognised for the existing flow', () async {
    final out = await _pay((_) => _json(400, _refusal('INSUFFICIENT_BALANCE')));
    expect(out.paid, isFalse);
    expect(out.insufficientBalance, isTrue);
  });

  for (final code in [
    'AMOUNT_MISMATCH',
    'NOT_CHARGED',
    'INVALID_STATE',
    'CURRENCY_MISMATCH',
    'NOT_FOUND',
    'MISSING_FIELDS',
  ]) {
    test('$code gets the neutral message and never claims money moved', () async {
      final out = await _pay(
        (_) => _json(
          code == 'NOT_FOUND' ? 404 : 409,
          _refusal(code, details: {'amount': '1.00'}),
        ),
      );
      expect(out.paid, isFalse);
      expect(
        out.failureMessage,
        "Couldn't pay from your wallet. Please try again or choose another way to pay.",
      );
      expect(out.failureMessage.toLowerCase(), isNot(contains('charged')));
      expect(out.failureMessage.toLowerCase(), isNot(contains('deducted')));
    });
  }

  test('a network failure is a neutral refusal', () async {
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
    final provider = WalletProvider(
      walletService: WalletService(
        client: MockClient((_) async => throw http.ClientException('down')),
      ),
    );
    final out = await provider.payForRide(tripId: 123);
    expect(out.paid, isFalse);
    expect(out.failureMessage, WalletPayOutcome.neutralFailureMessage);
  });
}

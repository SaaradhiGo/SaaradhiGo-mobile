/// 16 Nov, emulator: after 15 idle minutes the fare call got 401 and the
/// rider read "check your connection". A signed-in call is retried once
/// with a fresh token.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:saaradhigo_rider/core/market/app_http_client.dart';

void main() {
  tearDown(() => AppHttpClient.tokenRefresher = null);

  test('a 401 is retried once with the refreshed token', () async {
    final seen = <String?>[];
    AppHttpClient.tokenRefresher = () async => 'fresh';
    final client = AppHttpClient(
      MockClient((req) async {
        seen.add(req.headers['Authorization']);
        expect(jsonDecode(req.body), {'a': 1});
        return http.Response(
          '{}',
          req.headers['Authorization'] == 'Bearer fresh' ? 200 : 401,
        );
      }),
    );
    final r = await client.post(
      Uri.parse('https://qa.example/api/v1/ride/estimate-fare/'),
      headers: {'Authorization': 'Bearer stale'},
      body: jsonEncode({'a': 1}),
    );
    expect(r.statusCode, 200);
    expect(seen, ['Bearer stale', 'Bearer fresh']);
  });

  test('no refresh: the 401 is returned as is, once', () async {
    var calls = 0;
    AppHttpClient.tokenRefresher = () async => null;
    final client = AppHttpClient(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 401);
      }),
    );
    final r = await client.get(
      Uri.parse('https://qa.example/api/v1/x/'),
      headers: {'Authorization': 'Bearer stale'},
    );
    expect(r.statusCode, 401);
    expect(calls, 1);
  });

  test('an unsigned call is never retried', () async {
    var refreshed = false;
    AppHttpClient.tokenRefresher = () async {
      refreshed = true;
      return 'fresh';
    };
    final client = AppHttpClient(
      MockClient((_) async => http.Response('{}', 401)),
    );
    await client.get(Uri.parse('https://qa.example/api/v1/x/'));
    expect(refreshed, isFalse);
  });
}

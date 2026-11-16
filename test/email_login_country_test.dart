/// 16 Nov: an email sign-in loads the account's own country config. A US rider
/// who signed in by email stayed on the India config and was told "coming
/// soon" in Boise.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saaradhigo_rider/core/market/market_config.dart';
import 'package:saaradhigo_rider/core/market/market_config_store.dart';
import 'package:saaradhigo_rider/providers/auth_provider.dart';
import 'package:saaradhigo_rider/services/api_service.dart';

import 'support/app_config_fixtures.dart';

class _EmailOnlyApi implements AuthApiClient {
  _EmailOnlyApi(this.user);
  final Map<String, dynamic> user;

  @override
  Future<Map<String, dynamic>?> emailLogin({
    required String email,
    required String password,
    String? mfaCode,
  }) async => {
    'status': 'success',
    'data': {'token': 't', 'refresh_token': 'r', 'user': user},
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

MarketConfigStore _store(List<Uri> urls) => MarketConfigStore(
  client: MockClient((req) async {
    urls.add(req.url);
    if (req.url.queryParameters.isEmpty) {
      return _json({
        'status': 'success',
        'data': {
          'countries': [
            {'code': 'IN', 'name': 'India', 'calling_code': '91'},
            {'code': 'US', 'name': 'United States', 'calling_code': '1'},
          ],
        },
      });
    }
    return _json(
      req.url.queryParameters['country'] == 'US' ? usBody() : indiaBody(),
    );
  }),
  baseUrl: 'https://qa.example/api/v1',
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('market_country from the login reply picks the config', () async {
    final urls = <Uri>[];
    final store = _store(urls)
      ..debugSet(MarketConfig.builtIn, from: 'built-in');
    final auth = AuthProvider(
      apiService: _EmailOnlyApi({'id': 1, 'market_country': 'US'}),
      market: store,
    );
    expect(
      await auth.loginWithEmail(email: 'r@x.test', password: 'pw'),
      isNull,
    );
    await _settle();
    expect(store.current.countryCode, 'US');
  });

  test('no market_country: the phone number decides', () async {
    final urls = <Uri>[];
    final store = _store(urls)
      ..debugSet(MarketConfig.builtIn, from: 'built-in');
    final auth = AuthProvider(
      apiService: _EmailOnlyApi({'id': 1, 'phone_number': '+12025550123'}),
      market: store,
    );
    expect(
      await auth.loginWithEmail(email: 'r@x.test', password: 'pw'),
      isNull,
    );
    await _settle();
    expect(store.current.countryCode, 'US');
  });

  test('an Indian account stays on India', () async {
    final urls = <Uri>[];
    final store = _store(urls)
      ..debugSet(MarketConfig.builtIn, from: 'built-in');
    final auth = AuthProvider(
      apiService: _EmailOnlyApi({'id': 1, 'market_country': 'IN'}),
      market: store,
    );
    await auth.loginWithEmail(email: 'r@x.test', password: 'pw');
    await _settle();
    expect(store.current.countryCode, 'IN');
    expect(urls.every((u) => u.queryParameters['country'] != 'US'), isTrue);
  });
}

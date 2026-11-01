/// App catch-up phase 5 (data), rider: R6 city at sign-up, and the emergency
/// contact hint built from the market.
///
/// Payloads are the shapes servers/platform_ops/app_config.py returns
/// (cities[].code is the GeoNode code such as IN-TG-HYD;
/// country.phone.national_number_lengths).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/core/market/market_config.dart';
import 'package:saaradhigo_rider/core/market/market_config_store.dart';
import 'package:saaradhigo_rider/providers/auth_provider.dart';
import 'package:saaradhigo_rider/screens/profile/profile_setup_screen.dart';
import 'package:saaradhigo_rider/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_config_fixtures.dart';
import 'support/screen_test_harness.dart' show stubStartupPluginChannels;

Map<String, dynamic> _city(String code, String name, double lat, double lng) =>
    {
      'code': code,
      'name': name,
      'state': {'code': 'TG', 'name': 'Telangana'},
      'service_area': {
        'center': {'lat': lat, 'lng': lng},
        'bounds': {
          'south': lat - 0.1,
          'west': lng - 0.1,
          'north': lat + 0.1,
          'east': lng + 0.1,
        },
      },
    };

final hyd = _city('IN-TG-HYD', 'Hyderabad', 17.385, 78.4867);
final vja = _city('IN-AP-VJA', 'Vijayawada', 16.5062, 80.648);

MarketConfig _india({List<Map<String, dynamic>>? cities}) =>
    MarketConfig.fromData({
      ...(indiaBody(cities: cities ?? [hyd, vja])['data'] as Map)
          .cast<String, dynamic>(),
    });

MarketConfig _noLengths() => MarketConfig.fromData({
  'country': {
    'code': 'XX',
    'calling_code': '44',
    'phone': {'calling_code': '44', 'national_number_lengths': <int>[]},
  },
});

class _RecordingAuth extends AuthProvider {
  Map<String, dynamic>? sent;

  @override
  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    sent = Map.of(profileData);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token-placeholder',
    });
    stubStartupPluginChannels();
  });

  group('R6 phone hint from the market', () {
    test('India: dialling code plus a national number of the right length', () {
      expect(_india().phoneHint, '+91 98765 43210');
    });

    test('US body: +1 and its configured length', () {
      final us = MarketConfig.fromData(
        (usBody()['data'] as Map).cast<String, dynamic>(),
      );
      expect(us.phoneHint, '+1 98765 43210');
    });

    test('another length changes the example', () {
      final m = MarketConfig.fromData({
        'country': {
          'code': 'XX',
          'calling_code': '44',
          'phone': {
            'calling_code': '44',
            'national_number_lengths': [9],
          },
        },
      });
      expect(m.phoneHint, '+44 98765 4321');
    });

    test('no lengths from the server means no hint (neutral fallback)', () {
      expect(_noLengths().phoneHint, isNull);
    });

    test("built-in market is today's India", () {
      expect(MarketConfig.builtIn.phoneHint, '+91 98765 43210');
    });
  });

  group('R6 the sign-up payload', () {
    Future<Map<String, dynamic>?> patchBody({String? homeCity}) async {
      Map<String, dynamic>? body;
      final api = ApiService(
        client: MockClient((r) async {
          body = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'status': 'success', 'data': <String, dynamic>{}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await api.updateProfile(
        fullName: 'Asha Rao',
        email: '',
        gender: 'female',
        dob: '',
        emergencyContact: '',
        houseNo: '',
        street: '',
        city: 'Hyderabad',
        zipCode: '',
        homeCity: homeCity,
      );
      return body;
    }

    test('home_city is sent when a city was chosen', () async {
      final body = await patchBody(homeCity: 'IN-TG-HYD');
      expect(body!['home_city'], 'IN-TG-HYD');
      expect(body['city'], 'Hyderabad');
    });

    test('home_city is omitted when none was chosen', () async {
      final body = await patchBody();
      expect(body!.containsKey('home_city'), isFalse);
    });
  });

  group('R6 Complete Profile screen', () {
    Future<_RecordingAuth> pump(
      WidgetTester t, {
      required MarketConfig market,
      LatLng? at,
    }) async {
      t.view.devicePixelRatio = 1.0;
      await t.binding.setSurfaceSize(const Size(700, 1400));
      addTearDown(() {
        t.binding.setSurfaceSize(null);
        t.view.resetDevicePixelRatio();
      });
      final store = MarketConfigStore()..debugSet(market);
      final auth = _RecordingAuth();
      final router = GoRouter(
        initialLocation: '/profile-setup',
        routes: [
          GoRoute(
            path: '/profile-setup',
            builder: (c, s) =>
                ProfileSetupScreen(marketStore: store, locate: () async => at),
          ),
          GoRoute(path: '/home', builder: (c, s) => const Text('HOME')),
        ],
      );
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<MarketConfigStore>.value(value: store),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await t.pump();
      await t.pump();
      return auth;
    }

    Future<void> save(WidgetTester t) async {
      final btn = find.byType(ElevatedButton).last;
      await t.ensureVisible(btn);
      await t.tap(btn);
      await t.pumpAndSettle();
    }

    testWidgets('hint is built from the market config', (t) async {
      await pump(t, market: _india());
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('(555) 019-2834'), findsNothing);
    });

    testWidgets('neutral hint when the market has no number length', (t) async {
      await pump(t, market: _noLengths());
      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('(555) 019-2834'), findsNothing);
    });

    testWidgets('no location and nothing chosen: no city is sent', (t) async {
      final auth = await pump(t, market: _india());
      expect(find.byKey(const Key('city_picker')), findsOneWidget);
      await save(t);
      expect(auth.sent, isNotNull);
      expect(auth.sent!.containsKey('home_city'), isFalse);
    });

    testWidgets('defaults to the live city the rider is in', (t) async {
      final auth = await pump(
        t,
        market: _india(),
        at: const LatLng(17.44, 78.38),
      );
      expect(find.text('Hyderabad'), findsOneWidget);
      await save(t);
      expect(auth.sent!['home_city'], 'IN-TG-HYD');
      expect(auth.sent!['city'], 'Hyderabad');
    });

    testWidgets('a location outside every live city gives no default', (
      t,
    ) async {
      final auth = await pump(
        t,
        market: _india(),
        at: const LatLng(30.27, -97.74),
      );
      expect(find.text('Select your city'), findsOneWidget);
      await save(t);
      expect(auth.sent!.containsKey('home_city'), isFalse);
    });

    testWidgets('choosing another city sends that city', (t) async {
      final auth = await pump(
        t,
        market: _india(),
        at: const LatLng(17.44, 78.38),
      );
      await t.ensureVisible(find.byKey(const Key('city_picker')));
      await t.tap(find.byKey(const Key('city_picker')));
      await t.pumpAndSettle();
      await t.tap(find.text('Vijayawada').last);
      await t.pumpAndSettle();
      await save(t);
      expect(auth.sent!['home_city'], 'IN-AP-VJA');
      expect(auth.sent!['city'], 'Vijayawada');
    });

    testWidgets('built-in (no server cities) keeps the free-text city', (
      t,
    ) async {
      final auth = await pump(t, market: MarketConfig.builtIn);
      expect(find.byKey(const Key('city_picker')), findsNothing);
      await save(t);
      expect(auth.sent!.containsKey('home_city'), isFalse);
    });
  });
}

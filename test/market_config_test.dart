/// App catch-up R9 + R7: the market config (app-config), the version headers,
/// the 426 update screen, notices and the city-paused / not-live messages.
///
/// Fixtures are copied from the backend serializer (test/support/
/// app_config_fixtures.dart). Nothing here calls a real server.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as rp;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saaradhigo_rider/core/market/app_http_client.dart';
import 'package:saaradhigo_rider/core/market/booking_refusal.dart';
import 'package:saaradhigo_rider/core/market/market_config.dart';
import 'package:saaradhigo_rider/core/market/market_config_store.dart';
import 'package:saaradhigo_rider/providers/auth_provider.dart';
import 'package:saaradhigo_rider/providers/wallet_provider.dart';
import 'package:saaradhigo_rider/screens/auth/login_screen.dart';
import 'package:saaradhigo_rider/screens/components/coming_soon_overlay.dart';
import 'package:saaradhigo_rider/screens/components/market_overlays.dart';
import 'package:saaradhigo_rider/screens/home/add_money_screen.dart';
import 'package:saaradhigo_rider/services/fare_service.dart';
import 'package:saaradhigo_rider/services/service_area_service.dart';
import 'package:saaradhigo_rider/state/ride_notifier.dart';
import 'package:saaradhigo_rider/state/ride_state.dart';

import 'support/app_config_fixtures.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

MarketConfigStore _store(
  http.Client client, {
  Duration timeout = const Duration(seconds: 2),
}) => MarketConfigStore(
  client: client,
  baseUrl: 'https://qa.example/api/v1',
  timeout: timeout,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MarketConfigStore.instance.debugSet(MarketConfig.builtIn, from: 'built-in');
    UpdateRequiredState.instance.clear();
    BookingRefusalState.instance.dismiss();
    NoticeBanner.resetDismissed();
    AppIdentity.debugSetVersion('1.4.2');
  });

  group('built-in defaults are today\'s behaviour', () {
    test('India: +91, INR/rupee, km, 112, Hyderabad', () {
      const c = MarketConfig.builtIn;
      expect(c.dialPrefix, '+91');
      expect(c.currencyCode, 'INR');
      expect(c.currencySymbol, '₹');
      expect(c.distanceUnit, 'km');
      expect(c.emergency.number, '112');
      expect(c.cityNames, 'Hyderabad');
      expect(c.notices, isEmpty);
    });

    test('the QA document (India, no notices) parses to the same values', () {
      final c = MarketConfig.fromData(
        (indiaBody()['data'] as Map).cast<String, dynamic>(),
      );
      expect(c.dialPrefix, '+91');
      expect(c.currencySymbol, '₹');
      expect(c.currencyCode, 'INR');
      expect(c.distanceUnit, 'km');
      expect(c.emergency.number, '112');
      expect(c.cityNames, 'Hyderabad');
      expect(c.notices, isEmpty);
    });

    test('a partial or empty document falls back field by field', () {
      final c = MarketConfig.fromData({'country': {'code': 'IN'}});
      expect(c.dialPrefix, '+91');
      expect(c.currencySymbol, '₹');
      final empty = MarketConfig.fromData({});
      expect(empty.currencySymbol, '₹');
    });

    test('free to cancel only while it really is (9 Nov)', () {
      final feeOn = MarketConfig.fromData({
        'country': {
          'code': 'IN',
          'cancel_policy': {'charges_fee': true, 'free_before_accept': true},
        },
      });
      expect(feeOn.freeToCancel, isFalse);
      expect(feeOn.freeBeforeAccept, isTrue);
      final old = MarketConfig.fromData({
        'country': {
          'code': 'IN',
          'cancel_policy': {'charges_fee': true},
        },
      });
      expect(old.freeBeforeAccept, isFalse);
    });
  });

  group('fallback order: fresh -> cached -> built-in', () {
    test('a failed fetch with nothing cached stays on built-in', () async {
      final s = _store(MockClient((_) async => http.Response('boom', 500)));
      await s.restoreCached();
      await s.refresh();
      expect(s.source, 'built-in');
      expect(s.current.dialPrefix, '+91');
    });

    test('a good response is adopted and cached; a later failure uses the cache',
        () async {
      final good = _store(MockClient((_) async => _json(usBody())));
      await good.refresh(country: 'US');
      expect(good.source, 'fresh');
      expect(good.current.dialPrefix, '+1');

      // A new process: cache is read before any network.
      final next = _store(MockClient((_) async => throw Exception('offline')));
      await next.restoreCached();
      expect(next.source, 'cached');
      expect(next.current.currencySymbol, r'$');
      await next.refresh();
      expect(next.source, 'cached', reason: 'a failed fetch keeps the cache');
      expect(next.current.dialPrefix, '+1');
    });

    test('an unknown country (404) keeps the cached/built-in config, no crash',
        () async {
      final notFound = jsonEncode({
        'status': 'error',
        'error': {
          'code': 'UNKNOWN_COUNTRY',
          'message': "Unknown country 'ZZ'.",
          'details': {'field': 'country', 'issue': 'x'},
        },
      });
      final s = _store(MockClient((_) async => http.Response(notFound, 404)));
      await s.refresh(country: 'ZZ');
      expect(s.source, 'built-in');
      expect(s.current.countryCode, 'IN');

      final cached = _store(MockClient((_) async => _json(usBody())));
      await cached.refresh(country: 'US');
      final again = _store(MockClient((_) async => http.Response(notFound, 404)));
      await again.restoreCached();
      await again.refresh(country: 'ZZ');
      expect(again.current.countryCode, 'US');
    });

    test('a timeout never blocks and keeps what it had', () async {
      final s = _store(
        MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 50),
      );
      final c = await s.refresh();
      expect(c.countryCode, 'IN');
      expect(s.source, 'built-in');
    });

    test('a garbage body is ignored', () async {
      final s = _store(MockClient((_) async => http.Response('<html>', 200)));
      await s.refresh();
      expect(s.source, 'built-in');
    });

    test('country: last known first, IN only as the last fallback', () async {
      final seen = <String>[];
      final client = MockClient((req) async {
        seen.add(req.url.queryParameters['country']!);
        expect(req.url.queryParameters['app'], 'rider');
        expect(req.url.path, endsWith('/app-config/'));
        return _json(seen.length == 1 ? usBody() : indiaBody());
      });
      final s = _store(client);
      await s.refresh();
      expect(seen.last, 'IN');
      await s.refresh(country: 'US');
      expect(seen.last, 'US');
      final fresh = _store(client);
      await fresh.restoreCached();
      await fresh.refresh();
      expect(seen.last, 'IN');
    });

    test('refreshForPhone resolves the signed-in user\'s country', () async {
      final urls = <Uri>[];
      final s = _store(MockClient((req) async {
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
      }));
      await s.refreshForPhone('+12025550123');
      expect(s.current.countryCode, 'US');
      expect(
        urls.where((u) => u.queryParameters['country'] == 'US'),
        isNotEmpty,
      );
    });
  });

  group('headers on every request', () {
    test('X-App-Version / Platform / Name on get, post and streamed sends',
        () async {
      final seen = <http.BaseRequest>[];
      final client = AppHttpClient(
        MockClient((req) async {
          seen.add(req);
          return http.Response('{}', 200);
        }),
      );
      await client.get(Uri.parse('https://x.example/a'));
      await client.post(Uri.parse('https://x.example/b'), body: '{}');
      await client.send(http.MultipartRequest('PATCH', Uri.parse('https://x.example/c')));
      expect(seen, hasLength(3));
      for (final r in seen) {
        expect(r.headers['X-App-Version'], '1.4.2');
        expect(r.headers['X-App-Platform'], 'android');
        expect(r.headers['X-App-Name'], 'rider');
      }
    });

    test('top-level http.get and http.Client() are covered via runWithClient',
        () async {
      final seen = <Map<String, String>>[];
      await http.runWithClient(() async {
        await http.get(Uri.parse('https://x.example/a'));
        final c = http.Client();
        await c.post(Uri.parse('https://x.example/b'));
        c.close();
      }, () => AppHttpClient(MockClient((req) async {
        seen.add(req.headers);
        return http.Response('{}', 200);
      })));
      expect(seen, hasLength(2));
      expect(seen.every((h) => h['X-App-Name'] == 'rider'), isTrue);
    });
  });

  group('426 APP_UPDATE_REQUIRED', () {
    test('is published with the store link and the response is untouched',
        () async {
      final body = updateRequiredBody();
      final client = AppHttpClient(
        MockClient((_) async => http.Response(body, 426)),
        UpdateRequiredState.instance,
      );
      final res = await client.get(Uri.parse('https://x.example/ride/estimate-fare/'));
      expect(res.statusCode, 426);
      expect(res.body, body);
      final info = UpdateRequiredState.instance.info!;
      expect(info.storeUrl, contains('play.google.com'));
      expect(info.message, 'Please update the app to continue.');
    });

    test('a 426 that is not ours (or other statuses) shows nothing', () async {
      final client = AppHttpClient(
        MockClient((_) async => http.Response('proxy says no', 426)),
      );
      await client.get(Uri.parse('https://x.example/a'));
      expect(UpdateRequiredState.instance.info, isNull);
      final ok = AppHttpClient(MockClient((_) async => http.Response('{}', 500)));
      await ok.get(Uri.parse('https://x.example/a'));
      expect(UpdateRequiredState.instance.info, isNull);
    });

    testWidgets('shows a blocking update screen with the store button',
        (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: UpdateRequiredScreen(
            info: parseUpdateRequired(updateRequiredBody())!,
            onOpenStore: (u) async => opened = u,
          ),
        ),
      );
      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Please update the app to continue.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('update_required_button')));
      expect(opened, contains('play.google.com'));
    });

    testWidgets('MarketOverlays replaces the app with the update screen',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MarketOverlays(child: Scaffold(body: Text('THE APP'))),
        ),
      );
      expect(find.text('THE APP'), findsOneWidget);
      UpdateRequiredState.instance.report(
        parseUpdateRequired(updateRequiredBody())!,
      );
      await tester.pump();
      expect(find.byKey(const Key('update_required_title')), findsOneWidget);
      expect(find.text('THE APP'), findsNothing);
    });
  });

  group('notices', () {
    testWidgets('a notice shows as a dismissible banner; none shows nothing',
        (tester) async {
      final store = MarketConfigStore.instance;
      await tester.pumpWidget(
        const MaterialApp(
          home: MarketOverlays(child: Scaffold(body: Text('THE APP'))),
        ),
      );
      expect(find.byKey(const Key('notice_7')), findsNothing);

      store.debugSet(
        MarketConfig.fromData(
          (indiaBody(notices: [noticeJson()])['data'] as Map)
              .cast<String, dynamic>(),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('notice_7')), findsOneWidget);
      expect(find.textContaining('Scheduled maintenance'), findsOneWidget);
      expect(find.text('THE APP'), findsOneWidget, reason: 'not blocking');

      await tester.tap(find.byKey(const Key('notice_dismiss_7')));
      await tester.pump();
      expect(find.byKey(const Key('notice_7')), findsNothing);
    });

    test('a notice blocks only if it says so', () {
      final c = MarketConfig.fromData({
        'notices': [
          {...noticeJson(id: 1), 'blocking': true},
          noticeJson(id: 2),
        ],
      });
      expect(c.notices.firstWhere((n) => n.id == 1).blocking, isTrue);
      expect(c.notices.firstWhere((n) => n.id == 2).blocking, isFalse);
    });
  });

  group('booking refusals', () {
    test('messages are neutral, never a generic error', () {
      expect(
        bookingRefusalMessage(kCityPaused, city: 'Hyderabad'),
        'Rides are paused in Hyderabad right now. Please try again later.',
      );
      expect(
        bookingRefusalMessage(kCityNotLive, city: 'Austin'),
        "We're not in Austin yet.",
      );
      expect(bookingRefusalMessage(kCityNotLive), "We're not in your area yet.");
      expect(bookingRefusalMessage(kCityPaused), contains('your area'));
    });

    test('estimate-fare 400 CITY_PAUSED reaches the rider with the city name',
        () async {
      MarketConfigStore.instance.debugSet(
        MarketConfig.fromData((indiaBody()['data'] as Map).cast<String, dynamic>()),
      );
      await http.runWithClient(() async {
        final r = await FareService().estimateFare(
          pickupLat: 17.4,
          pickupLng: 78.45,
          destinationLat: 17.45,
          destinationLng: 78.5,
          distanceKm: 5,
          durationMin: 12,
          vehicleType: 'car',
        );
        expect(r, isNull);
      }, () => MockClient((_) async => http.Response(
            bookingRefusalBody(kCityPaused, 'paused'),
            400,
          )));
      expect(
        BookingRefusalState.instance.latest!.message,
        'Rides are paused in Hyderabad right now. Please try again later.',
      );
    });

    test('a different 400 is not reported as a refusal', () async {
      await http.runWithClient(() async {
        await FareService().estimateFare(
          pickupLat: 1,
          pickupLng: 1,
          destinationLat: 1,
          destinationLng: 1,
          distanceKm: 1,
          durationMin: 1,
          vehicleType: 'car',
        );
      }, () => MockClient((_) async => http.Response(
            bookingRefusalBody('OUT_OF_SERVICE_AREA', 'outside'),
            400,
          )));
      expect(BookingRefusalState.instance.latest, isNull);
    });

    test('a websocket CITY_NOT_LIVE error leaves "searching" and is reported',
        () async {
      final container = rp.ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(rideNotifierProvider.notifier);
      notifier.setSearching(vehicleType: 'car');
      expect(container.read(rideNotifierProvider).status, RideStatus.searchingDriver);
      notifier.updateFromWebSocket({
        'type': 'error',
        'code': 'CITY_NOT_LIVE',
        'message': 'SaaradhiGo is not available in this area yet.',
      });
      await Future<void>.delayed(Duration.zero);
      expect(container.read(rideNotifierProvider).status, RideStatus.none);
      expect(BookingRefusalState.instance.latest!.code, kCityNotLive);
      expect(
        BookingRefusalState.instance.latest!.message,
        "We're not in your area yet.",
      );
    });

    testWidgets('the card shows the CITY_NOT_LIVE message and OK dismisses it',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MarketOverlays(child: Scaffold(body: Text('THE APP'))),
        ),
      );
      BookingRefusalState.instance.report(kCityNotLive);
      await tester.pump();
      expect(find.byKey(const Key('booking_refusal_message')), findsOneWidget);
      expect(find.text("We're not in your area yet."), findsOneWidget);
      await tester.tap(find.byKey(const Key('booking_refusal_ok')));
      await tester.pump();
      expect(find.byKey(const Key('booking_refusal_card')), findsNothing);
    });
  });

  group('service area', () {
    test('no configured city: the built-in Hyderabad area, as before', () {
      expect(ServiceAreaService.isWithinServiceArea(const LatLng(17.385, 78.4867)), isTrue);
      expect(ServiceAreaService.isWithinServiceArea(const LatLng(12.97, 77.59)), isFalse);
    });

    test('configured cities replace the polygon', () {
      MarketConfigStore.instance.debugSet(
        MarketConfig.fromData((usBody()['data'] as Map).cast<String, dynamic>()),
      );
      expect(ServiceAreaService.isWithinServiceArea(const LatLng(30.2672, -97.7431)), isTrue);
      // Hyderabad is no longer "in" once the market is the US.
      expect(ServiceAreaService.isWithinServiceArea(const LatLng(17.385, 78.4867)), isFalse);
    });
  });

  group('screens read the market', () {
    Future<void> pumpLogin(WidgetTester tester) async {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1200, 3000);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MarketConfigStore>.value(
              value: MarketConfigStore.instance,
            ),
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(),
            ),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('India config: the phone field shows +91 exactly as today',
        (tester) async {
      MarketConfigStore.instance.debugSet(
        MarketConfig.fromData((indiaBody()['data'] as Map).cast<String, dynamic>()),
      );
      await pumpLogin(tester);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('+1'), findsNothing);
    });

    testWidgets('US config: the phone field shows +1', (tester) async {
      MarketConfigStore.instance.debugSet(
        MarketConfig.fromData((usBody()['data'] as Map).cast<String, dynamic>()),
      );
      await pumpLogin(tester);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('+91'), findsNothing);
    });

    Future<void> pumpAddMoney(WidgetTester tester) async {
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const AddMoneyScreen()),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MarketConfigStore>.value(
              value: MarketConfigStore.instance,
            ),
            ChangeNotifierProvider<WalletProvider>(
              create: (_) => WalletProvider(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
    }

    testWidgets('India config: wallet top-up shows the rupee exactly as today',
        (tester) async {
      MarketConfigStore.instance.debugSet(
        MarketConfig.fromData((indiaBody()['data'] as Map).cast<String, dynamic>()),
      );
      await pumpAddMoney(tester);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.decoration!.prefixText, '₹ ');
      expect(find.text('+ ₹100'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('US config: wallet top-up shows dollars', (tester) async {
      MarketConfigStore.instance.debugSet(
        MarketConfig.fromData((usBody()['data'] as Map).cast<String, dynamic>()),
      );
      await pumpAddMoney(tester);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.decoration!.prefixText, r'$ ');
      expect(find.text(r'+ $100'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    });

    testWidgets('the coming-soon overlay names the configured cities',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ComingSoonOverlay())),
      );
      expect(
        find.textContaining('available only in Hyderabad.'),
        findsOneWidget,
        reason: 'built-in config reads exactly as before',
      );
    });

    test('distance: km untouched for India, converted for mi markets', () {
      expect(MarketConfig.builtIn.displayDistance('12.3 km'), '12.3 km');
      final us = MarketConfig.fromData(
        (usBody()['data'] as Map).cast<String, dynamic>(),
      );
      expect(us.displayDistance('10.0 km'), '6.2 mi');
      expect(us.displayDistance(null), isNull);
      expect(us.distancePlaceholder, '-- mi');
    });
  });
}

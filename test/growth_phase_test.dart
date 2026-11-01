/// App catch-up phase 3 (growth), rider: R3 referrals.
///
/// Payloads are the shapes servers/promotions/referrals.py::mine and
/// views.py::referral_attach return (see tests/test_promotions_referrals.py in
/// the backend: code, offer, referrals[], attached_to; attach 201 with
/// status / required_trips / trips_completed / reward_minor / currency; errors
/// {status: error, error: {code, message}}).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/core/market/market_config.dart';
import 'package:saaradhigo_rider/core/market/market_config_store.dart';
import 'package:saaradhigo_rider/core/referral/referral_device_id.dart';
import 'package:saaradhigo_rider/core/referral/referral_models.dart';
import 'package:saaradhigo_rider/providers/auth_provider.dart';
import 'package:saaradhigo_rider/screens/home/home_screen.dart';
import 'package:saaradhigo_rider/screens/profile/profile_setup_screen.dart';
import 'package:saaradhigo_rider/screens/profile/referral_screen.dart';
import 'package:saaradhigo_rider/services/referral_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_config_fixtures.dart';
import 'support/screen_test_harness.dart';

http.Response _json(int code, Object body) => http.Response(
  jsonEncode(body),
  code,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _ok(Object data) => {'status': 'success', 'data': data};

Map<String, dynamic> _refusal(String code, String message) => {
  'status': 'error',
  'error': {
    'code': code,
    'message': message,
    'field': 'code',
    'issue': message,
  },
};

/// GET /promotions/referrals/mine/ on a live rider offer, one invite of each state.
Map<String, dynamic> mineLive() => {
  'code': 'ABCD2345',
  'offer': {
    'campaign_id': 7,
    'name': 'Refer a rider',
    'required_trips': 2,
    'referrer_reward_minor': 10000,
    'referee_reward_minor': 5000,
    'currency': 'INR',
    'referrer_reward': '₹100.00',
    'referee_reward': '₹50.00',
  },
  'referrals': [
    {
      'id': 1,
      'who': 'Asha K.',
      'status': 'rewarded',
      'trips_completed': 2,
      'required_trips': 2,
      'reward_minor': 10000,
      'currency': 'INR',
      'note': '',
      'reward_status': null,
      'joined_at': '2026-11-01T09:00:00+00:00',
    },
    {
      'id': 2,
      'who': 'Ravi',
      'status': 'attached',
      'trips_completed': 1,
      'required_trips': 2,
      'reward_minor': 0,
      'currency': 'INR',
      'note': '',
      'reward_status': null,
      'joined_at': '2026-11-01T09:30:00+00:00',
    },
    {
      'id': 3,
      'who': 'Meena S.',
      'status': 'blocked',
      'trips_completed': 2,
      'required_trips': 2,
      'reward_minor': 0,
      'currency': 'INR',
      'note': 'under review',
      'reward_status': null,
      'joined_at': '2026-11-01T10:00:00+00:00',
    },
    {
      'id': 4,
      'who': 'Dev P.',
      'status': 'rewarded',
      'trips_completed': 2,
      'required_trips': 2,
      'reward_minor': 10000,
      'currency': 'INR',
      'note': '',
      'reward_status': 'pending_review',
      'joined_at': '2026-11-01T10:30:00+00:00',
    },
  ],
  'attached_to': null,
};

/// The same endpoint for a rider when no offer is live: no offer, no invites.
Map<String, dynamic> mineNoOffer() => {
  'code': 'ABCD2345',
  'offer': null,
  'referrals': <dynamic>[],
  'attached_to': null,
};

Map<String, dynamic> attachCreated() => {
  'status': 'attached',
  'required_trips': 2,
  'trips_completed': 0,
  'reward_minor': 5000,
  'currency': 'INR',
};

MarketConfig _market({bool? referrals}) => MarketConfig.fromData({
  ...(indiaBody()['data'] as Map).cast<String, dynamic>(),
  'referrals_available': ?referrals,
});

class _OkAuth extends AuthProvider {
  @override
  Future<bool> updateProfile(Map<String, dynamic> profileData) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token-placeholder',
    });
    FlutterSecureStorage.setMockInitialValues({});
    ReferralDeviceId.resetCacheForTests();
    stubStartupPluginChannels();
  });

  group('R3 the flag', () {
    test('referrals_available is read from app-config; missing is false', () {
      expect(_market().referralsAvailable, isFalse);
      expect(_market(referrals: false).referralsAvailable, isFalse);
      expect(_market(referrals: true).referralsAvailable, isTrue);
      expect(MarketConfig.builtIn.referralsAvailable, isFalse);
    });

    test(
      'the app asks app-config with app=rider (the flag is per app)',
      () async {
        Uri? seen;
        final store = MarketConfigStore(
          baseUrl: 'https://example.test/api/v1',
          client: MockClient((r) async {
            seen = r.url;
            return _json(200, {
              ...indiaBody(),
              'data': {
                ...(indiaBody()['data'] as Map).cast<String, dynamic>(),
                'referrals_available': true,
              },
            });
          }),
        );
        await store.refresh(country: 'IN');
        expect(seen!.queryParameters['app'], 'rider');
        expect(store.current.referralsAvailable, isTrue);
      },
    );
  });

  group('R3 attach', () {
    Future<(AttachResult, http.Request?)> run(http.Response reply) async {
      http.Request? sent;
      final service = ReferralService(
        client: MockClient((r) async {
          sent = r;
          return reply;
        }),
      );
      final result = await service.attach('token-placeholder', ' abcd2345 ');
      return (result, sent);
    }

    test(
      'success posts the code upper-cased with the per-install device id',
      () async {
        final (result, sent) = await run(_json(201, _ok(attachCreated())));
        expect(result.ok, isTrue);
        expect(sent!.url.path, endsWith('/promotions/referrals/attach/'));
        expect(sent.headers['Authorization'], 'Bearer token-placeholder');
        final body = jsonDecode(sent.body) as Map;
        expect(body['code'], 'ABCD2345');
        expect(body['device_id'], await ReferralDeviceId.get());
        expect(body.keys.toSet(), {'code', 'device_id'});
      },
    );

    // Every code referrals.attach raises, with the status the backend gives it.
    final refusals = <String, (int, String)>{
      'SELF_REFERRAL': (400, 'You cannot use your own referral code.'),
      'ALREADY_REFERRED': (
        409,
        'A referral code was already used on this account.',
      ),
      'CODE_NOT_FOUND': (404, 'That referral code does not exist.'),
      'CODE_REQUIRED': (400, 'A referral code is required.'),
      'TOO_LATE': (409, 'A referral code must be used before your first trip.'),
      'NO_ACTIVE_CAMPAIGN': (
        409,
        'There is no referral offer running for you right now.',
      ),
      'NOT_ELIGIBLE': (403, 'Only riders and drivers can use a referral code.'),
    };
    for (final e in refusals.entries) {
      test('${e.key} gets a friendly message and never the raw one', () async {
        final (result, _) = await run(
          _json(e.value.$1, _refusal(e.key, e.value.$2)),
        );
        expect(result.ok, isFalse);
        expect(result.code, e.key);
        expect(result.message, isNotEmpty);
        expect(result.message, isNot(e.value.$2));
        expect(result.message, isNot(contains('trip')));
      });
    }

    test('the specific refusals read as intended', () {
      expect(attachRefusalMessage('SELF_REFERRAL'), contains('own code'));
      expect(
        attachRefusalMessage('ALREADY_REFERRED'),
        contains('already been used'),
      );
      expect(attachRefusalMessage('CODE_NOT_FOUND'), contains("couldn't find"));
      expect(
        attachRefusalMessage('DEVICE_ALREADY_USED'),
        contains('this phone'),
      );
      expect(
        attachRefusalMessage('NO_ACTIVE_CAMPAIGN'),
        contains('no referral offer'),
      );
      expect(
        attachRefusalMessage('TOO_LATE'),
        contains('before your first ride'),
      );
      expect(
        attachRefusalMessage('SOMETHING_NEW'),
        contains('still use the app'),
      );
    });

    test('a network failure is a result, not a throw', () async {
      final service = ReferralService(
        client: MockClient((r) async => throw http.ClientException('offline')),
      );
      final result = await service.attach('t', 'ABCD2345');
      expect(result.ok, isFalse);
      expect(result.code, 'NETWORK');
    });

    test('a garbage body is a result, not a throw', () async {
      final (result, _) = await run(http.Response('<html>', 502));
      expect(result.ok, isFalse);
    });
  });

  group('R3 device id', () {
    test(
      'is stable across app restarts (persisted, not regenerated)',
      () async {
        final first = await ReferralDeviceId.get();
        ReferralDeviceId.resetCacheForTests(); // a new process
        final second = await ReferralDeviceId.get();
        expect(second, first);
      },
    );

    test(
      'survives the secure store being empty (prefs copy) and vice versa',
      () async {
        final first = await ReferralDeviceId.get();
        FlutterSecureStorage.setMockInitialValues({});
        ReferralDeviceId.resetCacheForTests();
        expect(await ReferralDeviceId.get(), first);

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(ReferralDeviceId.storageKey);
        ReferralDeviceId.resetCacheForTests();
        expect(await ReferralDeviceId.get(), first);
      },
    );

    test(
      'is a random per-install value, never a hardware or personal identifier',
      () async {
        final id = await ReferralDeviceId.get();
        expect(
          id,
          matches(
            RegExp(
              r'^inst-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        // Not a phone number, an IMEI (15 digits) or a MAC address.
        expect(id, isNot(matches(RegExp(r'^\+?\d{10,15}$'))));
        expect(
          id,
          isNot(
            matches(
              RegExp(r'^([0-9a-f]{2}:){5}[0-9a-f]{2}$', caseSensitive: false),
            ),
          ),
        );
      },
    );

    test('two installs get different ids', () async {
      final a = await ReferralDeviceId.get();
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      ReferralDeviceId.resetCacheForTests();
      expect(await ReferralDeviceId.get(), isNot(a));
    });
  });

  group('R3 sign-up field', () {
    Future<void> pumpSetup(
      WidgetTester t, {
      required MarketConfig market,
      required ReferralService service,
      List<String> visited = const [],
      List<String>? log,
    }) async {
      t.view.devicePixelRatio = 1.0;
      // Wide enough for the test font (Ahem) not to overflow the button row.
      await t.binding.setSurfaceSize(const Size(700, 1400));
      addTearDown(() {
        t.binding.setSurfaceSize(null);
        t.view.resetDevicePixelRatio();
      });
      final store = MarketConfigStore();

      store.debugSet(market);
      final router = GoRouter(
        initialLocation: '/profile-setup',
        routes: [
          GoRoute(
            path: '/profile-setup',
            builder: (c, s) => ProfileSetupScreen(
              referralService: service,
              marketStore: store,
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (c, s) {
              log?.add('home');
              return const Scaffold(body: Text('HOME'));
            },
          ),
        ],
      );
      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => _OkAuth()),
            ChangeNotifierProvider<MarketConfigStore>.value(value: store),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await t.pump();
      await t.pump();
    }

    testWidgets('hidden when the flag is false or missing', (t) async {
      for (final m in [_market(), _market(referrals: false)]) {
        await pumpSetup(t, market: m, service: ReferralService());
        expect(find.byKey(const Key('referral_field')), findsNothing);
        expect(find.text('Referral code (optional)'), findsNothing);
      }
    });

    testWidgets('shown when a referral offer is live', (t) async {
      await pumpSetup(
        t,
        market: _market(referrals: true),
        service: ReferralService(),
      );
      expect(find.byKey(const Key('referral_field')), findsOneWidget);
      expect(find.text('Referral code (optional)'), findsOneWidget);
    });

    testWidgets(
      'a code is attached after the profile saves, then the rider goes home',
      (t) async {
        final calls = <http.Request>[];
        final service = ReferralService(
          client: MockClient((r) async {
            calls.add(r);
            return _json(201, _ok(attachCreated()));
          }),
        );
        await pumpSetup(t, market: _market(referrals: true), service: service);
        await t.enterText(
          find.descendant(
            of: find.byKey(const Key('referral_field')),
            matching: find.byType(TextField),
          ),
          'abcd2345',
        );
        await t.tap(find.text('Save & Continue'));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await t.pumpAndSettle();
        expect(calls, hasLength(1));
        expect(jsonDecode(calls.single.body)['code'], 'ABCD2345');
        expect(find.text('HOME'), findsOneWidget);
      },
    );

    testWidgets(
      'a refused code never blocks sign-up: the rider still gets home, with a message',
      (t) async {
        final service = ReferralService(
          client: MockClient(
            (r) async => _json(
              404,
              _refusal('CODE_NOT_FOUND', 'That referral code does not exist.'),
            ),
          ),
        );
        await pumpSetup(t, market: _market(referrals: true), service: service);
        await t.enterText(
          find.descendant(
            of: find.byKey(const Key('referral_field')),
            matching: find.byType(TextField),
          ),
          'WRONG123',
        );
        await t.tap(find.text('Save & Continue'));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('HOME'), findsOneWidget);
        expect(
          find.textContaining("couldn't find that referral code"),
          findsOneWidget,
        );
      },
    );

    testWidgets('a network failure on the code never blocks sign-up', (
      t,
    ) async {
      final service = ReferralService(
        client: MockClient((r) async => throw http.ClientException('offline')),
      );
      await pumpSetup(t, market: _market(referrals: true), service: service);
      await t.enterText(
        find.descendant(
          of: find.byKey(const Key('referral_field')),
          matching: find.byType(TextField),
        ),
        'ABCD2345',
      );
      await t.tap(find.text('Save & Continue'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('no code typed means no request at all', (t) async {
      var calls = 0;
      final service = ReferralService(
        client: MockClient((r) async {
          calls++;
          return _json(201, _ok(attachCreated()));
        }),
      );
      await pumpSetup(t, market: _market(referrals: true), service: service);
      await t.tap(find.text('Save & Continue'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  group('R3 menu entry', () {
    Future<void> pumpProfile(WidgetTester t, MarketConfig market) async {
      t.view.devicePixelRatio = 1.0;
      await t.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() {
        t.binding.setSurfaceSize(null);
        t.view.resetDevicePixelRatio();
      });
      MarketConfigStore.instance.debugSet(market);
      addTearDown(
        () => MarketConfigStore.instance.debugSet(MarketConfig.builtIn),
      );
      final router = GoRouter(
        initialLocation: '/home?tab=3',
        routes: [
          GoRoute(
            path: '/home',
            builder: (c, s) => const HomeScreen(initialTabIndex: 3),
          ),
          GoRoute(
            path: '/refer',
            builder: (c, s) => const Scaffold(body: Text('REFER SCREEN')),
          ),
        ],
      );
      await t.pumpWidget(
        wrapWithRiderProviders(
          auth: _OkAuth(),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('Refer & Earn is hidden when the flag is false or missing', (
      t,
    ) async {
      for (final m in [_market(), _market(referrals: false)]) {
        await pumpProfile(t, m);
        expect(find.text('Personal Information'), findsOneWidget);
        expect(find.text('Refer & Earn'), findsNothing);
      }
    });

    testWidgets('Refer & Earn shows and opens the referral screen when live', (
      t,
    ) async {
      await pumpProfile(t, _market(referrals: true));
      expect(find.text('Refer & Earn'), findsOneWidget);
      await t.ensureVisible(find.text('Refer & Earn'));
      await t.tap(find.text('Refer & Earn'));
      await t.pumpAndSettle();
      expect(find.text('REFER SCREEN'), findsOneWidget);
    });
  });

  group('R3 referral screen', () {
    Future<List<String>> pumpScreen(WidgetTester t, http.Response reply) async {
      t.view.devicePixelRatio = 1.0;
      await t.binding.setSurfaceSize(const Size(700, 1600));
      addTearDown(() {
        t.binding.setSurfaceSize(null);
        t.view.resetDevicePixelRatio();
      });
      final shared = <String>[];
      await t.pumpWidget(
        MaterialApp(
          home: ReferralScreen(
            service: ReferralService(client: MockClient((r) async => reply)),
            tokenReader: () async => 'token-placeholder',
            shareOverride: (text) async => shared.add(text),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      return shared;
    }

    testWidgets('shows the code, the offer and progress from the API', (
      t,
    ) async {
      await pumpScreen(t, _json(200, _ok(mineLive())));
      expect(find.byKey(const Key('referral_code')), findsOneWidget);
      expect(find.text('ABCD2345'), findsOneWidget);
      expect(
        find.text(
          'When a friend you invite completes 2 rides, you get ₹100.00 and they get ₹50.00.',
        ),
        findsOneWidget,
      );
      // 4 invited; 2 completed their rides (rewarded x2; the blocked one does not count as qualified); 2 pending review.
      expect(find.text('4'), findsOneWidget);
      expect(find.byKey(const Key('referral_pending_count')), findsOneWidget);
      expect(find.text('Rewards earned: ₹100.00'), findsOneWidget);
      expect(find.text('Pending review: ₹100.00'), findsOneWidget);
      expect(find.text('Reward earned: ₹100.00'), findsOneWidget);
      expect(find.text('1 of 2 rides'), findsOneWidget);
      expect(
        find.text('Pending review'),
        findsNWidgets(3),
      ); // stat label + two rows
      expect(find.textContaining('fraud'), findsNothing);
    });

    testWidgets(
      'a held reward and a blocked one both read pending review, never why',
      (t) async {
        await pumpScreen(t, _json(200, _ok(mineLive())));
        expect(find.textContaining('same_'), findsNothing);
        expect(find.textContaining('abuse'), findsNothing);
        final mine = ReferralMine.fromData(mineLive())!;
        expect(mine.pendingReviewCount, 2);
        expect(mine.earnedMinorByCurrency, {'INR': 10000});
      },
    );

    testWidgets(
      'no offer: the code still shows with a neutral line, no zero headline',
      (t) async {
        await pumpScreen(t, _json(200, _ok(mineNoOffer())));
        expect(find.byKey(const Key('referral_no_offer')), findsOneWidget);
        expect(find.byKey(const Key('referral_empty')), findsOneWidget);
        expect(find.text('No rewards earned yet'), findsOneWidget);
        expect(find.textContaining('₹0'), findsNothing);
      },
    );

    testWidgets('share sends the code and the offer, copy copies the code', (
      t,
    ) async {
      final shared = await pumpScreen(t, _json(200, _ok(mineLive())));
      await t.tap(find.byKey(const Key('referral_share')));
      await t.pump();
      expect(shared, hasLength(1));
      expect(shared.single, contains('ABCD2345'));
      expect(shared.single, contains('₹50.00'));
    });

    testWidgets('share without an offer is a neutral line with the code', (
      t,
    ) async {
      final shared = await pumpScreen(t, _json(200, _ok(mineNoOffer())));
      await t.tap(find.byKey(const Key('referral_share')));
      await t.pump();
      expect(
        shared.single,
        'Join me on SaaradhiGo. Use my referral code ABCD2345 when you sign up.',
      );
    });

    testWidgets('a failed load offers a retry', (t) async {
      await pumpScreen(t, http.Response('', 500));
      expect(find.byKey(const Key('referral_retry')), findsOneWidget);
    });

    testWidgets('a rider who joined with a code sees their own progress', (
      t,
    ) async {
      final data = mineNoOffer()
        ..['attached_to'] = {
          'status': 'attached',
          'trips_completed': 1,
          'required_trips': 2,
        };
      await pumpScreen(t, _json(200, _ok(data)));
      expect(
        find.text('You joined with a referral code: 1 of 2 rides done.'),
        findsOneWidget,
      );
    });
  });
}

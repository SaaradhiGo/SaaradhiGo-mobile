/// App catch-up phase 4 (comms and fraud messages), rider: R4 and R8.
///
/// Payloads are the shapes the backend returns:
/// * GET/PUT /api/v1/notifications/preferences/ -- servers/notifications/app_views.py
///   and tests/test_notifications_console.py::TestPreferencesApi (`effective`,
///   `locked`, `rows`);
/// * GET /api/v1/rider/wallet/balance/ -- servers/rider/views.py::get_wallet_balance
///   plus servers/fraud/money.py::pending_review_lines (`rewards_pending_review`,
///   `rewards_pending_review_label`, `rewards_pending_review_minor`, `currency`);
/// * GET /api/v1/rider/wallet/transactions/ -- WalletTransactionSerializer (`label`
///   is "Recovery of reward (reviewed)" for a reward_recovery line);
/// * CASH_NOT_AVAILABLE on the booking socket (servers/consumers.py) and on
///   POST /payments/switch/ (tests/test_fraud_money_restrictions.py).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/core/market/booking_refusal.dart';
import 'package:saaradhigo_rider/core/notifications/notification_prefs.dart';
import 'package:saaradhigo_rider/providers/notification_provider.dart';
import 'package:saaradhigo_rider/providers/remote_config_provider.dart';
import 'package:saaradhigo_rider/providers/wallet_provider.dart';
import 'package:saaradhigo_rider/screens/components/market_overlays.dart';
import 'package:saaradhigo_rider/screens/home/wallet_screen.dart';
import 'package:saaradhigo_rider/screens/profile/notification_preferences_screen.dart';
import 'package:saaradhigo_rider/services/models/wallet_model.dart';
import 'package:saaradhigo_rider/services/notification_preferences_service.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:saaradhigo_rider/state/ride_notifier.dart';
import 'package:saaradhigo_rider/state/ride_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_test_harness.dart';

http.Response _json(int code, Object body) => http.Response(
  jsonEncode(body),
  code,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _ok(Object data) => {'status': 'success', 'data': data};

/// The default `effective` map: what the backend reads for a user with no rows
/// (servers/notifications/preferences.py DEFAULT_ON and locked_on).
Map<String, dynamic> prefsPayload({
  bool whatsapp = true,
  Map<String, Map<String, bool>> overrides = const {},
}) {
  final effective = <String, Map<String, bool>>{
    'sms': {'transactional': true, 'promotional': false},
    'email': {'transactional': true, 'promotional': false},
    'push': {'transactional': true, 'promotional': false},
    'in_app': {'transactional': true, 'promotional': false},
    if (whatsapp) 'whatsapp': {'transactional': false, 'promotional': false},
  };
  overrides.forEach((channel, cats) {
    effective[channel] = {...?effective[channel], ...cats};
  });
  return {
    'effective': effective,
    'locked': [
      {'channel': 'in_app', 'category': 'transactional'},
    ],
    'rows': <Object>[],
  };
}

class _PrefsBackend {
  _PrefsBackend({Map<String, dynamic>? initial, this.putStatus = 200})
    : current = initial ?? prefsPayload();

  Map<String, dynamic> current;
  int putStatus;
  final requests = <http.Request>[];

  Iterable<http.Request> get puts => requests.where((r) => r.method == 'PUT');

  MockClient get client => MockClient((request) async {
    requests.add(request);
    if (!request.url.path.endsWith('/notifications/preferences/')) {
      return _json(404, {'status': 'error'});
    }
    if (request.method == 'GET') return _json(200, _ok(current));
    if (putStatus != 200) {
      return _json(putStatus, {
        'status': 'error',
        'error': {'code': 'SERVER_ERROR', 'message': 'x'},
      });
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final eff = (current['effective'] as Map).map(
      (k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
    );
    for (final p in body['preferences'] as List) {
      eff[p['channel']]![p['category']] = p['opted_in'];
    }
    current = {...current, 'effective': eff};
    return _json(200, _ok(current));
  });
}

Future<void> _pumpPrefs(WidgetTester tester, _PrefsBackend backend) async {
  await _phone(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationPreferencesScreen(
        service: NotificationPreferencesService(client: backend.client),
        tokenReader: () async => 'test-token',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Switch _switchOf(WidgetTester tester, String key) => tester.widget<Switch>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(Switch)),
);

class _FakeWallet extends WalletProvider {
  _FakeWallet(this._w, this._t);
  final Wallet? _w;
  final List<Transaction> _t;
  @override
  Wallet? get wallet => _w;
  @override
  List<Transaction> get transactions => _t;
  @override
  double get balance => _w?.balance ?? 0;
  @override
  bool get isLoading => false;
  @override
  Future<void> refreshWallet() async {}
}

Map<String, dynamic> balancePayload({String held = '100.00'}) => {
  'balance': '500.00',
  'rewards_pending_review': held,
  'rewards_pending_review_label': 'Pending review',
  'rewards_pending_review_minor': 10000,
  'currency': 'INR',
};

Map<String, dynamic> recoveryLine() => {
  'id': 41,
  'user_id': 7,
  'amount': '100.00',
  'txn_type': 'debit',
  'status': 'completed',
  'gateway_order_id': null,
  'gateway_payment_id': null,
  'gateway_signature': null,
  'payment_gateway': null,
  'created_at': '2026-11-01T09:00:00+05:30',
  'label': 'Recovery of reward (reviewed)',
};

Map<String, dynamic> ordinaryLine() => {
  'id': 40,
  'user_id': 7,
  'amount': '250.00',
  'txn_type': 'credit',
  'status': 'completed',
  'gateway_order_id': 'order_Placeholder1',
  'created_at': '2026-11-01T08:00:00+05:30',
  'label': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BookingRefusalState.instance.dismiss();
  });

  group('R4 notification preferences', () {
    test('the payload is read as the API sends it', () {
      final p = NotificationPrefs.fromData(prefsPayload())!;
      expect(p.value('sms', 'transactional'), isTrue);
      expect(p.value('whatsapp', 'transactional'), isFalse);
      expect(p.value('push', 'promotional'), isFalse);
      expect(p.isLocked('in_app', 'transactional'), isTrue);
      expect(p.isLocked('push', 'transactional'), isFalse);
      expect(p.hasChannel('whatsapp'), isTrue);
      expect(NotificationPrefs.fromData('nope'), isNull);
    });

    testWidgets('opening the screen writes nothing and shows offers off', (
      tester,
    ) async {
      final backend = _PrefsBackend();
      await _pumpPrefs(tester, backend);

      expect(
        backend.puts,
        isEmpty,
        reason: 'consent is never saved unprompted',
      );
      for (final key in [
        'pref_push_promotional',
        'pref_sms_promotional',
        'pref_email_promotional',
        'pref_in_app_promotional',
        'pref_whatsapp_transactional',
        'pref_whatsapp_promotional',
      ]) {
        expect(_switchOf(tester, key).value, isFalse, reason: key);
        expect(_switchOf(tester, key).onChanged, isNotNull, reason: key);
      }
      // The words "fraud" and "review" never appear on this screen.
      expect(find.textContaining('fraud'), findsNothing);
    });

    testWidgets(
      'ride and account updates in the app and by push are fixed on',
      (tester) async {
        final backend = _PrefsBackend();
        await _pumpPrefs(tester, backend);

        for (final key in [
          'pref_in_app_transactional',
          'pref_push_transactional',
        ]) {
          final s = _switchOf(tester, key);
          expect(s.value, isTrue, reason: key);
          expect(s.onChanged, isNull, reason: '$key is disabled');
        }
        expect(
          find.text('Always on. Needed for your rides and your safety.'),
          findsNWidgets(2),
        );
        await tester.tap(
          find.byKey(const Key('pref_in_app_transactional')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(backend.puts, isEmpty);
        expect(_switchOf(tester, 'pref_in_app_transactional').value, isTrue);
      },
    );

    testWidgets('a toggle is saved as one explicit PUT and sticks', (
      tester,
    ) async {
      final backend = _PrefsBackend();
      await _pumpPrefs(tester, backend);

      await tester.tap(find.byKey(const Key('pref_push_promotional')));
      await tester.pumpAndSettle();

      expect(backend.puts, hasLength(1));
      final body = jsonDecode(backend.puts.single.body) as Map<String, dynamic>;
      expect(body, {
        'preferences': [
          {'channel': 'push', 'category': 'promotional', 'opted_in': true},
        ],
      });
      expect(_switchOf(tester, 'pref_push_promotional').value, isTrue);
      expect(_switchOf(tester, 'pref_sms_promotional').value, isFalse);
      expect(find.byKey(const Key('prefs_error')), findsNothing);
    });

    testWidgets('WhatsApp has its own explicit opt-in toggle', (tester) async {
      final backend = _PrefsBackend();
      await _pumpPrefs(tester, backend);
      expect(find.text('WhatsApp'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pref_whatsapp_transactional')));
      await tester.pumpAndSettle();

      final body = jsonDecode(backend.puts.single.body) as Map<String, dynamic>;
      expect(body['preferences'], [
        {'channel': 'whatsapp', 'category': 'transactional', 'opted_in': true},
      ]);
      expect(_switchOf(tester, 'pref_whatsapp_transactional').value, isTrue);
      expect(_switchOf(tester, 'pref_whatsapp_promotional').value, isFalse);
    });

    testWidgets('WhatsApp is shown only when the API lists it', (tester) async {
      final backend = _PrefsBackend(initial: prefsPayload(whatsapp: false));
      await _pumpPrefs(tester, backend);

      expect(find.text('WhatsApp'), findsNothing);
      expect(
        find.byKey(const Key('pref_whatsapp_transactional')),
        findsNothing,
      );
      expect(find.byKey(const Key('pref_whatsapp_promotional')), findsNothing);
      expect(find.byKey(const Key('pref_push_promotional')), findsOneWidget);
    });

    testWidgets('a failed save puts the switch back and says so', (
      tester,
    ) async {
      final backend = _PrefsBackend(putStatus: 500);
      await _pumpPrefs(tester, backend);

      await tester.tap(find.byKey(const Key('pref_email_promotional')));
      await tester.pumpAndSettle();

      expect(backend.puts, hasLength(1));
      expect(_switchOf(tester, 'pref_email_promotional').value, isFalse);
      expect(find.text(kPrefsSaveFailed), findsOneWidget);

      // The next successful change clears the message.
      backend.putStatus = 200;
      await tester.tap(find.byKey(const Key('pref_email_promotional')));
      await tester.pumpAndSettle();
      expect(_switchOf(tester, 'pref_email_promotional').value, isTrue);
      expect(find.byKey(const Key('prefs_error')), findsNothing);
    });

    testWidgets('the switch moves at once, before the PUT answers', (
      tester,
    ) async {
      await _phone(tester);
      final gate = Future<void>.delayed(const Duration(seconds: 2));
      final client = MockClient((request) async {
        if (request.method == 'GET') return _json(200, _ok(prefsPayload()));
        await gate;
        return _json(
          200,
          _ok(
            prefsPayload(
              overrides: {
                'sms': {'promotional': true},
              },
            ),
          ),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationPreferencesScreen(
            service: NotificationPreferencesService(client: client),
            tokenReader: () async => 'test-token',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pref_sms_promotional')));
      await tester.pump();
      expect(_switchOf(tester, 'pref_sms_promotional').value, isTrue);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(_switchOf(tester, 'pref_sms_promotional').value, isTrue);
    });

    test(
      'the rider app calls the canonical endpoint, not the older rider one',
      () async {
        final seen = <Uri>[];
        final service = NotificationPreferencesService(
          client: MockClient((r) async {
            seen.add(r.url);
            return _json(200, _ok(prefsPayload()));
          }),
        );
        await service.fetch('t');
        await service.save(
          't',
          channel: 'push',
          category: 'promotional',
          optedIn: true,
        );
        expect(seen, hasLength(2));
        for (final u in seen) {
          expect(u.path, endsWith('/notifications/preferences/'));
          expect(u.path, isNot(contains('/rider/')));
        }
      },
    );
  });

  group('R8 cash not available', () {
    test(
      'a switch to cash refused with CASH_NOT_AVAILABLE is neutral, and sent once',
      () async {
        var posts = 0;
        final service = RideService(
          client: MockClient((request) async {
            posts++;
            return _json(400, {
              'status': 'error',
              'error': {
                'code': 'CASH_NOT_AVAILABLE',
                'message':
                    "Cash isn't available for your account. Please pay online.",
                'field': 'new_method',
                'issue': 'Cash not available',
              },
            });
          }),
        );

        final outcome = await service.selectCashPayment('t', '991');

        expect(outcome.status, CashSwitchStatus.refused);
        expect(outcome.code, 'CASH_NOT_AVAILABLE');
        expect(outcome.message, kCashNotAvailableMessage);
        expect(
          outcome.message,
          "Cash isn't available for this ride. Please choose another payment method.",
        );
        expect(posts, 1, reason: 'a refusal is not retried');
        expect(outcome.message!.toLowerCase(), isNot(contains('fraud')));
        expect(outcome.message!.toLowerCase(), isNot(contains('review')));
      },
    );

    test(
      'a booking refused on the socket shows the message and leaves searching',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(rideNotifierProvider.notifier);
        notifier.updateFromWebSocket({
          'type': 'error',
          'code': 'CASH_NOT_AVAILABLE',
          'message':
              "Cash isn't available for your account. Please pay online.",
        });
        await Future<void>.delayed(Duration.zero);

        final refusal = BookingRefusalState.instance.latest;
        expect(refusal, isNotNull);
        expect(refusal!.code, 'CASH_NOT_AVAILABLE');
        // Booking has no payment choice, so it never says "choose another".
        expect(refusal.message, kCashNotAvailableAtBookingMessage);
        expect(refusal.message, isNot(contains('another payment method')));
        expect(container.read(rideNotifierProvider).status, RideStatus.none);
      },
    );

    testWidgets('the message card shows the neutral sentence', (tester) async {
      await _phone(tester);
      BookingRefusalState.instance.reportMessage(
        kCashNotAvailable,
        kCashNotAvailableMessage,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: MarketOverlays(child: Scaffold(body: SizedBox.expand())),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('booking_refusal_message')), findsOneWidget);
      expect(find.text(kCashNotAvailableMessage), findsOneWidget);
    });
  });

  group('R8 wallet: pending review and recovery', () {
    test('rewards_pending_review is read, and zero or absent is no line', () {
      final held = Wallet.fromJson(balancePayload());
      expect(held.hasPendingReview, isTrue);
      expect(held.pendingReview, '100.00');
      expect(held.currency, 'INR');

      expect(
        Wallet.fromJson(balancePayload(held: '0.00')).hasPendingReview,
        isFalse,
      );
      // The shape before the API sent the key.
      final older = Wallet.fromJson({'balance': '500.00'});
      expect(older.hasPendingReview, isFalse);
      expect(older.balance, 500.0);
    });

    test('the recovery line carries the API label as its title', () {
      final t = Transaction.fromJson(recoveryLine());
      expect(t.title, 'Recovery of reward (reviewed)');
      expect(t.label, 'Recovery of reward (reviewed)');
      expect(t.isCredit, isFalse);
      final plain = Transaction.fromJson(ordinaryLine());
      expect(plain.label, isNull);
      expect(plain.title, isNot('Recovery of reward (reviewed)'));
    });

    Future<void> pumpWallet(
      WidgetTester tester,
      Wallet wallet,
      List<Transaction> txs,
    ) async {
      await _phone(tester);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<WalletProvider>.value(
              value: _FakeWallet(wallet, txs),
            ),
            ChangeNotifierProvider<NotificationProvider>.value(
              value: NotificationProvider(
                notificationService: FakeNotificationService(),
              ),
            ),
            ChangeNotifierProvider<RemoteConfigProvider>.value(
              value: RemoteConfigProvider(),
            ),
          ],
          child: const MaterialApp(home: WalletScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets(
      'a held reward reads Pending review and the recovery line is labelled',
      (tester) async {
        await pumpWallet(tester, Wallet.fromJson(balancePayload()), [
          Transaction.fromJson(recoveryLine()),
          Transaction.fromJson(ordinaryLine()),
        ]);
        expect(find.byKey(const Key('wallet_pending_review')), findsOneWidget);
        expect(
          find.text('Pending review: ₹100.00 (not spendable yet)'),
          findsOneWidget,
        );
        expect(find.text('Recovery of reward (reviewed)'), findsOneWidget);
        expect(find.text('-₹100.00'), findsOneWidget);
        expect(find.textContaining('raud'), findsNothing);
      },
    );

    testWidgets(
      'nothing held and no recovery: the wallet reads as it always did',
      (tester) async {
        await pumpWallet(
          tester,
          Wallet.fromJson(balancePayload(held: '0.00')),
          [Transaction.fromJson(ordinaryLine())],
        );
        expect(find.byKey(const Key('wallet_pending_review')), findsNothing);
        expect(find.textContaining('Pending review'), findsNothing);
        expect(find.textContaining('Recovery of reward'), findsNothing);
      },
    );
  });
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() {
    tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });
}

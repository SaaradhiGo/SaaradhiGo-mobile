/// App catch-up phase 2, rider side: R1 (promo at booking), R2 (Not charged),
/// R5 (ops-ended trips and receipts), R10 (Razorpay Checkout) and the US
/// pass-through lines. Fixtures are the backend's own payloads
/// (test/support/money_fixtures.dart).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/core/market/booking_refusal.dart';
import 'package:saaradhigo_rider/core/market/market_config.dart';
import 'package:saaradhigo_rider/core/promo/promo_messages.dart';
import 'package:saaradhigo_rider/core/promo/promo_selection.dart';
import 'package:saaradhigo_rider/providers/map_provider.dart';
import 'package:saaradhigo_rider/providers/wallet_provider.dart';
import 'package:saaradhigo_rider/screens/home/rider_flow_screens.dart';
import 'package:saaradhigo_rider/services/online_payment.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:saaradhigo_rider/services/trip_charge.dart';
import 'package:saaradhigo_rider/services/models/wallet_model.dart';
import 'package:saaradhigo_rider/services/wallet_service.dart';
import 'package:saaradhigo_rider/services/websocket_service.dart';
import 'package:saaradhigo_rider/state/ride_notifier.dart';
import 'package:saaradhigo_rider/state/ride_state.dart';
import 'package:saaradhigo_rider/widgets/fare_breakdown.dart';
import 'package:saaradhigo_rider/widgets/promo_code_field.dart';
import 'package:saaradhigo_rider/widgets/promo_entry_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_config_fixtures.dart';
import 'support/money_fixtures.dart';
import 'support/screen_test_harness.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeRazorpay implements RazorpayLauncher {
  FakeRazorpay(this.result);
  final CheckoutResult result;
  final opened = <RazorpayOrder>[];

  @override
  Future<CheckoutResult> open(RazorpayOrder order) async {
    opened.add(order);
    return result;
  }
}

class SeededRide extends RideNotifier {
  SeededRide(this.seed);
  final RideState seed;

  @override
  RideState build() {
    super.build();
    return seed;
  }
}

/// A server that answers the three payment/trip endpoints from a script and
/// records what it was asked.
class FakeBackend {
  FakeBackend({
    this.createOrder,
    this.verify = const [],
    this.tripReads = const [],
    this.tripDetail,
  });

  final http.Response? createOrder;
  final List<http.Response> verify;
  final List<http.Response> tripReads;
  final http.Response? tripDetail;
  final requests = <http.Request>[];
  var _verifies = 0;
  var _reads = 0;

  MockClient get client => MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/payments/create-order/')) {
      return createOrder ?? json(500, failure('X', 'unscripted'));
    }
    if (path.endsWith('/payments/verify/')) {
      final r = verify[_verifies.clamp(0, verify.length - 1)];
      _verifies++;
      return r;
    }
    if (RegExp(r'/ride/trip/\d+/$').hasMatch(path)) {
      if (tripDetail != null) return tripDetail!;
      final r = tripReads[_reads.clamp(0, tripReads.length - 1)];
      _reads++;
      return r;
    }
    return json(404, failure('NOT_FOUND', 'unscripted'));
  });

  Iterable<http.Request> to(String suffix) =>
      requests.where((r) => r.url.path.endsWith(suffix));
  Map<String, dynamic> bodyOf(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;
}

OnlinePaymentFlow flowFor(
  FakeBackend backend,
  RazorpayLauncher razorpay, {
  CashfreeStarter? cashfree,
  VoidCallback? onConfirming,
  int maxPolls = 3,
}) => OnlinePaymentFlow(
  rides: RideService(client: backend.client),
  razorpay: razorpay,
  cashfree: cashfree ?? (_) async => fail('Cashfree must not open'),
  pollInterval: Duration.zero,
  maxPolls: maxPolls,
  onConfirming: onConfirming,
);

const _success = CheckoutSuccess(
  orderId: 'order_TestPlaceholder01',
  paymentId: 'pay_TestPlaceholder01',
  signature: 'sig_placeholder',
);

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token-placeholder',
    });
    PromoSelection.instance.clear();
    BookingRefusalState.instance.dismiss();
  });

  // ------------------------------------------------------------------ R1
  group('R1 promo code at booking', () {
    test('the promo flag is read from app-config; a missing key is false', () {
      final noKey = MarketConfig.fromData(
        (indiaBody()['data'] as Map).cast<String, dynamic>(),
      );
      expect(noKey.promosAvailable, isFalse);

      final off = MarketConfig.fromData({
        ...(indiaBody()['data'] as Map).cast<String, dynamic>(),
        'promos_available': false,
      });
      expect(off.promosAvailable, isFalse);

      final on = MarketConfig.fromData({
        ...(indiaBody()['data'] as Map).cast<String, dynamic>(),
        'promos_available': true,
      });
      expect(on.promosAvailable, isTrue);
      expect(MarketConfig.builtIn.promosAvailable, isFalse);
    });

    Future<void> pumpEntry(
      WidgetTester tester, {
      required bool available,
      Future<Map<String, dynamic>?> Function(String)? apply,
      Map<String, dynamic>? fare,
    }) async {
      final base = MarketConfig.fromData({
        ...(indiaBody()['data'] as Map).cast<String, dynamic>(),
        if (available) 'promos_available': true,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PromoEntrySection(
              market: base,
              fareData: fare ?? indiaQuote(),
              vehicleType: 'car',
              applyOverride: apply,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the entry is hidden when no promo is available', (t) async {
      await pumpEntry(t, available: false);
      expect(find.byKey(const Key('promo_entry')), findsNothing);
      expect(find.byKey(const Key('promo_input')), findsNothing);
      expect(find.text('Promo code'), findsNothing);
    });

    testWidgets('the entry shows when the backend says a promo is live', (
      t,
    ) async {
      await pumpEntry(t, available: true);
      expect(find.byKey(const Key('promo_input')), findsOneWidget);
    });

    testWidgets('an applied code shows the discount and what the rider pays', (
      t,
    ) async {
      await pumpEntry(t, available: true, apply: (c) async => promoApplied());
      await t.enterText(find.byKey(const Key('promo_input')), 'welcome50');
      await t.tap(find.byKey(const Key('promo_apply')));
      await t.pumpAndSettle();

      expect(find.text('WELCOME50 applied'), findsOneWidget);
      expect(find.text('Discount -₹50.00'), findsOneWidget);
      expect(find.text('You pay ₹119.02'), findsOneWidget);
      // The code the booking will send.
      expect(PromoSelection.instance.code, 'WELCOME50');

      await t.tap(find.byKey(const Key('promo_remove')));
      await t.pumpAndSettle();
      expect(PromoSelection.instance.code, isNull);
      expect(find.byKey(const Key('promo_input')), findsOneWidget);
    });

    for (final entry in kPromoRefusalMessages.entries) {
      testWidgets('${entry.key} gets its own sentence', (t) async {
        await pumpEntry(
          t,
          available: true,
          apply: (c) async => promoRefused(entry.key),
        );
        await t.enterText(find.byKey(const Key('promo_input')), 'BADCODE');
        await t.tap(find.byKey(const Key('promo_apply')));
        await t.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        // The backend's wording is for the console, not the rider.
        expect(find.textContaining('backend wording'), findsNothing);
        expect(PromoSelection.instance.code, isNull);
      });
    }

    test('an unknown PROMO_ reason still gets a neutral sentence', () {
      expect(promoRefusalMessage('PROMO_SOMETHING_NEW'), isNotEmpty);
      expect(promoRefusalMessage('PROMO_SOMETHING_NEW'), isNot(contains('_')));
    });

    test('the booking frame carries promo_code only when one is applied', () {
      Map<String, dynamic> frame({String? promo}) =>
          WebSocketService.buildRideRequestPayload(
            pickupLat: 17.4,
            pickupLng: 78.4,
            destinationLat: 17.5,
            destinationLng: 78.5,
            distanceKm: 5,
            durationMin: 12,
            vehicleType: 'car',
            pickupAddress: 'A',
            destinationAddress: 'B',
            paymentMethod: 'cash',
            promoCode: promo,
          );
      expect(frame().containsKey('promo_code'), isFalse);
      expect(frame(promo: '').containsKey('promo_code'), isFalse);
      expect(frame(promo: 'WELCOME50')['promo_code'], 'WELCOME50');
      // Everything else in the frame is what it always was.
      expect(frame()['type'], 'ride_request');
      expect(frame()['payment_method'], 'cash');
    });

    test('a code the booking refuses is explained and cleared', () async {
      PromoSelection.instance.apply(PromoApplyResult.fromMap(promoApplied()));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(rideNotifierProvider.notifier)
          .updateFromWebSocket(bookingPromoRefusal('PROMO_EXPIRED'));
      await Future<void>.delayed(Duration.zero);

      final refusal = BookingRefusalState.instance.latest;
      expect(refusal, isNotNull);
      expect(refusal!.code, 'PROMO_EXPIRED');
      expect(refusal.message, contains('That code has expired.'));
      expect(PromoSelection.instance.code, isNull);
      expect(container.read(rideNotifierProvider).status, RideStatus.none);
    });

    test('a city refusal still works the way phase 1 built it', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(rideNotifierProvider.notifier).updateFromWebSocket({
        'type': 'error',
        'code': 'CITY_PAUSED',
        'message': 'Rides are paused.',
      });
      expect(BookingRefusalState.instance.latest?.code, 'CITY_PAUSED');
    });

    test(
      'the trip_created frame is read into the discount and the payable',
      () {
        final c = TripCharge.fromRide(tripCreatedWithPromo());
        expect(c.promoCode, 'WELCOME50');
        expect(c.discount, '50.00');
        expect(c.payable, '119.02');
        expect(c.notCharged, isFalse);

        final none = TripCharge.fromRide(tripCreatedPlain());
        expect(none.hasPromo, isFalse);
        expect(none.notCharged, isFalse);

        expect(
          TripCharge.fromRide(tripCreatedFullyCovered()).notCharged,
          isTrue,
        );
      },
    );
  });

  // ------------------------------------------------------------ R10 parse
  group('R10 create-order is read by gateway', () {
    test('razorpay: the order, key, amount, currency and prefill', () {
      final order = parseCreateOrder(razorpayOrder());
      expect(order, isA<RazorpayOrder>());
      final r = order as RazorpayOrder;
      expect(r.orderId, 'order_TestPlaceholder01');
      expect(r.keyId, 'rzp_test_placeholder');
      expect(r.amountMinor, 15000);
      expect(r.currency, 'INR');
      final options = razorpayOptions(r);
      expect(options['key'], 'rzp_test_placeholder');
      expect(options['order_id'], 'order_TestPlaceholder01');
      expect(options['amount'], 15000);
      expect(options['currency'], 'INR');
      expect(options['prefill'], {
        'contact': '+910000000001',
        'email': 'rider@example.test',
      });
    });

    test(
      'razorpay with a field missing is "unavailable", never a checkout',
      () {
        for (final drop in ['key_id', 'order_id', 'amount_paise']) {
          final body = razorpayOrder();
          (body['data'] as Map<String, dynamic>).remove(drop);
          if (drop == 'order_id') {
            (body['data'] as Map<String, dynamic>).remove('gateway_order_id');
          }
          expect(parseCreateOrder(body), isA<UnavailableOrder>(), reason: drop);
        }
      },
    );

    test('cashfree: the existing path, with its session', () {
      final order = parseCreateOrder(cashfreeOrder());
      expect(order, isA<CashfreeOrder>());
      expect((order as CashfreeOrder).sessionId, 'session_fake_1');
      expect(order.orderId, 'cf_order_placeholder_1');
    });

    test('an older backend with no gateway key still reaches Cashfree', () {
      expect(parseCreateOrder(legacyCashfreeOrder()), isA<CashfreeOrder>());
    });

    test('an unknown gateway or none is "online payment unavailable"', () {
      final body = cashfreeOrder();
      (body['data'] as Map<String, dynamic>)['gateway'] = 'stripe';
      expect(parseCreateOrder(body), isA<UnavailableOrder>());
      expect(parseCreateOrder(null), isA<UnavailableOrder>());
      final refused = parseCreateOrder(noGateway());
      expect(refused, isA<UnavailableOrder>());
      expect(
        (refused as UnavailableOrder).message,
        'No payment gateway configured',
      );
    });

    test('NOT_CHARGED is its own outcome, with the backend wording', () {
      final promo = parseCreateOrder(notChargedPromo());
      expect(promo, isA<NotChargedOrder>());
      expect(
        (promo as NotChargedOrder).message,
        'A promotion covered this trip, so you were not charged.',
      );
      expect(parseCreateOrder(notChargedOpsEnd()), isA<NotChargedOrder>());
    });
  });

  // ------------------------------------------------------------ R10 / R2 flow
  group('R10 Razorpay Checkout, end to end through the real RideService', () {
    test(
      'success: opens Checkout, then posts the three razorpay_ fields',
      () async {
        final backend = FakeBackend(
          createOrder: json(201, razorpayOrder()),
          verify: [json(200, verifyOk())],
        );
        final razorpay = FakeRazorpay(_success);
        final result = await flowFor(
          backend,
          razorpay,
        ).pay(token: 'token-placeholder', tripId: 991);

        expect(result.outcome, OnlinePaymentOutcome.paid);
        expect(razorpay.opened, hasLength(1));
        final verify = backend.bodyOf(backend.to('/payments/verify/').single);
        expect(verify, {
          'razorpay_order_id': 'order_TestPlaceholder01',
          'razorpay_payment_id': 'pay_TestPlaceholder01',
          'razorpay_signature': 'sig_placeholder',
        });
        expect(
          backend.to('/payments/verify/').single.headers['Authorization'],
          'Bearer token-placeholder',
        );
      },
    );

    test('cancel: no verify, a cancelled outcome', () async {
      final backend = FakeBackend(createOrder: json(201, razorpayOrder()));
      final result = await flowFor(
        backend,
        FakeRazorpay(const CheckoutCancelled()),
      ).pay(token: 't', tripId: 991);
      expect(result.outcome, OnlinePaymentOutcome.cancelled);
      expect(backend.to('/payments/verify/'), isEmpty);
    });

    test('failure: the SDK message, no verify', () async {
      final backend = FakeBackend(createOrder: json(201, razorpayOrder()));
      final result = await flowFor(
        backend,
        FakeRazorpay(const CheckoutFailed('Your card was declined.')),
      ).pay(token: 't', tripId: 991);
      expect(result.outcome, OnlinePaymentOutcome.failed);
      expect(result.message, 'Your card was declined.');
      expect(backend.to('/payments/verify/'), isEmpty);
    });

    test('a bad signature (400) is a failure, not a payment', () async {
      final backend = FakeBackend(
        createOrder: json(201, razorpayOrder()),
        verify: [json(400, signatureInvalid())],
      );
      final result = await flowFor(
        backend,
        FakeRazorpay(_success),
      ).pay(token: 't', tripId: 991);
      expect(result.outcome, OnlinePaymentOutcome.failed);
    });

    test(
      '409 PAYMENT_NOT_CAPTURED: says "confirming", then polls the trip',
      () async {
        var confirming = 0;
        final backend = FakeBackend(
          createOrder: json(201, razorpayOrder()),
          verify: [json(409, paymentNotCaptured())],
          tripReads: [
            json(200, tripDetailPending()),
            json(200, tripDetailPending()),
            json(200, tripDetailPaid()),
          ],
        );
        final result = await flowFor(
          backend,
          FakeRazorpay(_success),
          onConfirming: () => confirming++,
          maxPolls: 5,
        ).pay(token: 't', tripId: 991);

        expect(confirming, 1);
        expect(result.outcome, OnlinePaymentOutcome.paid);
        expect(backend.to('/ride/trip/991/'), hasLength(3));
        // The payment is not posted again: confirmation is the server's job.
        expect(backend.to('/payments/verify/'), hasLength(1));
      },
    );

    test(
      'the polling is bounded; the rider is told it is still confirming',
      () async {
        final backend = FakeBackend(
          createOrder: json(201, razorpayOrder()),
          verify: [json(409, paymentNotCaptured())],
          tripReads: [json(200, tripDetailPending())],
        );
        final result = await flowFor(
          backend,
          FakeRazorpay(_success),
          maxPolls: 4,
        ).pay(token: 't', tripId: 991);
        expect(result.outcome, OnlinePaymentOutcome.confirming);
        expect(result.message, kPaymentStillConfirmingMessage);
        expect(backend.to('/ride/trip/991/'), hasLength(4));
      },
    );

    test(
      'Cashfree is still exercised: its starter runs and verify keeps its shape',
      () async {
        final backend = FakeBackend(
          createOrder: json(201, cashfreeOrder()),
          verify: [json(200, verifyOk())],
        );
        CashfreeOrder? started;
        final razorpay = FakeRazorpay(_success);
        final result = await flowFor(
          backend,
          razorpay,
          cashfree: (order) async {
            started = order;
            return order.orderId;
          },
        ).pay(token: 't', tripId: 991);

        expect(result.outcome, OnlinePaymentOutcome.paid);
        expect(started!.sessionId, 'session_fake_1');
        expect(
          razorpay.opened,
          isEmpty,
          reason: 'Razorpay is not opened for Cashfree',
        );
        final verify = backend.bodyOf(backend.to('/payments/verify/').single);
        expect(verify['gateway_order_id'], 'cf_order_placeholder_1');
        expect(verify.containsKey('razorpay_order_id'), isFalse);
      },
    );

    test('Cashfree closed without paying is a cancel', () async {
      final backend = FakeBackend(createOrder: json(201, cashfreeOrder()));
      final result = await flowFor(
        backend,
        FakeRazorpay(_success),
        cashfree: (_) async => null,
      ).pay(token: 't', tripId: 991);
      expect(result.outcome, OnlinePaymentOutcome.cancelled);
      expect(backend.to('/payments/verify/'), isEmpty);
    });

    test(
      'no gateway: online payment is unavailable and nothing opens',
      () async {
        final backend = FakeBackend(createOrder: json(503, noGateway()));
        final razorpay = FakeRazorpay(_success);
        final result = await flowFor(
          backend,
          razorpay,
        ).pay(token: 't', tripId: 991);
        expect(result.outcome, OnlinePaymentOutcome.unavailable);
        expect(result.message, 'No payment gateway configured');
        expect(razorpay.opened, isEmpty);
      },
    );
  });

  group('R2 Not charged', () {
    for (final entry in {
      'a promo covered the fare': notChargedPromo(),
      'ops ended it as a safety incident or platform fault': notChargedOpsEnd(),
    }.entries) {
      test(
        '409 NOT_CHARGED (${entry.key}) never opens checkout or verifies',
        () async {
          final backend = FakeBackend(
            createOrder: json(409, entry.value),
            verify: [json(200, verifyOk())],
          );
          final razorpay = FakeRazorpay(_success);
          var cashfreeOpened = false;
          final result = await flowFor(
            backend,
            razorpay,
            cashfree: (_) async {
              cashfreeOpened = true;
              return 'x';
            },
          ).pay(token: 't', tripId: 991);

          expect(result.outcome, OnlinePaymentOutcome.notCharged);
          expect(razorpay.opened, isEmpty);
          expect(cashfreeOpened, isFalse);
          expect(backend.to('/payments/verify/'), isEmpty);
          expect(result.message, isNotEmpty);
        },
      );
    }
  });

  // ------------------------------------------------------------- the screen
  group('the payment summary screen', () {
    Future<ProviderContainer> pumpSummary(
      WidgetTester tester, {
      required List<Map<String, dynamic>> frames,
      FakeBackend? backend,
      RazorpayLauncher? razorpay,
      String status = 'complete',
    }) async {
      stubStartupPluginChannels();
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        tester.view.resetDevicePixelRatio();
      });
      var raw = <String, dynamic>{};
      for (final f in frames) {
        raw = {...raw, ...f};
      }
      final container = ProviderContainer(
        overrides: [
          rideNotifierProvider.overrideWith(
            () => SeededRide(
              RideState(
                status: RideStatus.rideCompleted,
                tripId: '991',
                rawResponse: {'status': status, ...raw},
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MapProvider>.value(
              value: MapProvider(container: container),
            ),
            ChangeNotifierProvider<WalletProvider>.value(
              // A wallet that answers at once: a real client never completes
              // under fake time and would leave the load timeout pending.
              value: WalletProvider(walletService: _InstantWallet()),
            ),
          ],
          child: MaterialApp(
            home: RidePaymentSummaryScreen(
              rideService: RideService(
                client: (backend ?? FakeBackend()).client,
              ),
              razorpay: razorpay,
              confirmPollInterval: Duration.zero,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      return container;
    }

    testWidgets('India, no promo: exactly the card it always was', (t) async {
      await pumpSummary(t, frames: [tripCreatedPlain()]);
      // Tier 2 receipt: the ticket and the cost side by side, equal.
      expect(find.byKey(const Key('receipt_ticket')), findsOneWidget);
      expect(find.byKey(const Key('receipt_exact')), findsOneWidget);
      expect(find.text('₹169.02'), findsNWidgets(2));
      expect(find.text('Pay ₹169.02 by Cash'), findsOneWidget);
      // The charge card is still there, under How it adds up.
      await t.tap(find.byKey(const Key('receipt_how')));
      await t.pumpAndSettle();
      expect(find.text('FARE'), findsOneWidget);
      await t.scrollUntilVisible(find.byKey(const Key('pay_button')), 200);
      expect(find.byKey(const Key('pay_button')), findsOneWidget);
      expect(
        find.text('Pay with Cash'),
        findsOneWidget,
        reason: 'booked as cash, so cash is preselected',
      );
      expect(find.byKey(const Key('promo_discount_line')), findsNothing);
      expect(find.byKey(const Key('not_charged_label')), findsNothing);
    });

    testWidgets('a promo trip shows the discount and what the rider pays', (
      t,
    ) async {
      await pumpSummary(t, frames: [tripCreatedWithPromo()]);
      expect(find.text('Promotion'), findsOneWidget);
      expect(find.byKey(const Key('receipt_unexplained')), findsNothing);
      await t.tap(find.byKey(const Key('receipt_how')));
      await t.pumpAndSettle();
      expect(find.text('Promo WELCOME50  -₹50.00'), findsOneWidget);
      expect(find.byKey(const Key('you_pay_amount')), findsOneWidget);
      expect(find.text('₹119.02'), findsWidgets);
      await t.scrollUntilVisible(find.byKey(const Key('pay_button')), 200);
      expect(find.byKey(const Key('pay_button')), findsOneWidget);
    });

    testWidgets(
      'a trip the promo fully covers says Not charged and asks for nothing',
      (t) async {
        await pumpSummary(t, frames: [tripCreatedFullyCovered()]);
        expect(find.byKey(const Key('not_charged_label')), findsOneWidget);
        expect(find.text('Not charged'), findsOneWidget);
        expect(find.byKey(const Key('pay_button')), findsNothing);
        expect(find.text('Pay with Cash instead?'), findsNothing);
        expect(find.byKey(const Key('not_charged_continue')), findsOneWidget);
      },
    );

    testWidgets(
      'create-order 409 NOT_CHARGED turns the screen to Not charged; checkout never opens',
      (t) async {
        final backend = FakeBackend(createOrder: json(409, notChargedOpsEnd()));
        final razorpay = FakeRazorpay(_success);
        await pumpSummary(
          t,
          frames: [tripCreatedPlain()],
          backend: backend,
          razorpay: razorpay,
        );
        await t.tap(find.text('Pay via UPI/Card'));
        await t.pump();
        await t.tap(find.byKey(const Key('pay_button')));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('not_charged_label')), findsOneWidget);
        expect(
          find.text(
            'This trip was ended by SaaradhiGo and you were not charged.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('pay_button')), findsNothing);
        expect(razorpay.opened, isEmpty);
        expect(backend.to('/payments/verify/'), isEmpty);
      },
    );

    testWidgets(
      'online payment unavailable keeps the existing message and cash',
      (t) async {
        final backend = FakeBackend(createOrder: json(503, noGateway()));
        final razorpay = FakeRazorpay(_success);
        await pumpSummary(
          t,
          frames: [tripCreatedPlain()],
          backend: backend,
          razorpay: razorpay,
        );
        await t.tap(find.text('Pay via UPI/Card'));
        await t.pump();
        await t.tap(find.byKey(const Key('pay_button')));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 100));

        expect(find.text('No payment gateway configured'), findsOneWidget);
        expect(razorpay.opened, isEmpty);
        // Still on the payment screen, cash still offered.
        expect(find.text('Pay with Cash instead?'), findsOneWidget);
      },
    );

    testWidgets(
      'a trip support ended: the notice, the distance driven and its fare',
      (t) async {
        final backend = FakeBackend(
          tripDetail: json(200, tripDetailOpsEndedStandard()),
        );
        await pumpSummary(
          t,
          frames: [tripCreatedPlain(), opsEndedFrame()],
          backend: backend,
        );
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 100));

        expect(find.text('Ride ended by SaaradhiGo support'), findsOneWidget);
        expect(find.text('Distance driven: 4.6 km'), findsOneWidget);
        // The capped fare for the distance driven, not the 169.02 quote.
        expect(find.text('₹92.40'), findsOneWidget);
        expect(find.text('₹169.02'), findsNothing);
        await t.scrollUntilVisible(find.byKey(const Key('pay_button')), 200);
        expect(find.byKey(const Key('pay_button')), findsOneWidget);
      },
    );

    testWidgets(
      'a platform-funded end shows Not charged with the distance driven',
      (t) async {
        final backend = FakeBackend(
          tripDetail: json(200, tripDetailOpsEndedNotCharged()),
        );
        await pumpSummary(
          t,
          frames: [tripCreatedPlain(), opsEndedFrame()],
          backend: backend,
        );
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 100));

        expect(find.text('Ride ended by SaaradhiGo support'), findsOneWidget);
        expect(find.text('Distance driven: 6.3 km'), findsOneWidget);
        expect(find.byKey(const Key('not_charged_label')), findsOneWidget);
        expect(find.byKey(const Key('pay_button')), findsNothing);
      },
    );
  });

  group('R5 reading the ops frames', () {
    test(
      'ops-ended and ops-cancelled are recognised; ordinary ones are not',
      () {
        expect(isOpsEnded(opsEndedFrame()), isTrue);
        expect(isOpsCancelled(opsCancelledFrame()), isTrue);
        expect(
          isOpsEnded({'status': 'complete', 'message': 'Trip completed'}),
          isFalse,
        );
        expect(
          isOpsCancelled({'status': 'cancel', 'message': 'Driver cancelled'}),
          isFalse,
        );
        expect(isOpsEnded(null), isFalse);
      },
    );

    test(
      'the trip detail says Not charged for a waived or zero final fare',
      () {
        final waived = TripCharge.fromTripDetail(
          (tripDetailOpsEndedNotCharged()['data'] as Map)
              .cast<String, dynamic>(),
        );
        expect(waived.notCharged, isTrue);
        final capped = TripCharge.fromTripDetail(
          (tripDetailOpsEndedStandard()['data'] as Map).cast<String, dynamic>(),
        );
        expect(capped.notCharged, isFalse);
        final paid = TripCharge.fromTripDetail(
          (tripDetailPaid()['data'] as Map).cast<String, dynamic>(),
        );
        expect(paid.notCharged, isFalse);
      },
    );
  });

  // ------------------------------------------------------ receipt, tax lines
  group('receipt: tax and the regulatory fee', () {
    Future<void> pumpPanel(WidgetTester t, Map<String, dynamic> fare) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: FareBreakdown(fareData: fare)),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets(
      'US: tax and the fee are shown as collected and remitted, apart from the fare',
      (t) async {
        await pumpPanel(t, usQuote());
        expect(find.text('Sales tax (8.25%)'), findsOneWidget);
        expect(find.text('\$1.65'), findsOneWidget);
        expect(find.text('Regulatory fee'), findsOneWidget);
        expect(find.text('\$0.50'), findsOneWidget);
        expect(
          find.text('Collected and remitted by SaaradhiGo'),
          findsNWidgets(2),
        );
        expect(find.text('\$22.15'), findsOneWidget);
      },
    );

    testWidgets('India: inclusive tax adds no line; the panel is unchanged', (
      t,
    ) async {
      await pumpPanel(t, indiaQuote());
      expect(find.textContaining('Collected and remitted'), findsNothing);
      expect(find.text('Regulatory fee'), findsNothing);
      expect(find.textContaining('GST'), findsNothing);
      expect(find.text('Base fare'), findsOneWidget);
      expect(find.text('₹169.02'), findsOneWidget);
    });
  });
}

class _InstantWallet extends WalletService {
  @override
  Future<Wallet> loadBalance() async => Wallet(balance: 0, currency: 'INR');

  @override
  Future<List<Transaction>> loadTransactions() async => const [];
}

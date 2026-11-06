import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saaradhigo_rider/core/market/market_config.dart';
import 'package:saaradhigo_rider/core/market/market_config_store.dart';
import 'package:saaradhigo_rider/screens/home/payment_status_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tier 2, PR D: payment failed says only what is known.
void main() {
  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const PaymentStatusScreen(
            status: 'failed',
            amount: 169,
            errorMessage: 'We could not take the payment.',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the banner, the careful refund line, what is still to pay', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('payment_failed_banner')), findsOneWidget);
    expect(find.text('Payment did not go through'), findsOneWidget);
    expect(
      find.text('If money left your account, it will come back to you.'),
      findsOneWidget,
    );
    expect(find.textContaining('No money left'), findsNothing);
    expect(find.text('₹169'), findsOneWidget);
    expect(find.byKey(const Key('payment_support')), findsOneWidget);
    expect(find.byKey(const Key('payment_try_again')), findsOneWidget);
  });

  testWidgets('refund days only when app-config gives them', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('payment_refund_days')), findsNothing);

    MarketConfigStore.instance.debugSet(
      MarketConfig.fromData({
        'country': {
          'code': 'IN',
          'cancel_policy': {'charges_fee': false, 'refund_days': 7},
        },
      }),
    );
    addTearDown(
      () => MarketConfigStore.instance.debugSet(MarketConfig.builtIn),
    );
    await pump(tester);
    expect(find.text('It comes back within 7 working days.'), findsOneWidget);
  });
}

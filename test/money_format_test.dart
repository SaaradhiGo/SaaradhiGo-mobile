/// Currency rendering, including the regression that caused this file.
///
/// The booking screen did `rideData?['currency'] ?? '₹'` and interpolated the
/// result as a symbol. That worked only while the server omitted the field.
/// The backend now returns an ISO 4217 code with every quote — verified
/// against deployed QA on 2026-10-17:
///
///   "estimated_fare": "169.02", "currency": "INR"
///
/// so the screen rendered **INR169.02** to a rider.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/utils/money.dart';
import 'package:saaradhigo_rider/widgets/fare_breakdown.dart';

void main() {
  group('the regression', () {
    test('an INR code renders as a rupee symbol, never as the letters INR', () {
      final shown = formatServerMoney('169.02', 'INR');
      expect(shown, '₹169.02');
      expect(shown, isNot(contains('INR')));
    });

    test('a USD code renders as a dollar symbol', () {
      expect(formatServerMoney('30.83', 'USD'), '\$30.83');
    });
  });

  group('symbol resolution', () {
    test('is case- and whitespace-tolerant, because this runs on a payload',
        () {
      expect(currencySymbol('inr'), '₹');
      expect(currencySymbol(' usd '), '\$');
    });

    test('an absent currency falls back to India, as the app did before', () {
      expect(currencySymbol(null), '₹');
      expect(currencySymbol(''), '₹');
      expect(normaliseCurrency(null), 'INR');
    });

    test('an unknown code is shown as a spaced code, never glued to digits',
        () {
      // "CAD 42.00" is a readable price. "CAD42.00" is the bug.
      final shown = formatMoney(42, 'CAD');
      expect(shown, 'CAD 42.00');
      expect(shown, isNot('CAD42.00'));
    });
  });

  group('the digits the server sent are the digits shown', () {
    test('a server decimal string is passed through untouched', () {
      // Re-parsing and re-rounding a fare is a chance to change what the
      // rider is charged. 169.02 must not become 169.0 or 169.
      expect(formatServerMoney('169.02', 'INR'), '₹169.02');
      expect(formatServerMoney('0.01', 'INR'), '₹0.01');
      expect(formatServerMoney('1000000.00', 'INR'), '₹1000000.00');
    });

    test('a num is given two decimals rather than passed through', () {
      // Dart renders the double 87.5 as "87.5", and "₹87.5" is not a price.
      expect(formatServerMoney(87.5, 'INR'), '₹87.50');
      expect(formatMoney(30, 'INR'), '₹30.00');
    });

    test('decimals can be dropped where they are noise', () {
      expect(formatMoney('169.02', 'INR', decimals: 0), '₹169');
    });

    test('an unparseable or absent amount yields null, not a zero', () {
      // A line that renders "₹0.00" is read by a rider as a real charge.
      expect(formatMoney(null, 'INR'), isNull);
      expect(formatMoney('not-a-number', 'INR'), isNull);
      expect(formatServerMoney(null, 'INR'), isNull);
    });
  });

  group('the fare panel', () {
    Future<void> pumpPanel(
      WidgetTester tester,
      Map<String, dynamic> fareData,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FareBreakdown(fareData: fareData),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders the quote currency on every line', (tester) async {
      // The shape deployed QA actually returns.
      await pumpPanel(tester, {
        'estimated_fare': '169.02',
        'currency': 'INR',
        'fare_breakdown': {
          'base_fare': '60.00',
          'distance_fare': '55.59',
          'time_fare': '19.62',
        },
        'fare_adjustments': [
          {'code': 'surge', 'label': 'Busy-time surcharge', 'amount': '33.80'},
          {'code': 'rounding', 'label': 'Rounding', 'amount': '0.01'},
        ],
      });

      expect(find.text('₹169.02'), findsOneWidget);
      expect(find.text('₹60.00'), findsOneWidget);
      expect(find.text('₹33.80'), findsOneWidget);
      expect(find.textContaining('INR'), findsNothing);
    });

    testWidgets('follows the currency the quote declares, not a default',
        (tester) async {
      await pumpPanel(tester, {
        'estimated_fare': '30.83',
        'currency': 'USD',
        'fare_breakdown': {'base_fare': '2.50', 'distance_fare': '17.50'},
      });

      expect(find.text('\$30.83'), findsOneWidget);
      expect(find.text('\$2.50'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    });

    testWidgets('a quote with no currency still renders in rupees',
        (tester) async {
      // An older server build. The app must not regress for it.
      await pumpPanel(tester, {
        'estimated_fare': '190.00',
        'fare_breakdown': {'base_fare': '30.00'},
      });

      expect(find.text('₹190.00'), findsOneWidget);
    });
  });
}

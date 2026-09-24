// Fare transparency is a money surface, so the parsing and the suppression
// rules are pinned rather than eyeballed.
//
// The panel previously compared `fareBreakdown['discount'] > 0` on a dynamic.
// DRF serialises Decimal as a String, so the server sends "0.00" and that
// comparison throws at runtime. These tests would have caught it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/widgets/fare_breakdown.dart';

Future<void> pumpPanel(
  WidgetTester tester,
  Map<String, dynamic>? fareData,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: FareBreakdown(fareData: fareData)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Shaped like a real /ride/estimate-fare/ response: every money field is a
/// String, because that is what DRF sends for a Decimal.
Map<String, dynamic> quote({
  String base = '30.00',
  String distance = '45.50',
  String time = '12.00',
  String surge = '1.0',
  bool minFare = false,
  String? discount,
  String? waiting,
  String? taxes,
  String total = '87.50',
}) {
  return {
    'estimated_fare': total,
    'fare_breakdown': {
      'base_fare': base,
      'distance_fare': distance,
      'time_fare': time,
      'surge_multiplier': surge,
      'min_fare_applied': minFare,
      if (discount != null) 'discount': discount,
      if (waiting != null) 'waiting_fare': waiting,
      if (taxes != null) 'taxes': taxes,
    },
  };
}

void main() {
  group('the components the server sends are shown', () {
    testWidgets('base, distance, time and total', (tester) async {
      await pumpPanel(tester, quote());

      expect(find.text('Base fare'), findsOneWidget);
      expect(find.text('₹30.00'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('₹45.50'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('₹12.00'), findsOneWidget);
      expect(find.text('Estimated total'), findsOneWidget);
      expect(find.text('₹87.50'), findsOneWidget);
    });

    testWidgets('money arriving as a number, not a String, still renders',
        (tester) async {
      await pumpPanel(tester, {
        'estimated_fare': 87.5,
        'fare_breakdown': {'base_fare': 30, 'distance_fare': 45.5},
      });

      expect(find.text('₹30.00'), findsOneWidget);
      expect(find.text('₹45.50'), findsOneWidget);
      expect(find.text('₹87.50'), findsOneWidget);
    });

    testWidgets('a field the server omits does not render as zero',
        (tester) async {
      // The quote endpoint sends no waiting_fare or taxes today. Rendering
      // "₹0.00" for them would read as a real charge of nothing.
      await pumpPanel(tester, quote());

      expect(find.text('Waiting'), findsNothing);
      expect(find.text('Taxes and fees'), findsNothing);
      expect(find.text('₹0.00'), findsNothing);
    });

    testWidgets('they render once the server does send them', (tester) async {
      await pumpPanel(tester, quote(waiting: '5.00', taxes: '4.20'));

      expect(find.text('Waiting'), findsOneWidget);
      expect(find.text('₹5.00'), findsOneWidget);
      expect(find.text('Taxes and fees'), findsOneWidget);
      expect(find.text('₹4.20'), findsOneWidget);
    });
  });

  group('promotions are not live, so a zero discount must stay invisible', () {
    testWidgets('a "0.00" String discount shows no promo line and does not throw',
        (tester) async {
      await pumpPanel(tester, quote(discount: '0.00'));

      expect(find.text('Promo discount'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a numeric zero discount shows no promo line', (tester) async {
      await pumpPanel(tester, {
        'estimated_fare': '87.50',
        'fare_breakdown': {'base_fare': '30.00', 'discount': 0},
      });

      expect(find.text('Promo discount'), findsNothing);
    });

    testWidgets('a real discount is shown as a deduction', (tester) async {
      await pumpPanel(tester, quote(discount: '15.00'));

      expect(find.text('Promo discount'), findsOneWidget);
      expect(find.text('-₹15.00'), findsOneWidget);
    });
  });

  group('surge is disclosed, not hidden', () {
    testWidgets('1.0x is not mentioned at all', (tester) async {
      // An ordinary trip should not carry a line saying nothing happened.
      await pumpPanel(tester, quote(surge: '1.0'));

      expect(find.text('Busy-time surcharge'), findsNothing);
    });

    testWidgets('a multiplier above 1 is named and explained', (tester) async {
      await pumpPanel(tester, quote(surge: '1.4'));

      expect(find.text('Busy-time surcharge'), findsOneWidget);
      expect(find.text('1.4x'), findsOneWidget);
      expect(
        find.textContaining('Demand is high'),
        findsOneWidget,
        reason: 'MVA-2020 requires surge to be disclosed, not just applied',
      );
    });

    testWidgets('a surge sent as a number is handled', (tester) async {
      await pumpPanel(tester, {
        'estimated_fare': '100.00',
        'fare_breakdown': {'base_fare': '30.00', 'surge_multiplier': 1.5},
      });

      expect(find.text('1.5x'), findsOneWidget);
    });
  });

  group('minimum fare', () {
    testWidgets('is said out loud when it applied', (tester) async {
      await pumpPanel(tester, quote(minFare: true));

      expect(find.text('Minimum fare applied'), findsOneWidget);
    });

    testWidgets('is silent when it did not', (tester) async {
      await pumpPanel(tester, quote(minFare: false));

      expect(find.text('Minimum fare applied'), findsNothing);
    });
  });

  group('degraded and hostile payloads', () {
    testWidgets('no fare data at all renders without throwing',
        (tester) async {
      await pumpPanel(tester, null);

      expect(find.text('Estimated total'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a total with no breakdown still shows the total',
        (tester) async {
      await pumpPanel(tester, {'estimated_fare': '99.00'});

      expect(find.text('₹99.00'), findsOneWidget);
      expect(find.text('Base fare'), findsNothing);
    });

    testWidgets('unparseable money is skipped rather than crashing',
        (tester) async {
      await pumpPanel(tester, {
        'estimated_fare': 'not-a-number',
        'fare_breakdown': {'base_fare': 'abc', 'distance_fare': '45.50'},
      });

      expect(find.text('Base fare'), findsNothing);
      expect(find.text('₹45.50'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('no internal pricing concept is shown to a rider',
      (tester) async {
    // A rider should never read FarePricing, RateCard or fare_basis.
    await pumpPanel(
      tester,
      quote(surge: '1.4', minFare: true, discount: '5.00', taxes: '4.20'),
    );

    for (final leaked in [
      'FarePricing',
      'RateCard',
      'fare_basis',
      'surge_multiplier',
      'min_fare_applied',
      'distance_fare',
      'base_fare',
    ]) {
      expect(
        find.textContaining(leaked),
        findsNothing,
        reason: '"$leaked" is an internal name and must not reach a rider',
      );
    }
  });

  group('server adjustment lines close the displayed total', () {
    // QA trip 45 displayed 60.00 + 55.59 + 19.62 beside a charged 135.22. The
    // server now sends named lines for the difference; the panel renders them and
    // does no arithmetic of its own.
    testWidgets('a rounding line is shown with an explanation', (tester) async {
      await pumpPanel(tester, {
        'estimated_fare': '135.22',
        'fare_breakdown': {
          'base_fare': '60.00',
          'distance_fare': '55.59',
          'time_fare': '19.62',
          'surge_multiplier': '1.00',
        },
        'fare_adjustments': [
          {'code': 'rounding', 'label': 'Rounding', 'amount': '0.01'},
        ],
      });

      expect(find.text('Rounding'), findsOneWidget);
      expect(find.text('₹0.01'), findsOneWidget);
      expect(find.textContaining('nearest paisa'), findsOneWidget);
    });

    testWidgets('a minimum-fare uplift is shown with its real amount',
        (tester) async {
      await pumpPanel(tester, {
        'estimated_fare': '50.00',
        'fare_breakdown': {
          'base_fare': '30.00',
          'distance_fare': '2.40',
          'time_fare': '2.00',
          'min_fare_applied': true,
        },
        'fare_adjustments': [
          {'code': 'minimum_fare', 'label': 'Minimum fare adjustment',
           'amount': '15.60'},
        ],
      });

      expect(find.text('Minimum fare adjustment'), findsOneWidget);
      expect(find.text('₹15.60'), findsOneWidget);
      // And the older valueless flag must stand down rather than saying it twice.
      expect(find.text('Minimum fare applied'), findsNothing);
    });

    testWidgets('the old minimum-fare flag still shows when no line is sent',
        (tester) async {
      // Negative control: an older server that sends no adjustments must not
      // lose the disclosure entirely.
      await pumpPanel(tester, {
        'estimated_fare': '50.00',
        'fare_breakdown': {
          'base_fare': '30.00',
          'min_fare_applied': true,
        },
      });

      expect(find.text('Minimum fare applied'), findsOneWidget);
    });

    testWidgets('no adjustments means no extra lines', (tester) async {
      await pumpPanel(tester, quote());

      expect(find.text('Rounding'), findsNothing);
      expect(find.textContaining('adjustment'), findsNothing);
    });

    testWidgets('a malformed adjustment list does not crash the panel',
        (tester) async {
      await pumpPanel(tester, {
        'estimated_fare': '100.00',
        'fare_breakdown': {'base_fare': '60.00'},
        'fare_adjustments': [
          'not-a-map',
          {'code': 'rounding'},                 // no amount
          {'amount': 'not-a-number'},           // unparseable
          {'code': 'surge', 'label': 'Busy-time surcharge', 'amount': '5.00'},
        ],
      });

      expect(tester.takeException(), isNull);
      expect(find.text('₹5.00'), findsOneWidget);
    });
  });

  testWidgets('the estimate is labelled as an estimate', (tester) async {
    // A quote presented as a final price is a complaint waiting to happen.
    await pumpPanel(tester, quote());

    expect(find.textContaining('An estimate'), findsOneWidget);
  });
}

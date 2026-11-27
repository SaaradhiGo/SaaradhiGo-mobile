// Trip charges step 2 (27 Nov): tolls and airport fees sit under "Collected on
// behalf of others", each saying whom it is for; waiting goes to the driver.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/services/models/trip_invoice.dart';
import 'package:saaradhigo_rider/widgets/fare_breakdown.dart';
import 'package:saaradhigo_rider/widgets/invoice_card.dart';

Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the quote groups tolls and fees and says waiting goes to the driver',
    (tester) async {
      await pump(
        tester,
        const FareBreakdown(
          fareData: {
            'estimated_fare': '798.00',
            'currency': 'INR',
            'fare_breakdown': {
              'base_fare': '60.00',
              'distance_fare': '450.00',
              'time_fare': '90.00',
              'surge_multiplier': '1.0',
            },
            'fare_adjustments': [
              {
                'code': 'trip_extra',
                'label': 'Toll (estimated): Outer Ring Road',
                'amount': '48.00',
                'kind': 'tolled_road',
                'collection': 'driver_at_gate',
              },
              {
                'code': 'trip_extra',
                'label': 'Airport pickup fee (RGIA)',
                'amount': '150.00',
                'kind': 'airport',
                'collection': 'driver_at_gate',
              },
            ],
            'waiting_terms': {'free_minutes': 3, 'per_minute_minor': 200},
          },
        ),
      );
      expect(find.text('Collected on behalf of others'), findsOneWidget);
      expect(find.text('₹198.00'), findsOneWidget);
      expect(
        find.text(
          'Collected on behalf of the toll operator. Your driver pays it at the plaza.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Collected on behalf of the airport. Your driver pays it at the gate.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('first 3 min are free, then ₹2.00/min'),
        findsOneWidget,
      );
      expect(find.textContaining('goes to your driver'), findsOneWidget);
    },
  );

  testWidgets('the receipt lists them apart, with whom each is for', (
    tester,
  ) async {
    final invoice = TripInvoice.fromTrip({
      'invoice': {
        'title': 'Receipt',
        'currency': 'USD',
        'breakdown': {
          'lines': [
            {'code': 'fare', 'label': 'Fare', 'amount': '21.40'},
            {
              'code': 'waiting',
              'label': 'Waiting (4 min after 2 free)',
              'amount': '1.60',
            },
          ],
          'extras': [
            {
              'code': 'trip_extra',
              'label': 'Boise Airport fee',
              'amount': '3.00',
              'on_behalf': true,
              'note':
                  'Collected on behalf of Boise Airport (ground transportation permit). SaaradhiGo pays it.',
            },
          ],
          'on_behalf_title': 'Collected on behalf of others',
          'total': '26.00',
        },
      },
    })!;
    await pump(tester, InvoiceCard(invoice: invoice));
    expect(find.byKey(const Key('invoice_on_behalf')), findsOneWidget);
    expect(find.text('Boise Airport fee'), findsOneWidget);
    expect(find.textContaining('SaaradhiGo pays it.'), findsOneWidget);
    expect(find.text('Waiting (4 min after 2 free)'), findsOneWidget);
  });
}

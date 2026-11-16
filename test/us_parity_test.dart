// US parity (launch readiness, 16 Nov): card hold at booking, the US receipt with refunds and the
// net charged, tips after a card trip, and trip times on the trip's own clock.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saaradhigo_rider/core/market/market_dates.dart';
import 'package:saaradhigo_rider/services/api_service.dart';
import 'package:saaradhigo_rider/services/card_hold_service.dart';
import 'package:saaradhigo_rider/services/models/trip_invoice.dart';
import 'package:saaradhigo_rider/services/models/trip_model.dart';
import 'package:saaradhigo_rider/services/tip_service.dart';
import 'package:saaradhigo_rider/widgets/card_paid_panel.dart';
import 'package:saaradhigo_rider/widgets/invoice_card.dart';

const _trip218 = {
  'invoice': {
    'number': 'SG-202611-218-v3',
    'rider_name': 'Avery Rider',
    'company': {'name': 'DeepTrics LLC'},
    'currency': 'USD',
    'breakdown': {
      'title': 'Receipt',
      'currency': 'USD',
      'lines': [
        {'label': 'Fare', 'amount': '28.08'},
      ],
      'extras': [
        {'label': 'Booking fee', 'amount': '1.50'},
      ],
      'total': '29.58',
      'tip': '5.32',
      'total_charged': '34.90',
      'refunds': [
        {
          'label': 'Refunded to your card',
          'amount': '29.58',
          'date': 'Nov 15, 2026',
        },
      ],
      'net_charged': '5.32',
    },
  },
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'access_token': 't'}));

  group('US receipt', () {
    test(
      'tip, total charged, refunds and net charged come from the breakdown',
      () {
        final i = TripInvoice.fromTrip(_trip218)!;
        expect(i.title, 'Receipt');
        expect(i.tip, '5.32');
        expect(i.totalCharged, '34.90');
        expect(i.refunds.single.amount, '29.58');
        expect(i.netCharged, '5.32');
      },
    );

    testWidgets(
      'the receipt card shows the refund and Net charged on one line each',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 340,
                child: InvoiceCard(invoice: TripInvoice.fromTrip(_trip218)!),
              ),
            ),
          ),
        );
        expect(find.text('Total charged'), findsOneWidget);
        expect(
          find.text('Refunded to your card · Nov 15, 2026'),
          findsOneWidget,
        );
        expect(find.text('−⁠\$29.58'), findsOneWidget);
        expect(find.byKey(const Key('invoice_net_charged')), findsOneWidget);
        expect(find.text('Tip'), findsOneWidget);
      },
    );
  });

  group('card hold at booking', () {
    test(
      'created, confirmed in the sheet, then authorised: the hold id goes with the booking',
      () async {
        var polls = 0;
        final client = MockClient((r) async {
          if (r.method == 'POST') {
            expect(jsonDecode(r.body), {'quote_id': 'q1'});
            return http.Response(
              jsonEncode({
                'data': {
                  'hold_id': 7,
                  'client_secret': 'pi_x_secret',
                  'publishable_key': 'pk_test_x',
                  'status': 'created',
                },
              }),
              201,
            );
          }
          polls += 1;
          return http.Response(
            jsonEncode({
              'data': {
                'hold_id': 7,
                'status': polls > 1 ? 'authorised' : 'created',
              },
            }),
            200,
          );
        });
        final out = await CardHoldService(
          client: client,
          present: (_) async => true,
        ).hold('q1');
        expect(out.ok, isTrue);
        expect(out.holdId, 7);
      },
    );

    test('closing Stripe sheet books nothing and says nothing', () async {
      final client = MockClient(
        (r) async => http.Response(
          jsonEncode({
            'data': {
              'hold_id': 8,
              'client_secret': 's',
              'publishable_key': 'pk_test_x',
              'status': 'created',
            },
          }),
          201,
        ),
      );
      final out = await CardHoldService(
        client: client,
        present: (_) async => false,
      ).hold('q1');
      expect(out.ok, isFalse);
      expect(out.message, isNull);
    });

    test(
      "the server's refusal is shown as it says (unpaid last trip)",
      () async {
        final client = MockClient(
          (r) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'UNPAID_LAST_TRIP',
                'message': 'Pay for your last trip first.',
              },
            }),
            402,
          ),
        );
        final out = await CardHoldService(
          client: client,
          present: (_) async => true,
        ).hold('q1');
        expect(out.message, 'Pay for your last trip first.');
      },
    );
  });

  testWidgets('a card trip: nothing to choose, a tip goes to the driver', (
    tester,
  ) async {
    var done = false;
    final tips = TipService(
      client: MockClient((r) async {
        expect(r.url.path, endsWith('/ride/trips/218/tip/'));
        expect(jsonDecode(r.body), {'percent': 18});
        return http.Response(
          jsonEncode({
            'data': {'tip_id': 1, 'amount': '5.32', 'currency': 'USD'},
          }),
          201,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CardPaidPanel(
              tripId: '218',
              amountText: '\$29.58',
              driverFirst: 'Jordan',
              tipPresets: const [15, 18, 20],
              onDone: () => done = true,
              tipService: tips,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Charged to your card: \$29.58'), findsOneWidget);
    expect(find.textContaining('Cash'), findsNothing);
    await tester.tap(find.byKey(const Key('tip_18')));
    await tester.pumpAndSettle();
    expect(find.text('Thanks! Your 18% tip goes to Jordan.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('card_paid_done')));
    expect(done, isTrue);
  });

  test("history shows a Boise trip on Boise's clock, in dollars' order", () {
    final t = Trip.fromJson({
      'id': 219,
      'pickup_address': 'a',
      'destination_address': 'b',
      'status': 'completed',
      'currency': 'USD',
      'timezone': 'America/Boise',
      'created_at': '2026-11-15T00:55:00Z',
    });
    expect(t.dates.shortDateTime(t.localCreatedAt!), 'Nov 14, 5:55 PM');
    expect(
      inTripZone(DateTime.utc(2026, 11, 14, 18, 30), 'Asia/Kolkata').hour,
      0,
    );
  });

  // Regression (emulator, 16 Nov): the service sent "dob": "" and the server refused the whole
  // update, so a rider with no date of birth on file could not get past Complete Profile.
  test('a profile update sends only what the rider filled in', () async {
    Map<String, dynamic>? sent;
    final api = ApiService(
      client: MockClient((r) async {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {'full_name': 'Harish'},
          }),
          200,
        );
      }),
    );
    await api.updateProfile(
      fullName: 'Harish',
      email: '',
      gender: 'male',
      dob: '',
      emergencyContact: '9876543210',
      houseNo: '12A',
      street: '',
      city: 'Hyderabad',
      zipCode: '500034',
    );
    expect(sent!.containsKey('dob'), isFalse);
    expect(sent!.containsKey('email'), isFalse);
    expect(sent!['emergency_contact'], '9876543210');
  });

  testWidgets('a negative receipt line reads −₹0.10, never ₹-0.10', (
    tester,
  ) async {
    final inv = TripInvoice.fromTrip({
      'invoice': {
        'company': {'name': 'DeepTrics Software Solutions Pvt Ltd'},
        'currency': 'INR',
        'breakdown': {
          'lines': [
            {'label': 'Rounding', 'amount': '-0.10'},
          ],
          'total': '247',
        },
      },
    })!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InvoiceCard(invoice: inv)),
      ),
    );
    expect(find.text('−⁠₹0.10'), findsOneWidget);
  });
}

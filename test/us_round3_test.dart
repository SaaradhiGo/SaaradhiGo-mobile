import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saaradhigo_rider/core/market/booking_refusal.dart';
import 'package:saaradhigo_rider/core/market/market_dates.dart';
import 'package:saaradhigo_rider/screens/components/market_overlays.dart';
import 'package:saaradhigo_rider/services/models/trip_model.dart';
import 'package:saaradhigo_rider/services/unpaid_trip_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _row(Map<String, dynamic> extra) => {
  'id': 1,
  'status': 'completed',
  'final_fare': '20.00',
  'created_at': '2026-11-14T19:30:00',
  ...extra,
};

void main() {
  final d = DateTime(2026, 11, 14, 19, 30);

  group('MarketDates', () {
    test('US is month-first', () {
      const m = MarketDates(isUs: true);
      expect(m.weekdayDay(d), 'Sat, Nov 14');
      expect(m.date(d), 'Nov 14, 2026');
      expect(m.time(d), '7:30 PM');
      expect(m.shortDateTime(d), 'Nov 14, 7:30 PM');
    });
    test('India stays day-first', () {
      const m = MarketDates(isUs: false);
      expect(m.weekdayDay(d), 'Sat, 14 Nov');
      expect(m.date(d), '14 Nov 2026');
      expect(m.time(d), '7:30 PM');
      expect(m.shortDateTime(d), '14 Nov, 7:30 PM');
    });
    test('market from currency or timezone', () {
      expect(MarketDates.forTrip(currency: 'USD').isUs, isTrue);
      expect(MarketDates.forTrip(timezone: 'America/Denver').isUs, isTrue);
      expect(
        MarketDates.forTrip(currency: 'INR', timezone: 'Asia/Kolkata').isUs,
        isFalse,
      );
      expect(MarketDates.forTrip().isUs, isFalse);
    });
    test('trip picks its market', () {
      final us = Trip.fromJson(_row({'currency': 'USD'}));
      expect(us.dates.shortDateTime(us.createdAt!), 'Nov 14, 7:30 PM');
      final inr = Trip.fromJson(_row({'currency': 'INR'}));
      expect(inr.dates.shortDateTime(inr.createdAt!), '14 Nov, 7:30 PM');
    });
  });

  group('history amount', () {
    test('uses total_charged when completed', () {
      expect(
        Trip.fromJson(_row({'total_charged': '23.00'})).displayAmount,
        '23.00',
      );
    });
    test('falls back to final_fare when null or absent', () {
      expect(
        Trip.fromJson(_row({'total_charged': null})).displayAmount,
        '20.00',
      );
      expect(Trip.fromJson(_row({})).displayAmount, '20.00');
    });
    test('ignores total_charged on a non-completed trip', () {
      expect(
        Trip.fromJson(_row({'status': 'cancelled', 'total_charged': '23.00'}))
            .displayAmount,
        '20.00',
      );
    });
  });

  group('UNPAID_LAST_TRIP', () {
    final frame = {
      'type': 'error',
      'code': 'UNPAID_LAST_TRIP',
      'message': 'Pay for your last trip',
      'trip_id': 9,
      'amount': '12.50',
      'currency': 'USD',
      'can_retry_card': true,
    };
    test('shows the server message', () {
      expect(isUnpaidLastTripFrame(frame), isTrue);
      expect(unpaidLastTripMessage(frame), 'Pay for your last trip');
      expect(
        unpaidLastTripMessage({...frame, 'message': ''}),
        kUnpaidFallbackMessage,
      );
    });

    testWidgets('card shows message and Pay now', (t) async {
      var paid = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingRefusalCard(
              refusal: BookingRefusal(
                kUnpaidLastTrip,
                unpaidLastTripMessage(frame),
                canPay: true,
              ),
              onPay: () async {
                paid++;
                return const UnpaidPayResult(
                  paid: true,
                  message: kUnpaidPaidMessage,
                );
              },
            ),
          ),
        ),
      );
      expect(find.text('Pay for your last trip'), findsOneWidget);
      await t.tap(find.byKey(const Key('unpaid_pay_button')));
      await t.pump();
      expect(paid, 1);
      expect(find.text('Paid. You can book now.'), findsOneWidget);
    });

    testWidgets('no Pay now without can_retry_card', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingRefusalCard(
              refusal: BookingRefusal(
                kUnpaidLastTrip,
                'Pay for your last trip',
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('unpaid_pay_button')), findsNothing);
    });

    test('service: 200 paid and 402 message', () async {
      SharedPreferences.setMockInitialValues({});
      http.Client c(int code, String body) =>
          MockClient((r) async => http.Response(body, code));
      final ok = await UnpaidTripService(
        client: c(200, '{"data":{"result":"paid"}}'),
      ).pay();
      expect(ok.paid, isTrue);
      expect(ok.message, 'Paid. You can book now.');
      final no = await UnpaidTripService(
        client: c(402, '{"message":"Card declined"}'),
      ).pay();
      expect(no.paid, isFalse);
      expect(no.message, 'Card declined');
    });
  });
}

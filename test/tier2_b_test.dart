import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/core/market/market_config.dart';
import 'package:saaradhigo_rider/ui/booking_widgets.dart';
import 'package:saaradhigo_rider/ui/choose_ride_sheet.dart';

/// Tier 2, PR B: Cheapest/Fastest tags, the demand line, cancel policy, the
/// finding checklist.
void main() {
  RideOption opt(String type, String fare, {int? eta}) =>
      RideOption.fromEstimate(type, {
        'estimated_fare': fare,
        'pickup_eta_min': ?eta,
      })!;

  group('rideTags', () {
    test('cheapest is the lowest fare, fastest the lowest ETA', () {
      final t = rideTags([
        opt('auto', '142', eta: 7),
        opt('sedan', '248', eta: 3),
        opt('suv', '400'),
      ]);
      expect(t.cheapest, 'auto');
      expect(t.fastest, 'sedan');
    });

    test('a tie gets no tag; no ETA anywhere means no Fastest', () {
      final t = rideTags([opt('auto', '142'), opt('bike', '142')]);
      expect(t.cheapest, isNull);
      expect(t.fastest, isNull);
      final u = rideTags([
        opt('auto', '142', eta: 4),
        opt('bike', '90', eta: 4),
      ]);
      expect(u.cheapest, 'bike');
      expect(u.fastest, isNull);
    });

    test('nothing to tag in an empty list', () {
      final t = rideTags([]);
      expect(t.cheapest, isNull);
      expect(t.fastest, isNull);
    });
  });

  group('demand line', () {
    test('rider_reason is shown verbatim', () {
      final o = RideOption.fromEstimate('auto', {
        'estimated_fare': '142',
        'rider_reason': 'Higher demand near Madhapur',
        'fare_breakdown': {'surge_multiplier': '1.4'},
      })!;
      expect(o.reason, 'Higher demand near Madhapur');
    });

    test('otherwise today: a multiplier above 1, never the word surge', () {
      final o = RideOption.fromEstimate('auto', {
        'estimated_fare': '142',
        'fare_breakdown': {'surge_multiplier': '1.4'},
      })!;
      expect(o.reason, 'Higher demand right now');
    });

    test('seats from the quote win over the fixed table', () {
      final o = RideOption.fromEstimate('sedan', {
        'estimated_fare': '248',
        'seats': 3,
      })!;
      expect(o.meta, '3 seats');
    });
  });

  group('cancel policy', () {
    MarketConfig cfg(Map<String, dynamic> policy) => MarketConfig.fromData({
      'country': {'code': 'IN', 'cancel_policy': policy},
    });

    test('charges_fee false means free to cancel', () {
      final c = cfg({'charges_fee': false, 'free_cancel_seconds': null});
      expect(c.freeToCancel, isTrue);
      expect(c.freeCancelSeconds, isNull);
    });

    test('null or true says nothing', () {
      expect(cfg({'charges_fee': null}).freeToCancel, isFalse);
      expect(cfg({'charges_fee': true}).freeToCancel, isFalse);
      expect(MarketConfig.builtIn.freeToCancel, isFalse);
    });

    test('refund days and free wait', () {
      final c = cfg({'refund_days': 7, 'free_wait_minutes': 3});
      expect(c.refundDays, 7);
      expect(c.freeWaitMinutes, 3);
      expect(cfg({}).refundDays, isNull);
    });
  });

  testWidgets('the finding checklist shows only what it is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FindingChecklistSheet(
            heading: 'Finding a Sedan driver',
            items: const [
              ChecklistItem('Fare locked at ₹248', ChecklistState.done),
              ChecklistItem(
                'Waiting for one to accept',
                ChecklistState.current,
              ),
            ],
            note: 'You can close the app; we will notify you.',
            cancelLabel: 'Cancel request',
            onCancel: () {},
          ),
        ),
      ),
    );
    expect(find.text('Finding a Sedan driver'), findsOneWidget);
    expect(find.text('Fare locked at ₹248'), findsOneWidget);
    expect(find.textContaining('Asked'), findsNothing);
    expect(find.byKey(const Key('free_to_cancel')), findsNothing);
  });
}

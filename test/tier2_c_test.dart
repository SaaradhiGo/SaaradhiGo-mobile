import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/ui/trip_t2_widgets.dart';

/// Tier 2, PR C: the arrival estimate, the receipt's difference lines, the
/// plate and the PIN.
void main() {
  group('ArrivalEstimate', () {
    final start = DateTime(2026, 11, 6, 21, 0);

    test('about HH:MM, minutes left and progress', () {
      final e = ArrivalEstimate.from(
        startedAt: start,
        estimatedMinutes: 20,
        now: start.add(const Duration(minutes: 5)),
      )!;
      expect(clockText(e.at), '9:20 pm');
      expect(e.minutesLeft, 15);
      expect(e.progress, closeTo(0.25, 1e-9));
      expect(e.overdue, isFalse);
    });

    test('progress stops at 95%; past the estimate there are no minutes', () {
      final near = ArrivalEstimate.from(
        startedAt: start,
        estimatedMinutes: 20,
        now: start.add(const Duration(minutes: 19, seconds: 50)),
      )!;
      expect(near.progress, 0.95);
      final late = ArrivalEstimate.from(
        startedAt: start,
        estimatedMinutes: 20,
        now: start.add(const Duration(minutes: 30)),
      )!;
      expect(late.overdue, isTrue);
      expect(late.minutesLeft, isNull);
      expect(late.progress, 0.95);
    });

    test('no start or no estimate: nothing', () {
      expect(
        ArrivalEstimate.from(startedAt: null, estimatedMinutes: 20, now: start),
        isNull,
      );
      expect(
        ArrivalEstimate.from(
          startedAt: start,
          estimatedMinutes: null,
          now: start,
        ),
        isNull,
      );
    });
  });

  group('receiptLines', () {
    test('equal: no lines', () {
      expect(receiptLines(quoted: 169.02, cost: 169.02), isEmpty);
    });

    test('a promotion explains the whole difference', () {
      final l = receiptLines(quoted: 169.02, cost: 119.02, promoDiscount: 50);
      expect(l, hasLength(1));
      expect(l.single.kind, ReceiptLineKind.promotion);
      expect(l.single.amount, -50);
    });

    test('an unexplained remainder is never hidden', () {
      final l = receiptLines(quoted: 169, cost: 180);
      expect(l.single.kind, ReceiptLineKind.unexplained);
      expect(l.single.amount, closeTo(11, 1e-9));
      final m = receiptLines(quoted: 169, cost: 129, promoDiscount: 30);
      expect(m.map((x) => x.kind), [
        ReceiptLineKind.promotion,
        ReceiptLineKind.unexplained,
      ]);
      expect(m.last.amount, closeTo(-10, 1e-9));
    });
  });

  testWidgets('Indian plate in India, a plain one elsewhere; every PIN digit', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SgNumberPlate('TS09QT0059', indian: true),
              SgNumberPlate('ABC123', indian: false),
              SgPinPanel(label: 'Ride PIN', hint: 'h', pin: '482913'),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('plate_in')), findsOneWidget);
    // The IND strip is drawn without lettering (6px type was under the floor).
    expect(find.text('TS 09 QT 0059'), findsOneWidget);
    expect(find.byKey(const Key('plate_plain')), findsOneWidget);
    // The code is six dots until the rider taps Show.
    expect(find.text('482913'), findsNothing);
    expect(find.byKey(const Key('ride_pin_dots')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ride_pin_toggle')));
    await tester.pump();
    expect(find.text('482913'), findsOneWidget);
  });
}

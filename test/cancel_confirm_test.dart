// 16 Nov regression: a booked trip was cancelled on one tap of a reason. Now: "Cancel this trip?"
// with what it costs, and nothing is cancelled unless the rider confirms.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saaradhigo_rider/ui/cancel_confirm.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'access_token': 't'}));

  test('the preview reads free or the fee', () async {
    final fee = await fetchCancelCost(
      '7',
      client: MockClient((r) async {
        expect(r.url.path, endsWith('/ride/trip/7/cancel-preview/'));
        return http.Response(
          jsonEncode({
            'data': {
              'free': false,
              'fee': '50.00',
              'fee_minor': 5000,
              'currency': 'INR',
            },
          }),
          200,
        );
      }),
    );
    expect(fee!.line(), 'A cancellation fee of ₹50 applies.');
    expect(const CancelCost(free: true).line(), 'Cancelling now is free.');
  });

  Future<bool?> open(WidgetTester tester, CancelCost? cost) async {
    bool? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => out = await confirmCancelTrip(c, cost),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this trip?'), findsOneWidget);
    return out;
  }

  testWidgets('Keep trip cancels nothing', (tester) async {
    await open(
      tester,
      const CancelCost(free: false, fee: '50', currency: 'INR'),
    );
    expect(find.text('A cancellation fee of ₹50 applies.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel_keep')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this trip?'), findsNothing);
  });

  testWidgets('Cancel trip confirms', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => result = await confirmCancelTrip(
              c,
              const CancelCost(free: true),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel_confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

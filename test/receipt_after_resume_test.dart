// Launch round 3, item 1: after a trip ends the rider always gets the receipt
// and tip panel, even when the app was in the background at drop or was
// reopened. Trip 228 (US, card charged at drop) went straight to Home.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:saaradhigo_rider/state/ride_notifier.dart';
import 'package:saaradhigo_rider/state/ride_state.dart';

class _NoRideService implements RideService {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _done(int id, String currency, String method) => {
  'status': 'success',
  'data': {
    'id': id,
    'status': 'completed',
    'payment_status': 'completed',
    'payment_method': method,
    'final_fare': currency == 'USD' ? '62.19' : '146.00',
    'currency': currency,
    'card_held': currency == 'USD',
    'is_active': false,
    'recovery': 'recently_completed',
  },
};

void main() {
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'access_token': 't'});
    c = ProviderContainer(
      overrides: [rideServiceProvider.overrideWithValue(_NoRideService())],
    );
  });
  tearDown(() => c.dispose());

  Future<RideState> resume(Map<String, dynamic> body) async {
    await c
        .read(rideNotifierProvider.notifier)
        .syncStateFromActiveTripResponse(body);
    return c.read(rideNotifierProvider);
  }

  test(
    'US: card charged at drop while backgrounded opens the receipt',
    () async {
      final s = await resume(_done(228, 'USD', 'card'));
      expect(s.status, RideStatus.rideCompleted);
      expect(s.tripId, '228');
      expect(s.rawResponse!['card_held'], isTrue);
    },
  );

  test('India: cash confirmed while backgrounded opens the receipt', () async {
    final s = await resume(_done(224, 'INR', 'cash'));
    expect(s.status, RideStatus.rideCompleted);
    expect(s.rawResponse!['currency'], 'INR');
  });

  test('a paid trip never shows the payment-pending banner', () async {
    final s = await resume(_done(228, 'USD', 'card'));
    expect(s.status, isNot(RideStatus.paymentPending));
  });

  test('once closed, the receipt stays closed', () async {
    await ClosedReceipts.add('228');
    final s = await resume(_done(228, 'USD', 'card'));
    expect(s.status, RideStatus.none);
  });

  test('the closed list keeps the last 20 trips', () async {
    for (var i = 0; i < 25; i++) {
      await ClosedReceipts.add('$i');
    }
    expect(await ClosedReceipts.contains('4'), isFalse);
    expect(await ClosedReceipts.contains('5'), isTrue);
    expect(await ClosedReceipts.contains('24'), isTrue);
  });
}

// A completed, unpaid trip recovered after a restart showed "FARE ₹0.00" and
// "Pay ₹0 by Cash" on QA (2026-11-06): recovery kept only the driver details.
// The receipt now reads the payload the way the server settles
// (`final_fare or estimated_fare`), and never shows ₹0 for a missing fare.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saaradhigo_rider/screens/home/rider_flow_screens.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:saaradhigo_rider/state/ride_notifier.dart';
import 'package:saaradhigo_rider/state/ride_state.dart';

class _NoRideService implements RideService {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the trip 152 payload: final_fare null, estimate 132.00', () async {
    SharedPreferences.setMockInitialValues({'access_token': 't'});
    await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [rideServiceProvider.overrideWithValue(_NoRideService())],
    );
    addTearDown(c.dispose);
    await c.read(rideNotifierProvider.notifier).syncStateFromActiveTripResponse(
      {
        'status': 'success',
        'data': {
          'id': 152,
          'status': 'completed',
          'payment_status': 'pending',
          'final_fare': null,
          'estimated_fare': '132.00',
          'currency': 'INR',
          'is_active': false,
          'recovery': 'recently_completed',
        },
      },
    );
    final s = c.read(rideNotifierProvider);
    expect(s.status, RideStatus.paymentPending);
    expect(receiptFareRaw(s.rawResponse), '132.00');
    expect(s.rawResponse!['currency'], 'INR');
  });

  test('the final fare wins; then the frame total; then the estimate', () {
    expect(
      receiptFareRaw({'final_fare': '140.00', 'estimated_fare': '132.00'}),
      '140.00',
    );
    expect(
      receiptFareRaw({'total_fare': '133.00', 'estimated_fare': '132.00'}),
      '133.00',
    );
    expect(receiptFareRaw({'estimated_fare': '132.00'}), '132.00');
  });

  test('no fare anywhere: no amount, never 0', () {
    expect(receiptFareRaw({}), isNull);
    expect(receiptFareRaw({'final_fare': null, 'estimated_fare': ''}), isNull);
    expect(receiptFareRaw(null), isNull);
  });

  test('the planned route decodes (the example in the Google docs)', () {
    final p = decodePlannedRoute('_p~iF~ps|U_ulLnnqC_mqNvxq`@')!;
    expect(p, hasLength(3));
    expect(p.first.latitude, closeTo(38.5, 1e-9));
    expect(p.first.longitude, closeTo(-120.2, 1e-9));
    expect(p.last.latitude, closeTo(43.252, 1e-9));
    expect(p.last.longitude, closeTo(-126.453, 1e-9));
    expect(decodePlannedRoute(null), isNull);
    expect(decodePlannedRoute(''), isNull);
    expect(decodePlannedRoute('_p~iF'), isNull);
  });
}

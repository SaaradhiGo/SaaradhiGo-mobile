// The OTP push is best-effort. The rider app must be able to go and ask.
//
// Measured on an isolated load stack (backend qa/load_harness.py): at 50 concurrent
// rides, 6 of 50 riders received the accept-time OTP on NEITHER socket -- not the
// trip channel and not their personal channel. At 100 rides in batches of 25, 2 did
// not. The fan-out is best-effort by design: channels_redis drops to a channel whose
// queue is full, and `group_send` swallows that per channel, so a client that was not
// draining at that instant never sees the frame.
//
// The server has always had a pull path -- GET /ride/active/ and the trip-details
// endpoint both return the OTP to the rider on that trip. What was missing was
// anything in the app that USED it on this trigger: `syncStateFromBackend` ran on
// startup and on resume, so a rider who missed the push saw "----" where their OTP
// should be, with a driver waiting outside, until they backgrounded the app and
// reopened it.
//
// These tests pin the trigger: reaching a state that should have an OTP without one
// must cause exactly one refetch, and having an OTP must cause none.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saaradhigo_rider/services/models/trip_model.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:saaradhigo_rider/state/ride_notifier.dart';
import 'package:saaradhigo_rider/state/ride_state.dart';

class _CountingRideService implements RideService {
  int statusCalls = 0;
  int detailCalls = 0;
  String? otpToReturn;

  @override
  Future<Map<String, dynamic>?> fetchActiveTrip(String token) async => null;

  @override
  Future<Map<String, dynamic>?> getTripStatus(String token, String tripId) async {
    statusCalls++;
    return {
      'status': 'success',
      'data': {'id': tripId, 'status': 'accepted'},
    };
  }

  @override
  Future<Map<String, dynamic>?> getTripDetails(String token, String tripId) async {
    detailCalls++;
    return {
      'status': 'success',
      'data': {'id': tripId, 'otp': otpToReturn, 'driver_name': 'Test Driver'},
    };
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _CountingRideService service;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
    await SharedPreferences.getInstance();
    service = _CountingRideService();
    container = ProviderContainer(
      overrides: [rideServiceProvider.overrideWithValue(service)],
    );
  });

  tearDown(() => container.dispose());

  test('an accept push with no OTP triggers a refetch', () async {
    final notifier = container.read(rideNotifierProvider.notifier);
    service.otpToReturn = '4321';

    notifier.updateFromWebSocket({
      'type': 'trip_update',
      'status': 'accept',
      'trip_id': 77,
      // No 'otp' key: this is the frame a rider gets when the push carried the
      // status but the OTP never arrived, or when only one of the two sends landed.
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      service.detailCalls,
      greaterThanOrEqualTo(1),
      reason: 'a rider left without an OTP never asked the server for it, so they '
          'would see "----" with a driver waiting outside until the app resynced',
    );
  });

  test('an accept push that carries the OTP triggers no refetch', () async {
    final notifier = container.read(rideNotifierProvider.notifier);

    notifier.updateFromWebSocket({
      'type': 'trip_update',
      'status': 'accept',
      'trip_id': 78,
      'otp': '1234',
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      service.detailCalls,
      0,
      reason: 'the happy path must not pay for an extra round trip on every accept',
    );
    expect(
      container.read(rideNotifierProvider).rawResponse?['otp'],
      '1234',
    );
  });

  test('a reached push with no OTP also triggers a refetch', () async {
    // The driver is outside. This is the worst moment to have no OTP.
    final notifier = container.read(rideNotifierProvider.notifier);
    service.otpToReturn = '9876';

    notifier.updateFromWebSocket({
      'type': 'trip_status_update',
      'status': 'reached',
      'trip_id': 79,
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(service.detailCalls, greaterThanOrEqualTo(1));
  });

  test('a searching-state frame does not trigger a refetch', () async {
    // No OTP exists yet at this point, and asking for one on every dispatch frame
    // would add a request per driver notified.
    final notifier = container.read(rideNotifierProvider.notifier);

    notifier.updateFromWebSocket({
      'type': 'dispatch_progress',
      'trip_id': 80,
      'drivers_notified': 3,
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      service.detailCalls,
      0,
      reason: 'the fallback fired before an OTP could possibly exist',
    );
  });
}

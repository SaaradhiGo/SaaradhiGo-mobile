// The rider must leave "on the way" when the driver cancels (owner, Tier 4).
//
// Ways the cancel was missed, each pinned here:
//  1. The resume check (GET /ride/active/) asked while the trip was accepted
//     came back after the cancel frame and put the rider back on "on the way".
//  2. A cancel sent while the trip socket was down is only in the greeting of
//     the next connect (`connection_established.trip_status`), which the app
//     ignored.
//  3. The FCM push is `type: ride_cancelled`, which matched nothing.
//  4. A late status frame from another trip must not move this one.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:saaradhigo_rider/state/ride_notifier.dart';
import 'package:saaradhigo_rider/state/ride_state.dart';

class _SlowRideService implements RideService {
  Completer<Map<String, dynamic>?>? active;

  @override
  Future<Map<String, dynamic>?> fetchActiveTrip(String token) =>
      (active ??= Completer()).future;

  @override
  Future<Map<String, dynamic>?> getTripStatus(String token, String id) async =>
      {
        'status': 'success',
        'data': {'id': id, 'status': 'accepted'},
      };

  @override
  Future<Map<String, dynamic>?> getTripDetails(String token, String id) async =>
      {
        'status': 'success',
        'data': {'id': id, 'otp': '123456'},
      };

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _frame(String status, {int trip = 143}) => {
  'type': 'trip_status_update',
  'trip_id': trip,
  'status': status,
  if (status == 'accept') 'otp': '123456',
};

void main() {
  late _SlowRideService service;
  late ProviderContainer container;
  late RideNotifier notifier;

  RideStatus status() => container.read(rideNotifierProvider).status;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
    await SharedPreferences.getInstance();
    service = _SlowRideService();
    container = ProviderContainer(
      overrides: [rideServiceProvider.overrideWithValue(service)],
    );
    notifier = container.read(rideNotifierProvider.notifier);
    notifier.setSearching(vehicleType: 'sedan');
    notifier.updateFromWebSocket(_frame('accept'));
    expect(status(), RideStatus.driverAccepted);
  });

  tearDown(() => container.dispose());

  test('a resume answer in flight during the cancel does not revive the '
      'trip', () async {
    final resume = notifier.loadInitialState();
    await Future<void>.delayed(Duration.zero);
    expect(service.active, isNotNull, reason: 'the GET is in flight');

    notifier.updateFromWebSocket(_frame('cancel'));
    expect(status(), RideStatus.cancelled);

    // The answer the server gave before the cancel committed.
    service.active!.complete({
      'status': 'success',
      'data': {'id': 143, 'status': 'accepted', 'otp': '123456'},
    });
    await resume;
    expect(status(), RideStatus.cancelled);
  });

  test('a cancelled trip is never revived by a later REST answer', () async {
    notifier.updateFromWebSocket(_frame('cancel'));
    await notifier.syncStateFromActiveTripResponse({
      'status': 'success',
      'data': {'id': 143, 'status': 'accepted'},
    });
    expect(status(), RideStatus.cancelled);
  });

  test('the trip socket greeting after a reconnect ends the trip', () {
    notifier.updateFromWebSocket({
      'type': 'connection_established',
      'trip_id': '143',
      'subscribed': true,
      'trip_status': 'cancelled',
    });
    expect(status(), RideStatus.cancelled);
  });

  test('a greeting only moves the ride forward', () {
    notifier.updateFromWebSocket(_frame('reached'));
    notifier.updateFromWebSocket({
      'type': 'connection_established',
      'trip_id': '143',
      'trip_status': 'accepted',
    });
    expect(status(), RideStatus.driverArrived);
    notifier.updateFromWebSocket({
      'type': 'connection_established',
      'trip_id': '143',
      'trip_status': 'in_progress',
    });
    expect(status(), RideStatus.rideStarted);
  });

  test('the ride_cancelled push ends the trip', () async {
    await notifier.updateFromNotification({
      'type': 'ride_cancelled',
      'trip_id': '143',
    });
    expect(status(), RideStatus.cancelled);
  });

  test('status "cancelled" (the status code) is read as a cancel too', () {
    notifier.updateFromWebSocket({
      'type': 'trip_update',
      'trip_id': 143,
      'status': 'cancelled',
      'cancelled_by': 'driver',
    });
    expect(status(), RideStatus.cancelled);
  });

  test('a cancel for another trip leaves this one alone', () async {
    notifier.updateFromWebSocket(_frame('cancel', trip: 99));
    await notifier.updateFromNotification({
      'type': 'ride_cancelled',
      'trip_id': '99',
    });
    expect(status(), RideStatus.driverAccepted);
  });
}

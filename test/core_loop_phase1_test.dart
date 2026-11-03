// Product phase 1: the core loop never stalls silently (PRODUCT_AUDIT §2, §8).
//
// What the audit found on the rider app, and what each group here pins:
//   * "Finding your ride..." forever: the server cancelled the search at 90 s
//     (no driver) and the app never heard; a second booking on an open socket
//     sent nothing at all.
//   * A yellow "Payment pending" banner for a trip that was already paid, whose
//     "Rate trip" could not open anything.
//   * Blank destination rows: Places (New) sends no `structured_formatting`.
//   * A rating screen with a hard-coded driver that saved nothing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saaradhigo_rider/screens/components/payment_pending_banner.dart';
import 'package:saaradhigo_rider/screens/profile/profile_setup_screen.dart';
import 'package:saaradhigo_rider/services/models/location_model.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:saaradhigo_rider/services/websocket_service.dart';
import 'package:saaradhigo_rider/state/ride_notifier.dart';
import 'package:saaradhigo_rider/state/ride_state.dart';

class _FakeRideService implements RideService {
  Map<String, dynamic>? active;
  Map<String, dynamic>? tripStatus;
  final cancelled = <String>[];

  @override
  Future<Map<String, dynamic>?> fetchActiveTrip(String token) async => active;

  @override
  Future<Map<String, dynamic>?> getTripStatus(String token, String tripId) async =>
      tripStatus;

  @override
  Future<Map<String, dynamic>?> getTripDetails(String token, String tripId) async =>
      null;

  @override
  Future<bool> cancelTrip(
    String token,
    String tripId, {
    String? reason,
    String? note,
  }) async {
    cancelled.add(tripId);
    return true;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietSocket extends WebSocketService {
  int abandoned = 0;

  @override
  void abandonRideRequest() => abandoned++;
}

void main() {
  late _FakeRideService service;
  late _QuietSocket socket;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
    await SharedPreferences.getInstance();
    service = _FakeRideService();
    socket = _QuietSocket();
    container = ProviderContainer(
      overrides: [
        rideServiceProvider.overrideWithValue(service),
        webSocketServiceProvider.overrideWithValue(socket),
      ],
    );
  });

  tearDown(() => container.dispose());

  RideNotifier searching() {
    final n = container.read(rideNotifierProvider.notifier);
    n.setSearching(vehicleType: 'auto');
    return n;
  }

  RideState state() => container.read(rideNotifierProvider);

  group('a search always ends in something the rider can act on', () {
    test('the no-driver frame keeps the search screen up, with the reason', () {
      final n = searching();
      n.updateFromWebSocket({'type': 'trip_created', 'trip_id': 114});
      n.updateFromWebSocket({
        'type': 'trip_update',
        'trip_id': 114,
        'status': 'cancel',
        'reason': 'no_driver_accepted',
        'message': 'No driver accepted your request. Please try again.',
      });

      expect(state().status, RideStatus.searchingDriver,
          reason: 'leaving the status alone keeps the global navigator out of it');
      expect(state().searchFailure,
          'No driver accepted your request. Please try again.');
      expect(state().tripId, isNull, reason: 'that trip is over on the server');
    });

    test('a refused booking is said plainly, never as a developer message', () {
      searching().updateFromWebSocket(
          {'type': 'error', 'message': 'Failed to create trip'});
      expect(state().searchFailure, "We couldn't book your ride. Please try again.");
    });

    test('a refusal written for riders is shown as written', () {
      searching().updateFromWebSocket({
        'type': 'error',
        'message': 'Your account cannot request rides right now.',
      });
      expect(state().searchFailure, 'Your account cannot request rides right now.');
    });

    test('a search that could not start cancels the trip it left behind', () async {
      searching().updateFromWebSocket({
        'type': 'dispatch_failed',
        'trip_id': 9,
        'message': 'We could not start the driver search. Please retry in a moment.',
      });
      await Future<void>.delayed(Duration.zero);
      expect(state().searchFailure, isNotNull);
      expect(service.cancelled, ['9'], reason: '"Try again" must be the only booking');
    });

    test('a cancel for another reason is still a cancellation, not a failure', () {
      final n = searching();
      n.updateFromWebSocket({'type': 'trip_created', 'trip_id': 5});
      n.updateFromWebSocket(
          {'type': 'trip_update', 'trip_id': 5, 'status': 'cancel'});
      expect(state().searchFailure, isNull);
      expect(state().status, RideStatus.cancelled);
    });

    test('Try again starts clean', () {
      final n = searching();
      n.failSearch('No driver accepted your request. Please try again.');
      n.setSearching(vehicleType: 'auto');
      expect(state().searchFailure, isNull);
      expect(state().tripId, isNull);
    });

    test('never acknowledged and no trip on the server: say so, stop resending', () async {
      final n = searching();
      await n.verifySearch();
      expect(state().searchFailure, kSearchUnreachableMessage);
      expect(socket.abandoned, 1);
    });

    test('never acknowledged but the trip exists: recover to it', () async {
      final n = searching();
      service.active = {
        'status': 'success',
        'data': {'id': 31, 'status': 'accepted', 'otp': '1234'},
      };
      await n.verifySearch();
      expect(state().searchFailure, isNull);
      expect(state().status, RideStatus.driverAccepted);
      expect(state().tripId, '31');
    });

    test('the server cancelled while the frame was lost', () async {
      final n = searching();
      n.updateFromWebSocket({'type': 'trip_created', 'trip_id': 40});
      service.tripStatus = {
        'status': 'success',
        'data': {'id': 40, 'status': 'cancelled'},
      };
      await n.verifySearch();
      expect(state().searchFailure, kNoDriverMessage);
    });

    test('still unanswered at the hard deadline: cancel it and say so', () async {
      final n = searching();
      n.updateFromWebSocket({'type': 'trip_created', 'trip_id': 41});
      service.tripStatus = {
        'status': 'success',
        'data': {'id': 41, 'status': 'requested'},
      };
      await n.verifySearch();
      expect(state().searchFailure, isNull, reason: 'the server deadline still runs');
      await n.verifySearch(giveUp: true);
      expect(service.cancelled, ['41']);
      expect(state().searchFailure, kNoDriverMessage);
    });

    test('a network failure ends the search only at the hard deadline', () async {
      final n = searching();
      n.updateFromWebSocket({'type': 'trip_created', 'trip_id': 42});
      await n.verifySearch();
      expect(state().searchFailure, isNull);
      await n.verifySearch(giveUp: true);
      expect(state().searchFailure, kSearchUnreachableMessage);
    });
  });

  group('the booking frame', () {
    test('carries an idempotency key, so a reconnect resend is not a second ride', () {
      final frame = WebSocketService.buildRideRequestPayload(
        pickupLat: 1,
        pickupLng: 2,
        destinationLat: 3,
        destinationLng: 4,
        distanceKm: 5,
        durationMin: 6,
        vehicleType: 'auto',
        pickupAddress: 'A',
        destinationAddress: 'B',
        paymentMethod: 'cash',
        clientRequestId: 'abc',
      );
      expect(frame['client_request_id'], 'abc');
    });
  });

  group('a paid trip leaves nothing behind', () {
    test('completed and paid is settled', () {
      expect(isSettledCompletedTrip({'status': 'completed', 'payment_status': 'completed'}),
          isTrue);
    });

    test('completed and unpaid still asks for payment', () {
      expect(isSettledCompletedTrip({'status': 'completed', 'payment_status': 'pending'}),
          isFalse);
      expect(isSettledCompletedTrip({'status': 'completed'}), isFalse);
    });

    test('recovering a paid trip shows no payment banner', () async {
      service.active = {
        'status': 'success',
        'data': {'id': 116, 'status': 'completed', 'payment_status': 'completed'},
      };
      await container.read(rideNotifierProvider.notifier).loadInitialState();
      expect(state().status, RideStatus.none);
    });

    testWidgets('the banner hands its tap to the router', (tester) async {
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PaymentPendingBanner(onOpen: () => opened++)),
      ));
      await tester.tap(find.text('Pay now'));
      expect(opened, 1);
      expect(find.textContaining('Pending'), findsNothing,
          reason: 'sentence case, and it says what to do');
    });
  });

  group('completing the profile', () {
    test('blank fields are left out, so an empty date of birth cannot fail the save', () {
      final body = profileUpdatePayload({
        'full_name': 'QA Rider',
        'dob': '',
        'emergency_contact': '',
        'gender': 'male',
        'home_city': null,
      });
      expect(body, {'full_name': 'QA Rider', 'gender': 'male'});
    });
  });

  group('destination rows', () {
    test('a prediction with only a description is split into two lines', () {
      final s = PlaceSuggestion.fromJson(
          {'place_id': 'x', 'description': 'Benz Circle, Vijayawada, Andhra Pradesh'});
      expect(s.mainText, 'Benz Circle');
      expect(s.secondaryText, 'Vijayawada, Andhra Pradesh');
    });

    test('structured parts win when present', () {
      final s = PlaceSuggestion.fromJson({
        'place_id': 'x',
        'description': 'MG Road, Vijayawada',
        'structured_formatting': {'main_text': 'MG Road', 'secondary_text': 'Labbipet'},
      });
      expect(s.mainText, 'MG Road');
      expect(s.secondaryText, 'Labbipet');
    });
  });
}

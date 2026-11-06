// The quote lock: "Locked when you book" is literally true. The booking
// carries the ticket's quote_id; a QUOTE_EXPIRED refusal books nothing and
// puts the fresh fare on the ticket; Confirm again books the fresh quote.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/core/pricing/quote_lock.dart';
import 'package:saaradhigo_rider/providers/map_provider.dart';
import 'package:saaradhigo_rider/screens/home/precise_pickup_screen.dart';
import 'package:saaradhigo_rider/services/map_service.dart';
import 'package:saaradhigo_rider/services/ride_service.dart';
import 'package:saaradhigo_rider/services/websocket_service.dart';
import 'package:saaradhigo_rider/state/ride_notifier.dart';
import 'package:saaradhigo_rider/state/ride_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/rider_ui_fixtures.dart';

class _Location extends Fake implements LocationService {
  @override
  Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async => {
    'distance': '5.0 km',
    'duration': '10 mins',
    'bounds': null,
    'polylineCoordinates': [origin, destination],
  };

  @override
  Future<PlaceDetails?> getPlaceDetails(
    String placeId,
    String sessionToken,
  ) async => PlaceDetails(
    placeId: placeId,
    name: 'Inorbit Mall',
    formattedAddress: '',
    latitude: 17.4400,
    longitude: 78.3489,
  );
}

class _Fares extends Fake implements FareService {
  @override
  Future<List<String>?> vehicleTypesAt(double lat, double lng) async => [
    'sedan',
  ];

  @override
  Future<Map<String, dynamic>?> estimateFare({
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    required double distanceKm,
    required int durationMin,
    required String vehicleType,
  }) async => {
    'estimated_fare': '248.00',
    'currency': 'INR',
    'quote_id': 'q-$vehicleType-1',
    'quote_expires_at': '2026-11-06T12:00:00Z',
  };
}

class _Rides extends Fake implements RideService {}

/// Records every booking frame instead of opening a socket.
class _Socket extends WebSocketService {
  final List<String?> quoteIds = [];

  @override
  void requestRide({
    required String token,
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    required double distanceKm,
    required int durationMin,
    required String vehicleType,
    required String pickupAddress,
    required String destinationAddress,
    required String paymentMethod,
    String? promoCode,
    String? quoteId,
  }) => quoteIds.add(quoteId);
}

Map<String, dynamic> _expired({String reason = 'expired'}) => {
  'type': 'error',
  'code': 'QUOTE_EXPIRED',
  'reason': reason,
  'message': 'Your fare changed.',
  'fresh_quote': {
    'quote_id': 'q-fresh',
    'quote_expires_at': '2026-11-06T12:05:00Z',
    'estimated_fare': '260.00',
    'fare_breakdown': {'base_fare': '50.00'},
    'currency': 'INR',
  },
};

/// The ticket screen over a fixed quote.
class _TicketMap extends MapProvider {
  Map<String, Map<String, dynamic>> estimates = {
    'sedan': {'estimated_fare': '248.00', 'currency': 'INR'},
  };

  @override
  PlaceDetails? get pickupLocation => PlaceDetails(
    placeId: 'p',
    name: 'Hitech City Metro',
    formattedAddress: '',
    latitude: 17.4435,
    longitude: 78.3772,
  );

  @override
  Map<String, Map<String, dynamic>> get fareEstimates => estimates;

  @override
  String? get selectedVehicleType => 'sedan';

  @override
  Future<String?> addressFor(LatLng point) async => null;
}

void main() {
  tearDown(QuoteLockState.instance.clear);

  test('the booking frame carries the quote_id', () {
    final frame = WebSocketService.buildRideRequestPayload(
      pickupLat: 1,
      pickupLng: 2,
      destinationLat: 3,
      destinationLng: 4,
      distanceKm: 5,
      durationMin: 6,
      vehicleType: 'sedan',
      pickupAddress: 'A',
      destinationAddress: 'B',
      paymentMethod: 'cash',
      quoteId: 'q-sedan-1',
    );
    expect(frame['quote_id'], 'q-sedan-1');
    final none = WebSocketService.buildRideRequestPayload(
      pickupLat: 1,
      pickupLng: 2,
      destinationLat: 3,
      destinationLng: 4,
      distanceKm: 5,
      durationMin: 6,
      vehicleType: 'sedan',
      pickupAddress: 'A',
      destinationAddress: 'B',
      paymentMethod: 'cash',
    );
    expect(none.containsKey('quote_id'), isFalse);
  });

  group('booking against the ticket quote', () {
    late _Socket socket;
    late ProviderContainer container;
    late MapProvider map;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
      socket = _Socket();
      container = ProviderContainer(
        overrides: [
          rideServiceProvider.overrideWithValue(_Rides()),
          webSocketServiceProvider.overrideWithValue(socket),
        ],
      );
      // Build the notifier so it listens to the socket from the start.
      container.read(rideNotifierProvider);
      map = MapProvider(
        container: container,
        locationService: _Location(),
        fareService: _Fares(),
        rideService: _Rides(),
      );
      await map.prepareAndCalculateRoute(
        presetPickup: const LatLng(17.4435, 78.3772),
        pickupName: 'Hitech City Metro',
        dropPlaceId: 'drop',
      );
      map.selectVehicleType('sedan');
    });

    tearDown(() {
      map.dispose();
      container.dispose();
    });

    test('Confirm sends the quote shown on the ticket', () async {
      await map.requestRide();
      expect(socket.quoteIds, ['q-sedan-1']);
    });

    test('QUOTE_EXPIRED books nothing and shows the fresh fare', () async {
      await map.requestRide();
      container
          .read(rideNotifierProvider.notifier)
          .updateFromWebSocket(_expired());
      await Future<void>.delayed(Duration.zero);

      final ride = container.read(rideNotifierProvider);
      expect(ride.status, RideStatus.none);
      expect(ride.tripId, isNull);
      expect(socket.quoteIds, hasLength(1), reason: 'nothing booked again');
      expect(map.fareEstimates['sedan']?['estimated_fare'], '260.00');
      expect(map.selectedQuoteId, 'q-fresh');
      final pending = QuoteLockState.instance.pending!;
      expect(pending.reason, QuoteChangeReason.expired);
      expect(pending.vehicleType, 'sedan');
    });

    test('confirming again books with the fresh quote', () async {
      await map.requestRide();
      container
          .read(rideNotifierProvider.notifier)
          .updateFromWebSocket(_expired(reason: 'moved'));
      await Future<void>.delayed(Duration.zero);
      expect(QuoteLockState.instance.pending?.reason, QuoteChangeReason.moved);

      await map.requestRide();
      expect(socket.quoteIds, ['q-sedan-1', 'q-fresh']);
      expect(QuoteLockState.instance.pending, isNull);
    });
  });

  group('the ticket after a refused quote', () {
    Future<_TicketMap> pumpTicket(WidgetTester tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      final fake = _TicketMap();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const PrecisePickupScreen()),
          GoRoute(
            path: '/searching-driver',
            builder: (_, _) => const Scaffold(body: Text('searching')),
          ),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<MapProvider>.value(
          value: fake,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      return fake;
    }

    testWidgets('time passed: the new fare and why, then Confirm books', (
      tester,
    ) async {
      final fake = await pumpTicket(tester);
      expect(find.byKey(const Key('fare_ticket_notice')), findsNothing);

      fake.estimates = {
        'sedan': {..._expired()['fresh_quote'] as Map<String, dynamic>},
      };
      QuoteLockState.instance.reportFrame(_expired(), vehicleType: 'sedan');
      await tester.pump();

      expect(
        find.text('Fare updated to ₹260 because time passed'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ticket_fare')), findsOneWidget);
      expect(find.text('₹260'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_and_book')));
      await tester.pumpAndSettle();
      expect(find.text('searching'), findsOneWidget);
    });

    testWidgets('pickup changed says so', (tester) async {
      final fake = await pumpTicket(tester);
      fake.estimates = {
        'sedan': {..._expired()['fresh_quote'] as Map<String, dynamic>},
      };
      QuoteLockState.instance.reportFrame(
        _expired(reason: 'moved'),
        vehicleType: 'sedan',
      );
      await tester.pump();
      expect(
        find.text('Fare updated to ₹260 because the pickup changed'),
        findsOneWidget,
      );
    });

    testWidgets('no fare on the ticket: Confirm cannot book', (tester) async {
      final fake = await pumpTicket(tester);
      fake.estimates = {};
      QuoteLockState.instance.reportFrame({
        'type': 'error',
        'code': 'QUOTE_EXPIRED',
        'reason': 'expired',
      }, vehicleType: 'sedan');
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm_and_book')));
      await tester.pumpAndSettle();
      expect(find.text('searching'), findsNothing);
    });
  });
}

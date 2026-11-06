// Rider UI group B: fare-quote ETA, confirm pickup, finding, arriving,
// trip complete and no-driver, on the design system.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:saaradhigo_rider/core/maps/placeholder_maps_provider.dart';
import 'package:saaradhigo_rider/core/maps/sg_map.dart';
import 'package:saaradhigo_rider/providers/map_provider.dart';
import 'package:saaradhigo_rider/screens/home/precise_pickup_screen.dart';
import 'package:saaradhigo_rider/services/models/location_model.dart';
import 'package:saaradhigo_rider/services/rating_service.dart';
import 'package:saaradhigo_rider/ui/choose_ride_sheet.dart';
import 'package:saaradhigo_rider/ui/ride_rating_panel.dart';
import 'package:saaradhigo_rider/ui/sg_widgets.dart';
import 'package:saaradhigo_rider/ui/trip_widgets.dart';

import 'support/rider_ui_fixtures.dart';

class _FakeMap extends MapProvider {
  LatLng? confirmed;
  String? confirmedAddress;

  @override
  PlaceDetails? get pickupLocation => PlaceDetails(
      placeId: 'p', name: 'Hitech City Metro', formattedAddress: '', latitude: 17.4435, longitude: 78.3772);

  @override
  Map<String, Map<String, dynamic>> get fareEstimates => {
        'sedan': {'estimated_fare': '248.00', 'pickup_eta_min': 5, 'drivers_nearby': true, 'currency': 'INR'},
      };

  @override
  String? get selectedVehicleType => 'sedan';

  @override
  Future<String?> addressFor(LatLng point) async => 'Road No 36, Jubilee Hills';

  @override
  void setPrecisePickupLocation(LatLng location, {String? address}) {
    confirmed = location;
    confirmedAddress = address;
  }
}

DriverCardData _ravi() => const DriverCardData(
    name: 'Ravi Kumar', rating: '4.92', vehicleLine: 'Maruti Dzire · White', plate: 'ts 09 ex 4821');

SgLockedFareCard _fare() => const SgLockedFareCard(
    vehicleType: 'sedan',
    className: 'Saaradhi Sedan',
    route: 'Hitech City Metro → Inorbit Mall',
    fareText: '₹248');

class _FakeRating implements RatingService {
  final scores = <int>[];
  @override
  Future<RatingResult> rateTrip({required String tripId, required int score, String? comments}) async {
    scores.add(score);
    return const RatingResult(RatingOutcome.submitted);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<SgActionData> _actions(void Function(String) tapped) => [
      for (final a in const [
        ('call', 'Call', SgIcons.call),
        ('msg', 'Message', SgIcons.message),
        ('share', 'Share trip', SgIcons.share),
      ])
        SgActionData(key: a.$1, label: a.$2, icon: a.$3, onTap: () => tapped(a.$1)),
      SgActionData(key: 'safety', label: 'Safety', icon: SgIcons.shield, danger: true, onTap: () => tapped('safety')),
    ];

void main() {
  group('fare-quote ETA', () {
    test('rows read "5 min · 4 seats"', () {
      final o = RideOption.fromEstimates({
        'sedan': {'estimated_fare': '248', 'pickup_eta_min': 5, 'drivers_nearby': true},
      }).single;
      expect(o.meta, '5 min · 4 seats');
      expect(o.etaMin, 5);
      expect(o.driversNearby, isTrue);
    });

    test('no drivers nearby says so, with seats, and drops the ETA', () {
      final o = RideOption.fromEstimates({
        'sedan': {'estimated_fare': '248', 'pickup_eta_min': null, 'drivers_nearby': false},
      }).single;
      expect(o.meta, 'No drivers nearby · 4 seats');
      expect(o.driversNearby, isFalse);
      expect(o.etaMin, isNull);
    });

    test('a null ETA with drivers near shows seats only; a missing flag is not "none nearby"', () {
      final o = RideOption.fromEstimates({
        'sedan': {'estimated_fare': '248', 'pickup_eta_min': null, 'drivers_nearby': true},
        'suv': {'estimated_fare': '400'},
      });
      expect(o.first.meta, '4 seats');
      expect(o.last.driversNearby, isTrue);
    });

    testWidgets('the no-drivers row stays selectable', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      final picked = <String>[];
      await tester.pumpWidget(sgApp(chooseFrame(
        options: RideOption.fromEstimates({
          'sedan': {'estimated_fare': '248', 'pickup_eta_min': 5, 'drivers_nearby': true},
          'suv': {'estimated_fare': '412', 'drivers_nearby': false},
        }),
        selected: 'sedan',
        onSelect: picked.add,
      )));
      await tester.pump();
      expect(find.text('5 min · 4 seats'), findsOneWidget);
      expect(find.text('No drivers nearby · 6 seats'), findsOneWidget);
      await tester.tap(find.text('Saaradhi SUV'));
      expect(picked, ['suv']);
    });
  });

  group('confirm pickup', () {
    testWidgets('the dragged coordinates are what is confirmed', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      final fake = _FakeMap();
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const PrecisePickupScreen()),
        GoRoute(path: '/searching-driver', builder: (_, _) => const Scaffold(body: Text('searching'))),
      ]);
      await tester.pumpWidget(ChangeNotifierProvider<MapProvider>.value(
        value: fake,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Confirm pickup'), findsOneWidget);
      expect(find.text('Pickup in 5 min'), findsOneWidget);
      expect(find.text('Fare locked at ₹248. Drivers see it before they accept.'), findsOneWidget);
      expect(find.text('Hitech City Metro'), findsOneWidget);
      expect(find.byType(SgPrimaryButton), findsOneWidget);

      await tester.dragFrom(const Offset(195, 300), const Offset(0, -120));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('Road No 36, Jubilee Hills'), findsOneWidget);

      await tester.tap(find.text('Request Sedan'));
      await tester.pump();
      final at = fake.confirmed!;
      expect(at.latitude, lessThan(17.4435), reason: 'dragging the map up moves the pin south');
      expect((at.latitude - 17.4435).abs(), greaterThan(0.0005));
      expect(at.longitude, closeTo(78.3772, 1e-6));
      expect(fake.confirmedAddress, 'Road No 36, Jubilee Hills');
      await tester.pumpAndSettle();
      expect(find.text('searching'), findsOneWidget);
    });

    testWidgets('no ETA in the quote hides the chip', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(sgApp(confirmFrame(
        sheet: ConfirmPickupSheet(
            address: 'Hitech City', lockText: 'Fare locked at ₹248.', buttonLabel: 'Request Sedan', onConfirm: () {}),
      )));
      expect(find.textContaining('Pickup in'), findsNothing);
    });
  });

  group('finding your Saaradhi', () {
    testWidgets('shows the locked fare and a way out, never a bare spinner', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      var cancelled = false;
      await tester.pumpWidget(sgApp(tripFrame(
        pulse: true,
        sheet: FindingSheet(
            subline: findingSubline(driversNearby: false), fare: _fare(), onCancel: () => cancelled = true),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Finding your Saaradhi'), findsOneWidget);
      expect(find.text('Usually under a minute.'), findsOneWidget);
      expect(find.text('₹248'), findsOneWidget);
      expect(find.text('Saaradhi Sedan'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Cancel request'));
      expect(cancelled, isTrue);
    });

    test('"Drivers nearby." only when the quote said so', () {
      expect(findingSubline(driversNearby: true), contains('Drivers nearby.'));
      expect(findingSubline(driversNearby: false), isNot(contains('Drivers nearby')));
    });
  });

  group('driver assigned', () {
    testWidgets('plate on champagne, four PIN boxes, Safety one tap away', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      final tapped = <String>[];
      await tester.pumpWidget(sgApp(tripFrame(
        sheetHeight: 470,
        sheet: ArrivingSheet(
          headline: 'Ravi is 3 min away',
          badge: 'On the way',
          meetLine: 'Meet at Gate 2',
          driver: _ravi(),
          pin: '482193',
          actions: _actions(tapped.add),
        ),
      )));
      await tester.pump();
      expect(find.text('Ravi is 3 min away'), findsOneWidget);
      expect(find.text('ON THE WAY'), findsOneWidget);
      expect(find.text('Meet at Gate 2'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('4.92'), findsOneWidget);
      expect(find.text('RK'), findsOneWidget);
      expect(find.text('Maruti Dzire · White'), findsOneWidget);
      final plate = find.text('TS 09 EX 4821');
      expect(plate, findsOneWidget);
      final box = tester.widget<Container>(find.ancestor(of: plate, matching: find.byType(Container)).first);
      expect((box.decoration as BoxDecoration).color, const Color(0xFFFFF4BF));
      expect(find.text('RIDE PIN'), findsOneWidget);
      expect(find.text('Share only in the car'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(Key('pin_box_$i')), findsOneWidget);
      }
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Share trip'), findsOneWidget);
      await tester.tap(find.text('Safety'));
      expect(tapped, ['safety']);
    });

    test('name, initials, rating and time helpers', () {
      expect(firstNameOf('Ravi Kumar'), 'Ravi');
      expect(initialsOf('ravi kumar'), 'RK');
      expect(ratingText('4.9'), '4.90');
      expect(ratingText(null), isNull);
      expect(ratingText(0), isNull);
      expect(ratingText('0.00'), isNull);
      expect(tripDetailLine('Inorbit Mall, Madhapur', DateTime(2026, 1, 1, 21, 41), '24 mins'),
          'Inorbit Mall · 9:41 pm · 24 min');
    });
  });

  group('live trip', () {
    testWidgets('keeps Share trip and Safety visible', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(sgApp(tripFrame(
        sheet: LiveTripSheet(
          headline: 'On the way to Inorbit Mall · 12 min',
          driver: _ravi(),
          actions: [
            SgActionData(key: 'share', label: 'Share trip', icon: SgIcons.share, onTap: () {}),
            SgActionData(key: 'safety', label: 'Safety', icon: SgIcons.shield, danger: true, onTap: () {}),
          ],
        ),
      )));
      expect(find.text('On the way to Inorbit Mall · 12 min'), findsOneWidget);
      expect(find.text('Share trip'), findsOneWidget);
      expect(find.text('Safety'), findsOneWidget);
      expect(find.text('TS 09 EX 4821'), findsOneWidget);
    });
  });

  group('trip complete', () {
    Future<void> pumpComplete(WidgetTester tester, {required bool paid, String? method = 'upi'}) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(sgApp(SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TripCompleteView(
            detailLine: 'Inorbit Mall · 9:41 pm · 24 min',
            paidLabel: paidLabelFor(method, paid: paid),
            fareText: '₹248',
            paid: paid,
            below: RideRatingPanel(tripId: '9', driverName: 'Ravi Kumar', onDone: (_) {}, service: _FakeRating()),
          ),
        ]),
      )));
      await tester.pump();
    }

    testWidgets('"Paid" shows only when the trip is paid', (tester) async {
      await pumpComplete(tester, paid: true);
      expect(find.text('You have arrived'), findsOneWidget);
      expect(find.text('PAID BY UPI'), findsOneWidget);
      expect(find.text('₹248'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('How was your ride with Ravi?'), findsOneWidget);
    });

    testWidgets('unpaid has no badge, and tips are not faked', (tester) async {
      await pumpComplete(tester, paid: false, method: 'cash');
      expect(find.text('PAID'), findsNothing);
      expect(find.text('FARE BY CASH'), findsOneWidget);
      expect(find.textContaining('Tip'), findsNothing);
      expect(find.byType(SgPrimaryButton), findsOneWidget);
    });

    test('plates print as written on the car; other formats stay', () {
      expect(formatPlate('TS09QT0059'), 'TS 09 QT 0059');
      expect(formatPlate('ts 09 ex 4821'), 'TS 09 EX 4821');
      expect(formatPlate('KA5A12'), 'KA 5 A 12');
      expect(formatPlate('abc-123'), 'ABC-123');
    });

    test('the paid amount is exact: no decimals only when paise are zero', () {
      expect(exactMoney(121.46, 'INR'), '₹121.46');
      expect(exactMoney(248.0, 'INR'), '₹248');
    });

    test('payment method names', () {
      expect(paidLabelFor('cash'), 'PAID BY CASH');
      expect(paidLabelFor('wallet'), 'PAID FROM WALLET');
      expect(paidLabelFor('upi'), 'PAID BY UPI');
    });

    testWidgets('Done saves the stars, or just leaves when there are none', (tester) async {
      final svc = _FakeRating();
      final results = <bool>[];
      await tester.pumpWidget(sgApp(
          RideRatingPanel(tripId: '9', driverName: 'Ravi Kumar', service: svc, onDone: results.add)));
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(results, [false]);
      expect(svc.scores, isEmpty);

      await tester.tap(find.byKey(const Key('star_4')));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(svc.scores, [4]);
      expect(results, [false, true]);
    });
  });

  group('no driver found', () {
    testWidgets('Try again is the one gold button; Change ride is secondary', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      final taps = <String>[];
      await tester.pumpWidget(sgApp(tripFrame(
        sheet: NoDriverSheet(
          subline: 'Drivers nearby are busy right now. Try again, or choose another ride.',
          fare: _fare(),
          onTryAgain: () => taps.add('again'),
          onChangeRide: () => taps.add('change'),
        ),
      )));
      expect(find.text('No Saaradhi nearby right now'), findsOneWidget);
      expect(find.text('₹248'), findsOneWidget);
      expect(find.byType(SgPrimaryButton), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Change ride'));
      expect(taps, ['again', 'change']);
    });
  });

  testWidgets('the placeholder map reports a drag and then idle', (tester) async {
    setPhoneSurface(tester);
    addTearDown(tester.view.reset);
    final moves = <LatLng>[];
    var idle = 0;
    await tester.pumpWidget(sgApp(SgMap(
      provider: const PlaceholderMapsProvider(),
      initialCenter: const LatLng(17.4, 78.4),
      initialZoom: 17,
      onCameraMove: (c) => moves.add(c.center),
      onCameraIdle: () => idle++,
    )));
    await tester.dragFrom(const Offset(200, 300), const Offset(60, 0));
    await tester.pump();
    expect(moves, isNotEmpty);
    expect(moves.last.longitude, lessThan(78.4), reason: 'content moved right, camera went west');
    expect(idle, 1);
  });
}

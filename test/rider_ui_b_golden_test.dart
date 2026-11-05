// Goldens at 390x844 logical. Regenerate with:
//   flutter test --update-goldens test/rider_ui_b_golden_test.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saaradhigo_rider/core/maps/sg_map.dart';
import 'package:saaradhigo_rider/ui/ride_rating_panel.dart';
import 'package:saaradhigo_rider/ui/sg_tokens.dart';
import 'package:saaradhigo_rider/ui/sg_widgets.dart';
import 'package:saaradhigo_rider/ui/trip_widgets.dart';

import 'support/rider_ui_fixtures.dart';

/// Goldens are made on Windows and checked on Linux CI, where text rasterises a
/// little differently (0.6% of pixels). Up to 1% passes; a layout change does not.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= 0.01) return true;
    throw FlutterError(await generateFailureOutput(result, golden, basedir));
  }
}

const _carAt = LatLng(17.395, 78.375);

const _pickup = SgMarker(
    id: 'pickup', point: tripPickup, icon: SgSvgMarker('assets/markers/pickup.svg'));
const _drop = SgMarker(
    id: 'drop', point: tripDrop, icon: SgSvgMarker('assets/markers/dropoff.svg'));
const _car = SgMarker(
    id: 'driver',
    point: _carAt,
    icon: SgIconMarker(Icons.directions_car, SgColors.gold500, size: 34),
    anchor: Offset(0.5, 0.5));

const _fare = SgLockedFareCard(
    vehicleType: 'sedan',
    className: 'Saaradhi Sedan',
    route: 'Hitech City Metro → Inorbit Mall',
    fareText: '₹248');

void main() {
  setUpAll(() async {
    goldenFileComparator = _TolerantComparator(
        (goldenFileComparator as LocalFileComparator).basedir.resolve('rider_ui_b_golden_test.dart'));
    await loadSgFonts();
  });

  Future<void> shoot(WidgetTester tester, Widget w, String name) async {
    setPhoneSurface(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(sgApp(w));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('confirm pickup', (tester) => shoot(
      tester,
      confirmFrame(
        chip: 'Pickup in 5 min',
        sheet: ConfirmPickupSheet(
          address: 'Hitech City Metro Station, Madhapur',
          lockText: 'Fare locked at ₹248. Drivers see it before they accept.',
          buttonLabel: 'Request Sedan',
          onConfirm: () {},
        ),
      ),
      'confirm_pickup'));

  testWidgets('finding your Saaradhi', (tester) => shoot(
      tester,
      tripFrame(
        pulse: true,
        sheetHeight: 400,
        markers: const [_pickup],
        sheet: FindingSheet(subline: findingSubline(driversNearby: true), fare: _fare, onCancel: () {}),
      ),
      'finding'));

  testWidgets('driver arriving', (tester) => shoot(
      tester,
      tripFrame(
        sheetHeight: 470,
        markers: const [_pickup, _car],
        polylines: const [
          SgPolyline(id: 'to', points: [_carAt, tripPickup], color: SgColors.inkMuted, width: 3, dotted: true),
        ],
        sheet: ArrivingSheet(
          headline: 'Ravi is 3 min away',
          badge: 'On the way',
          meetLine: 'Meet at Gate 2',
          driver: const DriverCardData(
              name: 'Ravi Kumar', rating: '4.92', vehicleLine: 'Maruti Dzire · White', plate: 'TS 09 EX 4821'),
          pin: '4821',
          onCancel: () {},
          actions: [
            SgActionData(key: 'c', label: 'Call', icon: SgIcons.call, onTap: () {}),
            SgActionData(key: 'm', label: 'Message', icon: SgIcons.message, onTap: () {}),
            SgActionData(key: 's', label: 'Share trip', icon: SgIcons.share, onTap: () {}),
            SgActionData(key: 'x', label: 'Safety', icon: SgIcons.shield, danger: true, onTap: () {}),
          ],
        ),
      ),
      'arriving'));

  testWidgets('trip complete', (tester) => shoot(
      tester,
      SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 24, 16, 24), children: [
          TripCompleteView(
            detailLine: 'Inorbit Mall · 9:41 pm · 24 min',
            paidLabel: paidLabelFor('upi'),
            fareText: '₹248',
            paid: true,
            below: RideRatingPanel(tripId: '9', driverName: 'Ravi Kumar', onDone: (_) {}),
          ),
        ]),
      ),
      'trip_complete'));

  testWidgets('no driver found', (tester) => shoot(
      tester,
      tripFrame(
        sheetHeight: 440,
        markers: const [_pickup],
        sheet: NoDriverSheet(
          subline: 'Drivers nearby are busy right now. Try again, or choose another ride.',
          fare: _fare,
          onTryAgain: () {},
          onChangeRide: () {},
        ),
      ),
      'no_driver'));
}

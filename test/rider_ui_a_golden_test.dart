// Goldens at 390x844 logical. Regenerate with:
//   flutter test --update-goldens test/rider_ui_a_golden_test.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/ui/choose_ride_sheet.dart';
import 'package:saaradhigo_rider/ui/home_sheet.dart';
import 'package:saaradhigo_rider/ui/sg_widgets.dart';

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

void main() {
  setUpAll(() async {
    goldenFileComparator = _TolerantComparator(
        (goldenFileComparator as LocalFileComparator).basedir.resolve('rider_ui_a_golden_test.dart'));
    await loadSgFonts();
  });
  testWidgets('home sheet over the placeholder map', (tester) async {
    setPhoneSurface(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(sgApp(homeFrame(
      chips: [
        SavedChipData(label: 'Home', icon: SgIcons.home, onTap: () {}),
        SavedChipData(label: 'Work', icon: SgIcons.work, onTap: () {}),
        SavedChipData(label: 'RGIA Airport', onTap: () {}),
      ],
      recents: [
        RecentPlaceData(
            name: 'Inorbit Mall', address: 'Madhapur, Hyderabad', distance: '4.2 km', onTap: () {}),
        RecentPlaceData(
            name: 'Charminar', address: 'Old City, Hyderabad', distance: '18 km', onTap: () {}),
      ],
    )));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home_sheet.png'));
  });

  testWidgets('choose a ride with four classes', (tester) async {
    setPhoneSurface(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(sgApp(chooseFrame(
      options: RideOption.fromEstimates(fourClasses()),
      selected: 'sedan',
    )));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/choose_ride.png'));
  });
}

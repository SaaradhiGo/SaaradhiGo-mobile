import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/ui/account_widgets.dart';
import 'package:saaradhigo_rider/ui/sg_tokens.dart';
import 'package:saaradhigo_rider/ui/sg_widgets.dart';

import 'support/rider_ui_fixtures.dart';

/// Same 1% tolerance as groups A and B: Windows-made goldens, Linux CI.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= 0.01) return true;
    throw FlutterError(await generateFailureOutput(result, golden, basedir));
  }
}

/// The Profile pane as HomeScreen builds it, from the public pieces.
Widget profileFrame({String? name, String? rating, int unread = 0}) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
      child: ListView(
        children: [
          const SgPageTitle('Profile'),
          SgPersonHeader(name: name, rating: rating),
          const SizedBox(height: SgSpace.s5),
          SgListGroup([
            SgListRow(icon: SgIcons.user, label: 'Personal information', chevron: true, onTap: () {}),
            SgListRow(icon: kCardIcon, label: 'Payment methods', chevron: true, onTap: () {}),
            SgListRow(icon: SgIcons.bell, label: 'Notifications', count: unread, onTap: () {}),
            SgListRow(icon: SgIcons.help, label: 'Help and support', chevron: true, onTap: () {}),
          ]),
          const SizedBox(height: SgSpace.s5),
          SgListGroup([SgListRow(icon: kLogoutIcon, label: 'Log out', danger: true, onTap: () {})]),
        ],
      ),
    );

void main() {
  setUpAll(() async {
    goldenFileComparator = _TolerantComparator(
        (goldenFileComparator as LocalFileComparator).basedir.resolve('rider_ui_c_test.dart'));
    await loadSgFonts();
  });

  testWidgets('the header shows only what the account holds', (tester) async {
    setPhoneSurface(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(sgApp(profileFrame(name: 'Aarav Sharma', rating: '4.9')));
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('AS'), findsOneWidget);
    expect(find.text('4.90'), findsOneWidget);

    await tester.pumpWidget(sgApp(profileFrame()));
    expect(find.text('Add your name'), findsOneWidget);
    expect(find.byKey(const Key('person_rating')), findsNothing);
    expect(find.text('4.98'), findsNothing);
  });

  testWidgets('a zero rating is not shown', (tester) async {
    await tester.pumpWidget(sgApp(const SgPersonHeader(name: 'Aarav', rating: '0.0')));
    expect(find.byKey(const Key('person_rating')), findsNothing);
  });

  testWidgets('rows carry an unread count and fire their action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(sgApp(
        SgListRow(icon: SgIcons.bell, label: 'Notifications', count: 3, onTap: () => taps++)));
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);
    await tester.tap(find.text('Notifications'));
    expect(taps, 1);
  });

  testWidgets('golden: profile', (tester) async {
    setPhoneSurface(tester);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(sgApp(profileFrame(name: 'Aarav Sharma', rating: '4.9', unread: 2)));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile.png'));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/screens/auth/otp_verification_screen.dart';
import 'package:saaradhigo_rider/services/home_fares.dart';
import 'package:saaradhigo_rider/services/models/location_model.dart';
import 'package:saaradhigo_rider/services/models/trip_model.dart';
import 'package:saaradhigo_rider/ui/home_widgets.dart';
import 'package:saaradhigo_rider/ui/sg_appearance.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tier 2, PR A: first-name split, which places the home quotes, the OTP
/// boxes, and the account's language.
void main() {
  group('homeFirstName', () {
    test('splits on the first space', () {
      expect(homeFirstName('Ravi Kumar Reddy'), 'Ravi');
      expect(homeFirstName('  Priya  '), 'Priya');
      expect(homeFirstName(''), '');
      expect(homeFirstName(null), '');
    });
  });

  test('durationLabel', () {
    expect(durationLabel(6), '6 min');
    expect(durationLabel(65), '1 h 05 min');
  });

  group('pickHomePlaces', () {
    FavoriteLocation fav(int id, String text, {String? label}) =>
        FavoriteLocation(
          id: id,
          addressText: text,
          latitude: 17.4 + id / 100,
          longitude: 78.4,
          label: label,
        );
    Trip trip(String to, {double? lat = 17.5}) => Trip.fromJson({
      'id': 1,
      'pickup_address': 'A',
      'destination_address': to,
      'status': 'completed',
      'destination_lat': lat,
      'destination_long': 78.5,
    });

    test('labelled places first, then saved, then recents; at most two', () {
      final picked = pickHomePlaces(
        [fav(1, 'Mindspace, Madhapur'), fav(2, 'Kondapur, X', label: 'home')],
        [trip('Inorbit Mall, Madhapur')],
      );
      expect(picked.map((p) => p.name), ['Home', 'Mindspace']);
    });

    test('recents fill in; no coordinates, no card; names once', () {
      final picked = pickHomePlaces([], [
        trip('Inorbit Mall, Madhapur', lat: null),
        trip('Charminar, Old City'),
        trip('Charminar, Old City'),
      ]);
      expect(picked.map((p) => p.name), ['Charminar']);
    });

    test('an unknown label is ignored', () {
      final f = FavoriteLocation.fromJson({
        'id': 3,
        'address_text': 'X',
        'latitude': '1',
        'longitude': '2',
        'label': 'gym',
      });
      expect(f.label, isNull);
      expect(
        FavoriteLocation.fromJson({
          'id': 3,
          'address_text': 'X',
          'label': 'WORK',
        }).label,
        'work',
      );
    });
  });

  testWidgets('a pasted or SMS-offered code fills all six boxes', (
    tester,
  ) async {
    final c = TextEditingController();
    final f = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => OtpBoxes(
              controller: c,
              focusNode: f,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('otp_field')), '48a2913');
    await tester.pump();
    // Digits only, six at most.
    expect(c.text, '482913');
    for (final (i, d) in ['4', '8', '2', '9', '1', '3'].indexed) {
      expect(
        find.descendant(
          of: find.byKey(Key('otp_box_$i')),
          matching: find.text(d),
        ),
        findsOneWidget,
      );
    }
  });

  group('preferred language', () {
    test(
      'the account language is used only when the device has none',
      () async {
        SharedPreferences.setMockInitialValues({});
        await SgAppearance.instance.restore();
        await SgAppearance.instance.adoptServerLanguage('te');
        expect(SgAppearance.instance.language, 'te');

        SharedPreferences.setMockInitialValues({SgAppearance.localeKey: 'hi'});
        await SgAppearance.instance.restore();
        await SgAppearance.instance.adoptServerLanguage('te');
        expect(SgAppearance.instance.language, 'hi');

        SharedPreferences.setMockInitialValues({});
        await SgAppearance.instance.restore();
        await SgAppearance.instance.adoptServerLanguage('fr');
        expect(SgAppearance.instance.language, 'en');
      },
    );

    test('picking a language tells the account', () async {
      SharedPreferences.setMockInitialValues({});
      await SgAppearance.instance.restore();
      final sent = <String>[];
      SgAppearance.onLanguagePicked = sent.add;
      addTearDown(() => SgAppearance.onLanguagePicked = null);
      await SgAppearance.instance.setLanguage('hi');
      expect(sent, ['hi']);
      await SgAppearance.instance.setLanguage('en');
    });
  });
}

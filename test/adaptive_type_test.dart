// Tier 1 (owner, 2026-11-06): type that adapts to every screen.
//
// * One scale in logical pixels, times the size class's factor (compact 0.92
//   under 360, regular 1.0, tablet 1.12 from 600).
// * Weights 500, 600 and 700 only; nothing under 13.
// * The main rider screens hold at 320 wide with a 1.3x text size: text
//   wraps or the sheet scrolls, and nothing overflows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/ui/booking_widgets.dart';
import 'package:saaradhigo_rider/ui/choose_ride_sheet.dart';
import 'package:saaradhigo_rider/ui/home_widgets.dart';
import 'package:saaradhigo_rider/ui/sg_appearance.dart';
import 'package:saaradhigo_rider/ui/sg_layout.dart';
import 'package:saaradhigo_rider/ui/sg_text.dart';
import 'package:saaradhigo_rider/ui/sg_tokens.dart';
import 'package:saaradhigo_rider/ui/sg_widgets.dart';
import 'package:saaradhigo_rider/ui/trip_t2_widgets.dart';

import 'support/rider_ui_fixtures.dart';

Widget _app(Widget body, {double textScale = 1.3}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: sgTheme(SgPalette.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: SgSizeScope(child: child!),
  ),
  home: Scaffold(backgroundColor: SgColors.bg000, body: body),
);

void _surface(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// A sheet over a map-sized space, as the trip screens place it.
Widget _overMap(Widget sheet) => Stack(
  children: [
    Positioned.fill(child: ColoredBox(color: SgColors.mapLandLight)),
    Align(
      alignment: Alignment.bottomCenter,
      child: SgScrollingSheet(child: sheet),
    ),
  ],
);

final _driver = SgDriverRow(
  name: 'Venkata Ramana Reddy Kothapalli',
  rating: '4.86',
  vehicleLine: 'White Maruti Suzuki Dzire Tour S',
  plate: 'TS 09 QT 0059',
);

final _actions = [
  SgIconButtonWide(icon: SgIcons.call, label: 'Call', onTap: () {}),
  SgIconButtonWide(icon: SgIcons.message, label: 'Message', onTap: () {}),
];

final Map<String, Widget> _screens = {
  'home header and fares': ListView(
    padding: const EdgeInsets.all(SgSpace.s4),
    children: [
      HomeHeader(
        languageShort: 'EN',
        onLanguage: () {},
        name: 'Aarav Sharma',
        onAccount: () {},
        onToggleTheme: () {},
      ),
      const SizedBox(height: SgSpace.s4),
      Text('Where to, Aarav?', style: SgText.display),
      const SizedBox(height: SgSpace.s4),
      HomeFareCard(
        name: 'Inorbit Mall, Madhapur, Hyderabad',
        meta: '6.2 km · 18 min',
        onTap: () {},
        chips: [
          HomeClassChip(type: 'auto', fareText: '₹142', onTap: () {}),
          HomeClassChip(type: 'sedan', fareText: '₹248', onTap: () {}),
          HomeClassChip(type: 'suv', fareText: '₹412', onTap: () {}),
        ],
      ),
    ],
  ),
  'every fare': ChooseRideSheet(
    options: RideOption.fromEstimates(fourClasses(higher: true)),
    selectedType: 'sedan',
    onSelect: (_) {},
    onConfirm: () {},
    summary: '12.4 km · 24 min',
    paymentLabel: 'Cash',
    onChangePayment: () {},
  ),
  'ticket': _overMap(
    FareTicketSheet(
      buttonLabel: 'Confirm and book',
      onConfirm: () {},
      notice: 'Fare updated to ₹248 because time passed.',
      ticket: FareTicket(
        eyebrow: 'Fare ticket',
        vehicleType: 'sedan',
        className: 'Sedan',
        fareText: '₹248',
        lockText: 'This fare is locked',
        pickupLabel: 'Pickup',
        pickup: 'Hitech City Metro Station, Gate 2, Madhapur',
        dropLabel: 'Drop',
        drop: 'Inorbit Mall, Mindspace, Madhapur, Hyderabad',
        editLabel: 'Edit',
        onEditPickup: () {},
        breakdownLabel: 'See how ₹248 is worked out',
        onBreakdown: () {},
      ),
    ),
  ),
  'arriving': _overMap(
    SgSheetSurface(
      child: ArrivingT2Sheet(
        eta: '4 min',
        headline: 'Venkata is on the way',
        meetLine: 'Meet at Hitech City Metro Station, Gate 2',
        driver: _driver,
        pinPanel: const SgPinPanel(
          label: 'Ride PIN',
          hint: 'Tell your driver this number to start the trip',
          pin: '482913',
        ),
        actions: _actions,
        cancelLabel: 'Cancel ride',
        onCancel: () {},
        cancelNote: 'Free to cancel',
      ),
    ),
  ),
  'on trip': _overMap(
    SgSheetSurface(
      child: OnTripSheet(
        arrivalLine: 'Arriving about 3:38 pm',
        minutesLeft: '7 min left',
        progress: 0.4,
        driver: _driver,
        actions: _actions,
      ),
    ),
  ),
  'receipt': ListView(
    padding: const EdgeInsets.all(SgSpace.s4),
    children: const [
      ReceiptTiles(
        ticketLabel: 'Your ticket said',
        ticketText: '₹1,248',
        costLabel: 'Trip cost',
        costText: '₹1,248',
        equal: true,
      ),
    ],
  ),
};

void main() {
  setUpAll(loadSgFonts);
  setUp(() => SgAppearance.instance.apply());

  group('the type scale', () {
    test('size classes by the shortest side', () {
      expect(SgText.scaleFor(320), 0.92);
      expect(SgText.scaleFor(359), 0.92);
      expect(SgText.scaleFor(360), 1.0);
      expect(SgText.scaleFor(599), 1.0);
      expect(SgText.scaleFor(600), 1.12);
    });

    test('base sizes and weights, times the factor', () {
      for (final f in [0.92, 1.0, 1.12]) {
        SgText.scale = f;
        expect(SgText.screenTitle.fontSize, closeTo(24 * f, 1e-9));
        expect(SgText.sectionTitle.fontSize, closeTo(18 * f, 1e-9));
        expect(SgText.body.fontSize, closeTo(16 * f, 1e-9));
        expect(SgText.caption.fontSize, closeTo(14 * f, 1e-9));
        expect(SgText.label.fontSize, closeTo(13 * f, 1e-9));
        expect(SgText.button.fontSize, closeTo(17 * f, 1e-9));
        for (final s in [
          SgText.screenTitle,
          SgText.sectionTitle,
          SgText.body,
          SgText.caption,
          SgText.label,
          SgText.button,
          SgText.fare,
          SgText.fareXl,
        ]) {
          expect([
            FontWeight.w500,
            FontWeight.w600,
            FontWeight.w700,
          ], contains(s.fontWeight));
          expect(s.letterSpacing ?? 0, 0);
        }
      }
      SgText.scale = 0.92;
      expect(SgText.fareXl.fontSize, 40);
      SgText.scale = 1.0;
      expect(SgText.fareXl.fontSize, 44);
    });

    test('hand-built sizes snap to the scale, never under 13', () {
      SgText.scale = 1.0;
      expect(SgText.px(6), 13);
      expect(SgText.px(11), 13);
      expect(SgText.px(12), 13);
      expect(SgText.px(14), 14);
      expect(SgText.px(15), 16);
      expect(SgText.px(19), 18);
      expect(SgText.px(26), 24);
      expect(SgText.px(52), 44);
      SgText.scale = 1.12;
      expect(SgText.px(16), closeTo(16 * 1.12, 1e-9));
    });
  });

  group('320 wide at 1.3x text: nothing overflows', () {
    for (final e in _screens.entries) {
      testWidgets(e.key, (tester) async {
        _surface(tester, 320, 640);
        await tester.pumpWidget(_app(e.value));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(SgText.compact, isTrue);
      });
    }
  });

  group('landscape phone and tablet: nothing overflows', () {
    for (final e in _screens.entries) {
      testWidgets('${e.key}, 640x360', (tester) async {
        _surface(tester, 640, 360);
        await tester.pumpWidget(_app(e.value, textScale: 1.0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('the tablet split puts the sheet in a 440 panel', (
      tester,
    ) async {
      _surface(tester, 1280, 800);
      await tester.pumpWidget(
        _app(
          SgMapSplit(
            map: ColoredBox(color: SgColors.mapLandLight),
            sheet: const SizedBox(
              key: Key('sheet'),
              height: 200,
              width: double.infinity,
            ),
          ),
          textScale: 1.0,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const Key('sheet'))).width, 440);
      expect(SgText.scale, 1.12);
    });
  });

  testWidgets('the sun/moon switch: 48 target, says what it does', (
    tester,
  ) async {
    _surface(tester, 390, 844);
    SgColors.palette = SgPalette.light;
    await tester.pumpWidget(_app(SgThemeToggle(onTap: () {}), textScale: 1.0));
    final box = tester.getSize(find.byKey(const Key('home_theme_toggle')));
    expect(box.width, greaterThanOrEqualTo(48));
    expect(box.height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Switch to dark theme'), findsOneWidget);
    SgColors.palette = SgPalette.dark;
    await tester.pumpWidget(
      _app(SgThemeToggle(key: UniqueKey(), onTap: () {}), textScale: 1.0),
    );
    expect(find.bySemanticsLabel('Switch to light theme'), findsOneWidget);
    SgColors.palette = SgPalette.light;
  });
}

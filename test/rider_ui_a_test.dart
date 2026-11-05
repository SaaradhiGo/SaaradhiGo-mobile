// Rider UI group A: the "Where to?" sheet, "Choose a ride", and the map seam.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/core/maps/maps_availability.dart';
import 'package:saaradhigo_rider/core/maps/placeholder_maps_provider.dart';
import 'package:saaradhigo_rider/core/maps/sg_map.dart';
import 'package:saaradhigo_rider/ui/choose_ride_sheet.dart';
import 'package:saaradhigo_rider/ui/home_sheet.dart';

import 'support/rider_ui_fixtures.dart';

void main() {
  setUpAll(loadSgFonts);
  group('home sheet', () {
    testWidgets('greets by time of day and asks Where to?', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(sgApp(homeFrame(chips: const [], recents: const [])));
      await tester.pump();
      expect(find.text('Good evening'), findsOneWidget);
      expect(find.text('Where to?'), findsOneWidget);
      expect(find.text('Search destination'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(greetingFor(DateTime(2026, 1, 1, 8)), 'Good morning');
      expect(greetingFor(DateTime(2026, 1, 1, 14)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 19)), 'Good evening');
    });

    testWidgets('no saved place means no chip; no recents means a calm line', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(sgApp(homeFrame(chips: const [], recents: const [])));
      await tester.pump();
      expect(find.text('Home'), findsNothing);
      expect(find.text('Work'), findsNothing);
      expect(find.text('Places you ride to will appear here.'), findsOneWidget);
    });

    testWidgets('saved chips and recents show what the app has, and are tappable', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      var tapped = '';
      await tester.pumpWidget(sgApp(homeFrame(
        chips: [SavedChipData(label: 'Home', onTap: () => tapped = 'home')],
        recents: [
          RecentPlaceData(
            name: 'Inorbit Mall',
            address: 'Madhapur, Hyderabad',
            distance: '4.2 km',
            onTap: () => tapped = 'inorbit',
          ),
        ],
      )));
      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Work'), findsNothing);
      expect(find.text('Inorbit Mall'), findsOneWidget);
      expect(find.text('4.2 km'), findsOneWidget);
      expect(find.text('Places you ride to will appear here.'), findsNothing);
      await tester.tap(find.text('Inorbit Mall'));
      expect(tapped, 'inorbit');
      await tester.tap(find.text('Home'));
      expect(tapped, 'home');
    });

    test('a full address splits into name and area', () {
      final p = splitPlace('Inorbit Mall, Madhapur, Hyderabad');
      expect(p.name, 'Inorbit Mall');
      expect(p.address, 'Madhapur, Hyderabad');
    });
  });

  group('choose a ride', () {
    test('preselects the last-used class, else sedan, else the first', () {
      expect(preselectVehicle(['auto', 'sedan', 'suv'], 'suv'), 'suv');
      expect(preselectVehicle(['auto', 'sedan', 'suv'], 'Auto'), 'auto');
      expect(preselectVehicle(['auto', 'sedan', 'suv'], 'bike'), 'sedan');
      expect(preselectVehicle(['auto', 'sedan', 'suv'], null), 'sedan');
      expect(preselectVehicle(['auto', 'suv'], 'bike'), 'auto');
      expect(preselectVehicle([], 'sedan'), isNull);
    });

    test('options are cheapest first, whole rupees, with ETA and seats', () {
      final o = RideOption.fromEstimates(fourClasses());
      expect(o.map((e) => e.type), ['auto', 'hatchback', 'sedan', 'suv']);
      expect(o[2].name, 'Saaradhi Sedan');
      expect(o[2].fareText, '₹248');
      expect(o[2].meta, '5 min · 4 seats');
      expect(o[1].fareText, '₹196');
    });

    testWidgets('the button names the selection and follows it', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      final options = RideOption.fromEstimates(fourClasses());
      await tester.pumpWidget(sgApp(_Host(options: options)));
      await tester.pump();
      expect(find.text('Confirm Sedan · ₹248'), findsOneWidget);
      await tester.tap(find.text('Saaradhi Auto'));
      await tester.pump();
      expect(find.text('Confirm Auto · ₹142'), findsOneWidget);
      expect(find.text('Confirm Sedan · ₹248'), findsNothing);
      expect(find.text('12.4 km · 24 min'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('a higher price is explained calmly and never says surge', (tester) async {
      setPhoneSurface(tester);
      addTearDown(tester.view.reset);
      final options = RideOption.fromEstimates(fourClasses(higher: true));
      await tester.pumpWidget(sgApp(_Host(options: options)));
      await tester.pump();
      expect(find.text('Higher demand right now'), findsOneWidget);
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => (t.data ?? '').toLowerCase());
      expect(texts.where((t) => t.contains('surge')), isEmpty);
    });
  });

  group('map provider choice', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MapsAvailability.channel, null);
      MapsAvailability.resetForTest();
    });

    Future<void> answer(WidgetTester tester, bool value) async {
      MapsAvailability.resetForTest();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MapsAvailability.channel,
        (call) async => call.method == 'hasKey' ? value : null,
      );
      await MapsAvailability.ensureResolved();
    }

    testWidgets('the placeholder is chosen when hasKey is false', (tester) async {
      await answer(tester, false);
      expect(mapsProviderFor(hasKey: MapsAvailability.hasKey.value), isA<PlaceholderMapsProvider>());
      expect(find.text('API KEY REQUIRED'), findsNothing);
    });

    testWidgets('the placeholder is also the default before the platform answers', (tester) async {
      MapsAvailability.resetForTest();
      expect(mapsProviderFor(hasKey: MapsAvailability.hasKey.value), isA<PlaceholderMapsProvider>());
    });

    testWidgets('Google is chosen only once hasKey answers true', (tester) async {
      await answer(tester, true);
      expect(MapsAvailability.hasKey.value, isTrue);
      expect(mapsProviderFor(hasKey: true), same(kMapsProvider));
    });
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.options});
  final List<RideOption> options;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? _selected = preselectVehicle([for (final o in widget.options) o.type], null);

  @override
  Widget build(BuildContext context) => chooseFrame(
        options: widget.options,
        selected: _selected,
        onSelect: (t) => setState(() => _selected = t),
      );
}

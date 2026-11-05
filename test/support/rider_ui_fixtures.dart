import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:saaradhigo_rider/core/maps/placeholder_maps_provider.dart';
import 'package:saaradhigo_rider/core/maps/sg_map.dart';
import 'package:saaradhigo_rider/ui/choose_ride_sheet.dart';
import 'package:saaradhigo_rider/ui/home_sheet.dart';
import 'package:saaradhigo_rider/ui/sg_text.dart';
import 'package:saaradhigo_rider/ui/sg_tokens.dart';
import 'package:saaradhigo_rider/ui/sg_widgets.dart';

const _mapProvider = PlaceholderMapsProvider();

Widget sgApp(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: sgDarkTheme(),
      home: Scaffold(backgroundColor: SgColors.bg000, body: child),
    );

Map<String, Map<String, dynamic>> fourClasses({bool higher = false}) => {
      'auto': {'estimated_fare': '142.00', 'pickup_eta_min': 3, 'seats': 3, 'currency': 'INR'},
      'hatchback': {'estimated_fare': '196.40', 'pickup_eta_min': 4, 'seats': 4, 'currency': 'INR'},
      'sedan': {
        'estimated_fare': '248.00',
        'pickup_eta_min': 5,
        'seats': 4,
        'currency': 'INR',
        if (higher) 'price_reason': 'Surge pricing near Hitech City',
      },
      'suv': {'estimated_fare': '412.00', 'pickup_eta_min': 8, 'seats': 6, 'currency': 'INR'},
    };

/// The Home frame: placeholder map, top bar, and the "Where to?" sheet.
Widget homeFrame({
  required List<SavedChipData> chips,
  required List<RecentPlaceData> recents,
  String greeting = 'Good evening',
}) {
  return Stack(
    children: [
      const Positioned.fill(
        child: SgMap(
          provider: _mapProvider,
          initialCenter: LatLng(17.44, 78.38),
          padding: EdgeInsets.only(bottom: 440),
          markers: [
            SgMarker(
              id: 'pickup',
              point: LatLng(17.44, 78.38),
              icon: SgSvgMarker('assets/markers/pickup.svg'),
            ),
          ],
        ),
      ),
      Positioned(
        top: 52,
        left: 16,
        right: 16,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SgMapButton(icon: SgIcons.menu, label: 'Menu', onTap: () {}),
            SgMapButton(icon: SgIcons.user, label: 'Account', onTap: () {}),
          ],
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 84),
          child: HomeSheet(
            greeting: greeting,
            search: SgSearchBar(
              field: Text('Search destination',
                  style: SgText.body.copyWith(color: SgColors.inkSubtle)),
            ),
            chips: chips,
            recents: recents,
          ),
        ),
      ),
    ],
  );
}

/// The Choose a ride frame: map in the top 40%, sheet below.
Widget chooseFrame({
  required List<RideOption> options,
  required String? selected,
  ValueChanged<String>? onSelect,
}) {
  return Column(
    children: [
      Expanded(
        flex: 40,
        child: SgMap(
          provider: _mapProvider,
          initialCenter: const LatLng(17.42, 78.4),
          markers: const [
            SgMarker(
                id: 'pickup',
                point: LatLng(17.40, 78.37),
                icon: SgSvgMarker('assets/markers/pickup.svg')),
            SgMarker(
                id: 'drop',
                point: LatLng(17.45, 78.45),
                icon: SgSvgMarker('assets/markers/dropoff.svg')),
          ],
          polylines: const [
            SgPolyline(
              id: 'route',
              color: SgColors.gold500,
              width: 4.5,
              points: [
                LatLng(17.40, 78.37),
                LatLng(17.41, 78.40),
                LatLng(17.43, 78.41),
                LatLng(17.44, 78.43),
                LatLng(17.45, 78.45),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        flex: 60,
        child: ChooseRideSheet(
          options: options,
          selectedType: selected,
          onSelect: onSelect ?? (_) {},
          onConfirm: () {},
          summary: '12.4 km · 24 min',
          paymentLabel: 'Cash',
          onChangePayment: () {},
        ),
      ),
    ],
  );
}

void setPhoneSurface(dynamic tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
}

/// flutter test draws every font as Ahem blocks unless told otherwise.
Future<void> loadSgFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await load('Manrope', ['Manrope.ttf']);
  await load('CormorantGaramond', ['CormorantGaramond.ttf']);
}

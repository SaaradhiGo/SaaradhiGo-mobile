// Owner decision D1 (2026-11-02): Google Maps behind one adapter, styled
// with the seven map-* tokens (dark), and no OpenStreetMap or CARTO tiles.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saaradhigo_rider/core/maps/map_style.dart';
import 'package:saaradhigo_rider/core/maps/sg_map.dart';

class _RecordingProvider extends MapsProvider {
  SgMap? last;
  @override
  Widget build(SgMap map) {
    last = map;
    return const SizedBox.expand();
  }
}

void main() {
  test('the basemap uses the seven map tokens and nothing else', () {
    final colours = <String>{};
    for (final rule in jsonDecode(kSgMapStyle) as List) {
      for (final styler in (rule as Map)['stylers'] as List) {
        final c = (styler as Map)['color'];
        if (c != null) colours.add(c as String);
      }
    }
    expect(colours, {
      MapTokens.ground, MapTokens.street, MapTokens.arterial, MapTokens.highway,
      MapTokens.water, MapTokens.park, MapTokens.label,
    });
  });

  test("Google's own business pins and transit are off, not recoloured", () {
    final rules = (jsonDecode(kSgMapStyle) as List).cast<Map>();
    bool off(String feature) => rules.any((r) =>
        r['featureType'] == feature &&
        (r['stylers'] as List).any((s) => (s as Map)['visibility'] == 'off'));
    expect(off('poi.business'), isTrue);
    expect(off('transit'), isTrue);
  });

  testWidgets('screens describe the map; the provider draws it', (tester) async {
    final provider = _RecordingProvider();
    await tester.pumpWidget(SgMap(
      provider: provider,
      initialCenter: const LatLng(16.5062, 80.6480),
      markers: const [
        SgMarker(id: 'pickup', point: LatLng(16.5, 80.6), icon: SgSvgMarker('assets/markers/pickup.svg')),
      ],
    ));
    expect(provider.last?.markers.single.id, 'pickup');
  });

  test('two looks never share a cached bitmap', () {
    const a = SgIconMarker(Icons.directions_car, Color(0xFFEEBD2B), size: 24);
    const b = SgIconMarker(Icons.directions_car, Color(0xFFEEBD2B), size: 34);
    const c = SgSvgMarker('assets/markers/pickup.svg');
    expect({a.key, b.key, c.key}.length, 3);
  });

  test('no OpenStreetMap or CARTO tiles anywhere in the app', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('cartocdn') || src.contains('tile.openstreetmap') ||
          src.contains('package:flutter_map/')) {
        hits.add(f.path);
      }
    }
    expect(hits, isEmpty);
  });
}

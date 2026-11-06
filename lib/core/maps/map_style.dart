/// The SaaradhiGo basemap for the Google Maps SDK: the website's style
/// (`apps/web/src/lib/mapStyle.ts`), from the same seven `map-*` tokens, dark
/// theme only (owner decision D2).
///
/// Seven colours and not one more. Anything Google would tint from its own
/// palette -- business pins, transit, parcel lines -- is turned off rather
/// than recoloured, so the route and the two journey markers are the only
/// saturated things on the map.
library;

import 'dart:convert';

import '../../ui/sg_tokens.dart';

/// `design-system/tokens.json`, dark values.
abstract final class MapTokens {
  static final ground = sgHex(SgColors.mapGround);
  static final street = sgHex(SgColors.mapStreet);
  static final arterial = sgHex(SgColors.mapArterial);
  static final highway = sgHex(SgColors.mapHighway);
  static final water = sgHex(SgColors.mapWater);
  static final park = sgHex(SgColors.mapPark);
  static final label = sgHex(SgColors.mapLabel);
}

List<Map<String, Object>> _rule(
  String? feature,
  String? element,
  Map<String, Object> styler,
) => [
  {
    if (feature != null) 'featureType': feature,
    if (element != null) 'elementType': element,
    'stylers': [styler],
  },
];

/// The style JSON `GoogleMap(style:)` takes.
final String kSgMapStyle = jsonEncode([
  ..._rule(null, 'geometry', {'color': MapTokens.ground}),
  ..._rule(null, 'labels.text.fill', {'color': MapTokens.label}),
  ..._rule(null, 'labels.text.stroke', {'color': MapTokens.ground}),
  ..._rule(null, 'labels.icon', {'visibility': 'off'}),
  ..._rule('road', 'geometry', {'color': MapTokens.street}),
  ..._rule('road.local', 'geometry', {'color': MapTokens.street}),
  ..._rule('road.arterial', 'geometry', {'color': MapTokens.arterial}),
  ..._rule('road.highway', 'geometry', {'color': MapTokens.highway}),
  ..._rule('road.highway.controlled_access', 'geometry', {
    'color': MapTokens.highway,
  }),
  ..._rule('water', 'geometry', {'color': MapTokens.water}),
  ..._rule('water', 'labels.text.fill', {'color': MapTokens.label}),
  ..._rule('poi.park', 'geometry', {'color': MapTokens.park}),
  ..._rule('landscape.natural', 'geometry', {'color': MapTokens.park}),
  ..._rule('poi', 'labels', {'visibility': 'off'}),
  ..._rule('poi.business', null, {'visibility': 'off'}),
  ..._rule('poi.park', 'labels', {'visibility': 'off'}),
  ..._rule('transit', null, {'visibility': 'off'}),
  ..._rule('administrative.land_parcel', null, {'visibility': 'off'}),
  ..._rule('administrative.neighborhood', 'labels', {'visibility': 'off'}),
  ..._rule('road', 'labels.icon', {'visibility': 'off'}),
]);

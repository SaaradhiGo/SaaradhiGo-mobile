import 'package:latlong2/latlong.dart';

import '../services/models/trip_model.dart';

String _normName(String address) => address
    .split(',')
    .first
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

/// The first [max] destinations with repeats of one place dropped: the same
/// normalised name, and either no coordinates to compare or under 10 km apart
/// (one mall's gates and geocoder drift read as two places otherwise).
List<Trip> distinctRecentTrips(Iterable<Trip> trips, {int max = 2}) {
  const dist = Distance();
  final out = <Trip>[];
  for (final t in trips) {
    final name = _normName(t.destinationAddress);
    if (name.isEmpty) continue;
    final dup = out.any((o) {
      if (_normName(o.destinationAddress) != name) return false;
      if (o.destinationLat == null || o.destinationLng == null ||
          t.destinationLat == null || t.destinationLng == null) {
        return true;
      }
      return dist(LatLng(o.destinationLat!, o.destinationLng!),
              LatLng(t.destinationLat!, t.destinationLng!)) < 10000;
    });
    if (!dup) out.add(t);
    if (out.length == max) break;
  }
  return out;
}

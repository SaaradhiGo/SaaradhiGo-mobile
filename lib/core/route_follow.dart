import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Pure helpers for following a drawn route without buying a new one per GPS
/// tick: measure how far the driver is from the line, gate re-fetches, and
/// trim the part already driven.
class RouteFollow {
  RouteFollow._();

  static const double offRouteMeters = 150;
  static const Duration minRefetchGap = Duration(seconds: 60);

  static const _earthR = 6371000.0;

  /// Nearest point on [line] to [p]: segment index and distance in meters.
  /// Per-segment equirectangular projection; accurate at city scale.
  static ({int segment, double meters, LatLng point})? nearest(
    LatLng p,
    List<LatLng> line,
  ) {
    if (line.isEmpty) return null;
    if (line.length == 1) {
      return (segment: 0, meters: _dist(p, line[0]), point: line[0]);
    }
    var best = (segment: 0, meters: double.infinity, point: line[0]);
    for (var i = 0; i < line.length - 1; i++) {
      final a = line[i], b = line[i + 1];
      final cosLat = math.cos(p.latitudeInRad);
      final ax = (a.longitude - p.longitude) * cosLat,
          ay = a.latitude - p.latitude;
      final bx = (b.longitude - p.longitude) * cosLat,
          by = b.latitude - p.latitude;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0
          ? 0.0
          : ((-ax * dx - ay * dy) / len2).clamp(0.0, 1.0).toDouble();
      final q = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final d = _dist(p, q);
      if (d < best.meters) best = (segment: i, meters: d, point: q);
    }
    return best;
  }

  static double _dist(LatLng a, LatLng b) {
    final dLat = (b.latitudeInRad - a.latitudeInRad);
    final dLng = (b.longitudeInRad - a.longitudeInRad);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitudeInRad) *
            math.cos(b.latitudeInRad) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthR * math.asin(math.min(1, math.sqrt(h)));
  }

  /// Distance in meters from [p] to [line]; infinity for an empty line.
  static double distanceToLine(LatLng p, List<LatLng> line) =>
      nearest(p, line)?.meters ?? double.infinity;

  /// Re-fetch only when far off the line AND the last fetch is old enough.
  /// An empty line counts as off-route (nothing drawn yet).
  static bool shouldRefetch({
    required LatLng driver,
    required List<LatLng> line,
    required DateTime? lastFetch,
    required DateTime now,
  }) {
    if (lastFetch != null && now.difference(lastFetch) < minRefetchGap) {
      return false;
    }
    return distanceToLine(driver, line) > offRouteMeters;
  }

  /// Drops the points behind the driver; the line then starts at the driver's
  /// projection on it. Returns [line] unchanged if empty.
  static List<LatLng> trim(LatLng driver, List<LatLng> line) {
    final n = nearest(driver, line);
    if (n == null || line.length < 2) return line;
    return [n.point, ...line.sublist(n.segment + 1)];
  }
}

/// "Fares from here, right now" on the home screen (Tier 2 spec, screen 3).
///
/// For up to two of the rider's own places (labelled saved places first, then
/// other saved places, then recent drops), the route and up to three classes'
/// fares through the SAME calls the booking flow uses: the maps directions
/// proxy, `/pricing/vehicle-types/` and `/ride/estimate-fare/` once per class.
/// Nothing is computed here; a fare is the server's `estimated_fare`.
///
/// Fetched only while the home is on screen and cached for five minutes.
library;

import 'package:latlong2/latlong.dart';

import '../core/vehicle_classes.dart';
import '../ui/choose_ride_sheet.dart' show RideOption;
import 'fare_service.dart';
import 'location_service.dart';
import 'models/location_model.dart';
import 'models/trip_model.dart';

/// A place the home quotes to.
class HomePlace {
  const HomePlace({required this.name, required this.to, this.address});

  /// What the card calls it: the label ("Home") or the first part of the
  /// address text.
  final String name;
  final String? address;
  final LatLng to;
}

/// One class's quote on a home card.
class HomeClassFare {
  const HomeClassFare({required this.type, required this.fareText});
  final String type;
  final String fareText;
}

class HomeQuote {
  const HomeQuote({
    required this.place,
    this.distanceKm,
    this.durationMin,
    this.fares = const [],
  });
  final HomePlace place;
  final double? distanceKm;
  final int? durationMin;
  final List<HomeClassFare> fares;

  /// False when the route or every class failed: the card says "Tap to see
  /// fares" and opens the normal flow.
  bool get ok => fares.isNotEmpty;
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

/// Up to [max] places: labelled saved places first, then other saved places,
/// then recent drops with coordinates. Each name once.
List<HomePlace> pickHomePlaces(
  List<FavoriteLocation> saved,
  List<Trip> recents, {
  int max = 2,
}) {
  final out = <HomePlace>[];
  final seen = <String>{};
  void add(String name, String? address, double? lat, double? lng) {
    if (out.length >= max || lat == null || lng == null) return;
    if (lat == 0 && lng == 0) return;
    final n = name.trim();
    if (n.isEmpty || !seen.add(n.toLowerCase())) return;
    out.add(HomePlace(name: n, address: address, to: LatLng(lat, lng)));
  }

  String first(String address) => address.split(',').first.trim();

  for (final f in saved.where((f) => f.label != null)) {
    final named = f.label == 'home' || f.label == 'work';
    add(
      named ? _titleCase(f.label!) : first(f.addressText),
      f.addressText,
      f.latitude,
      f.longitude,
    );
  }
  for (final f in saved.where((f) => f.label == null)) {
    add(first(f.addressText), f.addressText, f.latitude, f.longitude);
  }
  for (final t in recents) {
    add(
      first(t.destinationAddress),
      t.destinationAddress,
      t.destinationLat,
      t.destinationLng,
    );
  }
  return out;
}

class HomeFares {
  HomeFares({
    FareService? fares,
    LocationService? location,
    DateTime Function()? now,
  }) : _fares = fares ?? FareService(),
       _location = location ?? LocationService(),
       _now = now ?? DateTime.now;

  final FareService _fares;
  final LocationService _location;
  final DateTime Function() _now;

  static const ttl = Duration(minutes: 5);
  static const maxClasses = 3;

  /// Shared across home visits: coming back to home within five minutes
  /// costs no calls.
  static final Map<String, (DateTime, HomeQuote)> _cache = {};

  static String _key(LatLng from, LatLng to) =>
      '${from.latitude.toStringAsFixed(3)},${from.longitude.toStringAsFixed(3)}'
      '>${to.latitude.toStringAsFixed(4)},${to.longitude.toStringAsFixed(4)}';

  /// A cached quote still inside its five minutes, or null.
  HomeQuote? cached(LatLng from, HomePlace place) {
    final hit = _cache[_key(from, place.to)];
    if (hit == null || _now().difference(hit.$1) > ttl) return null;
    return hit.$2;
  }

  Future<HomeQuote> quote(LatLng from, HomePlace place) async {
    final hit = cached(from, place);
    if (hit != null) return hit;
    HomeQuote result = HomeQuote(place: place);
    try {
      final route = await _location.getDirections(
        origin: from,
        destination: place.to,
      );
      final km = (route?['distance_km'] as num?)?.toDouble();
      final min = (route?['duration_min'] as num?)?.toInt();
      if (km != null && min != null) {
        final types =
            await _fares.vehicleTypesAt(from.latitude, from.longitude) ??
            kFallbackVehicleTypes;
        final picked = types.take(maxClasses).toList();
        final estimates = await Future.wait([
          for (final t in picked)
            _fares.estimateFare(
              pickupLat: from.latitude,
              pickupLng: from.longitude,
              destinationLat: place.to.latitude,
              destinationLng: place.to.longitude,
              distanceKm: km,
              durationMin: min,
              vehicleType: t,
            ),
        ]);
        final fares = <HomeClassFare>[
          for (var i = 0; i < picked.length; i++)
            if (estimates[i] != null)
              if (RideOption.fromEstimate(picked[i], estimates[i]!)
                  case final o?)
                HomeClassFare(type: o.type, fareText: o.fareText),
        ];
        result = HomeQuote(
          place: place,
          distanceKm: km,
          durationMin: min,
          fares: fares,
        );
      }
    } catch (_) {
      // The card falls back to "Tap to see fares".
    }
    if (result.ok) _cache[_key(from, place.to)] = (_now(), result);
    return result;
  }

  /// Test seam.
  static void clearCache() => _cache.clear();
}

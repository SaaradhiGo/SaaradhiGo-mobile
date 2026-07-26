import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../core/app_config.dart';
import 'api_service.dart';
import 'models/location_model.dart';

/// Place search, geocoding and routing — all via our own backend.
///
/// This class used to call Google Places, Google Geocoding and the public
/// OSRM demo server straight from the device:
///
///   * the Maps API key shipped inside the app bundle (`assets/.env`),
///     which anyone who downloads the APK can extract and spend against
///     our billing account;
///   * on web the requests were relayed through `corsproxy.io`, a
///     third-party public proxy that saw every rider's search text and
///     home address;
///   * routing went to `router.project-osrm.org`, a community server with
///     no SLA that we do not control and which saw every origin/destination
///     pair.
///
/// Everything now goes through `/ride/maps/*`, which holds the key
/// server-side, rate-limits per user and caches responses (a repeated
/// place lookup costs us nothing).
class LocationService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    final response = await _api.authedRequest(
      (headers) => http.post(uri, headers: headers, body: json.encode(body)),
    );
    if (response == null) return null;
    if (response.statusCode != 200) {
      debugPrint('maps proxy $path failed: ${response.statusCode}');
      return null;
    }
    final decoded = json.decode(response.body);
    // Backend envelope: {status, data}. Older endpoints return bare JSON.
    final data = decoded is Map<String, dynamic>
        ? (decoded['data'] ?? decoded)
        : decoded;
    return data is Map<String, dynamic> ? data : null;
  }

  Future<List<PlaceSuggestion>> getPlaceAutocomplete(
    String query,
    String sessionToken,
  ) async {
    if (query.length < 3) return [];

    try {
      final data = await _post(AppConfig.mapsAutocomplete, {
        'input': query,
        'session_token': sessionToken,
      });
      if (data != null && data['status'] == 'OK') {
        final List predictions = data['predictions'] ?? const [];
        return predictions.map((p) => PlaceSuggestion.fromJson(p)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching autocomplete: $e');
    }
    return [];
  }

  Future<PlaceDetails?> getPlaceDetails(
    String placeId,
    String sessionToken,
  ) async {
    if (placeId == 'current') return null;

    try {
      final data = await _post(AppConfig.mapsPlaceDetails, {
        'place_id': placeId,
        'session_token': sessionToken,
      });
      if (data != null && data['status'] == 'OK') {
        return PlaceDetails.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching place details: $e');
    }

    // "lat,lng" pseudo-ids come from map-pin selections, not from Places.
    if (placeId.contains(',')) {
      final parts = placeId.split(',');
      if (parts.length == 2) {
        return PlaceDetails(
          placeId: placeId,
          name: 'Selected Location',
          formattedAddress: '',
          latitude: double.tryParse(parts[0]) ?? 0.0,
          longitude: double.tryParse(parts[1]) ?? 0.0,
        );
      }
    }
    return null;
  }

  Future<String?> getAddressFromCoordinates(double lat, double lon) async {
    try {
      final data = await _post(AppConfig.mapsReverseGeocode, {
        'lat': lat,
        'lng': lon,
      });
      if (data != null &&
          data['status'] == 'OK' &&
          (data['results'] as List).isNotEmpty) {
        final firstResult = data['results'][0];
        final String address = firstResult['formatted_address'];
        final addressComponents = firstResult['address_components'] as List;

        String? route;
        String? sublocality;
        String? locality;

        for (var component in addressComponents) {
          final types = component['types'] as List;
          if (types.contains('route')) route = component['long_name'];
          if (types.contains('sublocality')) {
            sublocality = component['long_name'];
          }
          if (types.contains('locality')) locality = component['long_name'];
        }

        final List<String> parts = [];
        if (route != null) {
          parts.add(route);
        } else if (sublocality != null) {
          parts.add(sublocality);
        }
        if (locality != null) parts.add(locality);

        if (parts.isNotEmpty) return parts.join(', ');
        return address;
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
    return null;
  }

  /// Route between two points, via our Directions proxy.
  ///
  /// Returns the same shape the OSRM version returned so callers are
  /// unchanged: distance/duration strings, a bounds box and decoded
  /// polyline points.
  Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final data = await _post(AppConfig.mapsDirections, {
        'origin_lat': origin.latitude,
        'origin_lng': origin.longitude,
        'dest_lat': destination.latitude,
        'dest_lng': destination.longitude,
      });

      if (data == null) return null;
      final routes = data['routes'] as List?;
      if (data['status'] != 'OK' || routes == null || routes.isEmpty) {
        return null;
      }

      final route = routes.first;
      final leg = (route['legs'] as List).first;

      final List<PointLatLng> decoded = PolylinePoints.decodePolyline(
        route['overview_polyline']['points'],
      );
      final List<LatLng> polylineCoordinates = decoded
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      // Google returns human-readable text plus raw values; prefer the
      // raw values so formatting stays consistent with the fare screen.
      final num distanceMeters = leg['distance']?['value'] ?? 0;
      final num durationSeconds = leg['duration']?['value'] ?? 0;
      final int minutes = (durationSeconds / 60).round();
      final double km = distanceMeters / 1000;

      // Google gives us the viewport directly; fall back to computing it
      // from the polyline if a response ever omits it.
      Map<String, dynamic> bounds;
      final vp = route['bounds'];
      if (vp != null && vp['southwest'] != null && vp['northeast'] != null) {
        bounds = {
          'southwest': {
            'lat': vp['southwest']['lat'],
            'lng': vp['southwest']['lng'],
          },
          'northeast': {
            'lat': vp['northeast']['lat'],
            'lng': vp['northeast']['lng'],
          },
        };
      } else {
        double minLat = origin.latitude, maxLat = origin.latitude;
        double minLng = origin.longitude, maxLng = origin.longitude;
        for (var p in polylineCoordinates) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLng) minLng = p.longitude;
          if (p.longitude > maxLng) maxLng = p.longitude;
        }
        bounds = {
          'southwest': {'lat': minLat, 'lng': minLng},
          'northeast': {'lat': maxLat, 'lng': maxLng},
        };
      }

      return {
        'distance': '${km.toStringAsFixed(1)} km',
        'duration': '$minutes mins',
        'distance_km': km,
        'duration_min': minutes,
        'bounds': bounds,
        'polylineCoordinates': polylineCoordinates,
      };
    } catch (e) {
      debugPrint('Error fetching directions: $e');
    }
    return null;
  }
}

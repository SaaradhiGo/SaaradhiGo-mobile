import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';
import 'api_service.dart';
import 'models/location_model.dart';

/// GET /rider/places/: the rider's places and how many of each label fit.
class SavedPlaces {
  const SavedPlaces({required this.places, required this.limits});
  final List<FavoriteLocation> places;

  /// `{home: 1, work: 1, other: 10}` as the server sends it.
  final Map<String, int> limits;

  FavoriteLocation? byLabel(String label) =>
      places.where((p) => p.label == label).firstOrNull;
  List<FavoriteLocation> get others =>
      places.where((p) => p.label != 'home' && p.label != 'work').toList();
}

/// A refused or failed places call. [code] is the server's error code
/// (PLACE_LIMIT, VALIDATION_ERROR, ...) or NETWORK when nothing came back.
class PlaceError implements Exception {
  const PlaceError(this.code, {this.status = 0, this.field, this.message});
  final String code;
  final int status;
  final String? field;
  final String? message;

  @override
  String toString() => 'PlaceError($code, $status, $field)';
}

class FavoriteLocationService {
  FavoriteLocationService({ApiService? api}) : _apiOverride = api;
  final ApiService? _apiOverride;
  ApiService get _api => _apiOverride ?? ApiService();

  static Uri _places([int? id]) => Uri.parse(
    '${AppConfig.baseUrl}/rider/places/${id == null ? '' : '$id/'}',
  );

  static Object? _decode(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  static PlaceError _errorFrom(http.Response? r) {
    if (r == null) return const PlaceError('NETWORK');
    final body = _decode(r.body);
    final err = body is Map ? body['error'] : null;
    if (err is Map) {
      final details = err['details'];
      return PlaceError(
        err['code']?.toString() ?? 'HTTP_${r.statusCode}',
        status: r.statusCode,
        field: details is Map ? details['field']?.toString() : null,
        message: err['message']?.toString(),
      );
    }
    return PlaceError('HTTP_${r.statusCode}', status: r.statusCode);
  }

  static FavoriteLocation _placeFrom(http.Response r) {
    final body = _decode(r.body);
    final data = body is Map ? body['data'] : null;
    final place = data is Map ? data['place'] : null;
    if (place is! Map) throw _errorFrom(r);
    return FavoriteLocation.fromJson(Map<String, dynamic>.from(place));
  }

  /// GET /rider/places/. Null when this server does not have it yet (404),
  /// so callers can fall back to /rider/locations/all/. Throws [PlaceError].
  Future<SavedPlaces?> fetchPlaces() async {
    final r = await _api.authedRequest((h) => http.get(_places(), headers: h));
    if (r != null && r.statusCode == 404) return null;
    if (r == null || r.statusCode != 200) throw _errorFrom(r);
    final body = _decode(r.body);
    final data = body is Map ? body['data'] : null;
    if (data is! Map || data['places'] is! List) throw _errorFrom(r);
    final limits = <String, int>{};
    final rawLimits = data['limits'];
    if (rawLimits is Map) {
      rawLimits.forEach((k, v) {
        final n = v is int ? v : int.tryParse('$v');
        if (n != null) limits['$k'] = n;
      });
    }
    return SavedPlaces(
      places: [
        for (final p in data['places'] as List)
          if (p is Map) FavoriteLocation.fromJson(Map<String, dynamic>.from(p)),
      ],
      limits: limits,
    );
  }

  /// POST `/rider/places/`. Throws [PlaceError] (PLACE_LIMIT is a 409).
  Future<FavoriteLocation> createPlace({
    required String label,
    required String addressText,
    required double latitude,
    required double longitude,
    String name = '',
  }) async {
    final r = await _api.authedRequest(
      (h) => http.post(
        _places(),
        headers: h,
        body: json.encode({
          'label': label,
          if (label == 'other') 'name': name,
          'address_text': addressText,
          'latitude': latitude.toStringAsFixed(6),
          'longitude': longitude.toStringAsFixed(6),
        }),
      ),
    );
    if (r == null || (r.statusCode != 201 && r.statusCode != 200)) {
      throw _errorFrom(r);
    }
    return _placeFrom(r);
  }

  /// PATCH `/rider/places/<id>/` with only the fields given.
  Future<FavoriteLocation> updatePlace(
    int id, {
    String? label,
    String? name,
    String? addressText,
    double? latitude,
    double? longitude,
  }) async {
    final r = await _api.authedRequest(
      (h) => http.patch(
        _places(id),
        headers: h,
        body: json.encode({
          'label': ?label,
          'name': ?name,
          'address_text': ?addressText,
          if (latitude != null) 'latitude': latitude.toStringAsFixed(6),
          if (longitude != null) 'longitude': longitude.toStringAsFixed(6),
        }),
      ),
    );
    if (r == null || r.statusCode != 200) throw _errorFrom(r);
    return _placeFrom(r);
  }

  /// DELETE `/rider/places/<id>/`.
  Future<void> deletePlace(int id) async {
    final r = await _api.authedRequest(
      (h) => http.delete(_places(id), headers: h),
    );
    if (r == null || (r.statusCode != 204 && r.statusCode != 200)) {
      throw _errorFrom(r);
    }
  }

  /// Saved places for Home: GET /rider/places/, else the older
  /// /rider/locations/all/ on a server that does not have it yet. Throws
  /// [PlaceError] when /rider/places/ fails.
  Future<List<FavoriteLocation>> fetchFavoriteLocations() async {
    final places = await fetchPlaces();
    if (places != null) return places.places;
    return _fetchLegacy();
  }

  /// A stored access token that has expired is refreshed once and the call
  /// retried; it used to come back empty on a cold start.
  Future<List<FavoriteLocation>> _fetchLegacy({bool retried = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final url = Uri.parse('${AppConfig.baseUrl}/rider/locations/all/');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'SaaradhiGo/1.0',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 401 && !retried) {
        final fresh = await ApiService().refreshAccessToken();
        if (fresh != null) return await _fetchLegacy(retried: true);
      }
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List locations = data['data'];
          return locations
              .map((json) => FavoriteLocation.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching favorite locations: $e');
    }
    return [];
  }

  Future<bool> saveFavoriteLocation(
    String address,
    double lat,
    double lng,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final url = Uri.parse('${AppConfig.baseUrl}/rider/locations/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'SaaradhiGo/1.0',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'address_text': address,
          'latitude': lat.toString(),
          'longitude': lng.toString(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('Error saving favorite location: $e');
    }
    return false;
  }

  Future<bool> deleteFavoriteLocation(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final url = Uri.parse('${AppConfig.baseUrl}/rider/locations/$id/delete/');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'SaaradhiGo/1.0',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting favorite location: $e');
    }
    return false;
  }
}

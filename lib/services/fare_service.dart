import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';
import '../core/market/booking_refusal.dart';
import 'package:latlong2/latlong.dart';

const kOutOfServiceArea = 'OUT_OF_SERVICE_AREA';

/// The area named in the server's outside-area message, or null.
String? outsideAreaName(String? message) {
  final m = RegExp(r'\(([^()]+)\)\.?\s*$').firstMatch(message ?? '');
  return m?.group(1)?.trim();
}

class FareService {
  /// The classes priced at [lat],[lng], or null when the API cannot say.
  /// An empty list is a real answer: nothing is priced there.
  Future<List<String>?> vehicleTypesAt(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/pricing/vehicle-types/?lat=$lat&lng=$lng',
        ),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) return null;
      final body = json.decode(response.body);
      final data = body is Map ? body['data'] : null;
      final types = data is Map ? data['vehicle_types'] : null;
      if (types is! List) return null;
      return [
        for (final t in types)
          if (t is Map && (t['type']?.toString() ?? '').isNotEmpty)
            t['type'].toString(),
      ];
    } catch (e) {
      debugPrint('Error loading vehicle types: $e');
      return null;
    }
  }

  /// `GET /ride/booking-options/`: how the rider can pay at this pickup and
  /// the default. Null when the call fails (the caller then offers cash only).
  Future<Map<String, dynamic>?> bookingOptions(double lat, double lng) async {
    try {
      final token = (await SharedPreferences.getInstance()).getString(
        'access_token',
      );
      if (token == null) return null;
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.baseUrl}/ride/booking-options/?lat=$lat&lng=$lng',
            ),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = json.decode(response.body);
      final data = body is Map ? (body['data'] ?? body) : null;
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      debugPrint('Error loading booking options: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> estimateFare({
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    required double distanceKm,
    required int durationMin,
    required String vehicleType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final url = Uri.parse('${AppConfig.baseUrl}/ride/estimate-fare/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'SaaradhiGo/1.0',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'pickup_lat': pickupLat,
          'pickup_long': pickupLng,
          'destination_lat': destinationLat,
          'destination_long': destinationLng,
          'distance_km': distanceKm,
          'duration_min': durationMin,
          'vehicle_type': vehicleType,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          lastOutsideArea = null;
          return data['data'];
        }
      } else {
        // CITY_PAUSED / CITY_NOT_LIVE: tell the rider plainly, not a silent empty list.
        _reportRefusal(response.body, LatLng(pickupLat, pickupLng));
      }
    } catch (e) {
      debugPrint('Error estimating fare: $e');
    }
    return null;
  }

  /// The server's words for the last pickup or drop outside every zone, e.g.
  /// "This place is outside our service area (Treasure Valley)." Null after
  /// any other answer. Round 3: this used to read "check your connection".
  String? lastOutsideArea;

  void _reportRefusal(String body, LatLng pickup) {
    try {
      final decoded = json.decode(body);
      final error = decoded is Map ? decoded['error'] : null;
      final code = error is Map ? error['code']?.toString() : null;
      if (code == kOutOfServiceArea) {
        lastOutsideArea = (error as Map)['message']?.toString() ?? '';
      }
      if (isBookingRefusalCode(code)) {
        BookingRefusalState.instance.report(code!, pickup: pickup);
      }
    } catch (_) {
      // Not our envelope: leave it to the existing no-estimate handling.
    }
  }
}

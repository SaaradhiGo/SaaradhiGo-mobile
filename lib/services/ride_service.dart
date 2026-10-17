import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'models/trip_model.dart';
import '../core/app_config.dart';
import '../utils/log_redaction.dart';

class RideService {
  /// `client` exists so tests can drive this class's own parsing and request
  /// bodies instead of re-describing them. Passing nothing behaves exactly
  /// as before.
  RideService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  WebSocketChannel? _rideRequestChannel;
  WebSocketChannel? _tripChannel;

  Stream<dynamic>? get rideUpdates => _rideRequestChannel?.stream;
  Stream<dynamic>? get tripUpdates => _tripChannel?.stream;

  Future<List<Trip>> fetchRideHistory(String token) async {
    String url = '${AppConfig.baseUrl}${AppConfig.rideHistory}';

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        // Handle both wrapped and unwrapped paginated responses
        List<dynamic>? results;
        if (data is Map<String, dynamic>) {
          if (data['results'] != null) {
            results = data['results'];
          } else if (data['status'] == 'success' &&
              data['data'] != null &&
              data['data']['results'] != null) {
            results = data['data']['results'];
          }
        }

        if (results != null) {
          return results.map((json) => Trip.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Fetch Ride History error: $e');
      return [];
    }
  }

  Future<void> requestRide({
    required String token,
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    required double distanceKm,
    required int durationMin,
    required String vehicleType,
    required String pickupAddress,
    required String destinationAddress,
    required String paymentMethod,
  }) async {
    final wsUrl = '${AppConfig.rideRequestWs}?token=$token';

    try {
      debugPrint('Connecting to Ride Request WebSocket...');
      // Close existing connection if any
      _rideRequestChannel?.sink.close();
      _rideRequestChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      final requestPayload = {
        'type': 'ride_request',
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'destination_lat': destinationLat,
        'destination_lng': destinationLng,
        'pickup_address': pickupAddress,
        'destination_address': destinationAddress,
        'distance_km': distanceKm,
        'duration_min': durationMin,
        'vehicle_type': vehicleType,
        'payment_method': paymentMethod,
      };

      _rideRequestChannel!.sink.add(jsonEncode(requestPayload));
      debugPrint('Ride request sent');
    } catch (e) {
      debugPrint('Ride Request WebSocket error: $e');
      rethrow;
    }
  }

  Future<void> connectToTrip(String token, int tripId) async {
    final wsUrl = '${AppConfig.tripWs(tripId)}?token=$token';

    try {
      debugPrint('Connecting to Trip WebSocket: $tripId');
      // Close existing connection if any
      _tripChannel?.sink.close();
      _tripChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    } catch (e) {
      debugPrint('Trip WebSocket error: $e');
      rethrow;
    }
  }

  void closeConnection() {
    _rideRequestChannel?.sink.close();
    _tripChannel?.sink.close();
    _rideRequestChannel = null;
    _tripChannel = null;
    debugPrint('All WebSocket connections closed');
  }

  Future<Map<String, dynamic>?> createTripPaymentOrder(
    String token,
    int tripId,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/payments/create-order/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'trip_id': tripId}),
      );
      // NOT the raw body. This response carries the Cashfree
      // `payment_session_id` -- the credential the checkout SDK opens a
      // payment with -- and logging it in full puts a payment session into
      // logcat.
      debugPrint(
        'Create order: ${response.statusCode} '
        '${redactedBody(response.body)}',
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      try {
        final errorData = jsonDecode(response.body);
        debugPrint(
          'Create Trip Payment Order API Error: ${response.statusCode} - $errorData',
        );
        return errorData; // Return error data so UI can show message
      } catch (_) {
        debugPrint(
          'Create Trip Payment Order Error: ${response.statusCode} - ${redactedBody(response.body)}',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Create Trip Payment Order error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifyTripPayment(
    String token,
    String orderId,
    String paymentId,
    String signature,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/payments/verify/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'gateway_order_id': orderId,
          'gateway_payment_id': paymentId,
          'gateway_signature': signature,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Verify Trip Payment error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTripStatus(
    String token,
    String tripId,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse('${AppConfig.baseUrl}/ride/trip/$tripId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get Trip Status error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTripDetails(
    String token,
    String tripId,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse('${AppConfig.baseUrl}/ride/trip/$tripId/details/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Get Trip Details error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchActiveTrip(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.activeRide}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        // No active trip - this is expected
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to fetch active trip: $e');
      return null;
    }
  }

  /// Checks if there's an active ride for the user
  /// Returns true if there's an active ride, false otherwise
  Future<bool> checkActiveRide(String token) async {
    try {
      final activeTrip = await fetchActiveTrip(token);
      return activeTrip != null &&
          activeTrip['status'] == 'success' &&
          activeTrip['data'] != null;
    } catch (e) {
      debugPrint('Check Active Ride error: $e');
      return false;
    }
  }

  /// The reasons `POST /ride/trip/<id>/cancel/` accepts for a RIDER.
  ///
  /// Deliberately not shared with the driver endpoint's set: they differ, and
  /// sending one app's vocabulary to the other's endpoint is a 400.
  static const riderCancelReasons = <String>{
    'no_show',
    'wrong_location',
    'too_long',
    'safety',
    'other',
  };

  static String _validCancelReason(String? reason) {
    final candidate = reason?.trim() ?? '';
    return riderCancelReasons.contains(candidate) ? candidate : 'other';
  }

  Future<bool> cancelTrip(
    String token,
    String tripId, {
    String? reason,
    String? note,
  }) async {
    final url = '${AppConfig.baseUrl}/ride/trip/$tripId/cancel/';
    try {
      // `reason` is REQUIRED by the server, which validates it against
      // {no_show, wrong_location, too_long, safety, other} and answers
      // INVALID_REASON 400 for anything else -- including an absent field.
      //
      // Every caller in this app invokes `cancelTrip(token, tripId)` with no
      // reason, so the body was `{}` and every rider cancellation was
      // refused. The failure was caught and debugPrinted while the app went
      // on to clear its local state, so the rider was shown "cancelled"
      // while the trip stayed live on the server and a driver could still be
      // dispatched to them.
      //
      // 'other' is the honest default for a rider cancelling a search with
      // no reason UI. Note the rider vocabulary is NOT the driver's: the
      // driver endpoint accepts `vehicle_issue` and `personal`, which this
      // one rejects.
      final Map<String, dynamic> requestBody = {
        'reason': _validCancelReason(reason),
      };
      if (note != null) {
        requestBody['note'] = note;
      }

      final response = await _client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      debugPrint(
        'Cancel Trip failed: ${response.statusCode} '
        '${redactedBody(response.body)}',
      );
      return false;
    } catch (e) {
      debugPrint('Cancel Trip error: $e');
      return false;
    }
  }
}

import 'dart:async';
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

  /// How long to wait for a cancellation to be confirmed.
  ///
  /// Short on purpose: an unconfirmed cancellation leaves the ride on
  /// screen, so the rider needs to be told quickly rather than held.
  static const cancelTimeout = Duration(seconds: 12);

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

      // Bounded, because the caller now treats an unconfirmed cancellation
      // as "the trip is still live" and keeps the ride on screen. Without a
      // timeout a dead connection would leave the rider staring at a
      // spinner instead of being told to retry.
      final response = await _client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(cancelTimeout);
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

  /// How long to wait for `POST /payments/switch/` to answer.
  ///
  /// Bounded for the same reason cancellation is: an unanswered switch is
  /// NOT a cash payment, and the rider has to be told rather than held on a
  /// spinner while the fare is owed.
  static const cashSwitchTimeout = Duration(seconds: 12);

  /// How long to wait for the verification read that follows an unanswered
  /// switch. Shorter: it is a single indexed read, and it runs when the
  /// connection has already proven slow.
  static const cashVerifyTimeout = Duration(seconds: 8);

  /// What the server says about a trip after the rider chose cash.
  ///
  /// `awaitingCollection` is deliberately not called "paid". Choosing cash
  /// settles nothing: the server writes a `pending` cash payment and the
  /// DRIVER confirms collection afterwards. Anything in this app that
  /// treats selection as settlement is wrong.
  Future<CashSwitchOutcome> selectCashPayment(
    String token,
    String tripId, {
    int maxAttempts = 2,
  }) async {
    CashSwitchOutcome outcome = await _postCashSwitch(token, tripId);

    for (var attempt = 1; attempt < maxAttempts; attempt++) {
      if (outcome.status != CashSwitchStatus.unconfirmed) return outcome;

      // NEVER retry a switch blindly. `POST /payments/switch/` is not
      // idempotent: each accepted call marks the current payment row failed
      // and creates a replacement, so a blind retry after a timeout that had
      // in fact succeeded leaves two payment rows and a trip whose real
      // state nobody can read off the screen.
      //
      // So a retry is allowed ONLY after a read has proven the first attempt
      // did not land. If the read says it did land, that answer is returned
      // as-is and no second POST is ever sent.
      final verified = await verifyCashSelection(token, tripId);
      if (verified.status != CashSwitchStatus.unconfirmed) return verified;

      outcome = await _postCashSwitch(token, tripId);
    }

    if (outcome.status != CashSwitchStatus.unconfirmed) return outcome;

    // The last attempt was also unanswered. One final read, so that a
    // response lost on the way back is not reported to the rider as a
    // failure when the server actually did switch the trip.
    return verifyCashSelection(token, tripId);
  }

  Future<CashSwitchOutcome> _postCashSwitch(String token, String tripId) async {
    final parsedTripId = int.tryParse(tripId.trim());
    if (parsedTripId == null) {
      return const CashSwitchOutcome(
        status: CashSwitchStatus.refused,
        code: 'INVALID_TRIP_ID',
        message: 'This trip cannot be paid in cash. Please contact support.',
      );
    }

    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}/payments/switch/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            // The server requires an integer trip_id and one of
            // cash/upi/wallet/online, and answers MISSING_FIELDS or
            // INVALID_METHOD otherwise.
            body: jsonEncode({
              'trip_id': parsedTripId,
              'new_method': 'cash',
            }),
          )
          .timeout(cashSwitchTimeout);

      return _readSwitchResponse(response);
    } catch (e) {
      // A timeout, a dropped connection, a malformed response: all mean the
      // same thing here, which is that we do not know what the server did.
      debugPrint('Switch to cash: unconfirmed ($e)');
      return const CashSwitchOutcome(status: CashSwitchStatus.unconfirmed);
    }
  }

  CashSwitchOutcome _readSwitchResponse(http.Response response) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }

    final payload = _unwrap(body);
    final error = body?['error'];
    final code = (error is Map ? error['code'] : null)?.toString();
    final message = (error is Map ? error['message'] : null)?.toString();

    if (response.statusCode == 200 || response.statusCode == 201) {
      final paymentStatus = payload?['status']?.toString();
      final paymentId = payload?['payment_id'];

      // A 200 whose body we cannot read is not a confirmation. Saying
      // "unconfirmed" sends the caller to the verification read, which
      // answers the question properly.
      if (paymentStatus == null) {
        debugPrint('Switch to cash: 200 with no payment status');
        return const CashSwitchOutcome(status: CashSwitchStatus.unconfirmed);
      }

      // The server writes `pending` for cash. `completed` would mean the
      // money is already in -- not something this call can cause, but if it
      // ever says so, believe it rather than asking for cash twice.
      if (paymentStatus == 'completed') {
        return const CashSwitchOutcome(status: CashSwitchStatus.alreadyPaid);
      }

      return CashSwitchOutcome(
        status: CashSwitchStatus.awaitingCollection,
        paymentId: paymentId is int ? paymentId : int.tryParse('$paymentId'),
      );
    }

    // 409 ALREADY_PAID: the rider completed the online checkout just before
    // tapping cash, and the gateway has confirmed it. The trip is paid; it
    // must not be collected in cash as well.
    if (response.statusCode == 409 || code == 'ALREADY_PAID') {
      return CashSwitchOutcome(
        status: CashSwitchStatus.alreadyPaid,
        code: code,
        message: message,
      );
    }

    // A server fault is not a refusal -- the trip may or may not have been
    // switched -- so it is treated as unknown, not as "no".
    if (response.statusCode >= 500) {
      debugPrint('Switch to cash: server fault ${response.statusCode}');
      return const CashSwitchOutcome(status: CashSwitchStatus.unconfirmed);
    }

    debugPrint(
      'Switch to cash refused: ${response.statusCode} '
      '${redactedBody(response.body)}',
    );
    return CashSwitchOutcome(
      status: CashSwitchStatus.refused,
      code: code,
      message: message,
    );
  }

  /// Read the trip back and decide what actually happened.
  ///
  /// This is what makes an unanswered switch safe: the server's own view of
  /// `payment_method` and `payment_status` is the only thing that settles
  /// whether the rider owes cash, has already paid, or is still where they
  /// started.
  Future<CashSwitchOutcome> verifyCashSelection(
    String token,
    String tripId,
  ) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/ride/trip/$tripId/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(cashVerifyTimeout);

      if (response.statusCode != 200) {
        debugPrint('Verify cash selection: HTTP ${response.statusCode}');
        return const CashSwitchOutcome(status: CashSwitchStatus.unconfirmed);
      }

      final decoded = jsonDecode(response.body);
      final trip = _unwrap(decoded is Map<String, dynamic> ? decoded : null);
      if (trip == null) {
        return const CashSwitchOutcome(status: CashSwitchStatus.unconfirmed);
      }

      final paymentStatus = trip['payment_status']?.toString();
      final paymentMethod = trip['payment_method']?.toString();

      // Settled beats selected: if the trip is paid, nobody should be asked
      // for cash, whichever method got it there.
      if (paymentStatus == 'completed' || paymentStatus == 'paid') {
        return const CashSwitchOutcome(status: CashSwitchStatus.alreadyPaid);
      }

      if (paymentMethod == 'cash') {
        return const CashSwitchOutcome(
          status: CashSwitchStatus.awaitingCollection,
        );
      }

      // The trip is not on cash and is not paid, so the switch did not land.
      return const CashSwitchOutcome(status: CashSwitchStatus.unconfirmed);
    } catch (e) {
      debugPrint('Verify cash selection error: $e');
      return const CashSwitchOutcome(status: CashSwitchStatus.unconfirmed);
    }
  }

  /// Both `{...}` and `{status: success, data: {...}}` come back from this
  /// API depending on the view, so neither shape is assumed.
  static Map<String, dynamic>? _unwrap(Map<String, dynamic>? body) {
    if (body == null) return null;
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }
}

/// What the server did about the rider's choice of cash.
enum CashSwitchStatus {
  /// A pending cash payment exists. The rider now owes the driver cash, and
  /// the DRIVER confirms collection. This is not "paid".
  awaitingCollection,

  /// The trip is already settled -- typically the online payment the rider
  /// was trying to move away from went through. Do not collect cash.
  alreadyPaid,

  /// The server refused and the trip is unchanged: wrong state, not the
  /// rider's trip, no payment row. Retrying as-is will be refused again.
  refused,

  /// Unknown. Nothing may be claimed about this trip's payment, and the
  /// rider must not be shown a success screen.
  unconfirmed,
}

class CashSwitchOutcome {
  const CashSwitchOutcome({
    required this.status,
    this.code,
    this.message,
    this.paymentId,
  });

  final CashSwitchStatus status;
  final String? code;
  final String? message;
  final int? paymentId;

  /// True only when the server has placed the trip in a state the rider can
  /// act on. Never true for [CashSwitchStatus.unconfirmed].
  bool get isSettledOrOwed =>
      status == CashSwitchStatus.awaitingCollection ||
      status == CashSwitchStatus.alreadyPaid;
}

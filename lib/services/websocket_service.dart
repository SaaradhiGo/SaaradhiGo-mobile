import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/app_config.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

class WebSocketService {
  WebSocketChannel? _rideChannel;
  WebSocketChannel? _tripChannel;
  StreamSubscription? _rideSubscription;
  StreamSubscription? _tripSubscription;

  final _rideEventController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _rideEventController.stream;

  Map<String, dynamic>? _lastRideRequestPayload;

  Timer? _rideReconnectTimer;
  Timer? _tripReconnectTimer;
  bool _isIntentionalDisconnect = false;
  bool _tripActive = false;

  // Connection tracking
  String? _activeTripWsUrl;
  bool _isConnectingTrip = false;
  int _tripReconnectAttempts = 0;

  /// The ride-request frame the booking socket sends. `promo_code` is present
  /// only when the rider applied a code, so a booking without one is the frame
  /// the app has always sent.
  @visibleForTesting
  static Map<String, dynamic> buildRideRequestPayload({
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
    String? promoCode,
    String? clientRequestId,
    String? quoteId,
  }) => {
    'action': 'request',
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
    if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
    if (clientRequestId != null) 'client_request_id': clientRequestId,
    // The quote shown on the ticket: the server books at exactly its fare,
    // or refuses with QUOTE_EXPIRED and a fresh one (quote_lock.dart).
    if (quoteId != null && quoteId.isNotEmpty) 'quote_id': quoteId,
  };

  /// Frames after which the booking must not be sent again on a reconnect:
  /// the server has answered it. Resending a request the server already
  /// cancelled (nobody accepted) would book a ride the rider gave up on.
  static const _answeredTypes = {
    'trip_created',
    'error',
    'dispatch_failed',
    'current_trip',
  };

  void requestRide({
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
    String? promoCode,
    String? quoteId,
  }) {
    debugPrint("WebSocketService: requestRide invoked.");
    _isIntentionalDisconnect = false;
    _tripActive = false;
    final wsUrl = '${AppConfig.rideRequestWs}?token=$token';

    // Every booking attempt is a new request with its own idempotency key.
    // This used to skip the request when a channel from an earlier booking
    // was still open, so a second "Request ride" (after a cancel or a failed
    // search) silently sent nothing and the rider watched "Finding your
    // ride" forever (PRODUCT_AUDIT §2). The key makes a reconnect resend of
    // THIS request safe: the server answers it with the trip it already made.
    _lastRideRequestPayload = buildRideRequestPayload(
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      distanceKm: distanceKm,
      durationMin: durationMin,
      vehicleType: vehicleType,
      pickupAddress: pickupAddress,
      destinationAddress: destinationAddress,
      paymentMethod: paymentMethod,
      promoCode: promoCode,
      clientRequestId: const Uuid().v4(),
      quoteId: quoteId,
    );

    debugPrint("WebSocketService: Payload prepared. Connecting to ride WS.");
    _connectRideChannel(wsUrl);
  }

  void connectToTrip(String token, int tripId) {
    _isIntentionalDisconnect = false;
    _tripActive = true;
    final wsUrl = '${AppConfig.tripWs(tripId)}?token=$token';

    // Prevent redundant connection attempts to the SAME URL
    // Also check if we are ALREADY scheduled to reconnect to this URL
    if (_activeTripWsUrl == wsUrl) {
      if (_tripChannel != null || _isConnectingTrip) {
        debugPrint(
          "WebSocketService: Already connected or connecting to trip WS: $tripId",
        );
        return;
      }
      if (_tripReconnectTimer != null && _tripReconnectTimer!.isActive) {
        debugPrint(
          "WebSocketService: Reconnection already scheduled for trip WS: $tripId. Respecting backoff.",
        );
        return;
      }
    }

    debugPrint(
      "WebSocketService: connectToTrip invoked for trip: $tripId. URL: $wsUrl",
    );

    // Close the ride request channel since we have a trip now
    _rideReconnectTimer?.cancel();
    _tripReconnectTimer?.cancel(); // Cancel any pending trip logic/reconnects
    _rideSubscription?.cancel();
    _rideSubscription = null;
    _rideChannel?.sink.close();
    _rideChannel = null;
    _lastRideRequestPayload = null;

    _connectTripChannel(wsUrl);
  }

  void _connectRideChannel(String wsUrl) {
    debugPrint("WebSocketService: _connectRideChannel executing...");
    try {
      // Drop the old channel's listener first, so its onDone cannot schedule
      // a reconnect that races this one.
      _rideReconnectTimer?.cancel();
      _rideSubscription?.cancel();
      _rideSubscription = null;
      _rideChannel?.sink.close();
      _rideChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      debugPrint("WebSocketService: WebSocketChannel initialized.");

      _rideSubscription = _rideChannel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> decoded = jsonDecode(data);
            if (_answeredTypes.contains(decoded['type'])) {
              _lastRideRequestPayload = null;
            }
            _rideEventController.add(decoded);
          } catch (e) {
            debugPrint("Error parsing ride WS data: $e");
          }
        },
        onDone: () {
          debugPrint("Ride request WS closed");
          _scheduleRideReconnect(wsUrl);
        },
        onError: (err) {
          debugPrint("Ride request WS error: $err");
          _scheduleRideReconnect(wsUrl);
        },
      );

      _rideChannel!.ready
          .then((_) {
            debugPrint("Ride WS Ready, sending payload");
            if (_lastRideRequestPayload != null) {
              _rideChannel!.sink.add(jsonEncode(_lastRideRequestPayload));
            }
          })
          .catchError((error) {
            debugPrint("Ride WS failed to be ready: $error");
          });
    } catch (e) {
      debugPrint("Ride request WS connect error: $e");
      _scheduleRideReconnect(wsUrl);
    }
  }

  /// Stops a booking that has not been answered: the rider gave up waiting
  /// for the server to acknowledge it. Nothing is resent after this.
  void abandonRideRequest() {
    _lastRideRequestPayload = null;
    _rideReconnectTimer?.cancel();
    _rideSubscription?.cancel();
    _rideSubscription = null;
    _rideChannel?.sink.close();
    _rideChannel = null;
  }

  void _scheduleRideReconnect(String wsUrl) {
    if (_isIntentionalDisconnect || _tripActive) return;
    _rideReconnectTimer?.cancel();
    _rideReconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint("Reconnecting Ride request WS...");
      _connectRideChannel(wsUrl);
    });
  }

  void _connectTripChannel(String wsUrl) {
    debugPrint("WebSocketService: _connectTripChannel starting for $wsUrl");
    _isConnectingTrip = true;
    _activeTripWsUrl = wsUrl;

    try {
      // Cancel old subscription first to prevent ghost onDone callbacks
      _tripSubscription?.cancel();
      _tripSubscription = null;
      _tripChannel?.sink.close();
      _tripChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _tripSubscription = _tripChannel!.stream.listen(
        (data) {
          // On first successful message, we consider it "connected"
          _isConnectingTrip = false;
          _tripReconnectAttempts = 0; // Reset backoff on success

          try {
            final Map<String, dynamic> decoded = jsonDecode(data);
            _rideEventController.add(decoded);
          } catch (e) {
            debugPrint("Error parsing trip WS data: $e");
          }
        },
        onDone: () {
          debugPrint(
            "Trip WS closed. URL: $wsUrl, Code: ${_tripChannel?.closeCode}, Reason: ${_tripChannel?.closeReason}",
          );
          _isConnectingTrip = false;
          // Note: we KEEP _activeTripWsUrl to track what we are reconnecting to
          _scheduleTripReconnect(wsUrl);
        },
        onError: (err) {
          debugPrint(
            "Trip WS error: $err, Code: ${_tripChannel?.closeCode}, Reason: ${_tripChannel?.closeReason}",
          );
          _isConnectingTrip = false;
          _scheduleTripReconnect(wsUrl);
        },
      );

      _tripChannel!.ready
          .then((_) {
            debugPrint("Trip WS Ready for $wsUrl");
            _isConnectingTrip = false;
            _tripReconnectAttempts = 0;
          })
          .catchError((error) {
            debugPrint("Trip WS failed to be ready: $error");
            // onDone/onError will handle reconnection
          });
    } catch (e) {
      debugPrint("Trip WS connect error: $e");
      _isConnectingTrip = false;
      _scheduleTripReconnect(wsUrl);
    }
  }

  void _scheduleTripReconnect(String wsUrl) {
    if (_isIntentionalDisconnect) return;

    _tripReconnectTimer?.cancel();

    // Exponential backoff: 2, 4, 8, 16, max 30 seconds
    _tripReconnectAttempts++;
    final delaySeconds = (2 * _tripReconnectAttempts).clamp(2, 30);

    debugPrint(
      "Scheduling Trip WS reconnect in ${delaySeconds}s (Attempt: $_tripReconnectAttempts)",
    );

    _tripReconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      debugPrint("Reconnecting Trip WS...");
      _connectTripChannel(wsUrl);
    });
  }

  void disconnectAll() {
    debugPrint("WebSocketService: Disconnecting all channels intentionally.");
    _isIntentionalDisconnect = true;
    _tripActive = false;
    _rideReconnectTimer?.cancel();
    _tripReconnectTimer?.cancel();
    _tripSubscription?.cancel();
    _tripSubscription = null;
    _rideSubscription?.cancel();
    _rideSubscription = null;
    _rideChannel?.sink.close();
    _tripChannel?.sink.close();
    _rideChannel = null;
    _tripChannel = null;
    _lastRideRequestPayload = null;
    _activeTripWsUrl = null;
    _isConnectingTrip = false;
    _tripReconnectAttempts = 0;
  }
}

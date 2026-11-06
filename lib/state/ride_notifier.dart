import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'ride_state.dart';
import '../core/market/booking_refusal.dart';
import '../core/promo/promo_messages.dart';
import '../core/promo/promo_selection.dart';
import '../core/pricing/quote_lock.dart';
import '../services/models/location_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/websocket_service.dart';
import '../services/ride_service.dart';

/// Injection seam for the ride API.
///
/// RideNotifier used to build its RideService inline, which left no way to
/// substitute a fake -- so the ride-state-recovery tests could never run against
/// anything but the real network, and in practice never ran at all. Recovery after
/// an app kill or a network outage is one of the behaviours a rider notices most,
/// so it needs to be testable.
///
/// Overriding this provider is the supported way to do that:
///   ProviderContainer(overrides: [rideServiceProvider.overrideWithValue(fake)])
final rideServiceProvider = Provider<RideService>((ref) => RideService());

final rideNotifierProvider = NotifierProvider<RideNotifier, RideState>(
  RideNotifier.new,
);

/// The server's "nobody accepted" sentence, used when the frame has none.
const String kNoDriverMessage =
    'No driver accepted your request. Please try again.';

/// Said when the server never acknowledged the booking.
const String kSearchUnreachableMessage =
    "We couldn't reach SaaradhiGo. Check your connection and try again.";

const String _kBookingFailedMessage =
    "We couldn't book your ride. Please try again.";

/// Server messages written for developers, not riders.
const _technicalMessages = {
  'Failed to create trip',
  'Internal server error',
  'Invalid JSON',
};

/// The sentence that ends a driver search, or null if [frame] does not end
/// one. Covers every frame the booking socket uses to say "no": a refused
/// request, a search that could not start, and the accept deadline passing
/// with nobody (backend `auto_cancel_trip`).
@visibleForTesting
String? searchFailureFor(Map<String, dynamic> frame) {
  final type = frame['type'];
  final message = frame['message']?.toString().trim();
  final hasMessage = message != null && message.isNotEmpty;
  if (type == 'error') {
    if (!hasMessage ||
        _technicalMessages.contains(message) ||
        message.contains('_lat')) {
      return _kBookingFailedMessage;
    }
    return message;
  }
  if (type == 'dispatch_failed') {
    return hasMessage
        ? message
        : "We couldn't start the driver search. Please try again.";
  }
  if ((type == 'trip_update' || type == 'trip_status_update') &&
      frame['status'] == 'cancel' &&
      frame['reason'] == 'no_driver_accepted') {
    return hasMessage ? message : kNoDriverMessage;
  }
  return null;
}

/// Maps a backend trip status_code onto a rider-facing RideStatus.
///
/// The canonical list lives in the backend's TripStatus.status_code choices:
/// requested, accepted, reached, in_progress, completed, cancelled.
///
/// Both recovery paths used to branch on 'arrived' and 'started', neither of
/// which the backend ever sends, and silently fell through to the current status
/// for anything unrecognised. A rider whose app restarted while the driver was
/// waiting at the pickup point therefore recovered to RideStatus.none -- no
/// active ride shown at all, while a driver sat outside. 'requested' was
/// unmapped too, so recovering mid-search failed the same way. The live
/// WebSocket handler had 'reached' right; only recovery was wrong.
///
/// Returns null for a status this app does not know, so callers can log it
/// instead of pretending nothing changed.
RideStatus? rideStatusFromBackendCode(String code) {
  switch (code) {
    case 'requested':
      return RideStatus.searchingDriver;
    case 'accepted':
      return RideStatus.driverAccepted;
    case 'reached':
      return RideStatus.driverArrived;
    case 'in_progress':
      return RideStatus.rideStarted;
    case 'completed':
      return RideStatus.paymentPending;
    case 'cancelled':
      return RideStatus.cancelled;
  }
  return null;
}

/// A completed trip whose payment is settled is over: nothing to show.
///
/// `/ride/active/` returns a trip completed in the last hour whether or not
/// it was paid, and both recovery paths mapped every `completed` trip to
/// "payment pending". A rider who had paid cash saw a yellow "Payment Pending
/// for your last ride" banner for an hour (PRODUCT_AUDIT §2, Home).
bool isSettledCompletedTrip(dynamic trip) {
  if (trip is! Map || trip['status']?.toString() != 'completed') return false;
  final payment = trip['payment_status']?.toString();
  return payment == 'completed' || payment == 'not_charged';
}

class RideNotifier extends Notifier<RideState> {
  /// Pending auto-dismiss of the "ride cancelled" overlay.
  ///
  /// Held so it can be cancelled on dispose. The two dismiss paths used bare
  /// `Future.delayed`, which cannot be cancelled: if the rider left the screen --
  /// or the provider was otherwise disposed -- within those three seconds, the
  /// callback still fired and wrote to a disposed notifier, which Riverpod throws
  /// on. Two cancellations in quick succession also left two timers racing to
  /// clear the same flag.
  Timer? _cancelledOverlayTimer;

  bool _disposed = false;

  /// Drivers offered this search, per dispatch wave (`dispatch_progress`).
  /// Each wave offers only drivers not offered before in the same search, so
  /// the total asked is the sum. Keyed by wave so a repeated frame is not
  /// counted twice.
  final Map<int, int> _askedByWave = {};

  /// Bumped by every live change of the ride (a socket or push frame that
  /// moves the status, a new booking, a clear). A REST answer is applied only
  /// if no live change happened while it was in flight.
  ///
  /// The resume check (`GET /ride/active/`) used to be applied whenever it
  /// came back. Asked while the trip was `accepted`, it could land after the
  /// driver's cancel frame and put the rider back on "on the way" for a trip
  /// that no longer existed, with no socket left to correct it. The driver
  /// app had the same race on accept (driver PR #27).
  int _generation = 0;

  /// Trips this app has seen end by cancellation. A REST answer never brings
  /// one of these back.
  final Set<String> _cancelledTrips = {};

  static const _postAccept = {
    RideStatus.driverAccepted,
    RideStatus.driverArrived,
    RideStatus.rideStarted,
  };

  /// True (and logged) when a live change happened since [generation].
  bool _isStale(int generation, String what) {
    if (generation == _generation) return false;
    debugPrint(
      'RideNotifier: $what ignored -- the ride changed while it was in '
      'flight (status now ${state.status}).',
    );
    return true;
  }

  /// The trip ended by cancellation, learned from somewhere other than the
  /// live cancel frame (the trip socket's greeting, the FCM push).
  void _endByCancel(String tripId) {
    _cancelledTrips.add(tripId);
    _generation++;
    state = state.copyWith(
      status: RideStatus.cancelled,
      rawResponse: {...?state.rawResponse, 'status': 'cancel'},
    );
    _saveState();
  }

  /// The trip socket's greeting (`connection_established`) carries the
  /// committed `trip_status` from PostgreSQL, and for the rider the PIN. A
  /// frame sent while the socket was down (Android drops sockets in the
  /// background; the reconnect backs off up to 30 s) is lost, so this
  /// greeting is the socket's only record of a cancel in that gap. It used to
  /// be ignored outright.
  void _applyTripGreeting(Map<String, dynamic> data) {
    final frameTrip = data['trip_id']?.toString();
    if (frameTrip == null || frameTrip != state.tripId) return;
    final otp = data['otp']?.toString() ?? '';
    if (otp.isNotEmpty && _postAccept.contains(state.status)) {
      state = state.copyWith(rawResponse: {...?state.rawResponse, 'otp': otp});
    }
    final code = data['trip_status']?.toString();
    if (code == null) return;
    final mapped = rideStatusFromBackendCode(code);
    if (mapped == RideStatus.cancelled) {
      if (_postAccept.contains(state.status)) {
        _endByCancel(frameTrip);
      } else if (state.status == RideStatus.searchingDriver) {
        failSearch(kNoDriverMessage);
      }
      return;
    }
    // Only ever forward: a greeting never undoes a frame that already arrived.
    const order = [
      RideStatus.searchingDriver,
      RideStatus.driverAccepted,
      RideStatus.driverArrived,
      RideStatus.rideStarted,
    ];
    final now = order.indexOf(state.status);
    RideStatus? next;
    if (code == 'completed' && state.status == RideStatus.rideStarted) {
      next = RideStatus.rideCompleted;
    } else if (mapped != null && now >= 0 && order.indexOf(mapped) > now) {
      next = mapped;
    }
    if (next == null) return;
    _generation++;
    state = state.copyWith(status: next);
    _saveState();
  }

  @override
  RideState build() {
    final wsService = ref.watch(webSocketServiceProvider);
    final subscription = wsService.eventStream.listen((data) {
      updateFromWebSocket(data);
    });

    ref.onDispose(() {
      subscription.cancel();
      _cancelledOverlayTimer?.cancel();
      _disposed = true;
    });

    return const RideState();
  }

  /// Raises the cancelled overlay and schedules exactly one dismissal.
  void _showCancelledOverlayBriefly() {
    _cancelledOverlayTimer?.cancel();
    state = state.copyWith(showCancelledOverlay: true);
    _cancelledOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed) return;
      state = state.copyWith(showCancelledOverlay: false);
    });
  }

  Future<void> loadInitialState() async {
    // Implementation based on FLUTTER_STATE_RECOVERY.md app launch flow
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      // No auth token, clear any saved state
      await _clearActiveTripId();
      return;
    }

    // Every answer below is applied only if nothing live happened meanwhile.
    final gen = _generation;

    // 1. Try to fetch active trip from backend
    try {
      final rideService = ref.read(rideServiceProvider);
      final activeTripResponse = await rideService.fetchActiveTrip(token);
      if (_isStale(gen, 'Active-trip answer')) return;

      if (activeTripResponse != null &&
          activeTripResponse['status'] == 'success' &&
          activeTripResponse['data'] != null) {
        // Active trip exists on backend
        final tripData = activeTripResponse['data'];
        final tripId = tripData['id']?.toString();

        if (tripId != null && tripId.isNotEmpty) {
          // Save trip ID locally
          await prefs.setString('active_trip_id', tripId);

          // Sync state directly from the active trip response
          // This avoids making additional API calls to trip-specific endpoints
          await syncStateFromActiveTripResponse(
            activeTripResponse,
            generation: gen,
          );
          return;
        }
      }

      // No active trip on backend - check local storage for stale trip ID
      final savedTripId = prefs.getString('active_trip_id');
      if (savedTripId != null && savedTripId.isNotEmpty) {
        // We have a locally saved trip ID but backend says no active trip
        // This could be stale data - try to fetch the trip details
        final tripStatus = await rideService.getTripStatus(token, savedTripId);
        if (_isStale(gen, 'Saved-trip answer')) return;

        if (tripStatus != null &&
            tripStatus['status'] == 'success' &&
            tripStatus['data'] != null) {
          // Trip still exists, sync state using trip-specific endpoints
          await syncStateFromBackend(savedTripId, generation: gen);
        } else {
          // Trip doesn't exist or error - clear stale ID
          await _clearActiveTripId();
          await clearState();
        }
      } else {
        // No trip locally or on backend
        await _clearActiveTripId();
        await clearState();
      }
    } catch (e) {
      // Network error or other exception
      debugPrint('Error in loadInitialState: $e');

      // Fallback to local storage if available
      final savedTripId = prefs.getString('active_trip_id');
      if (_isStale(gen, 'Failed recovery')) return;
      if (savedTripId != null && savedTripId.isNotEmpty) {
        // Try to sync with backend (will handle errors in syncStateFromBackend)
        await syncStateFromBackend(savedTripId, generation: gen);
      } else {
        await _clearActiveTripId();
        await clearState();
      }
    }
  }

  Future<void> syncStateFromBackend(String tripId, {int? generation}) async {
    final gen = generation ?? _generation;
    state = state.copyWith(isSyncing: true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      await clearState();
      state = state.copyWith(isSyncing: false);
      return;
    }

    final rideService = ref.read(rideServiceProvider);

    // Fetch in parallel
    final results = await Future.wait([
      rideService.getTripStatus(token, tripId),
      rideService.getTripDetails(token, tripId),
    ]);

    final statusData = results[0];
    final detailsData = results[1];

    if (_isStale(gen, 'Trip $tripId answer')) {
      state = state.copyWith(isSyncing: false);
      return;
    }

    if (statusData == null ||
        statusData['status'] == 'error' ||
        statusData['data'] == null) {
      await clearState();
      state = state.copyWith(isSyncing: false);
      return;
    }

    final String tripStatus = statusData['data']['status'] ?? '';

    if (tripStatus == 'cancelled') {
      await clearState();
      _showCancelledOverlayBriefly();
      return;
    }
    if (isSettledCompletedTrip(statusData['data'])) {
      await clearState();
      return;
    }

    final mapped = rideStatusFromBackendCode(tripStatus);
    if (mapped == null) {
      // Do not silently keep the old status: that is how 'reached' produced a
      // blank screen for a rider with a driver waiting outside.
      debugPrint(
        'Unrecognised trip status from backend: "$tripStatus" -- '
        'rider state left at ${state.status}. This is a client/server '
        'status-vocabulary mismatch and should be reported.',
      );
    }
    final RideStatus newStatus = mapped ?? state.status;
    if (_cancelledTrips.contains(tripId) && newStatus != RideStatus.cancelled) {
      debugPrint('RideNotifier: trip $tripId was cancelled; not reviving it.');
      state = state.copyWith(isSyncing: false);
      return;
    }

    Map<String, dynamic> mergedResponse = Map<String, dynamic>.from(
      state.rawResponse ?? {},
    );
    if (detailsData != null && detailsData['data'] != null) {
      final dData = detailsData['data'];
      if (dData['driver_name'] != null)
        mergedResponse['driver_name'] = dData['driver_name'];
      if (dData['vehicle_info'] != null)
        mergedResponse['vehicle_info'] = dData['vehicle_info'];
      if (dData['otp'] != null) mergedResponse['otp'] = dData['otp'];
      if (dData['driver_rating'] != null)
        mergedResponse['driver_rating'] = dData['driver_rating'];
    }

    state = state.copyWith(
      // The trip id arrives as this method's parameter and used to be dropped
      // here. _saveActiveTripId() only keeps 'active_trip_id' when
      // state.tripId is set, so recovering a ride deleted the very pointer it
      // had just recovered from -- and LifecycleObserver then had nothing to
      // re-persist when the app was backgrounded. A rider whose app was killed
      // mid-ride lost the ride on the next offline start.
      tripId: tripId,
      status: newStatus,
      rawResponse: mergedResponse,
      isSyncing: false,
    );
    _saveState();
  }

  /// Syncs state directly from the /ride/active/ endpoint response
  /// This avoids making additional API calls to trip-specific endpoints
  Future<void> syncStateFromActiveTripResponse(
    Map<String, dynamic> activeTripResponse, {
    int? generation,
  }) async {
    if (generation != null && _isStale(generation, 'Active-trip answer')) {
      return;
    }
    state = state.copyWith(isSyncing: true);

    if (activeTripResponse['status'] != 'success' ||
        activeTripResponse['data'] == null) {
      await clearState();
      state = state.copyWith(isSyncing: false);
      return;
    }

    final tripData = activeTripResponse['data'];
    final String tripId = tripData['id']?.toString() ?? '';
    final String tripStatus = tripData['status'] ?? '';

    if (tripStatus == 'cancelled') {
      await clearState();
      _showCancelledOverlayBriefly();
      return;
    }
    if (isSettledCompletedTrip(tripData)) {
      await clearState();
      return;
    }
    // Backend #181: `is_active: false` is the server saying this trip is not
    // in progress. Only a completed trip is kept (the receipt recovery,
    // `recovery: recently_completed`); anything else is never shown live.
    if (tripData['is_active'] == false && tripStatus != 'completed') {
      await clearState();
      return;
    }

    final mapped = rideStatusFromBackendCode(tripStatus);
    if (mapped == null) {
      // Do not silently keep the old status: that is how 'reached' produced a
      // blank screen for a rider with a driver waiting outside.
      debugPrint(
        'Unrecognised trip status from backend: "$tripStatus" -- '
        'rider state left at ${state.status}. This is a client/server '
        'status-vocabulary mismatch and should be reported.',
      );
    }
    final RideStatus newStatus = mapped ?? state.status;
    if (_cancelledTrips.contains(tripId) && newStatus != RideStatus.cancelled) {
      debugPrint('RideNotifier: trip $tripId was cancelled; not reviving it.');
      state = state.copyWith(isSyncing: false);
      return;
    }

    Map<String, dynamic> mergedResponse = Map<String, dynamic>.from(
      state.rawResponse ?? {},
    );
    mergedResponse['id'] = tripId;
    if (tripData['driver_name'] != null)
      mergedResponse['driver_name'] = tripData['driver_name'];
    if (tripData['vehicle_info'] != null)
      mergedResponse['vehicle_info'] = tripData['vehicle_info'];
    if (tripData['otp'] != null) mergedResponse['otp'] = tripData['otp'];
    if (tripData['driver_rating'] != null)
      mergedResponse['driver_rating'] = tripData['driver_rating'];

    state = state.copyWith(
      // Same defect as syncStateFromBackend: tripId was parsed into a local,
      // put into rawResponse['id'], and never placed in the state the rest of
      // the app reads. RideNavigationHandler and LifecycleObserver both read
      // state.tripId directly.
      tripId: tripId,
      status: newStatus,
      rawResponse: mergedResponse,
      isSyncing: false,
    );
    _saveState();
  }

  void _saveState() {
    _saveActiveTripId();
  }

  Future<void> _saveActiveTripId() async {
    final prefs = await SharedPreferences.getInstance();

    // Save trip ID only if we have an active ride
    if (state.isActiveRide &&
        state.tripId != null &&
        state.tripId!.isNotEmpty) {
      await prefs.setString('active_trip_id', state.tripId!);
    } else {
      // Clear the saved trip ID if no active ride
      await prefs.remove('active_trip_id');
    }
  }

  Future<void> _clearActiveTripId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_trip_id');
  }

  void setSearching({
    PlaceDetails? pickup,
    PlaceDetails? drop,
    String? vehicleType,
    String? distance,
    String? duration,
  }) {
    _askedByWave.clear();
    _generation++;
    state = state.copyWith(
      status: RideStatus.searchingDriver,
      pickupLocation: pickup,
      dropLocation: drop,
      pickupAddress: pickup?.name,
      destinationAddress: drop?.name,
      vehicleType: vehicleType,
      distance: distance,
      duration: duration,
      rawResponse: {},
      clearSearchFailure: true,
      clearTripId: true,
    );
    _saveState();
  }

  /// Ends the search with [message]. The status stays `searchingDriver` so
  /// the search screen, not the global navigator, owns what happens next.
  void failSearch(String message) {
    if (state.status != RideStatus.searchingDriver) return;
    state = state.copyWith(searchFailure: message, clearTripId: true);
    _saveState();
  }

  /// What the search screen calls when the server has been quiet too long.
  ///
  /// The answer comes from the REST API, which does not depend on a socket
  /// frame arriving. A trip a driver took is recovered; a cancelled one ends
  /// the search; [giveUp] (the hard client deadline) cancels a trip that is
  /// still unanswered. A network failure ends the search only on [giveUp].
  Future<void> verifySearch({bool giveUp = false}) async {
    if (state.status != RideStatus.searchingDriver ||
        state.searchFailure != null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final rideService = ref.read(rideServiceProvider);
    final tripId = state.tripId;

    if (tripId == null) {
      // Never acknowledged. Did the trip get made anyway?
      final active = token.isEmpty
          ? null
          : await rideService.fetchActiveTrip(token);
      final data = active?['status'] == 'success' ? active!['data'] : null;
      if (data is Map && data['status'] != 'completed') {
        await syncStateFromActiveTripResponse(active!);
        return;
      }
      ref.read(webSocketServiceProvider).abandonRideRequest();
      failSearch(kSearchUnreachableMessage);
      return;
    }

    final trip = token.isEmpty
        ? null
        : await rideService.getTripStatus(token, tripId);
    final tripData = trip != null && trip['status'] == 'success'
        ? trip['data']
        : null;
    final code = tripData is Map ? tripData['status']?.toString() : null;
    if (code == null) {
      if (giveUp) failSearch(kSearchUnreachableMessage);
      return;
    }
    if (code == 'cancelled') {
      failSearch(kNoDriverMessage);
    } else if (code == 'requested') {
      if (!giveUp) return; // The server's own deadline still applies.
      await rideService.cancelTrip(token, tripId, reason: 'too_long');
      failSearch(kNoDriverMessage);
    } else {
      // A driver took it and the frame was lost.
      await syncStateFromBackend(tripId);
    }
  }

  Future<void> _cancelQuietly(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      if (token.isEmpty) return;
      await ref.read(rideServiceProvider).cancelTrip(token, tripId);
    } catch (e) {
      debugPrint('Could not cancel stranded trip $tripId: $e');
    }
  }

  void updateFromWebSocket(Map<String, dynamic> data) {
    final type = data['type'];
    final status = data['status'];

    // The booking was refused because the city is paused or not live. Say so,
    // and leave the "searching" screen: no trip exists to wait for.
    if (type == 'error' && isBookingRefusalCode(data['code']?.toString())) {
      BookingRefusalState.instance.report(
        data['code'].toString(),
        pickup: state.pickupLocation?.latLng,
      );
      unawaited(clearState());
      return;
    }

    // Cash is not available for this account. Neutral message, and back out of
    // the "searching" screen.
    if (type == 'error' && data['code']?.toString() == kCashNotAvailable) {
      BookingRefusalState.instance.reportMessage(
        kCashNotAvailable,
        kCashNotAvailableAtBookingMessage,
      );
      unawaited(clearState());
      return;
    }

    // The code the rider applied stopped applying between the preview and the
    // booking. Booking without it would charge more than they were shown, so
    // the server refused; say why and let them re-quote.
    if (type == 'error' && isPromoRefusalCode(data['code']?.toString())) {
      PromoSelection.instance.clear();
      BookingRefusalState.instance.reportMessage(
        data['code'].toString(),
        promoBookingRefusalMessage(data['code']?.toString()),
      );
      unawaited(clearState());
      return;
    }

    // The quote on the ticket expired, or the pickup, drop or class moved off
    // it. The server booked nothing and sent a fresh quote: hand it to the
    // ticket (MapProvider shows it, the search screen goes back to it) and
    // leave the search. Never book silently at a different fare.
    if (isQuoteExpiredFrame(data)) {
      QuoteLockState.instance.reportFrame(data, vehicleType: state.vehicleType);
      unawaited(clearState());
      return;
    }

    // A search that ended without a driver. Said on the search screen, with
    // "Try again"; it used to be dropped, so the screen waited forever.
    if (state.status == RideStatus.searchingDriver) {
      final failure = searchFailureFor(data);
      if (failure != null) {
        // A search that could not start leaves a `requested` trip behind
        // until its deadline. Cancel it, so "Try again" is the only booking.
        final stranded = data['trip_id']?.toString();
        if (type == 'dispatch_failed' && stranded != null) {
          unawaited(_cancelQuietly(stranded));
        }
        failSearch(failure);
        return;
      }
    }

    // The driver confirmed the cash. The payment screen used to keep asking
    // the rider to pay -- offering the wallet for a ride already paid in cash
    // (product phase 1 emulator run, trip 118). Mark it, and let that screen
    // move on to rating.
    if (type == 'cash_payment_confirmed') {
      final merged = Map<String, dynamic>.from(state.rawResponse ?? {})
        ..['cash_confirmed'] = true
        ..['payment_status'] = 'completed';
      state = state.copyWith(rawResponse: merged);
      return;
    }

    if (type == 'driver_location_update' || type == 'location_update') {
      final lat = data['lat'] ?? data['latitude'];
      final lng = data['lng'] ?? data['longitude'];
      if (lat != null && lng != null) {
        state = state.copyWith(
          driverLocation: LatLng(
            double.parse(lat.toString()),
            double.parse(lng.toString()),
          ),
        );
        _saveState();
      }
      return;
    }

    // Search progress: how many drivers have been asked so far. Kept as
    // `drivers_asked` on the response for the Finding screen.
    if (type == 'dispatch_progress') {
      if (state.status != RideStatus.searchingDriver) return;
      final frameTrip = data['trip_id']?.toString();
      if (frameTrip != null &&
          state.tripId != null &&
          frameTrip != state.tripId) {
        return; // A frame from an earlier search.
      }
      final wave = (data['wave'] is num) ? (data['wave'] as num).toInt() : 0;
      final n = (data['drivers_notified'] is num)
          ? (data['drivers_notified'] as num).toInt()
          : 0;
      _askedByWave[wave] = n < 0 ? 0 : n;
      final asked = _askedByWave.values.fold<int>(0, (a, b) => a + b);
      state = state.copyWith(
        tripId: state.tripId ?? frameTrip,
        rawResponse: {...?state.rawResponse, 'drivers_asked': asked},
      );
      _saveState();
      return;
    }

    // The trip socket's greeting: the committed status after a (re)connect.
    if (type == 'connection_established') {
      _applyTripGreeting(data);
      return;
    }

    // The FCM push for a cancelled trip (consumers.py and views.py send
    // `type: ride_cancelled`). It used to match nothing below and was
    // dropped, so a rider whose socket missed the cancel frame stayed on
    // "on the way". Only after accept: a search that ends is told on the
    // search screen by its own frames.
    if (type == 'ride_cancelled') {
      final t = data['trip_id']?.toString();
      if (t != null &&
          t == state.tripId &&
          _postAccept.contains(state.status)) {
        _endByCancel(t);
      }
      return;
    }

    // A status frame for another trip (a late frame from an earlier ride)
    // must not end or move this one.
    final frameTrip = data['trip_id']?.toString();
    if ((type == 'trip_update' || type == 'trip_status_update') &&
        frameTrip != null &&
        state.tripId != null &&
        frameTrip != state.tripId &&
        _postAccept.contains(state.status)) {
      debugPrint(
        'RideNotifier: $type for trip $frameTrip ignored; '
        'the ride is trip ${state.tripId}.',
      );
      return;
    }

    RideStatus newStatus = state.status;

    // Strict event -> state mapping
    if (type == 'trip_created' || type == 'drivers_notified') {
      // Prevent reverting to searching if a driver has already accepted
      if (state.status == RideStatus.none ||
          state.status == RideStatus.searchingDriver) {
        newStatus = RideStatus.searchingDriver;
      }
    } else if (type == 'trip_update' || type == 'trip_status_update') {
      if (status == 'accept') {
        newStatus = RideStatus.driverAccepted;
      } else if (status == 'reached') {
        newStatus = RideStatus.driverArrived;
      } else if (status == 'start') {
        newStatus = RideStatus.rideStarted;
      } else if (status == 'complete') {
        newStatus = RideStatus.rideCompleted;
      } else if (status == 'cancel' || status == 'cancelled') {
        // The sockets send the action name ('cancel'); accept the status
        // code too, so a sender that uses it is not silently dropped.
        newStatus = RideStatus.cancelled;
      }
    }

    LatLng? driverLoc = state.driverLocation;
    final initLat = data['driver_lat'] ?? data['latitude'];
    final initLng = data['driver_lng'] ?? data['longitude'];
    if (initLat != null && initLng != null) {
      driverLoc = LatLng(
        double.parse(initLat.toString()),
        double.parse(initLng.toString()),
      );
    }

    String? tripId = state.tripId;
    bool shouldConnectTrip = false;

    // Check if we should connect to the trip websocket now
    if (newStatus == RideStatus.driverAccepted &&
        state.status == RideStatus.searchingDriver) {
      shouldConnectTrip = true;
    }

    if (data['trip_id'] != null) {
      final newTripId = data['trip_id'].toString();
      if (tripId != newTripId) {
        tripId = newTripId;
        if (newStatus != RideStatus.searchingDriver &&
            newStatus != RideStatus.none) {
          shouldConnectTrip = true;
        }
      }
    }

    Map<String, dynamic> mergedResponse = Map<String, dynamic>.from(
      state.rawResponse ?? {},
    );
    if (type != 'connection_established' &&
        type != 'driver_location_update' &&
        type != 'location_update') {
      // Keys that should not be overwritten once set (only come with accept events)
      const protectedKeys = {
        'driver_info',
        'vehicle_info',
        'otp',
        'driver_name',
        'vehicle_number',
      };
      data.forEach((key, value) {
        // Don't let non-accept events erase protected driver/vehicle details
        if (protectedKeys.contains(key) &&
            mergedResponse.containsKey(key) &&
            (value == null || (value is String && value.isEmpty))) {
          return;
        }
        mergedResponse[key] = value;
      });
    }

    if (newStatus != state.status) _generation++;
    if (newStatus == RideStatus.cancelled && tripId != null) {
      _cancelledTrips.add(tripId);
    }
    state = state.copyWith(
      status: newStatus,
      rawResponse: mergedResponse,
      driverLocation: driverLoc,
      tripId: tripId,
    );
    _saveState();

    if (shouldConnectTrip &&
        tripId != null &&
        newStatus != RideStatus.searchingDriver) {
      SharedPreferences.getInstance().then((prefs) {
        final token = prefs.getString('access_token');
        if (token != null) {
          ref
              .read(webSocketServiceProvider)
              .connectToTrip(token, int.parse(tripId!));
        }
      });
    }

    // A driver is on the way and we have no OTP. Go and ask for it.
    //
    // The OTP is pushed once, on accept, to the trip group and to the rider's
    // personal group. That push is best-effort: channels_redis drops to a channel
    // whose queue is full and group_send swallows it per channel, so a client that
    // was not draining at that instant simply never sees the frame. Measured on an
    // isolated load stack: at 50 concurrent rides 6 of 50 riders received the OTP
    // on neither socket. At 100 rides in batches of 25, 2 did not.
    //
    // Without this, that rider stares at "----" where their OTP should be, with a
    // driver waiting outside, and nothing in the app ever tries again -- the
    // existing sync only runs on startup or resume, so the fix was to background
    // the app and reopen it. `syncStateFromBackend` already fetches trip details
    // and merges the OTP; it just was never called for this reason.
    //
    // Cheap and bounded: one extra request, only when a rider reaches a state that
    // should have an OTP and does not.
    const needsOtp = {RideStatus.driverAccepted, RideStatus.driverArrived};
    final haveOtp = (mergedResponse['otp']?.toString() ?? '').isNotEmpty;
    if (tripId != null && needsOtp.contains(newStatus) && !haveOtp) {
      debugPrint(
        'OTP missing after a $status push for trip $tripId -- refetching. '
        'The push is best-effort; this is the documented pull fallback.',
      );
      syncStateFromBackend(tripId);
    }
  }

  // Explicit methods for payment and rating transition
  void setPaymentPending() {
    state = state.copyWith(status: RideStatus.paymentPending);
    _saveState();
  }

  void setRated() {
    state = state.copyWith(status: RideStatus.rated);
    _saveState();
  }

  Future<void> updateFromNotification(Map<String, dynamic> payload) async {
    final action = payload['action'] ?? payload['type'];
    if (action != null) {
      updateFromWebSocket(payload);

      final tripIdStr = payload['trip_id']?.toString() ?? state.tripId;
      if (tripIdStr != null && state.isActiveRide) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          ref
              .read(webSocketServiceProvider)
              .connectToTrip(token, int.parse(tripIdStr));
        }
      }
    }
  }

  /// Clears ride state and the persisted active-trip pointer.
  ///
  /// Returns a Future so callers can await the *durable* part. It used to be
  /// `void` while firing two un-awaited SharedPreferences writes, so a caller had
  /// no way to know when 'active_trip_id' was actually gone -- and the two writes
  /// raced each other. A cancel or completion followed closely by the app being
  /// killed could leave the finished trip's id on disk.
  Future<void> clearState() async {
    _generation++;
    state = const RideState();
    // One write, not two racing ones: _saveState() would remove the key anyway
    // for an empty state, but being explicit here is what callers depend on.
    await _clearActiveTripId();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'ride_state.dart';
import '../services/models/location_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/websocket_service.dart';
import '../services/ride_service.dart';

final rideNotifierProvider = NotifierProvider<RideNotifier, RideState>(RideNotifier.new);

class RideNotifier extends Notifier<RideState> {
  @override
  RideState build() {
    final wsService = ref.watch(webSocketServiceProvider);
    final subscription = wsService.eventStream.listen((data) {
      updateFromWebSocket(data);
    });
    
    ref.onDispose(() {
      subscription.cancel();
    });

    return const RideState();
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
    
    // 1. Try to fetch active trip from backend
    try {
      final rideService = RideService();
      final activeTripResponse = await rideService.fetchActiveTrip(token);
      
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
          await syncStateFromActiveTripResponse(activeTripResponse);
          return;
        }
      }
      
      // No active trip on backend - check local storage for stale trip ID
      final savedTripId = prefs.getString('active_trip_id');
      if (savedTripId != null && savedTripId.isNotEmpty) {
        // We have a locally saved trip ID but backend says no active trip
        // This could be stale data - try to fetch the trip details
        final tripStatus = await rideService.getTripStatus(token, savedTripId);
        
        if (tripStatus != null &&
            tripStatus['status'] == 'success' &&
            tripStatus['data'] != null) {
          // Trip still exists, sync state using trip-specific endpoints
          await syncStateFromBackend(savedTripId);
        } else {
          // Trip doesn't exist or error - clear stale ID
          await _clearActiveTripId();
          clearState();
        }
      } else {
        // No trip locally or on backend
        await _clearActiveTripId();
        clearState();
      }
    } catch (e) {
      // Network error or other exception
      debugPrint('Error in loadInitialState: $e');
      
      // Fallback to local storage if available
      final savedTripId = prefs.getString('active_trip_id');
      if (savedTripId != null && savedTripId.isNotEmpty) {
        // Try to sync with backend (will handle errors in syncStateFromBackend)
        await syncStateFromBackend(savedTripId);
      } else {
        await _clearActiveTripId();
        clearState();
      }
    }
  }

  Future<void> syncStateFromBackend(String tripId) async {
    state = state.copyWith(isSyncing: true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      clearState();
      state = state.copyWith(isSyncing: false);
      return;
    }

    final rideService = RideService();
    
    // Fetch in parallel
    final results = await Future.wait([
      rideService.getTripStatus(token, tripId),
      rideService.getTripDetails(token, tripId),
    ]);

    final statusData = results[0];
    final detailsData = results[1];

    if (statusData == null || statusData['status'] == 'error' || statusData['data'] == null) {
      clearState();
      state = state.copyWith(isSyncing: false);
      return;
    }

    final String tripStatus = statusData['data']['status'] ?? '';
    
    if (tripStatus == 'cancelled') {
        clearState();
        state = state.copyWith(showCancelledOverlay: true);
        Future.delayed(const Duration(seconds: 3), () {
            state = state.copyWith(showCancelledOverlay: false);
        });
        return;
    }

    RideStatus newStatus = state.status;
    if (tripStatus == 'accepted') { newStatus = RideStatus.driverAccepted; }
    else if (tripStatus == 'arrived') { newStatus = RideStatus.driverArrived; }
    else if (tripStatus == 'started' || tripStatus == 'in_progress') { newStatus = RideStatus.rideStarted; }
    else if (tripStatus == 'completed') { newStatus = RideStatus.paymentPending; }

    Map<String, dynamic> mergedResponse = Map<String, dynamic>.from(state.rawResponse ?? {});
    if (detailsData != null && detailsData['data'] != null) {
       final dData = detailsData['data'];
       if (dData['driver_name'] != null) mergedResponse['driver_name'] = dData['driver_name'];
       if (dData['vehicle_info'] != null) mergedResponse['vehicle_info'] = dData['vehicle_info'];
       if (dData['otp'] != null) mergedResponse['otp'] = dData['otp'];
       if (dData['driver_rating'] != null) mergedResponse['driver_rating'] = dData['driver_rating'];
    }

    state = state.copyWith(
       status: newStatus,
       rawResponse: mergedResponse,
       isSyncing: false,
    );
    _saveState();
  }

  /// Syncs state directly from the /ride/active/ endpoint response
  /// This avoids making additional API calls to trip-specific endpoints
  Future<void> syncStateFromActiveTripResponse(Map<String, dynamic> activeTripResponse) async {
    state = state.copyWith(isSyncing: true);

    if (activeTripResponse['status'] != 'success' || activeTripResponse['data'] == null) {
      clearState();
      state = state.copyWith(isSyncing: false);
      return;
    }

    final tripData = activeTripResponse['data'];
    final String tripId = tripData['id']?.toString() ?? '';
    final String tripStatus = tripData['status'] ?? '';
    
    if (tripStatus == 'cancelled') {
        clearState();
        state = state.copyWith(showCancelledOverlay: true);
        Future.delayed(const Duration(seconds: 3), () {
            state = state.copyWith(showCancelledOverlay: false);
        });
        return;
    }

    RideStatus newStatus = state.status;
    if (tripStatus == 'accepted') { newStatus = RideStatus.driverAccepted; }
    else if (tripStatus == 'arrived') { newStatus = RideStatus.driverArrived; }
    else if (tripStatus == 'started' || tripStatus == 'in_progress') { newStatus = RideStatus.rideStarted; }
    else if (tripStatus == 'completed') { newStatus = RideStatus.paymentPending; }

    Map<String, dynamic> mergedResponse = Map<String, dynamic>.from(state.rawResponse ?? {});
    mergedResponse['id'] = tripId;
    if (tripData['driver_name'] != null) mergedResponse['driver_name'] = tripData['driver_name'];
    if (tripData['vehicle_info'] != null) mergedResponse['vehicle_info'] = tripData['vehicle_info'];
    if (tripData['otp'] != null) mergedResponse['otp'] = tripData['otp'];
    if (tripData['driver_rating'] != null) mergedResponse['driver_rating'] = tripData['driver_rating'];

    state = state.copyWith(
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
    if (state.isActiveRide && state.tripId != null && state.tripId!.isNotEmpty) {
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
    );
    _saveState();
  }

  void updateFromWebSocket(Map<String, dynamic> data) {
    final type = data['type'];
    final status = data['status'];

    if (type == 'driver_location_update' || type == 'location_update') {
      final lat = data['lat'] ?? data['latitude'];
      final lng = data['lng'] ?? data['longitude'];
      if (lat != null && lng != null) {
        state = state.copyWith(
          driverLocation: LatLng(
            double.parse(lat.toString()), 
            double.parse(lng.toString())
          )
        );
        _saveState();
      }
      return; 
    }

    RideStatus newStatus = state.status;
    
    // Strict event -> state mapping
    if (type == 'trip_created' || type == 'drivers_notified') {
      // Prevent reverting to searching if a driver has already accepted
      if (state.status == RideStatus.none || state.status == RideStatus.searchingDriver) {
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
      } else if (status == 'cancel') {
        newStatus = RideStatus.cancelled;
      }
    }

    LatLng? driverLoc = state.driverLocation;
    final initLat = data['driver_lat'] ?? data['latitude'];
    final initLng = data['driver_lng'] ?? data['longitude'];
    if (initLat != null && initLng != null) {
      driverLoc = LatLng(
        double.parse(initLat.toString()), 
        double.parse(initLng.toString())
      );
    }
    
    String? tripId = state.tripId;
    bool shouldConnectTrip = false;
    
    // Check if we should connect to the trip websocket now
    if (newStatus == RideStatus.driverAccepted && state.status == RideStatus.searchingDriver) {
      shouldConnectTrip = true;
    }

    if (data['trip_id'] != null) {
      final newTripId = data['trip_id'].toString();
      if (tripId != newTripId) {
        tripId = newTripId;
        if (newStatus != RideStatus.searchingDriver && newStatus != RideStatus.none) {
          shouldConnectTrip = true;
        }
      }
    }

    Map<String, dynamic> mergedResponse = Map<String, dynamic>.from(state.rawResponse ?? {});
    if (type != 'connection_established' && type != 'driver_location_update' && type != 'location_update') {
      // Keys that should not be overwritten once set (only come with accept events)
      const protectedKeys = {'driver_info', 'vehicle_info', 'otp', 'driver_name', 'vehicle_number'};
      data.forEach((key, value) {
        // Don't let non-accept events erase protected driver/vehicle details
        if (protectedKeys.contains(key) && mergedResponse.containsKey(key) && (value == null || (value is String && value.isEmpty))) {
          return;
        }
        mergedResponse[key] = value;
      });
    }

    state = state.copyWith(
      status: newStatus,
      rawResponse: mergedResponse,
      driverLocation: driverLoc,
      tripId: tripId,
    );
    _saveState();

    if (shouldConnectTrip && tripId != null && newStatus != RideStatus.searchingDriver) {
      SharedPreferences.getInstance().then((prefs) {
        final token = prefs.getString('access_token');
        if (token != null) {
          ref.read(webSocketServiceProvider).connectToTrip(token, int.parse(tripId!));
        }
      });
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
           ref.read(webSocketServiceProvider).connectToTrip(token, int.parse(tripIdStr));
         }
       }
    }
  }

  void clearState() {
    state = const RideState();
    _saveState();
    // Also explicitly clear the active trip ID
    _clearActiveTripId();
  }
}

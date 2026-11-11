import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_events.dart';
import '../services/api_service.dart';
import '../services/ride_service.dart';
import '../services/models/trip_model.dart';

class HistoryProvider extends ChangeNotifier {
  HistoryProvider({RideService? rideService, ApiService? api})
    : _rideService = rideService ?? RideService(),
      _api = api;

  final RideService _rideService;
  final ApiService? _api;

  List<Trip> _trips = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Trip> get trips => _trips;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Loads the rider's trips through the 401 refresh path, capped at
  /// kLoadTimeout. A failure is an error with Try again, not "no trips": the
  /// old path swallowed a 401 into an empty list. A refused session signs
  /// out to Log in (ApiService).
  Future<void> fetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('access_token') == null) {
      // No session at all: say so, and let the app take the rider to Log in.
      _errorMessage = "We couldn't load your trips.";
      notifyListeners();
      SessionEvents.emitExpired();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _trips = await _rideService.loadRideHistory(api: _api);
    } catch (e) {
      debugPrint('Ride history failed: $e');
      _errorMessage = "We couldn't load your trips.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearHistory() {
    _trips = [];
    notifyListeners();
  }
}

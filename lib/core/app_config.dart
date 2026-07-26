import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://dev.api.saaradhigo.in/api/v1';
  static String get wsBaseUrl =>
      dotenv.env['WS_BASE_URL'] ?? 'wss://dev.api.saaradhigo.in/ws';

  // API Endpoints
  static const String authOtp = '/auth/otp/';
  static const String authLogin = '/auth/login/';
  static const String authRefresh = '/auth/refresh/';
  static const String authUpdate = '/auth/update/';
  static const String authProfile = '/auth/profile/';

  static const String riderNotifications = '/rider/notifications/';
  static const String rideHistory = '/ride/ride-history/';
  static const String activeRide = '/ride/active/';

  // WebSocket Endpoints
  static String rideRequestWs = '$wsBaseUrl/ride/request/';
  static String tripWs(int tripId) => '$wsBaseUrl/ride/trip/$tripId/';

  // Maps proxy — the Google Maps key lives on the server, never here.
  // Anything bundled in assets/.env ships inside the APK and can be
  // extracted from it, so a key placed here is a public key. Place search,
  // place details, reverse geocoding and directions all go through these
  // endpoints, which hold the key, rate-limit per user and cache results.
  static const String mapsAutocomplete = '/ride/maps/geocode';
  static const String mapsPlaceDetails = '/ride/maps/place-details';
  static const String mapsReverseGeocode = '/ride/maps/reverse-geocode';
  static const String mapsDirections = '/ride/maps/directions';

  // Cashfree
  static String get cashfreeAppId => dotenv.env['CASHFREE_APP_ID'] ?? '';
  static String get cashfreeEnvironment =>
      dotenv.env['CASHFREE_ENVIRONMENT'] ?? 'sandbox';
}

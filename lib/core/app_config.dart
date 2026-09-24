import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Build-time configuration for the rider app.
///
/// Resolution order, highest first:
///   1. `--dart-define` (compile-time, cannot be swapped after the build)
///   2. `assets/.env` via dotenv, when one was loaded (local development)
///   3. the QA host -- DEBUG BUILDS ONLY
///
/// A RELEASE build that resolves to nothing, or to a dev/staging/qa/localhost
/// host, refuses to start; see [misconfiguration]. Previously the fallback pointed
/// at QA unconditionally, so a store build with a missing or stale `.env` shipped
/// talking to test data with nothing in the app to say so -- riders would have
/// booked rides that did not exist against drivers who were not there.
///
/// `assets/.env` is also no longer declared in pubspec. It was gitignored, so CI
/// could never have it, and anything bundled as a Flutter asset can be extracted
/// from the APK -- which made it the wrong place for a key in the first place.
///
/// Build with:
///   flutter build apk --dart-define=BASE_URL=https://api.saaradhigo.in/api/v1 \
///                     --dart-define=WS_BASE_URL=wss://api.saaradhigo.in/ws
class AppConfig {
  static const String _defineBaseUrl = String.fromEnvironment('BASE_URL');
  static const String _defineWsBaseUrl = String.fromEnvironment('WS_BASE_URL');

  static const String _devBaseUrl = 'https://dev.api.saaradhigo.in/api/v1';
  static const String _devWsBaseUrl = 'wss://dev.api.saaradhigo.in/ws';

  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  /// Reads dotenv without throwing when no `.env` was ever loaded.
  static String _fromDotenv(String key) {
    try {
      return dotenv.isInitialized ? (dotenv.env[key] ?? '') : '';
    } on Object {
      return '';
    }
  }

  static String _resolve(String define, String key, String devFallback) {
    if (define.isNotEmpty) return define;
    final fromFile = _fromDotenv(key);
    if (fromFile.isNotEmpty) return fromFile;
    return isProduction ? '' : devFallback;
  }

  static String get baseUrl => _resolve(_defineBaseUrl, 'BASE_URL', _devBaseUrl);
  static String get wsBaseUrl =>
      _resolve(_defineWsBaseUrl, 'WS_BASE_URL', _devWsBaseUrl);

  /// Hosts that must never appear in a release build.
  static const List<String> _nonProductionMarkers = <String>[
    'dev.',
    'staging.',
    'qa.',
    'localhost',
    '127.0.0.1',
    '10.0.2.2',
  ];

  /// Why this build must refuse to start, or null when it is configured sanely.
  /// Only ever non-null in a RELEASE build.
  static String? get misconfiguration {
    if (!isProduction) return null;
    final api = baseUrl;
    final ws = wsBaseUrl;
    if (api.isEmpty || ws.isEmpty) {
      return 'This release build was compiled without BASE_URL and WS_BASE_URL. '
          'Rebuild with --dart-define for the target environment.';
    }
    final offending = _nonProductionMarkers
        .where((m) => api.contains(m) || ws.contains(m));
    if (offending.isNotEmpty) {
      return 'This release build points at a non-production host '
          '("${offending.first}"). Rebuild with the production URLs.';
    }
    return null;
  }

  /// Short label for the environment, shown on any build that is not production.
  static String get environmentLabel {
    final api = baseUrl;
    if (api.isEmpty) return 'UNCONFIGURED';
    for (final marker in _nonProductionMarkers) {
      if (api.contains(marker)) {
        return marker == 'dev.' ? 'QA' : marker.replaceAll('.', '').toUpperCase();
      }
    }
    return 'PRODUCTION';
  }

  static bool get showEnvironmentBadge => environmentLabel != 'PRODUCTION';

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

  // Cashfree. `--dart-define` first so a release build does not depend on a file
  // that is not in the repository. The environment defaults to sandbox, which is
  // the safe direction to fail: a build that forgets the flag cannot take real
  // money.
  static const String _defineCashfreeAppId =
      String.fromEnvironment('CASHFREE_APP_ID');
  static const String _defineCashfreeEnv =
      String.fromEnvironment('CASHFREE_ENVIRONMENT');

  static String get cashfreeAppId => _defineCashfreeAppId.isNotEmpty
      ? _defineCashfreeAppId
      : _fromDotenv('CASHFREE_APP_ID');

  static String get cashfreeEnvironment {
    if (_defineCashfreeEnv.isNotEmpty) return _defineCashfreeEnv;
    final fromFile = _fromDotenv('CASHFREE_ENVIRONMENT');
    return fromFile.isNotEmpty ? fromFile : 'sandbox';
  }
}

/// Fetches, caches and serves the [MarketConfig].
///
/// Order of preference, always: FRESH response -> CACHED last good response ->
/// BUILT-IN defaults (today's India behaviour). A failed fetch (offline,
/// timeout, 5xx, 404 for an unknown country, garbage body) never throws, never
/// blocks start-up or booking, and never replaces something better with
/// something worse.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import 'market_config.dart';

class MarketConfigStore extends ChangeNotifier {
  MarketConfigStore({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 6),
    this.appName = 'rider',
  }) : _client = client,
       _baseUrl = baseUrl;

  /// The app-wide instance. Non-widget code (service-area checks, models)
  /// reads [current] from here; widgets reach it through Provider so they
  /// rebuild when it changes.
  static final MarketConfigStore instance = MarketConfigStore();

  static const cacheKey = 'market_config_cache_v1';
  static const countryKey = 'market_config_country_v1';

  final http.Client? _client;
  final String? _baseUrl;
  final Duration timeout;
  final String appName;

  MarketConfig _current = MarketConfig.builtIn;
  String? _lastCountry;

  MarketConfig get current => _current;

  /// Which layer the current value came from, for tests and diagnostics.
  String source = 'built-in';

  String get _base => _baseUrl ?? AppConfig.baseUrl;

  /// Loads the cached response (cheap, local). Call before the first frame.
  Future<void> restoreCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastCountry = prefs.getString(countryKey);
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _current = MarketConfig.fromData(Map<String, dynamic>.from(decoded));
        source = 'cached';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('MarketConfig: cache unreadable ($e); using built-in');
    }
  }

  /// Fetches the document and, if it is good, adopts and caches it.
  /// [country] defaults to the last known country, then to IN as the very
  /// last fallback. Returns the config now in force. Never throws.
  Future<MarketConfig> refresh({String? country}) async {
    final code = (country ?? _lastCountry ?? MarketConfig.builtIn.countryCode)
        .toUpperCase();
    final client = _client ?? http.Client();
    try {
      final uri = Uri.parse(
        '$_base/app-config/',
      ).replace(queryParameters: {'country': code, 'app': appName});
      final response = await client.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        // 404 = unknown country: never a crash, never a guess. Keep what we have.
        debugPrint('MarketConfig: HTTP ${response.statusCode}; keeping $source');
        return _current;
      }
      final body = jsonDecode(response.body);
      final data = body is Map ? body['data'] : null;
      if (data is! Map || data['country'] is! Map) return _current;
      final map = Map<String, dynamic>.from(data);
      _current = MarketConfig.fromData(map);
      source = 'fresh';
      _lastCountry = _current.countryCode;
      await _persist(map);
      notifyListeners();
    } on Object catch (e) {
      debugPrint('MarketConfig: fetch failed (${e.runtimeType}); keeping $source');
    } finally {
      if (_client == null) client.close();
    }
    return _current;
  }

  /// After sign-in: use the country of the signed-in user's phone number.
  /// Same dialling code as the config in force -> refresh that country;
  /// otherwise ask the backend which live country owns that code.
  Future<MarketConfig> refreshForPhone(String? e164) async {
    final digits = (e164 ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty || digits.startsWith(_current.callingCode)) {
      return refresh();
    }
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse('$_base/app-config/'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final countries = (body is Map && body['data'] is Map)
            ? (body['data'] as Map)['countries']
            : null;
        if (countries is List) {
          for (final c in countries) {
            if (c is Map) {
              final cc = (c['calling_code'] ?? '').toString();
              if (cc.isNotEmpty && digits.startsWith(cc)) {
                return await refresh(country: c['code']?.toString());
              }
            }
          }
        }
      }
    } on Object catch (e) {
      debugPrint('MarketConfig: country lookup failed (${e.runtimeType})');
    } finally {
      if (_client == null) client.close();
    }
    return refresh();
  }

  Future<void> _persist(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(data));
      await prefs.setString(countryKey, _current.countryCode);
    } catch (e) {
      debugPrint('MarketConfig: could not cache ($e)');
    }
  }

  /// Test seam.
  @visibleForTesting
  void debugSet(MarketConfig config, {String from = 'fresh'}) {
    _current = config;
    source = from;
    notifyListeners();
  }

  // ---- service area ------------------------------------------------------

  static const double _bufferKm = 1.5;

  /// The configured live city containing [p] (service-area box + a small
  /// buffer), or null.
  CityConfig? cityAt(LatLng? p) {
    if (p == null) return null;
    for (final c in _current.cities) {
      final b = c.bounds;
      if (b != null && b.grownByKm(_bufferKm).contains(p)) return c;
    }
    return null;
  }

  /// True when the server named live cities with service-area boxes AND [p]
  /// is inside none of them. When the server named none, the caller falls back
  /// to the built-in polygon (today's behaviour).
  bool? insideConfiguredArea(LatLng p) {
    final boxed = _current.cities.where((c) => c.bounds != null);
    if (boxed.isEmpty) return null;
    return cityAt(p) != null;
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../core/notifications/notification_prefs.dart';

/// `GET` and `PUT /notifications/preferences/` (servers/notifications/app_views.py).
///
/// This is the canonical preferences endpoint. The older
/// `/rider/notifications/preferences/` pair is not used by this app.
class NotificationPreferencesService {
  NotificationPreferencesService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Uri get _uri => Uri.parse('${AppConfig.baseUrl}/notifications/preferences/');

  NotificationPrefs? _read(http.Response resp) {
    if (resp.statusCode != 200) return null;
    final parsed = jsonDecode(resp.body);
    if (parsed is! Map || parsed['status'] != 'success') return null;
    return NotificationPrefs.fromData(parsed['data']);
  }

  /// The caller's effective choices, or null on any failure.
  Future<NotificationPrefs?> fetch(String token) async {
    final client = _client ?? http.Client();
    try {
      final resp = await client
          .get(_uri, headers: _headers(token))
          .timeout(const Duration(seconds: 10));
      return _read(resp);
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Saves one explicit choice. Returns the server's view after the save, or
  /// null when it was not saved (the caller rolls the switch back).
  Future<NotificationPrefs?> save(
    String token, {
    required String channel,
    required String category,
    required bool optedIn,
  }) async {
    final client = _client ?? http.Client();
    try {
      final resp = await client
          .put(
            _uri,
            headers: _headers(token),
            body: jsonEncode({
              'preferences': [
                {'channel': channel, 'category': category, 'opted_in': optedIn},
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));
      return _read(resp);
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }
}

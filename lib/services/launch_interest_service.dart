import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';

/// "Tell me when we launch": `POST /platform/launch-interest/` {lat, lng}.
class LaunchInterestService {
  LaunchInterestService({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// True when the server took the request.
  Future<bool> register(LatLng pickup) async {
    try {
      final token = (await SharedPreferences.getInstance()).getString(
        'access_token',
      );
      final client = _client ?? http.Client();
      final response = await client
          .post(
            Uri.parse('${AppConfig.baseUrl}/platform/launch-interest/'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'lat': pickup.latitude, 'lng': pickup.longitude}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Launch interest failed: $e');
      return false;
    }
  }
}

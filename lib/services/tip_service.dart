import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';

/// `POST /ride/trips/<id>/tip/` (USA): a tip on the card used for the trip,
/// 100% to the driver. Returns null when it went through, else the message.
class TipService {
  TipService({http.Client? client}) : _client = client;
  final http.Client? _client;

  Future<String?> tip(String tripId, int percent) async {
    try {
      final token = (await SharedPreferences.getInstance()).getString(
        'access_token',
      );
      final r = await (_client ?? http.Client())
          .post(
            Uri.parse('${AppConfig.baseUrl}/ride/trips/$tripId/tip/'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'percent': percent}),
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode < 300) return null;
      final body = r.body.isEmpty ? null : jsonDecode(r.body);
      final err = body is Map ? body['error'] : null;
      return (err is Map ? err['message']?.toString() : null) ??
          "We couldn't add the tip. Please try again.";
    } catch (_) {
      return "We couldn't add the tip. Please try again.";
    }
  }
}

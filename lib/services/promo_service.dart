import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';

/// Thin wrapper around POST /api/v1/ride/promo/apply/.
/// Returns the parsed PromoResult dict from the server (ok / reason /
/// discount_amount / final_fare / description), or null on transport
/// error.
class PromoService {
  Future<Map<String, dynamic>?> applyPromo({
    required String token,
    required String code,
    required double fare,
    double? pickupLat,
    double? pickupLong,
  }) async {
    final body = <String, dynamic>{
      'code': code.trim().toUpperCase(),
      'fare': fare.toStringAsFixed(2),
    };
    if (pickupLat != null) body['pickup_lat'] = pickupLat;
    if (pickupLong != null) body['pickup_long'] = pickupLong;

    final resp = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/ride/promo/apply/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));
    try {
      final parsed = jsonDecode(resp.body) as Map<String, dynamic>;
      // Successful: {status: success, data: {...PromoResult}}
      // Failure:    {status: error,   error: {code, message, ...}}
      if (resp.statusCode == 200 && parsed['status'] == 'success') {
        return {
          'ok': true,
          ...?(parsed['data'] as Map?)?.cast<String, dynamic>(),
        };
      }
      final err = parsed['error'] as Map?;
      return {
        'ok': false,
        'reason': err?['code'] ?? 'PROMO_INVALID',
        'description': err?['message'] ?? 'Promo could not be applied.',
      };
    } catch (_) {
      return null;
    }
  }
}

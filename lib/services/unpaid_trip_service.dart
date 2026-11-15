import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';

const String kUnpaidPaidMessage = 'Paid. You can book now.';
const String _kUnpaidFailedMessage =
    "We couldn't take the payment. Please try again.";

class UnpaidPayResult {
  const UnpaidPayResult({required this.paid, required this.message});
  final bool paid;
  final String message;
}

/// `POST /api/v1/payments/unpaid/pay/`: settle the last unpaid trip.
/// 200 with `data.result == 'paid'` is success; 402 carries the server's
/// message, which is shown as is.
class UnpaidTripService {
  UnpaidTripService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<UnpaidPayResult> pay() async {
    try {
      final token = (await SharedPreferences.getInstance()).getString(
        'access_token',
      );
      final response = await (_client ?? http.Client())
          .post(
            Uri.parse('${AppConfig.baseUrl}/payments/unpaid/pay/'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));
      Object? body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {}
      final map = body is Map ? body : const {};
      final data = map['data'];
      if (response.statusCode == 200 &&
          data is Map &&
          data['result']?.toString() == 'paid') {
        return const UnpaidPayResult(paid: true, message: kUnpaidPaidMessage);
      }
      final err = map['error'];
      final msg = (map['message'] ?? (err is Map ? err['message'] : null))
          ?.toString()
          .trim();
      return UnpaidPayResult(
        paid: false,
        message: (msg == null || msg.isEmpty) ? _kUnpaidFailedMessage : msg,
      );
    } catch (e) {
      debugPrint('Unpaid pay failed: $e');
      return const UnpaidPayResult(paid: false, message: _kUnpaidFailedMessage);
    }
  }
}

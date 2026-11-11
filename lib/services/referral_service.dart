import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../core/referral/referral_device_id.dart';
import '../core/referral/referral_models.dart';

/// `GET /promotions/referrals/mine/` and `POST /promotions/referrals/attach/`.
class ReferralService {
  ReferralService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  /// The rider's code, the offer and the people they referred. Null on any
  /// failure (the screen shows a retry).
  Future<ReferralMine?> fetchMine(String token) async {
    final client = _client ?? http.Client();
    try {
      final resp = await client
          .get(
            Uri.parse('${AppConfig.baseUrl}/promotions/referrals/mine/'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final parsed = jsonDecode(resp.body);
      if (parsed is! Map || parsed['status'] != 'success') return null;
      return ReferralMine.fromData(parsed['data']);
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Uses a referral code. Never throws: a failure is a result, because a
  /// referral problem must never get in the way of signing up.
  Future<AttachResult> attach(
    String token,
    String code, {
    String? deviceId,
  }) async {
    final client = _client ?? http.Client();
    try {
      final device = deviceId ?? await ReferralDeviceId.get();
      final resp = await client
          .post(
            Uri.parse('${AppConfig.baseUrl}/promotions/referrals/attach/'),
            headers: _headers(token),
            body: jsonEncode({
              'code': code.trim().toUpperCase(),
              'device_id': device,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final parsed = jsonDecode(resp.body);
      if (resp.statusCode == 201 &&
          parsed is Map &&
          parsed['status'] == 'success') {
        return const AttachResult(ok: true);
      }
      final err = parsed is Map ? parsed['error'] : null;
      final refusal = err is Map ? err['code']?.toString() : null;
      return AttachResult(
        ok: false,
        code: refusal,
        message: attachRefusalMessage(refusal),
      );
    } catch (_) {
      return AttachResult(
        ok: false,
        code: 'NETWORK',
        message: attachRefusalMessage('NETWORK'),
      );
    } finally {
      if (_client == null) client.close();
    }
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import 'sg_text.dart';
import 'sg_tokens.dart';
import 'trip_widgets.dart' show exactMoney;

/// What cancelling now costs (`GET /ride/trip/<id>/cancel-preview/`): free, or the fee.
class CancelCost {
  const CancelCost({required this.free, this.fee, this.currency});
  final bool free;
  final String? fee;
  final String? currency;

  /// "Cancelling now is free." or "A cancellation fee of ₹50 applies."; null when unknown.
  String? line() {
    if (free) return 'Cancelling now is free.';
    final n = double.tryParse(fee ?? '');
    if (n == null || n <= 0) return null;
    return 'A cancellation fee of ${exactMoney(n, currency)} applies.';
  }
}

Future<CancelCost?> fetchCancelCost(
  String tripId, {
  http.Client? client,
}) async {
  try {
    final token = (await SharedPreferences.getInstance()).getString(
      'access_token',
    );
    final r = await (client ?? http.Client())
        .get(
          Uri.parse('${AppConfig.baseUrl}/ride/trip/$tripId/cancel-preview/'),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    final body = jsonDecode(r.body);
    final d = body is Map && body['data'] is Map ? body['data'] as Map : body;
    if (d is! Map) return null;
    return CancelCost(
      free: d['free'] == true,
      fee: d['fee']?.toString(),
      currency: d['currency']?.toString(),
    );
  } catch (_) {
    return null;
  }
}

/// "Cancel this trip?" with what it costs: nothing is cancelled until the rider confirms.
Future<bool> confirmCancelTrip(BuildContext context, CancelCost? cost) async {
  final line = cost?.line();
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('cancel_confirm_dialog'),
          backgroundColor: SgColors.bg200,
          title: Text(
            'Cancel this trip?',
            style: TextStyle(color: SgColors.ink, fontWeight: FontWeight.w600),
          ),
          content: Text(
            line ?? 'Your driver will be told the trip is cancelled.',
            key: const Key('cancel_confirm_cost'),
            style: SgText.body.copyWith(color: SgColors.inkMuted),
          ),
          actions: [
            TextButton(
              key: const Key('cancel_keep'),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Keep trip',
                style: TextStyle(color: SgColors.goldText),
              ),
            ),
            TextButton(
              key: const Key('cancel_confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Cancel trip',
                style: TextStyle(color: SgColors.danger),
              ),
            ),
          ],
        ),
      ) ??
      false;
}

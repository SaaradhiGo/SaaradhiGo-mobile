import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';

/// A card held at booking for the locked fare (USA; backend
/// servers/payments/card_hold.py). The card never reaches SaaradhiGo:
/// Stripe's own sheet takes it, the hold is done when Stripe authorises it.
class CardHold {
  const CardHold({
    required this.holdId,
    required this.clientSecret,
    required this.publishableKey,
    required this.status,
    required this.testMode,
  });

  final int holdId;
  final String? clientSecret;
  final String publishableKey;
  final String status;
  final bool testMode;

  static CardHold? fromJson(Object? json) {
    if (json is! Map) return null;
    final data = json['data'] is Map ? json['data'] as Map : json;
    final id = int.tryParse('${data['hold_id'] ?? ''}');
    if (id == null) return null;
    return CardHold(
      holdId: id,
      clientSecret: data['client_secret']?.toString(),
      publishableKey: data['publishable_key']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      testMode: data['test_mode'] == true,
    );
  }
}

/// What the booking needs to know: the hold id to send, or why there is none.
class CardHoldOutcome {
  const CardHoldOutcome.held(this.holdId) : message = null;
  const CardHoldOutcome.failed(this.message) : holdId = null;
  const CardHoldOutcome.cancelled() : holdId = null, message = null;

  final int? holdId;
  final String? message;
  bool get ok => holdId != null;
}

/// Shows Stripe's payment sheet for a hold; replaced in tests.
typedef PresentHoldSheet = Future<bool> Function(CardHold hold);

Future<bool> presentStripeHoldSheet(CardHold hold) async {
  Stripe.publishableKey = hold.publishableKey;
  await Stripe.instance.applySettings();
  await Stripe.instance.initPaymentSheet(
    paymentSheetParameters: SetupPaymentSheetParameters(
      paymentIntentClientSecret: hold.clientSecret,
      merchantDisplayName: 'SaaradhiGo',
      googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'US'),
      applePay: const PaymentSheetApplePay(merchantCountryCode: 'US'),
    ),
  );
  try {
    await Stripe.instance.presentPaymentSheet();
    return true;
  } on StripeException catch (e) {
    if (e.error.code == FailureCode.Canceled) return false;
    rethrow;
  }
}

class CardHoldService {
  CardHoldService({http.Client? client, PresentHoldSheet? present})
    : _client = client,
      _present = present ?? presentStripeHoldSheet;

  final http.Client? _client;
  final PresentHoldSheet _present;

  static const _notAvailable =
      'Card payment is not available right now. Please try again.';

  Future<Map<String, String>> _headers() async {
    final token = (await SharedPreferences.getInstance()).getString(
      'access_token',
    );
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Hold the card for [quoteId]: create the hold, let the rider confirm it in
  /// Stripe's sheet, then wait for Stripe to authorise it (a few seconds).
  Future<CardHoldOutcome> hold(String quoteId) async {
    final client = _client ?? http.Client();
    try {
      final r = await client
          .post(
            Uri.parse('${AppConfig.baseUrl}/payments/card/hold/'),
            headers: await _headers(),
            body: jsonEncode({'quote_id': quoteId}),
          )
          .timeout(const Duration(seconds: 20));
      final body = r.body.isEmpty ? null : jsonDecode(r.body);
      if (r.statusCode >= 300) {
        final err = body is Map ? body['error'] : null;
        return CardHoldOutcome.failed(
          (err is Map ? err['message']?.toString() : null) ?? _notAvailable,
        );
      }
      final hold = CardHold.fromJson(body);
      if (hold == null) return const CardHoldOutcome.failed(_notAvailable);
      if (hold.status == 'authorised') return CardHoldOutcome.held(hold.holdId);
      if ((hold.clientSecret ?? '').isEmpty || hold.publishableKey.isEmpty) {
        return const CardHoldOutcome.failed(_notAvailable);
      }
      if (!await _present(hold)) return const CardHoldOutcome.cancelled();
      for (var i = 0; i < 10; i++) {
        final s = await client
            .get(
              Uri.parse(
                '${AppConfig.baseUrl}/payments/card/hold/${hold.holdId}/',
              ),
              headers: await _headers(),
            )
            .timeout(const Duration(seconds: 10));
        final st = s.body.isEmpty ? null : jsonDecode(s.body);
        final data = st is Map && st['data'] is Map ? st['data'] as Map : st;
        final status = data is Map ? data['status']?.toString() : null;
        if (status == 'authorised') return CardHoldOutcome.held(hold.holdId);
        if (status == 'failed' || status == 'released') break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      return const CardHoldOutcome.failed(
        "Your card wasn't confirmed. Nothing was charged. Please try again.",
      );
    } on StripeException catch (e) {
      debugPrint('Card hold: Stripe sheet error ${e.error.code}');
      return CardHoldOutcome.failed(e.error.localizedMessage ?? _notAvailable);
    } catch (e) {
      debugPrint('Card hold failed: $e');
      return const CardHoldOutcome.failed(_notAvailable);
    }
  }
}

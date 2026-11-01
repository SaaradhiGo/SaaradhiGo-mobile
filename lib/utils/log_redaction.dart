/// Redact credentials before anything reaches a log line.
///
/// THE DEFECT THIS CLOSES
/// ----------------------
/// `ride_service.dart` called `debugPrint(response.body)` on the response
/// from `POST /payments/create-order/`. That body carries a Cashfree
/// **`payment_session_id`** -- the credential the checkout SDK opens a
/// payment with. Logging it in full puts a payment session into logcat,
/// where any app with log access on a rooted or shared handset can read it.
///
/// Matching is by key-name SUBSTRING, not an exact list. The driver app's
/// interceptor had an exact list, it did not contain `fcm_token`, and a push
/// token was logged in full the moment the app started registering rotated
/// tokens. The backend's `base/logging_filters.py` says the same thing in its
/// own comment: exact enumeration "would inevitably miss one".
library;

import 'dart:convert';

/// Key-name fragments whose values must never be logged.
const _sensitiveKeyFragments = <String>{
  'token',
  'secret',
  'password',
  'passwd',
  'authorization',
  'otp',
  'jwt',
  'api_key',
  'apikey',
  'credential',
  'signature',
  // Bare 'session', not 'session_id': a camelCase key lowercases to
  // `paymentsessionid`, which the underscored form does not match.
  'session',
  'cvv',
  // Payment-instrument keys only. A bare 'card' also swallows
  // `rate_card_id`, which is a pricing-schedule identifier and exactly the
  // provenance a fare dispute needs -- over-redaction looks like privacy
  // while destroying the audit trail.
  'card_number',
  'cardnumber',
  'card_no',
};

const _redacted = '[REDACTED]';

/// True when a key's name marks its value as not loggable.
bool isSensitiveLogKey(String key) {
  final lower = key.toLowerCase();
  for (final fragment in _sensitiveKeyFragments) {
    if (lower.contains(fragment)) return true;
  }
  return false;
}

/// A JSON body with every sensitive value replaced, safe to log.
///
/// Returns a short placeholder rather than the original when the body cannot
/// be parsed: an unparseable body is exactly the case where logging it
/// verbatim is most likely to spill something.
String redactedBody(String? body, {int maxLength = 600}) {
  if (body == null || body.isEmpty) return '<empty>';

  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return '<${body.length} bytes, not JSON — not logged>';
  }

  final redactedJson = jsonEncode(_redactValue(decoded, 0));
  if (redactedJson.length <= maxLength) return redactedJson;
  return '${redactedJson.substring(0, maxLength)}…<truncated>';
}

/// Depth-limited so a deeply nested or self-referential body cannot make
/// logging recurse forever.
Object? _redactValue(Object? value, int depth) {
  if (depth > 4) return '<nested>';
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(
        key.toString(),
        isSensitiveLogKey(key.toString())
            ? _redacted
            : _redactValue(item, depth + 1),
      ),
    );
  }
  if (value is Iterable) {
    return value.map((item) => _redactValue(item, depth + 1)).toList();
  }
  return value;
}

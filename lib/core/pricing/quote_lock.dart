/// The quote lock: "Locked when you book" is literally true.
///
/// `/ride/estimate-fare/` returns a `quote_id` and `quote_expires_at` beside
/// `estimated_fare`. The booking frame carries the `quote_id` of the class the
/// rider chose, and the server books at exactly that fare. When the quote has
/// expired, or the pickup, drop or class no longer match it, the server books
/// nothing and answers:
///
///   {"type": "error", "code": "QUOTE_EXPIRED", "reason": "expired"|"moved",
///    "message": ..., "fresh_quote": {...an estimate-fare response...}}
///
/// The app then shows the ticket again with the fresh fare and says why it
/// changed; the rider taps Confirm again, which books with the fresh quote.
/// Nothing is ever booked at a fare the rider did not see.
library;

import 'package:flutter/foundation.dart';

const String kQuoteExpired = 'QUOTE_EXPIRED';

/// Why the server replaced the quote.
enum QuoteChangeReason {
  /// Time passed: the quote's `quote_expires_at` is behind us.
  expired,

  /// The pickup, drop or class no longer match the quote.
  moved,
}

QuoteChangeReason quoteChangeReasonFrom(Object? raw) =>
    raw?.toString() == 'moved'
    ? QuoteChangeReason.moved
    : QuoteChangeReason.expired;

/// A fresh quote the server sent in place of the one the rider booked with.
@immutable
class QuoteRefresh {
  const QuoteRefresh({
    required this.reason,
    required this.freshQuote,
    this.vehicleType,
  });

  final QuoteChangeReason reason;

  /// The same shape as an estimate-fare response: `quote_id`,
  /// `quote_expires_at`, `estimated_fare`, `fare_breakdown`, `currency`.
  final Map<String, dynamic> freshQuote;

  /// The class the refused booking was for.
  final String? vehicleType;
}

/// The latest refused-and-re-quoted booking, until the rider books again.
class QuoteLockState extends ChangeNotifier {
  static final QuoteLockState instance = QuoteLockState();

  QuoteRefresh? _pending;
  QuoteRefresh? get pending => _pending;

  /// Records a QUOTE_EXPIRED frame. A frame without a usable fresh fare is
  /// still recorded (the booking was refused either way), so the ticket
  /// re-quotes instead of booking.
  void reportFrame(Map<String, dynamic> frame, {String? vehicleType}) {
    final fresh = frame['fresh_quote'];
    _pending = QuoteRefresh(
      reason: quoteChangeReasonFrom(frame['reason']),
      freshQuote: fresh is Map ? Map<String, dynamic>.from(fresh) : const {},
      vehicleType: vehicleType,
    );
    notifyListeners();
  }

  void clear() {
    if (_pending == null) return;
    _pending = null;
    notifyListeners();
  }
}

/// True when [frame] is the server refusing a stale or moved quote.
bool isQuoteExpiredFrame(Map<String, dynamic> frame) =>
    frame['type'] == 'error' && frame['code']?.toString() == kQuoteExpired;

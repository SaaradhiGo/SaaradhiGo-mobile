/// What a rider is told when a promo code is refused.
///
/// The codes are the backend's (`servers/ride/promos.py`,
/// `servers/promotions/rider_promos.py`): the preview endpoint answers them as
/// `error.code`, and the booking socket answers the same code in an `error`
/// frame when the code stopped applying between the preview and the booking.
/// The backend's own wording is for logs and the console; riders get one plain
/// sentence per reason, with no amounts or internal names in it.
library;

const Map<String, String> kPromoRefusalMessages = {
  'PROMO_NOT_FOUND': "That code isn't valid.",
  'PROMO_NOT_YET_VALID': "That code isn't active yet.",
  'PROMO_EXPIRED': 'That code has expired.',
  'PROMO_WRONG_ZONE': "That code isn't available for this pickup area.",
  'PROMO_MIN_FARE': "This ride doesn't meet the minimum fare for that code.",
  'PROMO_USER_LIMIT': "You've already used that code.",
  'PROMO_LIMIT_REACHED': 'That code has been fully claimed.',
  'PROMO_BUDGET_EXHAUSTED': 'That offer has ended.',
  'PROMO_NEW_RIDERS_ONLY': 'That code is for first-time riders only.',
  'PROMO_INVALID': "That code couldn't be applied.",
};

bool isPromoRefusalCode(String? code) =>
    code != null && code.startsWith('PROMO_');

/// The sentence for [code]. An unknown `PROMO_*` code (a reason added on the
/// backend later) still gets a neutral sentence rather than a raw code.
String promoRefusalMessage(String? code) =>
    kPromoRefusalMessages[code] ?? kPromoRefusalMessages['PROMO_INVALID']!;

/// Booking was refused because a code that applied at the fare screen no
/// longer does: the rider is asked to check the fare again.
String promoBookingRefusalMessage(String? code) =>
    '${promoRefusalMessage(code)} Please check the fare and book again.';

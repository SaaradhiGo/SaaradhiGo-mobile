/// What a rider is charged for a trip, read from what the API already says.
///
/// The app computes no money here. Each field is a server string
/// (`discount_amount`, `rider_payable`, `promo_discount`, `final_fare`,
/// `payment_status`), carried through unchanged.
///
/// Two sources carry the same facts under slightly different names:
///   * the booking socket's `trip_created` frame
///     (`promo_code`, `discount_amount`, `rider_payable`), kept in the ride
///     state's `rawResponse`;
///   * the trip detail (`GET /ride/trip/<id>/`): `promo_discount`,
///     `rider_payable`, `final_fare`, `actual_distance_km`, `payment_status`.
library;

import 'dart:core';

double? _d(Object? v) => double.tryParse(v?.toString() ?? '');

bool _isZero(Object? v) {
  final n = _d(v);
  return n != null && n <= 0;
}

class TripCharge {
  const TripCharge({
    this.promoCode,
    this.discount,
    this.payable,
    this.notCharged = false,
  });

  final String? promoCode;

  /// The discount, as the server sent it ("20.00"). Null when none.
  final String? discount;

  /// What the rider pays after the discount ("129.00"). Null when no promo.
  final String? payable;

  /// True when the server says nothing is owed.
  final bool notCharged;

  bool get hasPromo => discount != null;

  /// From the booking socket's accumulated frame (`rawResponse`).
  factory TripCharge.fromRide(Map<dynamic, dynamic>? raw) {
    if (raw == null) return const TripCharge();
    final discount = _d(raw['discount_amount']) != null &&
            _d(raw['discount_amount'])! > 0
        ? raw['discount_amount'].toString()
        : null;
    final payable = raw['rider_payable']?.toString();
    final code = raw['promo_code']?.toString();
    return TripCharge(
      promoCode: (code == null || code.isEmpty) ? null : code,
      discount: discount,
      payable: discount == null ? null : payable,
      notCharged: discount != null && _isZero(payable),
    );
  }

  /// From a trip detail payload (already unwrapped from `data`).
  factory TripCharge.fromTripDetail(Map<dynamic, dynamic>? trip) {
    if (trip == null) return const TripCharge();
    final d = trip['promo_discount']?.toString();
    final discount = (_d(d) != null && _d(d)! > 0) ? d : null;
    final payable = trip['rider_payable']?.toString();
    final status = trip['status']?.toString();
    final waived = trip['payment_status']?.toString() == 'waived';
    // A finished trip whose final fare is zero is one nobody was charged for
    // (a platform-funded end writes final_fare 0 and payment_status waived).
    final zeroFinal = status == 'completed' && _isZero(trip['final_fare']);
    return TripCharge(
      discount: discount,
      payable: discount == null ? null : payable,
      notCharged:
          waived || zeroFinal || (discount != null && _isZero(payable)),
    );
  }
}

/// Support ended a started trip (`operator_end.py`). The socket frame is the
/// only signal today: status `complete` with this message. A structured field
/// on the trip is a backend gap (reported); until then the wording is matched.
bool isOpsEnded(Map<dynamic, dynamic>? raw) {
  if (raw == null || raw['status']?.toString() != 'complete') return false;
  final m = (raw['message'] ?? '').toString().toLowerCase();
  return m.contains('ended by saaradhigo');
}

/// Support cancelled a trip the driver never reached (`admin_trips.py`).
bool isOpsCancelled(Map<dynamic, dynamic>? raw) {
  if (raw == null || raw['status']?.toString() != 'cancel') return false;
  final m = (raw['message'] ?? '').toString().toLowerCase();
  return m.contains('cancelled by support');
}

const String kOpsCancelledNotice =
    'SaaradhiGo support cancelled this ride. You have not been charged.';

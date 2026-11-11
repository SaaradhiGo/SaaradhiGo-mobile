/// The promo code the rider has applied on the fare screen, if any.
///
/// App-wide on purpose (like `BookingRefusalState`): the fare screen sets it,
/// the booking reads it into the `promo_code` field of the ride-request frame,
/// and the socket handler clears it when the booking is refused because the
/// code stopped applying. It is only ever set after the server accepted the
/// code at the preview, and the booking re-validates it.
library;

import 'package:flutter/foundation.dart';

import '../../widgets/promo_code_field.dart';

class PromoSelection extends ChangeNotifier {
  static final PromoSelection instance = PromoSelection();

  PromoApplyResult? _applied;
  PromoApplyResult? get applied => _applied;

  /// The code to send on the booking frame, or null for none.
  String? get code {
    final a = _applied;
    return (a != null && a.ok && a.code.isNotEmpty) ? a.code : null;
  }

  void apply(PromoApplyResult result) {
    if (!result.ok) return;
    _applied = result;
    notifyListeners();
  }

  void clear() {
    if (_applied == null) return;
    _applied = null;
    notifyListeners();
  }
}

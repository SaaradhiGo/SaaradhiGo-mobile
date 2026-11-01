/// A booking the backend refused because the city is paused or not live yet
/// (`CITY_PAUSED` / `CITY_NOT_LIVE`, servers/platform_ops/markets.py).
///
/// Neutral wording, never the generic "failed". The backend's own message does
/// not name the city, so the name comes from the configured live cities
/// (the one containing the pickup) when it can.
library;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'market_config_store.dart';

const String kCityPaused = 'CITY_PAUSED';
const String kCityNotLive = 'CITY_NOT_LIVE';

bool isBookingRefusalCode(String? code) =>
    code == kCityPaused || code == kCityNotLive;

/// "Rides are paused in Hyderabad right now" / "We're not in your area yet".
String bookingRefusalMessage(String code, {String? city}) {
  final hasCity = city != null && city.trim().isNotEmpty;
  if (code == kCityPaused) {
    return hasCity
        ? 'Rides are paused in $city right now. Please try again later.'
        : 'Rides are paused in your area right now. Please try again later.';
  }
  return hasCity ? "We're not in $city yet." : "We're not in your area yet.";
}

@immutable
class BookingRefusal {
  const BookingRefusal(this.code, this.message);
  final String code;
  final String message;
}

class BookingRefusalState extends ChangeNotifier {
  static final BookingRefusalState instance = BookingRefusalState();

  BookingRefusal? _latest;
  BookingRefusal? get latest => _latest;

  /// Records a refusal. [pickup] is used to name the city when it is one of
  /// the configured live cities.
  void report(String code, {LatLng? pickup, MarketConfigStore? store}) {
    if (!isBookingRefusalCode(code)) return;
    final city = (store ?? MarketConfigStore.instance).cityAt(pickup)?.name;
    _latest = BookingRefusal(code, bookingRefusalMessage(code, city: city));
    notifyListeners();
  }

  /// Records a refusal whose sentence the caller already worded (a promo code
  /// the booking could no longer apply).
  void reportMessage(String code, String message) {
    _latest = BookingRefusal(code, message);
    notifyListeners();
  }

  void dismiss() {
    if (_latest == null) return;
    _latest = null;
    notifyListeners();
  }
}

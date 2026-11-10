/// The market the app is running in: dialling code, currency, distance unit,
/// service area, emergency number, notices.
///
/// Source of truth is the backend's public app-config document
/// (`GET /api/v1/app-config/?country=XX&app=rider`, platform_ops/app_config.py).
/// Field names here are exactly the ones that document returns.
///
/// [MarketConfig.builtIn] is TODAY'S behaviour (India: +91, INR/₹, km,
/// Hyderabad, 112). It is what the app uses when there is neither a fresh nor a
/// cached response, so a failed fetch can never change what a rider sees.
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class CurrencyConfig {
  const CurrencyConfig({
    required this.code,
    required this.symbol,
    this.symbolPosition = 'prefix',
    this.minorUnits = 2,
  });

  final String code;
  final String symbol;
  final String symbolPosition;
  final int minorUnits;
}

class EmergencyConfig {
  const EmergencyConfig({required this.number, this.label});

  /// What to dial.
  final String number;

  /// "Police", "Emergency services"... as the backend labels the first number.
  final String? label;
}

class BoundsConfig {
  const BoundsConfig({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(LatLng p) =>
      p.latitude >= south &&
      p.latitude <= north &&
      p.longitude >= west &&
      p.longitude <= east;

  /// The box grown by roughly [km] on every side.
  BoundsConfig grownByKm(double km) {
    final dLat = km / 110.574;
    final midLat = (south + north) / 2;
    final cosLat = math.cos(midLat * math.pi / 180).abs();
    final dLng = cosLat < 0.01 ? 0.0 : km / (111.320 * cosLat);
    return BoundsConfig(
      south: south - dLat,
      west: west - dLng,
      north: north + dLat,
      east: east + dLng,
    );
  }
}

/// "Fares from here" range when app-config does not say.
const double kDefaultHomeFarePlacesMaxKm = 60;

class CityConfig {
  const CityConfig({
    required this.code,
    required this.name,
    this.center,
    this.bounds,
  });

  final String code;
  final String name;
  final LatLng? center;
  final BoundsConfig? bounds;
}

class AppNotice {
  const AppNotice({
    required this.id,
    required this.message,
    this.severity = 'info',
    this.blocking = false,
  });

  final int id;
  final String message;

  /// `info` or `warning`.
  final String severity;

  /// The backend does not send this today; a notice blocks only if one day it
  /// says so (`blocking: true`).
  final bool blocking;
}

class MarketConfig {
  const MarketConfig({
    required this.countryCode,
    required this.countryName,
    required this.callingCode,
    required this.currency,
    required this.distanceUnit,
    required this.emergency,
    required this.cities,
    this.notices = const [],
    this.nationalNumberLengths = const [],
    this.promosAvailable = false,
    this.referralsAvailable = false,
    this.isBuiltIn = false,
    this.supportPhone,
    this.cancelChargesFee,
    this.freeBeforeAccept = false,
    this.freeCancelSeconds,
    this.freeWaitMinutes,
    this.refundDays,
    this.homeFarePlacesMaxKm = kDefaultHomeFarePlacesMaxKm,
  });

  /// `country.home_fare_places_max_km`: how far from the rider a saved or
  /// recent place may be and still get a "Fares from here" card. 60 when the
  /// server does not send it.
  final double homeFarePlacesMaxKm;

  /// `country.cancel_policy.charges_fee`. False: cancelling never costs the
  /// rider anything, so a cancel action may say "Free to cancel". Null: say
  /// nothing about it.
  final bool? cancelChargesFee;

  /// `country.cancel_policy.free_before_accept` (9 Nov): cancelling costs
  /// nothing until a driver accepts, even where a fee applies after that.
  final bool freeBeforeAccept;

  /// `country.cancel_policy.free_cancel_seconds`; null while there is no
  /// window. TODO(data): no window is configured today.
  final int? freeCancelSeconds;

  /// `country.cancel_policy.free_wait_minutes`; null today.
  final int? freeWaitMinutes;

  /// `country.cancel_policy.refund_days` (working days); null hides the
  /// refund-time line.
  final int? refundDays;

  /// True only when the config says cancelling costs nothing.
  bool get freeToCancel => cancelChargesFee == false;

  /// `country.support.phone`: SaaradhiGo's own support line, or null while
  /// none is configured. The call row is hidden then; the app showed the
  /// placeholder 1800-000-0000 before (PRODUCT_AUDIT §8).
  final String? supportPhone;

  /// ISO country code, upper case ("IN", "US").
  final String countryCode;
  final String countryName;

  /// Digits only, no plus ("91", "1").
  final String callingCode;
  final CurrencyConfig currency;

  /// `km` or `mi`.
  final String distanceUnit;
  final EmergencyConfig emergency;

  /// Live cities. Empty means "the server named none": the service-area check
  /// then falls back to the built-in Hyderabad polygon.
  final List<CityConfig> cities;
  final List<AppNotice> notices;

  /// `country.phone.national_number_lengths`: the digit counts a national
  /// number may have here ([10] for India). Empty when the server sent none.
  final List<int> nationalNumberLengths;

  /// `promos_available` from app-config: true only while a rider promo is live
  /// in this market. The promo-code entry is hidden unless it is true; a
  /// document without the key (an older backend) reads as false, which is
  /// exactly how the app behaved before promos existed.
  final bool promosAvailable;

  /// `referrals_available` from app-config (named with `app=rider`): true only
  /// while a referral offer is live for riders in this market. The referral
  /// entry (menu item and the sign-up code field) is hidden unless it is true;
  /// a document without the key reads as false.
  final bool referralsAvailable;
  final bool isBuiltIn;

  /// `+91`, `+1`: what the phone field shows and E.164 numbers start with.
  String get dialPrefix => '+$callingCode';

  String get currencySymbol => currency.symbol;
  String get currencyCode => currency.code;

  /// "Hyderabad", "Hyderabad and Warangal", "Hyderabad, Vijayawada and Warangal".
  String get cityNames {
    final names = cities.map((c) => c.name).toList();
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  /// A phone-number hint in this market's style, e.g. "+91 98765 43210":
  /// the dialling code plus a sample national number of the configured
  /// length. Null when the length is not known, so the caller shows a neutral
  /// hint instead.
  String? get phoneHint {
    if (nationalNumberLengths.isEmpty || callingCode.isEmpty) return null;
    final n = nationalNumberLengths.first;
    if (n < 4 || n > 15) return null;
    final digits = List.generate(n, (i) => '9876543210'[i % 10]).join();
    final cut = (n + 1) ~/ 2;
    return '$dialPrefix ${digits.substring(0, cut)} ${digits.substring(cut)}';
  }

  /// Address-form hints in this market's style. India and the US get a
  /// local-looking sample; any other (or unknown) market gets a neutral label
  /// rather than a wrong-country example.
  String get streetAddressHint => switch (countryCode.toUpperCase()) {
    'IN' => 'Road No. 12, Banjara Hills',
    'US' => '123 Main Street',
    _ => 'Street address',
  };

  /// A sample postal code: a 6-digit PIN in India, a 5-digit ZIP in the US.
  String get postalCodeHint => switch (countryCode.toUpperCase()) {
    'IN' => '500034',
    'US' => '78701',
    _ => 'Postal code',
  };

  /// The postal-code field's label: "PIN code" / "ZIP code" / "Postal code".
  String get postalCodeLabel => switch (countryCode.toUpperCase()) {
    'IN' => 'PIN code',
    'US' => 'ZIP code',
    _ => 'Postal code',
  };

  /// A short distance string in this market's unit: "12.3 km" / "7.6 mi".
  String formatDistanceKm(double km, {int decimals = 1}) {
    if (distanceUnit == 'mi') {
      return '${(km * 0.621371).toStringAsFixed(decimals)} mi';
    }
    return '${km.toStringAsFixed(decimals)} km';
  }

  /// Display form of the app's internal distance string ("12.3 km"). The
  /// pipeline (fare requests, ETA maths) stays in km; only what the rider READS
  /// changes unit. Null in, null out. India (km) returns the string untouched.
  String? displayDistance(String? raw) {
    if (raw == null || distanceUnit != 'mi') return raw;
    final m = RegExp(r'(\d+\.?\d*)').firstMatch(raw);
    if (m == null) return raw;
    return formatDistanceKm(double.parse(m.group(1)!));
  }

  /// The placeholder shown while a distance is unknown: "-- km" / "-- mi".
  String get distancePlaceholder => '-- $distanceUnit';

  /// TODAY'S behaviour.
  static const MarketConfig builtIn = MarketConfig(
    countryCode: 'IN',
    countryName: 'India',
    callingCode: '91',
    currency: CurrencyConfig(code: 'INR', symbol: '₹'),
    distanceUnit: 'km',
    emergency: EmergencyConfig(number: '112', label: 'Emergency services'),
    nationalNumberLengths: [10],
    cities: [
      CityConfig(
        code: 'HYD',
        name: 'Hyderabad',
        center: LatLng(17.3850, 78.4867),
      ),
    ],
    isBuiltIn: true,
  );

  /// Parses the `data` object of the app-config response. Tolerant: any piece
  /// that is missing or malformed falls back to the built-in value, so a
  /// partial document can never break a screen.
  factory MarketConfig.fromData(Map<String, dynamic> data) {
    const base = MarketConfig.builtIn;
    final country = _map(data['country']);
    final currency = _map(country['currency']);
    final emergency = _map(country['emergency']);
    final numbers = emergency['numbers'];
    String? number;
    if (numbers is List && numbers.isNotEmpty) {
      number = _str(_map(numbers.first)['number']);
    }

    final callingCode = _digits(
      _str(country['calling_code']) ??
          _str(_map(country['phone'])['calling_code']),
    );

    final lengths = <int>[];
    final rawLengths = _map(country['phone'])['national_number_lengths'];
    if (rawLengths is List) {
      for (final l in rawLengths) {
        if (l is num && l > 0) lengths.add(l.toInt());
      }
    }

    final cities = <CityConfig>[];
    final rawCities = data['cities'];
    if (rawCities is List) {
      for (final c in rawCities) {
        final m = _map(c);
        final code = _str(m['code']);
        final name = _str(m['name']);
        if (code == null || name == null) continue;
        final area = _map(m['service_area']);
        final center = _map(area['center']);
        final b = _map(area['bounds']);
        final lat = _num(center['lat']);
        final lng = _num(center['lng']);
        final s = _num(b['south']);
        final w = _num(b['west']);
        final n = _num(b['north']);
        final e = _num(b['east']);
        cities.add(
          CityConfig(
            code: code,
            name: name,
            center: (lat != null && lng != null) ? LatLng(lat, lng) : null,
            bounds: (s != null && w != null && n != null && e != null)
                ? BoundsConfig(south: s, west: w, north: n, east: e)
                : null,
          ),
        );
      }
    }

    final notices = <AppNotice>[];
    final rawNotices = data['notices'];
    if (rawNotices is List) {
      for (final n in rawNotices) {
        final m = _map(n);
        final message = _str(m['message']);
        if (message == null) continue;
        notices.add(
          AppNotice(
            id: (m['id'] is num) ? (m['id'] as num).toInt() : message.hashCode,
            message: message,
            severity: _str(m['severity']) ?? 'info',
            blocking: m['blocking'] == true,
          ),
        );
      }
    }

    final countryCode = _str(country['code'])?.toUpperCase();
    final unit = _str(country['distance_unit']);
    return MarketConfig(
      countryCode: countryCode ?? base.countryCode,
      countryName: _str(country['name']) ?? base.countryName,
      callingCode: callingCode ?? base.callingCode,
      currency: CurrencyConfig(
        code: _str(currency['code']) ?? base.currency.code,
        symbol: _str(currency['symbol']) ?? base.currency.symbol,
        symbolPosition:
            _str(currency['symbol_position']) ?? base.currency.symbolPosition,
        minorUnits: (currency['minor_units'] is num)
            ? (currency['minor_units'] as num).toInt()
            : base.currency.minorUnits,
      ),
      distanceUnit: (unit == 'mi' || unit == 'km') ? unit! : base.distanceUnit,
      emergency: EmergencyConfig(
        number: number ?? base.emergency.number,
        label: _str(emergency['label']) ?? base.emergency.label,
      ),
      cities: cities,
      notices: notices,
      nationalNumberLengths: lengths.isNotEmpty
          ? lengths
          : (country.isEmpty ? base.nationalNumberLengths : const <int>[]),
      promosAvailable: data['promos_available'] == true,
      referralsAvailable: data['referrals_available'] == true,
      supportPhone: _str(_map(country['support'])['phone']),
      cancelChargesFee: _map(country['cancel_policy'])['charges_fee'] is bool
          ? _map(country['cancel_policy'])['charges_fee'] as bool
          : null,
      freeBeforeAccept:
          _map(country['cancel_policy'])['free_before_accept'] == true,
      freeCancelSeconds: _int(
        _map(country['cancel_policy'])['free_cancel_seconds'],
      ),
      freeWaitMinutes: _int(
        _map(country['cancel_policy'])['free_wait_minutes'],
      ),
      refundDays:
          _int(_map(country['cancel_policy'])['refund_days']) ??
          _int(country['refund_days']),
      homeFarePlacesMaxKm:
          (country['home_fare_places_max_km'] is num &&
              (country['home_fare_places_max_km'] as num) > 0)
          ? (country['home_fare_places_max_km'] as num).toDouble()
          : kDefaultHomeFarePlacesMaxKm,
    );
  }
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

int? _int(Object? v) => v is num && v >= 0 ? v.toInt() : null;

String? _digits(String? v) {
  if (v == null) return null;
  final d = v.replaceAll(RegExp(r'[^0-9]'), '');
  return d.isEmpty ? null : d;
}

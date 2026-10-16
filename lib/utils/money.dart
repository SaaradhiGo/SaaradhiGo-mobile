/// Money formatting for the rider app.
///
/// THE DEFECT THIS CLOSES
/// ----------------------
/// The fare screen did this:
///
///     final currency = rideData?['currency'] ?? '₹';
///     ...
///     '$currency$totalFareStr'
///
/// which treats the field as a *symbol*. It worked only while the server did
/// not send the field at all and the `?? '₹'` fallback supplied one. The
/// backend now returns an ISO 4217 **code** on every quote, so that line
/// rendered a rider's fare as:
///
///     INR169.02
///
/// Verified against deployed QA on 2026-10-17: `/ride/estimate-fare/` returns
/// `"currency": "INR"` alongside `"estimated_fare": "169.02"`.
///
/// So the app takes a code and resolves a symbol, in one place.
///
/// WHY NOT NumberFormat.currency
/// -----------------------------
/// `intl`'s `NumberFormat.simpleCurrency` would also map a code to a symbol,
/// but it formats according to the *locale*, which puts the digits in a layout
/// the server did not choose: an Indian locale renders 169.02 in the lakh
/// grouping, and a US locale would render a rupee amount with Western
/// grouping. The server already decided the number of decimals and sends the
/// amount as a string precisely so no client re-rounds it. This formatter
/// therefore touches the symbol and never the digits.
library;

/// ISO 4217 code -> the symbol a rider should see.
///
/// Mirrors `base/money.py` on the backend, which is the authority. Kept small
/// on purpose: a currency the platform does not serve has no business having a
/// symbol guessed for it here.
const Map<String, String> _symbols = <String, String>{
  'INR': '₹',
  'USD': '\$',
};

/// Currencies whose symbol goes before the amount. Every currency the platform
/// serves today is a prefix currency; the field exists because the euro and the
/// Scandinavian currencies are not, and the backend models the same thing.
const Set<String> _suffixCurrencies = <String>{};

/// The default when the server sends nothing at all.
///
/// India, because that is the only market with riders. An older server build
/// that omits `currency` therefore behaves exactly as the app did before.
const String kDefaultCurrency = 'INR';

/// The symbol for an ISO code, or the code itself when it is unknown.
///
/// An unknown code returns the code followed by a non-breaking space, never
/// glued to the digits -- "CAD 42.00" is a readable price, "CAD42.00" is the
/// bug this file exists to prevent.
String currencySymbol(String? code) {
  final normalised = normaliseCurrency(code);
  return _symbols[normalised] ?? '$normalised ';
}

/// Upper-cases and trims a code, falling back to [kDefaultCurrency].
///
/// Tolerant on purpose: this runs on a response payload, and a quote that
/// renders with the wrong symbol is better than a booking screen that throws.
String normaliseCurrency(String? code) {
  final trimmed = (code ?? '').trim().toUpperCase();
  if (trimmed.isEmpty) return kDefaultCurrency;
  return trimmed;
}

/// `amount` rendered in `currencyCode`.
///
/// [amount] may be a String (what DRF sends for a Decimal), an int or a
/// double. Returns null when it is absent or unparseable, so a caller can omit
/// a line rather than print a zero a rider would read as a real charge.
///
/// [decimals] defaults to 2 because that is what every money field on this
/// platform carries. Pass 0 for a map pin or a vehicle tile where the decimals
/// are noise.
String? formatMoney(
  dynamic amount,
  String? currencyCode, {
  int decimals = 2,
}) {
  if (amount == null) return null;
  final value =
      amount is num ? amount.toDouble() : double.tryParse(amount.toString());
  if (value == null) return null;

  final code = normaliseCurrency(currencyCode);
  final symbol = currencySymbol(code);
  final digits = value.toStringAsFixed(decimals);

  return _suffixCurrencies.contains(code)
      ? '$digits $symbol'
      : '$symbol$digits';
}

/// Like [formatMoney] but keeps the server's own digit string untouched.
///
/// For a value the server already formatted ("169.02"), where re-parsing to a
/// double and re-rounding is a chance to change a number the rider is about to
/// be charged.
///
/// Only a **String** is passed through. A `num` is delegated to [formatMoney]
/// and gets two decimals: Dart renders the double 87.5 as "87.5", and
/// "₹87.5" is not a price. A pre-existing widget test caught exactly that.
String? formatServerMoney(dynamic amount, String? currencyCode) {
  if (amount == null) return null;
  if (amount is! String) return formatMoney(amount, currencyCode);

  final raw = amount.trim();
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(raw)) {
    return formatMoney(amount, currencyCode);
  }

  final code = normaliseCurrency(currencyCode);
  final symbol = currencySymbol(code);
  return _suffixCurrencies.contains(code) ? '$raw $symbol' : '$symbol$raw';
}

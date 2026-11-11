/// "Choose a ride" (design: MobileBooking, Choose a ride).
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../core/vehicle_classes.dart';
import '../utils/money.dart' show currencySymbol;
import '../l10n/app_localizations.dart';
import 'appearance_settings.dart' show sgStrings;
import 'sg_text.dart';
import 'sg_tokens.dart';
import 'sg_widgets.dart';

/// "92 mins" -> "92 min": the app says min everywhere.
String minLabel(String s) =>
    s.replaceAllMapped(RegExp(r'\b(mins|minutes|minute)\b'), (_) => 'min');

/// One bookable class, built from a `/ride/estimate-fare/` response.
class RideOption {
  const RideOption({
    required this.type,
    required this.name,
    required this.fare,
    required this.fareText,
    required this.meta,
    this.reason,
    this.etaMin,
    this.driversNearby = true,
    this.seats,
    this.locked = false,
    this.quoteExpiresAt,
  });

  /// True when the quote carries a `quote_id`: booking holds this fare.
  final bool locked;

  /// The quote's `quote_expires_at`, when sent.
  final DateTime? quoteExpiresAt;

  /// Seats in the class: the quote's `seats` when sent, else the table.
  final int? seats;

  /// [meta] in the rider's language.
  String metaIn(AppLocalizations l) => [
    if (seats != null) l.seatsCount(seats!),
    if (!driversNearby)
      l.noDriversNearby
    else if (etaMin != null)
      l.minutesShort(etaMin!),
  ].join(' · ');

  /// Backend identifier (`sedan`); never shown.
  final String type;

  /// "Saaradhi Sedan".
  final String name;
  final double fare;
  final String fareText;

  /// "5 min · 4 seats", from what the API returned.
  final String meta;

  /// Minutes until a driver reaches the pickup; null when the quote has none.
  final int? etaMin;

  /// False only when the quote says no driver is near; unknown counts as true.
  final bool driversNearby;

  /// Why the price is higher than usual, if the API says so.
  final String? reason;

  String get shortName => vehicleClassName(type);

  static const _etaKeys = [
    'pickup_eta_min',
    'eta_min',
    'eta_minutes',
    'pickup_eta',
    'driver_eta_min',
  ];
  static const _seatKeys = [
    'seats',
    'seat_count',
    'seating_capacity',
    'capacity',
  ];

  static num? _num(Map<String, dynamic> m, List<String> keys) {
    for (final src in [
      m,
      if (m['vehicle'] is Map) (m['vehicle'] as Map).cast<String, dynamic>(),
    ]) {
      for (final k in keys) {
        final v = src[k];
        if (v is num) return v;
        final p = num.tryParse(v?.toString() ?? '');
        if (p != null) return p;
      }
    }
    return null;
  }

  static String _money(double v, String symbol) {
    final f = NumberFormat.decimalPattern(symbol == '₹' ? 'en_IN' : 'en_US');
    return '$symbol${f.format(v.round())}';
  }

  /// A server reason, with the word "surge" never reaching the rider.
  static String? _reason(Map<String, dynamic> e) {
    // `rider_reason` (Night 2 field) is written for riders: shown verbatim.
    final rider = e['rider_reason']?.toString().trim();
    if (rider != null && rider.isNotEmpty) return rider;
    final raw = (e['price_reason'] ?? e['fare_reason'] ?? e['surge_reason'])
        ?.toString()
        .trim();
    if (raw != null && raw.isNotEmpty) {
      return RegExp('surge', caseSensitive: false).hasMatch(raw)
          ? 'Higher demand right now'
          : raw;
    }
    final bd = e['fare_breakdown'];
    final m = bd is Map
        ? num.tryParse(bd['surge_multiplier']?.toString() ?? '')
        : null;
    return (m != null && m > 1) ? 'Higher demand right now' : null;
  }

  static RideOption? fromEstimate(String type, Map<String, dynamic> e) {
    final fare = double.tryParse(e['estimated_fare']?.toString() ?? '');
    if (fare == null) return null;
    final eta = _num(e, _etaKeys);
    final seats = _num(e, _seatKeys) ?? vehicleClassSeats(type);
    final nearby = e['drivers_nearby'] != false;
    final parts = <String>[
      if (seats != null) '${seats.toInt()} ${seats == 1 ? 'seat' : 'seats'}',
      if (!nearby)
        'No drivers nearby'
      else if (eta != null)
        '${eta.ceil()} min',
    ];
    return RideOption(
      type: type,
      name: 'Saaradhi ${vehicleClassName(type)}',
      fare: fare,
      fareText: _money(fare, currencySymbol(e['currency']?.toString())),
      meta: parts.join(' · '),
      reason: _reason(e),
      etaMin: nearby ? eta?.ceil() : null,
      driversNearby: nearby,
      seats: seats?.toInt(),
      locked: (e['quote_id']?.toString() ?? '').isNotEmpty,
      quoteExpiresAt: DateTime.tryParse(
        e['quote_expires_at']?.toString() ?? '',
      ),
    );
  }

  /// Priced classes only, cheapest first.
  static List<RideOption> fromEstimates(
    Map<String, Map<String, dynamic>> estimates,
  ) {
    final out = [
      for (final e in estimates.entries) ?fromEstimate(e.key, e.value),
    ]..sort((a, b) => a.fare.compareTo(b.fare));
    return out;
  }
}

/// The class the rider used last if offered, else sedan if offered, else the first.
String? preselectVehicle(List<String> offered, String? lastUsed) {
  if (offered.isEmpty) return null;
  final last = lastUsed?.trim().toLowerCase();
  if (last != null && offered.contains(last)) return last;
  if (offered.contains('sedan')) return 'sedan';
  return offered.first;
}

/// Cheapest and Fastest, each only when one class alone has it.
///
/// Cheapest is the lowest fare; Fastest the lowest non-null pickup ETA. A tie
/// gets no tag rather than two.
({String? cheapest, String? fastest}) rideTags(List<RideOption> options) {
  String? unique(Iterable<(String, num)> xs) {
    if (xs.isEmpty) return null;
    final low = xs.map((x) => x.$2).reduce((a, b) => a < b ? a : b);
    final at = xs.where((x) => x.$2 == low).toList();
    return at.length == 1 ? at.single.$1 : null;
  }

  return (
    cheapest: unique([for (final o in options) (o.type, o.fare)]),
    fastest: unique([
      for (final o in options)
        if (o.etaMin != null) (o.type, o.etaMin!),
    ]),
  );
}

/// Whole minutes the quote is still held, or null when there is no expiry
/// or it has passed.
int? heldMinutes(DateTime? expiresAt, {DateTime? now}) {
  if (expiresAt == null) return null;
  final left = expiresAt.difference(now ?? DateTime.now());
  if (left.inSeconds <= 0) return null;
  return (left.inSeconds / 60).ceil();
}

/// The card icon (design: payment row).
const kCardIconBody =
    '<rect x="3" y="6" width="18" height="14" rx="2"/><path d="M3 10h18M16 15h2"/>';

/// "Choose a ride" (signed-in design rider-app-choose): one row per priced
/// class with its locked fare, the payment method, how long the fare is
/// held, and Book.
class ChooseRideSheet extends StatelessWidget {
  const ChooseRideSheet({
    super.key,
    required this.options,
    required this.selectedType,
    required this.onSelect,
    required this.onConfirm,
    required this.paymentLabel,
    this.summary,
    this.route,
    this.onChangePayment,
    this.footer,
  });

  final List<RideOption> options;
  final String? selectedType;
  final ValueChanged<String> onSelect;
  final VoidCallback onConfirm;

  /// "12.4 km · 24 min". The design does not show it; kept for callers.
  final String? summary;

  /// "Banjara Hills → Mindspace". The design does not show it; kept for callers.
  final String? route;
  final String paymentLabel;
  final VoidCallback? onChangePayment;

  /// Below the rows inside the scroll area (promo code).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l = sgStrings(context);
    RideOption? selected;
    for (final o in options) {
      if (o.type == selectedType) selected = o;
    }
    final held = selected == null || !selected.locked
        ? null
        : heldMinutes(selected.quoteExpiresAt);
    return SgSheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.chooseARide,
            key: const Key('choose_title'),
            style: SgText.title,
          ),
          const SizedBox(height: SgSpace.s3),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final o in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SgSpace.s3),
                    child: _RideRow(
                      option: o,
                      selected: o.type == selectedType,
                      onTap: () => onSelect(o.type),
                    ),
                  ),
                ?footer,
              ],
            ),
          ),
          // The demand line: the server's reason verbatim, or "Higher demand
          // right now". Never the word surge.
          if (selected?.reason != null)
            Padding(
              key: const Key('choose_demand'),
              padding: const EdgeInsets.only(bottom: SgSpace.s2),
              child: Text(selected!.reason!, style: SgText.caption),
            ),
          Row(
            children: [
              InkWell(
                key: const Key('choose_payment'),
                onTap: onChangePayment,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SgIcon(kCardIconBody, size: 16, color: SgColors.ink),
                      const SizedBox(width: 6),
                      Text(
                        paymentLabel,
                        style: SgText.caption.copyWith(color: SgColors.ink),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (held != null)
                Row(
                  key: const Key('choose_held'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SgIcon(SgIcons.lock, size: 14, color: SgColors.pickup),
                    const SizedBox(width: 6),
                    Text(
                      l.fareHeldMin(held),
                      style: SgText.caption.copyWith(color: SgColors.pickup),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: SgSpace.s3),
          SgPrimaryButton(
            key: const Key('choose_book'),
            label: selected == null
                ? l.selectRide
                : l.bookClass(selected.shortName, selected.fareText),
            onPressed: selected == null ? null : onConfirm,
          ),
        ],
      ),
    );
  }
}

/// A small pill: Cheapest / Fastest.
class SgTag extends StatelessWidget {
  const SgTag(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SgColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(SgRadius.pill),
      ),
      child: Text(
        text,
        style: SgText.caption.copyWith(
          color: c,
          fontSize: SgText.sizeSmall,
          height: 16 / 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RideRow extends StatelessWidget {
  const _RideRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });
  final RideOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = sgStrings(context);
    final meta = option.metaIn(l);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: Key('ride_row_${option.type}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: SgMotion.press,
          curve: SgMotion.curve,
          // The 2px selected border takes its extra pixel from the padding,
          // so the row does not jump.
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 11 : 12,
            vertical: selected ? 9 : 10,
          ),
          decoration: BoxDecoration(
            color: SgColors.bg100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? SgColors.ink : SgColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: vehicleTileColour(option.type),
                  borderRadius: BorderRadius.circular(SgSpace.s3),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    vehicleClassAsset(option.type),
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      vehicleIconColour(option.type),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SgSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SgText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: option.driversNearby
                            ? SgText.caption
                            : SgText.caption.copyWith(
                                color: SgColors.inkSubtle,
                              ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: SgSpace.s2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    option.fareText,
                    style: SgText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (option.locked)
                    Text(
                      l.locked,
                      key: Key('ride_locked_${option.type}'),
                      style: SgText.caption.copyWith(color: SgColors.pickup),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

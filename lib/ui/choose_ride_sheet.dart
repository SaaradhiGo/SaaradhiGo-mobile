/// "Choose a ride" (design: MobileBooking, Choose a ride).
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../core/vehicle_classes.dart';
import '../utils/money.dart' show currencySymbol;
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
  });

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

  static const _etaKeys = ['pickup_eta_min', 'eta_min', 'eta_minutes', 'pickup_eta', 'driver_eta_min'];
  static const _seatKeys = ['seats', 'seat_count', 'seating_capacity', 'capacity'];

  static num? _num(Map<String, dynamic> m, List<String> keys) {
    for (final src in [m, if (m['vehicle'] is Map) (m['vehicle'] as Map).cast<String, dynamic>()]) {
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
    final raw = (e['price_reason'] ?? e['fare_reason'] ?? e['surge_reason'])?.toString().trim();
    if (raw != null && raw.isNotEmpty) {
      return RegExp('surge', caseSensitive: false).hasMatch(raw) ? 'Higher demand right now' : raw;
    }
    final bd = e['fare_breakdown'];
    final m = bd is Map ? num.tryParse(bd['surge_multiplier']?.toString() ?? '') : null;
    return (m != null && m > 1) ? 'Higher demand right now' : null;
  }

  static RideOption? fromEstimate(String type, Map<String, dynamic> e) {
    final fare = double.tryParse(e['estimated_fare']?.toString() ?? '');
    if (fare == null) return null;
    final eta = _num(e, _etaKeys);
    final seats = _num(e, _seatKeys) ?? vehicleClassSeats(type);
    final nearby = e['drivers_nearby'] != false;
    final parts = <String>[
      if (!nearby) 'No drivers nearby' else if (eta != null) '${eta.ceil()} min',
      if (seats != null) '${seats.toInt()} ${seats == 1 ? 'seat' : 'seats'}',
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
    );
  }

  /// Priced classes only, cheapest first.
  static List<RideOption> fromEstimates(Map<String, Map<String, dynamic>> estimates) {
    final out = [
      for (final e in estimates.entries)
        ?fromEstimate(e.key, e.value),
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

class ChooseRideSheet extends StatelessWidget {
  const ChooseRideSheet({
    super.key,
    required this.options,
    required this.selectedType,
    required this.onSelect,
    required this.onConfirm,
    required this.paymentLabel,
    this.summary,
    this.onChangePayment,
    this.footer,
  });

  final List<RideOption> options;
  final String? selectedType;
  final ValueChanged<String> onSelect;
  final VoidCallback onConfirm;

  /// "12.4 km · 24 min".
  final String? summary;
  final String paymentLabel;
  final VoidCallback? onChangePayment;

  /// Below the rows inside the scroll area (fare details, promo code).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    RideOption? selected;
    for (final o in options) {
      if (o.type == selectedType) selected = o;
    }
    return SgSheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('Choose a ride', style: SgText.title.copyWith(fontSize: 20, height: 26 / 20))),
              ?(summary == null ? null : Text(summary!, style: SgText.caption)),
            ],
          ),
          const SizedBox(height: SgSpace.s3),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final o in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SgSpace.s2),
                    child: _RideRow(
                      option: o,
                      selected: o.type == selectedType,
                      onTap: () => onSelect(o.type),
                    ),
                  ),
                if (footer != null) footer!,
              ],
            ),
          ),
          if (selected?.reason != null)
            Padding(
              padding: const EdgeInsets.only(top: SgSpace.s2),
              child: Text(selected!.reason!, style: SgText.caption),
            ),
          const SizedBox(height: SgSpace.s2),
          Container(
            height: kSgTouch,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: SgColors.line)),
            ),
            child: Row(
              children: [
                const SgIcon(SgIcons.cash, size: 20),
                const SizedBox(width: SgSpace.s3),
                Expanded(child: Text(paymentLabel, style: SgText.body)),
                if (onChangePayment != null)
                  TextButton(
                    onPressed: onChangePayment,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(kSgTouch, kSgTouch),
                      foregroundColor: SgColors.goldText,
                    ),
                    child: Text('Change',
                        style: SgText.body.copyWith(color: SgColors.goldText, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: SgSpace.s2),
          SgPrimaryButton(
            label: selected == null
                ? 'Select a ride'
                : 'Confirm ${selected.shortName} · ${selected.fareText}',
            onPressed: selected == null ? null : onConfirm,
          ),
        ],
      ),
    );
  }
}

class _RideRow extends StatelessWidget {
  const _RideRow({required this.option, required this.selected, required this.onTap});
  final RideOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(SgRadius.md),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: SgSpace.s3, vertical: SgSpace.s2),
          decoration: BoxDecoration(
            color: selected ? SgColors.goldSoft : SgColors.bg200,
            borderRadius: BorderRadius.circular(SgRadius.md),
            border: Border.all(
              color: selected ? SgColors.gold500 : SgColors.lineStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(
                  color: SgColors.bg300,
                  borderRadius: BorderRadius.circular(SgRadius.sm),
                ),
                child: Center(
                  child: SvgPicture.asset(vehicleClassAsset(option.type), width: 30, height: 30),
                ),
              ),
              const SizedBox(width: SgSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SgText.body.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (option.meta.isNotEmpty)
                      Text(option.meta,
                          style: option.driversNearby
                              ? SgText.caption
                              : SgText.caption.copyWith(color: SgColors.inkSubtle)),
                  ],
                ),
              ),
              Text(option.fareText, style: SgText.fare),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rider-facing fare transparency.
///
/// This was a finished widget sitting unrendered inside rider_flow_screens.dart
/// behind an `ignore_for_file: unused_element`. The booking screen showed a
/// rider one number per vehicle type and nothing about how it was reached, even
/// though `/ride/estimate-fare/` already returns the components.
///
/// It reads the server's numbers and does no arithmetic of its own. Fare
/// computation belongs on the server -- the backend comment on `estimate_fare`
/// is explicit that trusting client-supplied distance was the audit's primary
/// fare-tampering vector, and a second implementation here would be a second
/// answer to the same question.
///
/// Nothing on screen names an internal concept. A rider sees "Base fare" and
/// "Busy-time surcharge", never FarePricing, RateCard or fare_basis.
library;

import 'package:flutter/material.dart';

/// Formats a money value that may arrive as a String, an int or a double.
///
/// DRF serialises Decimal as a String by default, so a breakdown field is
/// usually `"42.50"` and occasionally a number. The previous version of this
/// widget compared `fareBreakdown['discount'] > 0` directly, which throws at
/// runtime the moment the server sends the String it actually sends.
String? _money(dynamic raw, {String currency = '₹'}) {
  if (raw == null) return null;
  final value = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
  if (value == null) return null;
  return '$currency${value.toStringAsFixed(2)}';
}

/// True only when [raw] parses to a number strictly greater than zero.
bool _isPositive(dynamic raw) {
  if (raw == null) return false;
  final value = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
  return value != null && value > 0;
}

/// A single labelled amount.
class FareLine extends StatelessWidget {
  const FareLine(
    this.label,
    this.value, {
    super.key,
    this.color = Colors.white,
    this.bold = false,
    this.note,
  });

  final String label;
  final String value;
  final Color color;
  final bool bold;

  /// Optional smaller line under the label, for explaining a charge rather
  /// than leaving the rider to guess what it is.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontSize: bold ? 18 : 15,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      note!,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// The breakdown panel.
///
/// [fareData] is a `/ride/estimate-fare/` response or a trip detail payload.
/// Both carry `estimated_fare`/`total_fare` and a `fare_breakdown` map.
///
/// Every line is null-guarded, so a field the server does not send simply does
/// not appear rather than rendering a zero the rider would read as a real
/// charge. `waiting_fare` and `taxes` are not in the quote response today; they
/// will render the day it includes them, with no change here.
class FareBreakdown extends StatelessWidget {
  const FareBreakdown({
    super.key,
    this.fareData,
    this.showHeading = true,
  });

  final Map<String, dynamic>? fareData;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    final breakdown = fareData?['fare_breakdown'] as Map<String, dynamic>?;
    final total = _money(
      fareData?['total_fare'] ?? fareData?['estimated_fare'],
    );

    final lines = <Widget>[];

    void add(String label, dynamic raw, {String? note, Color? color}) {
      final formatted = _money(raw);
      if (formatted == null) return;
      lines.add(FareLine(label, formatted, note: note,
          color: color ?? Colors.white));
    }

    if (breakdown != null) {
      add('Base fare', breakdown['base_fare'],
          note: 'Charged on every trip');
      add('Distance', breakdown['distance_fare'],
          note: 'For the distance travelled');
      add('Time', breakdown['time_fare'],
          note: 'For the time the trip takes');
      add('Waiting', breakdown['waiting_fare'],
          note: 'If your driver waits at pickup');
      add('Taxes and fees', breakdown['taxes']);

      // Surge is disclosed, not hidden. A rider paying a multiplier is entitled
      // to be told, and India's Motor Vehicles Aggregator Guidelines 2020 both
      // cap surge and require it to be shown. Only rendered when it is actually
      // above 1x, so an ordinary trip is not cluttered by "1.0x".
      final surge = breakdown['surge_multiplier'];
      final surgeValue = surge is num
          ? surge.toDouble()
          : double.tryParse(surge?.toString() ?? '');
      if (surgeValue != null && surgeValue > 1.0) {
        lines.add(
          FareLine(
            'Busy-time surcharge',
            '${surgeValue.toStringAsFixed(1)}x',
            note: 'Demand is high right now, so fares are raised',
            color: const Color(0xFFEEBD2B),
          ),
        );
      }

      // A minimum fare that has kicked in is the difference between the rider's
      // arithmetic and ours, so it gets said out loud -- but only once. When the
      // server sends an explicit `minimum_fare` adjustment with the actual uplift,
      // that line is strictly better than this valueless flag, so this one stands
      // down rather than showing the same fact twice.
      final adjustmentCodes = <String>{
        for (final a in (fareData?['fare_adjustments'] is List
                ? fareData!['fare_adjustments'] as List
                : const []))
          if (a is Map && a['code'] != null) a['code'].toString(),
      };
      if (breakdown['min_fare_applied'] == true &&
          !adjustmentCodes.contains('minimum_fare')) {
        lines.add(
          const FareLine(
            'Minimum fare applied',
            '',
            note: 'Short trips are charged a minimum',
          ),
        );
      }

      // Named adjustment lines from the server that close the gap between the
      // metered components and the amount charged.
      //
      // Without these the panel showed base + distance + time beside a total they
      // did not sum to -- QA trip 45 displayed 60.00 + 55.59 + 19.62 next to a
      // charged 135.22. A rider who adds up an itemised fare and gets a different
      // number has been handed a reason to distrust the whole receipt.
      //
      // The server decides what these are and what they are called; this widget
      // renders them and does no arithmetic of its own.
      final adjustments = fareData?['fare_adjustments'];
      if (adjustments is List) {
        for (final raw in adjustments) {
          if (raw is! Map) continue;
          final amount = _money(raw['amount']);
          if (amount == null) continue;
          final label = (raw['label'] ?? raw['code'] ?? 'Adjustment').toString();
          final code = (raw['code'] ?? '').toString();
          lines.add(
            FareLine(
              label,
              amount,
              note: code == 'rounding'
                  ? 'Rounded to the nearest paisa'
                  : (code == 'minimum_fare'
                      ? 'Short trips are charged a minimum'
                      : null),
              color: code == 'surge'
                  ? const Color(0xFFEEBD2B)
                  : Colors.white,
            ),
          );
        }
      }

      // Promotions are not live. `_isPositive` means an inactive promo sending
      // "0.00" cannot render a "Promo discount" line worth nothing, which would
      // read as a broken promise.
      if (_isPositive(breakdown['discount'])) {
        lines.add(
          FareLine(
            'Promo discount',
            '-${_money(breakdown['discount'])}',
            color: const Color(0xFFEEBD2B),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeading)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Fare details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ...lines,
        if (lines.isNotEmpty) const Divider(color: Colors.white24, height: 20),
        FareLine('Estimated total', total ?? '—', bold: true),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'An estimate. The final fare can change if the route or '
            'waiting time does.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows [FareBreakdown] in a bottom sheet.
Future<void> showFareBreakdownSheet(
  BuildContext context,
  Map<String, dynamic>? fareData,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1814),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: FareBreakdown(fareData: fareData),
        ),
      ),
    ),
  );
}

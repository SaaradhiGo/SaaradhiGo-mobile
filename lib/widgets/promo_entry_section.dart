import 'package:flutter/material.dart';

import '../core/market/market_config.dart';
import '../core/promo/promo_selection.dart';
import 'promo_code_field.dart';

/// The fare screen's promo entry, behind the backend's say-so.
///
/// Builds NOTHING unless app-config said a promo is available in this market
/// (`MarketConfig.promosAvailable`, from `promos_available`; a missing key is
/// false), so with no promo running the fare screen is exactly what it was
/// before. When shown, it keeps the applied code in [PromoSelection] so the
/// booking can send it.
class PromoEntrySection extends StatelessWidget {
  const PromoEntrySection({
    super.key,
    required this.market,
    required this.fareData,
    this.vehicleType,
    this.pickupLat,
    this.pickupLong,
    this.selection,
    this.applyOverride,
  });

  final MarketConfig market;

  /// The selected vehicle's `/ride/estimate-fare/` response.
  final Map<String, dynamic>? fareData;
  final String? vehicleType;
  final double? pickupLat;
  final double? pickupLong;
  final PromoSelection? selection;
  final Future<Map<String, dynamic>?> Function(String code)? applyOverride;

  @override
  Widget build(BuildContext context) {
    if (!market.promosAvailable) return const SizedBox.shrink();
    final fareRaw = fareData?['estimated_fare'];
    final fare = double.tryParse(fareRaw?.toString() ?? '');
    if (fare == null) return const SizedBox.shrink();
    final sel = selection ?? PromoSelection.instance;
    return ListenableBuilder(
      listenable: sel,
      builder: (context, _) => Padding(
        key: const Key('promo_entry'),
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: PromoCodeField(
          fare: fare,
          currencyCode: fareData?['currency']?.toString(),
          vehicleType: vehicleType,
          pickupLat: pickupLat,
          pickupLong: pickupLong,
          applied: sel.applied,
          applyOverride: applyOverride,
          onApplied: sel.apply,
          onRemoved: sel.clear,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/trip_charge.dart';
import '../utils/money.dart';

const Color _gold = Color(0xFFEEBD2B);
const Color _muted = Color(0xFF94A3B8);

/// The fare card at the top of the trip's payment summary.
///
/// Shows what the server says, in this order:
///   * the fare (`total_fare` / `estimated_fare`, the FULL fare);
///   * with a promo: the discount and what the rider pays
///     (`discount_amount`, `rider_payable`);
///   * a trip support ended: that it was ended by SaaradhiGo, the distance
///     driven and the fare for it;
///   * a trip nobody is charged for: "Not charged", and no amount to pay.
///
/// Nothing is computed here; every amount is a server string.
class TripChargeCard extends StatelessWidget {
  const TripChargeCard({
    super.key,
    required this.fare,
    required this.currencyCode,
    required this.charge,
    this.endedBySupport = false,
    this.distanceDriven,
    this.fareTitle = 'Ride Fare',
  });

  /// The fare string the server sent.
  final String fare;
  final String? currencyCode;
  final TripCharge charge;

  /// Support ended this trip (shows the notice and the distance driven).
  final bool endedBySupport;

  /// Display text for the distance actually driven, when known.
  final String? distanceDriven;
  final String fareTitle;

  @override
  Widget build(BuildContext context) {
    final fareText = formatServerMoney(fare, currencyCode) ?? '';
    final discountText = charge.discount == null
        ? null
        : formatServerMoney(charge.discount, currencyCode);
    final payableText = charge.payable == null
        ? null
        : formatServerMoney(charge.payable, currencyCode);

    return Container(
      key: const Key('trip_charge_card'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF24211C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        children: [
          if (endedBySupport) ...[
            Text(
              'Ride ended by SaaradhiGo support',
              key: const Key('ops_ended_notice'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _gold,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (distanceDriven != null) ...[
              const SizedBox(height: 4),
              Text(
                'Distance driven: $distanceDriven',
                key: const Key('ops_ended_distance'),
                style: GoogleFonts.inter(color: _muted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 14),
          ],
          Text(
            charge.notCharged ? 'Your ride' : fareTitle,
            style: GoogleFonts.inter(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (charge.notCharged)
            Text(
              kNotChargedLabel,
              key: const Key('not_charged_label'),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            )
          else ...[
            Text(
              fareText,
              key: const Key('fare_amount'),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: charge.hasPromo ? 22 : 40,
                fontWeight: FontWeight.w800,
                decoration: charge.hasPromo ? TextDecoration.lineThrough : null,
                decorationColor: _muted,
              ),
            ),
            if (charge.hasPromo && discountText != null) ...[
              const SizedBox(height: 10),
              Text(
                charge.promoCode == null
                    ? 'Promo discount  -$discountText'
                    : 'Promo ${charge.promoCode}  -$discountText',
                key: const Key('promo_discount_line'),
                style: GoogleFonts.inter(
                  color: const Color(0xFF10B981),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (payableText != null) ...[
                const SizedBox(height: 6),
                Text(
                  'You pay',
                  style: GoogleFonts.inter(color: _muted, fontSize: 13),
                ),
                Text(
                  payableText,
                  key: const Key('you_pay_amount'),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ],
          if (charge.notCharged && charge.hasPromo) ...[
            const SizedBox(height: 8),
            Text(
              'Covered by your promo',
              style: GoogleFonts.inter(color: _muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

const String kNotChargedLabel = 'Not charged';

/// Replaces the payment options on a trip nobody is charged for.
class NotChargedPanel extends StatelessWidget {
  const NotChargedPanel({super.key, required this.message, this.onContinue});

  final String message;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('not_charged_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            key: const Key('not_charged_continue'),
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              'Continue',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

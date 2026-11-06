/// Tier 2 trip screens: driver arriving (7), on trip (8) and the receipt (9).
/// Pure views and pure helpers: values in, taps out.
library;

import 'package:flutter/material.dart';

import 'sg_text.dart';
import 'sg_tokens.dart';
import 'sg_widgets.dart';
import 'trip_widgets.dart' show SgStar, formatPlate, initialsOf;

/// The red SOS pill, top right on the arriving and on-trip screens. It opens
/// the existing safety flow.
class SgSosPill extends StatelessWidget {
  const SgSosPill({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'SOS',
    excludeSemantics: true,
    child: Material(
      color: SgColors.danger,
      borderRadius: BorderRadius.circular(SgRadius.pill),
      child: InkWell(
        key: const Key('sos_pill'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(SgRadius.pill),
        child: Container(
          height: kSgTouch,
          padding: const EdgeInsets.symmetric(horizontal: SgSpace.s4),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SgIcon(SgIcons.shield, size: 18, color: SgColors.onDanger),
              const SizedBox(width: SgSpace.s1),
              Text(
                'SOS',
                style: SgText.body.copyWith(
                  color: SgColors.onDanger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The number plate. Indian style (white plate, black border, blue IND strip)
/// when the market is India; otherwise a plain bordered plate.
class SgNumberPlate extends StatelessWidget {
  const SgNumberPlate(this.number, {super.key, required this.indian});
  final String number;
  final bool indian;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      formatPlate(number),
      style: SgText.fare.copyWith(
        fontSize: SgText.px(16),
        height: 20 / 16,
        color: indian ? SgColors.black : SgColors.ink,
      ),
    );
    if (!indian) {
      return Container(
        key: const Key('plate_plain'),
        padding: const EdgeInsets.symmetric(
          horizontal: SgSpace.s2,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SgRadius.sm),
          border: Border.all(color: SgColors.lineStrong, width: 1.5),
        ),
        child: text,
      );
    }
    return Container(
      key: const Key('plate_in'),
      decoration: BoxDecoration(
        color: SgColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SgColors.black, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 18,
              color: SgColors.plateBlue,
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 2),
              // The IND strip is drawn, not lettered: 6px type is under
              // the 13px floor, and the plate number beside it is the text.
              child: const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SgSpace.s2,
                vertical: 4,
              ),
              child: text,
            ),
          ],
        ),
      ),
    );
  }
}

/// The ride PIN on noir: every digit, gold, letter-spaced, 38px.
class SgPinPanel extends StatelessWidget {
  const SgPinPanel({
    super.key,
    required this.label,
    required this.hint,
    required this.pin,
  });
  final String label;
  final String hint;
  final String pin;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('pin_panel'),
    padding: const EdgeInsets.symmetric(
      horizontal: SgSpace.s4,
      vertical: SgSpace.s3,
    ),
    decoration: BoxDecoration(
      color: SgColors.black,
      borderRadius: BorderRadius.circular(SgRadius.lg),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: SgText.label.copyWith(color: SgColors.brandGold),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: SgText.caption.copyWith(color: SgPalette.dark.inkMuted),
              ),
            ],
          ),
        ),
        Text(
          pin,
          key: const Key('ride_pin'),
          style: SgText.fare.copyWith(
            fontSize: SgText.px(38),
            height: 1,
            color: SgColors.brandGold,
            letterSpacing: 6,
          ),
        ),
      ],
    ),
  );
}

/// Initials, name and rating, the plate and the car.
class SgDriverRow extends StatelessWidget {
  const SgDriverRow({
    super.key,
    required this.name,
    this.rating,
    this.vehicleLine,
    this.plate,
    this.indianPlate = true,
    this.trailing,
  });
  final String name;
  final String? rating;
  final String? vehicleLine;
  final String? plate;
  final bool indianPlate;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      // TODO(data): driver photo, trip count and languages are not sent;
      // initials stand in.
      Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: SgColors.bg300,
          shape: BoxShape.circle,
          border: Border.all(color: SgColors.goldLine, width: 1.5),
        ),
        child: Text(
          initialsOf(name),
          style: SgText.title.copyWith(color: SgColors.goldText),
        ),
      ),
      const SizedBox(width: SgSpace.s3),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SgText.title,
                  ),
                ),
                if (rating != null) ...[
                  const SizedBox(width: SgSpace.s2),
                  SgStar(color: SgColors.goldText),
                  const SizedBox(width: 2),
                  Text(
                    rating!,
                    style: SgText.caption.copyWith(
                      color: SgColors.goldText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            if (vehicleLine != null && vehicleLine!.isNotEmpty)
              Text(
                vehicleLine!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SgText.caption,
              ),
            if (plate != null && plate!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: SgSpace.s1),
                child: SgNumberPlate(plate!, indian: indianPlate),
              ),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

/// An outlined button with an icon: Call, Message, Safety.
class SgIconButtonWide extends StatelessWidget {
  const SgIconButtonWide({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = danger ? SgColors.danger : SgColors.ink;
    return Material(
      color: SgColors.bg200,
      borderRadius: BorderRadius.circular(SgRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SgRadius.md),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SgRadius.md),
            border: Border.all(color: SgColors.lineStrong),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SgIcon(icon, size: 20, color: c),
              const SizedBox(width: SgSpace.s2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SgText.body.copyWith(
                    color: c,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Driver arriving (screen 7).
class ArrivingT2Sheet extends StatelessWidget {
  const ArrivingT2Sheet({
    super.key,
    required this.headline,
    required this.driver,
    required this.pinPanel,
    required this.actions,
    this.eta,
    this.meetLine,
    this.cancelLabel,
    this.onCancel,
    this.cancelNote,
  });

  /// "4 min" at 52px, or null when there is no pickup ETA.
  final String? eta;

  /// Under the ETA ("Ravi is on the way"), or alone when there is no ETA.
  final String headline;
  final String? meetLine;
  final Widget driver;
  final Widget? pinPanel;
  final List<Widget> actions;
  final String? cancelLabel;
  final VoidCallback? onCancel;
  final String? cancelNote;

  @override
  Widget build(BuildContext context) => SgSheetSurface(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eta != null)
            Text(
              eta!,
              key: const Key('arriving_eta'),
              style: SgText.fare.copyWith(fontSize: SgText.px(52), height: 1),
            ),
          Text(
            headline,
            key: const Key('arriving_headline'),
            style: eta == null ? SgText.heading : SgText.title,
          ),
          if (meetLine != null && meetLine!.isNotEmpty)
            Text(meetLine!, style: SgText.caption),
          const SizedBox(height: SgSpace.s4),
          driver,
          if (pinPanel != null) ...[
            const SizedBox(height: SgSpace.s4),
            pinPanel!,
          ],
          const SizedBox(height: SgSpace.s4),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: SgSpace.s2),
                Expanded(child: actions[i]),
              ],
            ],
          ),
          if (onCancel != null && cancelLabel != null)
            TextButton(
              key: const Key('arriving_cancel'),
              onPressed: onCancel,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(kSgTouch),
              ),
              child: Text(
                cancelLabel!,
                style: SgText.body.copyWith(color: SgColors.inkMuted),
              ),
            ),
          if (cancelNote != null)
            Text(
              cancelNote!,
              key: const Key('free_to_cancel'),
              textAlign: TextAlign.center,
              style: SgText.caption,
            ),
        ],
      ),
    ),
  );
}

/// When the rider should arrive: started_at + estimated_duration_min. Minutes
/// left and progress come from elapsed / estimated; progress stops at 95%.
/// Past the estimate there are no minutes: "Arriving soon".
class ArrivalEstimate {
  const ArrivalEstimate({
    required this.at,
    required this.minutesLeft,
    required this.progress,
  });
  final DateTime at;

  /// Null once the estimate has passed.
  final int? minutesLeft;
  final double progress;
  bool get overdue => minutesLeft == null;

  static ArrivalEstimate? from({
    required DateTime? startedAt,
    required num? estimatedMinutes,
    required DateTime now,
  }) {
    if (startedAt == null ||
        estimatedMinutes == null ||
        estimatedMinutes <= 0) {
      return null;
    }
    final total = Duration(seconds: (estimatedMinutes * 60).round());
    final at = startedAt.add(total);
    final elapsed = now.difference(startedAt);
    final ratio = elapsed.inSeconds / total.inSeconds;
    final left = at.difference(now);
    return ArrivalEstimate(
      at: at,
      minutesLeft: left.isNegative ? null : (left.inSeconds / 60).ceil(),
      progress: ratio.clamp(0.0, 0.95).toDouble(),
    );
  }
}

/// "9:41 pm".
String clockText(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
}

/// On trip (screen 8).
class OnTripSheet extends StatelessWidget {
  const OnTripSheet({
    super.key,
    required this.arrivalLine,
    required this.driver,
    required this.actions,
    this.minutesLeft,
    this.progress,
    this.extra,
  });

  /// "Arriving about 9:41 pm" / "Arriving soon" / "On the way to X".
  final String arrivalLine;
  final String? minutesLeft;
  final double? progress;
  final Widget driver;
  final List<Widget> actions;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => SgSheetSurface(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            arrivalLine,
            key: const Key('trip_arrival'),
            style: SgText.heading.copyWith(
              fontSize: SgText.px(44),
              height: 46 / 44,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (minutesLeft != null) ...[
            const SizedBox(height: SgSpace.s1),
            Text(minutesLeft!, key: const Key('trip_left'), style: SgText.body),
          ],
          if (progress != null) ...[
            const SizedBox(height: SgSpace.s3),
            ClipRRect(
              borderRadius: BorderRadius.circular(SgRadius.pill),
              child: LinearProgressIndicator(
                key: const Key('trip_progress'),
                value: progress,
                minHeight: 6,
                color: SgColors.gold500,
                backgroundColor: SgColors.bg300,
              ),
            ),
          ],
          const SizedBox(height: SgSpace.s4),
          Container(
            padding: const EdgeInsets.all(SgSpace.s3),
            decoration: BoxDecoration(
              color: SgColors.bg200,
              borderRadius: BorderRadius.circular(SgRadius.lg),
              border: Border.all(color: SgColors.line),
            ),
            child: driver,
          ),
          const SizedBox(height: SgSpace.s3),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: SgSpace.s2),
                Expanded(child: actions[i]),
              ],
            ],
          ),
          if (extra != null) ...[const SizedBox(height: SgSpace.s3), extra!],
        ],
      ),
    ),
  );
}

/// The fare and the word Locked, at the end of the compact driver row.
class LockedFare extends StatelessWidget {
  const LockedFare({super.key, required this.fareText, required this.locked});
  final String fareText;
  final String locked;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(fareText, style: SgText.fare),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SgIcon(SgIcons.lock, size: 12, color: SgColors.success),
          const SizedBox(width: 2),
          Text(
            locked,
            style: SgText.caption.copyWith(
              color: SgColors.success,
              fontWeight: FontWeight.w700,
              fontSize: SgText.px(12),
            ),
          ),
        ],
      ),
    ],
  );
}

/// One line under the receipt tiles.
class ReceiptLine {
  const ReceiptLine(this.kind, this.amount);
  final ReceiptLineKind kind;

  /// Signed: a promotion is negative.
  final double amount;
}

enum ReceiptLineKind { promotion, unexplained }

/// How the trip cost differs from the ticket.
///
/// Empty when they are equal ("Exactly what you were quoted"). Otherwise the
/// promotion the server sent, then any remainder nobody has explained, so a
/// difference is never hidden.
List<ReceiptLine> receiptLines({
  required double quoted,
  required double cost,
  double? promoDiscount,
}) {
  const eps = 0.005;
  if ((cost - quoted).abs() < eps) return const [];
  final out = <ReceiptLine>[];
  var explained = quoted;
  if (promoDiscount != null && promoDiscount.abs() >= eps) {
    out.add(ReceiptLine(ReceiptLineKind.promotion, -promoDiscount.abs()));
    explained -= promoDiscount.abs();
  }
  final rest = cost - explained;
  if (rest.abs() >= eps) {
    // TODO(data): the API gives no reason for this part of the difference.
    out.add(ReceiptLine(ReceiptLineKind.unexplained, rest));
  }
  return out;
}

/// "Your ticket said" next to "Trip cost". Success tint when they match.
class ReceiptTiles extends StatelessWidget {
  const ReceiptTiles({
    super.key,
    required this.ticketLabel,
    required this.ticketText,
    required this.costLabel,
    required this.costText,
    required this.equal,
  });
  final String ticketLabel;
  final String ticketText;
  final String costLabel;
  final String costText;
  final bool equal;

  Widget _tile(String label, String value, {Key? key, bool tint = false}) =>
      Container(
        key: key,
        padding: const EdgeInsets.all(SgSpace.s4),
        decoration: BoxDecoration(
          color: tint
              ? Color.alphaBlend(
                  SgColors.success.withValues(alpha: 0.14),
                  SgColors.bg100,
                )
              : SgColors.bg100,
          borderRadius: BorderRadius.circular(SgRadius.lg),
          border: Border.all(color: tint ? SgColors.success : SgColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: SgText.label),
            const SizedBox(height: SgSpace.s2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: SgText.fare.copyWith(fontSize: SgText.px(32), height: 36 / 32),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _tile(ticketLabel, ticketText, key: const Key('receipt_ticket')),
      ),
      const SizedBox(width: SgSpace.s3),
      Expanded(
        child: _tile(
          costLabel,
          costText,
          key: const Key('receipt_cost'),
          tint: equal,
        ),
      ),
    ],
  );
}

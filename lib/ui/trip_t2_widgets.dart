/// Tier 2 trip screens: driver arriving (7), on trip (8) and the receipt (9).
/// Pure views and pure helpers: values in, taps out.
library;

import 'package:flutter/material.dart';

import 'sg_text.dart';
import 'sg_tokens.dart';
import 'sg_widgets.dart';
import 'trip_widgets.dart' show formatPlate;

/// The red SOS pill, top right on the arriving and on-trip screens. It opens
/// the existing safety flow.
class SgSosPill extends StatelessWidget {
  const SgSosPill({super.key, required this.onTap, this.label = 'SOS'});
  final VoidCallback onTap;

  /// "Safety" on the arriving screen (design); SOS elsewhere.
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: SgColors.danger,
      borderRadius: BorderRadius.circular(SgRadius.pill),
      child: InkWell(
        key: const Key('sos_pill'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(SgRadius.pill),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SgIcon(SgIcons.shield, size: 18, color: SgColors.onDanger),
              const SizedBox(width: SgSpace.s1),
              Text(
                label,
                style: SgText.body.copyWith(
                  color: SgColors.onDanger,
                  fontWeight: FontWeight.w600,
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
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: _plate(),
  );

  Widget _plate() {
    final text = Text(
      formatPlate(number),
      style: SgText.fare.copyWith(
        fontSize: SgText.sizeBody,
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

/// The ride code (signed-in design rider-app-trip): hidden as six dots until
/// the rider taps Show, so it is not read off the screen by someone nearby.
class SgPinPanel extends StatefulWidget {
  const SgPinPanel({
    super.key,
    required this.label,
    required this.hint,
    required this.pin,
    this.showLabel = 'Show',
    this.hideLabel = 'Hide',
  });
  final String label;
  final String hint;
  final String pin;
  final String showLabel;
  final String hideLabel;

  @override
  State<SgPinPanel> createState() => _SgPinPanelState();
}

class _SgPinPanelState extends State<SgPinPanel> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('pin_panel'),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: SgSpace.s3),
    decoration: BoxDecoration(
      color: SgColors.codeSoft,
      borderRadius: BorderRadius.circular(SgSpace.s3),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                style: SgText.caption.copyWith(
                  color: SgColors.goldText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(widget.hint, style: SgText.caption),
            ],
          ),
        ),
        const SizedBox(width: SgSpace.s2),
        if (_shown)
          Text(
            widget.pin,
            key: const Key('ride_pin'),
            style: SgText.title.copyWith(
              letterSpacing: 2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        else
          Row(
            key: const Key('ride_pin_dots'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.pin.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: SgColors.ink,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(width: SgSpace.s2),
        InkWell(
          key: const Key('ride_pin_toggle'),
          onTap: () => setState(() => _shown = !_shown),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Center(
              child: Text(
                _shown ? widget.hideLabel : widget.showLabel,
                style: SgText.caption.copyWith(
                  color: SgColors.goldText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
      // TODO(data): driver photo is not sent; a person icon stands in.
      Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: SgColors.line, shape: BoxShape.circle),
        child: SgIcon(SgIcons.user, size: 24, color: SgColors.inkMuted),
      ),
      const SizedBox(width: SgSpace.s3),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rating == null ? name : '$name \u00b7 $rating',
              key: const Key('driver_name_line'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SgText.body.copyWith(fontWeight: FontWeight.w600),
            ),
            if (vehicleLine != null && vehicleLine!.isNotEmpty)
              Text(
                vehicleLine!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SgText.caption,
              ),
          ],
        ),
      ),
      if (plate != null && plate!.isNotEmpty) ...[
        const SizedBox(width: SgSpace.s2),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Container(
              key: const Key('plate_box'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SgSpace.s2),
                border: Border.all(color: SgColors.ink, width: 2),
              ),
              child: Text(
                formatPlate(plate!),
                style: SgText.caption.copyWith(
                  color: SgColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
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
      color: SgColors.bg100,
      borderRadius: BorderRadius.circular(SgSpace.s3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SgSpace.s3),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SgSpace.s3),
            border: Border.all(color: SgColors.line),
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
                    fontWeight: FontWeight.w600,
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

/// Driver arriving (signed-in design rider-app-trip): the ETA and status, the
/// driver and plate, the ride code, the class and locked fare, then actions.
class ArrivingT2Sheet extends StatelessWidget {
  const ArrivingT2Sheet({
    super.key,
    required this.headline,
    required this.driver,
    required this.pinPanel,
    required this.actions,
    this.eta,
    this.meetLine,
    this.status,
    this.fareLine,
    this.fareText,
    this.lockedLabel,
    this.cancelLabel,
    this.onCancel,
    this.cancelNote,
  });

  /// "Arriving in 4 min", or null when there is no pickup ETA.
  final String? eta;

  /// "Ravi is on the way": the title when there is no ETA.
  final String headline;
  final String? meetLine;

  /// The pill beside the title: "On the way", "Arrived".
  final String? status;
  final Widget driver;
  final Widget? pinPanel;

  /// "Mini · Cash" and the fare the rider booked at.
  final String? fareLine;
  final String? fareText;

  /// "Locked", only when the booking used a quote.
  final String? lockedLabel;
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eta ?? headline,
                      key: const Key('arriving_headline'),
                      style: SgText.title,
                    ),
                    if (meetLine != null && meetLine!.isNotEmpty)
                      Text(meetLine!, style: SgText.caption),
                  ],
                ),
              ),
              if (status != null) SgStatusPill(status!),
            ],
          ),
          const SizedBox(height: SgSpace.s3),
          driver,
          if (pinPanel != null) ...[
            const SizedBox(height: SgSpace.s3),
            pinPanel!,
          ],
          if (fareText != null && fareText!.isNotEmpty) ...[
            const SizedBox(height: SgSpace.s3),
            Container(
              key: const Key('arriving_fare'),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: SgColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fareLine ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SgText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(fareText!, style: SgText.fare),
                  if (lockedLabel != null) ...[
                    const SizedBox(width: SgSpace.s2),
                    SgStatusPill(lockedLabel!, icon: SgIcons.lock),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: SgSpace.s3),
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

/// A green 28px pill: "On the way", "Locked" (design `.pill.ok`).
class SgStatusPill extends StatelessWidget {
  const SgStatusPill(this.text, {super.key, this.icon});
  final String text;
  final String? icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: SgColors.okSoft,
      borderRadius: BorderRadius.circular(SgRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          SgIcon(icon!, size: 14, color: SgColors.success),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: SgText.caption.copyWith(
            color: SgColors.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
  // A no-break space: "2:24" and "pm" never split across lines.
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
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
              fontSize: SgText.sizeDisplay,
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
              fontWeight: FontWeight.w600,
              fontSize: SgText.sizeSmall,
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
            Text(label.toUpperCase(), style: SgText.eyebrow),
            const SizedBox(height: SgSpace.s2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: SgText.fare.copyWith(
                  fontSize: SgText.sizeDisplay,
                  height: 36 / 32,
                ),
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

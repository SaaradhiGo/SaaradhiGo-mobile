/// Booking-to-rating pieces (design: MobileBooking frame 3, MobileTrip,
/// DriverCard, FareSummary, Badge). Pure widgets: values in, taps out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/vehicle_classes.dart';
import 'choose_ride_sheet.dart' show minLabel;
import 'sg_text.dart';
import 'sg_tokens.dart';
import 'sg_widgets.dart';

const _arrow = '→';

const _starPath = '<path d="M12 2.5l2.9 6 6.6.9-4.8 4.6 1.2 6.5L12 17.4l-5.9 3.1 1.2-6.5L2.5 9.4l6.6-.9z"/>';

/// A filled star (the design's), in one colour.
class SgStar extends StatelessWidget {
  const SgStar({super.key, this.size = 14, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">$_starPath</svg>',
        width: size,
        height: size,
        theme: SvgTheme(currentColor: color),
      );
}
const _dot = '·';

/// "Ravi Kumar" -> "Ravi"; "RK" for the avatar.
String firstNameOf(String? full) {
  final t = (full ?? '').trim();
  return t.isEmpty ? '' : t.split(RegExp(r'\s+')).first;
}

String initialsOf(String? full) {
  final parts = (full ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final a = parts.first[0];
  final b = parts.length > 1 ? parts.last[0] : '';
  return (a + b).toUpperCase();
}

/// Status pill; green by default ("On the way", "Arrived", "Paid").
class SgBadge extends StatelessWidget {
  const SgBadge(this.label, {super.key, this.color = SgColors.pickup});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: SgSpace.s2),
        decoration: BoxDecoration(color: SgColors.bg300, borderRadius: BorderRadius.circular(SgRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: SgSpace.s1),
          Text(label.toUpperCase(),
              style: SgText.label.copyWith(color: color, letterSpacing: 0.66)),
        ]),
      );
}

/// The number plate, uppercase as printed, on champagne.
class SgPlate extends StatelessWidget {
  const SgPlate(this.number, {super.key});
  final String number;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: SgSpace.s2, vertical: 4),
        decoration: BoxDecoration(color: SgColors.champagne, borderRadius: BorderRadius.circular(SgRadius.sm)),
        child: Text(number.toUpperCase(),
            style: SgText.fare.copyWith(fontSize: 14, height: 20 / 14, color: SgColors.onGold, letterSpacing: 1.1)),
      );
}

/// Secondary action: outlined, never gold.
class SgGhostButton extends StatelessWidget {
  const SgGhostButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SgRadius.md),
          onTap: onPressed,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SgRadius.md),
              border: Border.all(color: SgColors.lineStrong),
            ),
            child: Text(label, style: SgText.button.copyWith(color: SgColors.ink)),
          ),
        ),
      );
}

/// Thin gold indeterminate bar.
class SgProgressBar extends StatefulWidget {
  const SgProgressBar({super.key});
  @override
  State<SgProgressBar> createState() => _SgProgressBarState();
}

class _SgProgressBarState extends State<SgProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Searching for a driver',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SgRadius.pill),
          child: Container(
            height: 4,
            color: SgColors.bg300,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Align(
                alignment: Alignment(-1 + 2 * _c.value, 0),
                child: FractionallySizedBox(
                  widthFactor: 0.4,
                  child: Container(decoration: BoxDecoration(color: SgColors.gold500, borderRadius: BorderRadius.circular(SgRadius.pill))),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Green rings that pulse out from the middle of the box.
class PulseRings extends StatefulWidget {
  const PulseRings({super.key});
  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(painter: _RingsPainter(_c.value), size: Size.infinite),
          ),
        ),
      );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      canvas.drawCircle(
        c,
        14 + 76 * p,
        Paint()
          ..color = SgColors.pickup.withValues(alpha: 0.7 * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t;
}

/// Four boxes, one digit each.
class SgPinBoxes extends StatelessWidget {
  const SgPinBoxes(this.pin, {super.key});
  final String pin;

  @override
  Widget build(BuildContext context) {
    final digits = pin.padRight(4, '-').substring(0, 4).split('');
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 4; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Container(
          key: Key('pin_box_$i'),
          width: 36,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SgColors.bg300,
            borderRadius: BorderRadius.circular(SgRadius.sm),
            border: Border.all(color: SgColors.lineStrong),
          ),
          child: Text(digits[i], style: SgText.fare.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
      ],
    ]);
  }
}

class DriverCardData {
  const DriverCardData({required this.name, this.rating, this.vehicleLine, this.plate});
  final String name;

  /// "4.92"; null when the API sent none.
  final String? rating;

  /// "Maruti Dzire · White".
  final String? vehicleLine;
  final String? plate;
}

/// Two decimals, as printed in the design ("4.92"); null if not a number.
String? ratingText(Object? raw) {
  final v = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
  return v?.toStringAsFixed(2);
}

class SgDriverCard extends StatelessWidget {
  const SgDriverCard({super.key, required this.driver, this.compact = false, this.photoUrl});
  final DriverCardData driver;
  final bool compact;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 48.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: SgSpace.s4, vertical: compact ? SgSpace.s2 : SgSpace.s3),
      decoration: BoxDecoration(
        color: SgColors.bg200,
        borderRadius: BorderRadius.circular(SgRadius.lg),
        border: Border.all(color: SgColors.goldLine),
      ),
      child: Row(children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SgColors.bg300,
            shape: BoxShape.circle,
            border: Border.all(color: SgColors.gold500, width: 2),
          ),
          child: Text(initialsOf(driver.name), style: SgText.title.copyWith(color: SgColors.goldText)),
        ),
        const SizedBox(width: SgSpace.s4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(driver.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SgText.title.copyWith(fontSize: 16)),
              ),
              if (driver.rating != null) ...[
                const SizedBox(width: SgSpace.s2),
                const SgStar(color: SgColors.goldText),
                const SizedBox(width: 2),
                Text(driver.rating!, style: SgText.caption.copyWith(color: SgColors.goldText, fontWeight: FontWeight.w700)),
              ],
            ]),
            if (driver.vehicleLine != null && driver.vehicleLine!.isNotEmpty)
              Text(driver.vehicleLine!, maxLines: 1, overflow: TextOverflow.ellipsis, style: SgText.caption),
            if (driver.plate != null && driver.plate!.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: SgPlate(driver.plate!)),
          ]),
        ),
      ]),
    );
  }
}

class SgActionData {
  const SgActionData({required this.key, required this.label, required this.icon, required this.onTap, this.danger = false});
  final String key;
  final String label;
  final String icon;
  final VoidCallback onTap;
  final bool danger;
}

/// Call, Message, Share trip, Safety.
class SgActionsRow extends StatelessWidget {
  const SgActionsRow(this.actions, {super.key});
  final List<SgActionData> actions;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (final a in actions)
          Expanded(
            child: Semantics(
              button: true,
              label: a.label,
              child: InkWell(
                key: Key(a.key),
                borderRadius: BorderRadius.circular(SgRadius.md),
                onTap: a.onTap,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: kSgTouch,
                    height: kSgTouch,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: SgColors.bg200,
                      shape: BoxShape.circle,
                      border: Border.all(color: SgColors.line),
                    ),
                    child: SgIcon(a.icon, color: a.danger ? SgColors.danger : SgColors.ink),
                  ),
                  const SizedBox(height: 6),
                  ExcludeSemantics(
                    child: Text(a.label,
                        style: SgText.caption.copyWith(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          ),
      ]);
}

/// The fare the rider was quoted: class icon, name, route, fare. Gold border.
class SgLockedFareCard extends StatelessWidget {
  const SgLockedFareCard({
    super.key,
    required this.vehicleType,
    required this.className,
    required this.route,
    required this.fareText,
  });
  final String? vehicleType;
  final String className;
  final String route;
  final String fareText;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('locked_fare_card'),
        padding: const EdgeInsets.symmetric(horizontal: SgSpace.s3, vertical: SgSpace.s2),
        constraints: const BoxConstraints(minHeight: 68),
        decoration: BoxDecoration(
          color: SgColors.goldSoft,
          borderRadius: BorderRadius.circular(SgRadius.md),
          border: Border.all(color: SgColors.gold500, width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 56,
            height: 40,
            decoration: BoxDecoration(color: SgColors.bg300, borderRadius: BorderRadius.circular(SgRadius.sm)),
            child: Center(child: SvgPicture.asset(vehicleClassAsset(vehicleType), width: 30, height: 30)),
          ),
          const SizedBox(width: SgSpace.s3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(className,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SgText.body.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(route, maxLines: 1, overflow: TextOverflow.ellipsis, style: SgText.caption),
            ]),
          ),
          Text(fareText, style: SgText.fare),
        ]),
      );
}

/// "Pickup → Drop" with whatever is known.
String routeLine(String? pickup, String? drop) {
  final a = (pickup ?? '').split(',').first.trim();
  final b = (drop ?? '').split(',').first.trim();
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  return '$a $_arrow $b';
}

/// Stars you can tap; 0 means none chosen.
class SgStars extends StatelessWidget {
  const SgStars({super.key, required this.score, required this.onChanged});
  final int score;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            key: Key('star_$i'),
            tooltip: '$i star${i == 1 ? '' : 's'}',
            iconSize: 36,
            constraints: const BoxConstraints(minWidth: kSgTouch, minHeight: kSgTouch),
            onPressed: onChanged == null ? null : () => onChanged!(i),
            icon: SgStar(size: 36, color: i <= score ? SgColors.gold500 : SgColors.bg300),
          ),
      ]);
}

Widget _title(String t) => Text(t, style: SgText.heading.copyWith(fontSize: 22, height: 28 / 22));

Widget _displayLine(String t) => Text(t, textAlign: TextAlign.center, style: SgText.displayLg);

Widget _subline(String t, {Color? color}) => Text(t,
    textAlign: TextAlign.center,
    style: SgText.body.copyWith(color: color ?? SgColors.inkMuted));

/// Confirm pickup (MobileBooking frame 3).
class ConfirmPickupSheet extends StatelessWidget {
  const ConfirmPickupSheet({
    super.key,
    required this.address,
    required this.lockText,
    required this.buttonLabel,
    required this.onConfirm,
  });
  final String address;
  final String lockText;
  final String buttonLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) => SgSheetSurface(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Confirm pickup'),
          const SizedBox(height: SgSpace.s3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: SgSpace.s3),
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              color: SgColors.bg200,
              borderRadius: BorderRadius.circular(SgRadius.md),
              border: Border.all(color: SgColors.line),
            ),
            child: Row(children: [
              const SgIcon(SgIcons.pin, color: SgColors.pickup),
              const SizedBox(width: SgSpace.s3),
              Expanded(
                child: Text(address, key: const Key('pickup_address'), maxLines: 2, overflow: TextOverflow.ellipsis, style: SgText.body),
              ),
            ]),
          ),
          const SizedBox(height: SgSpace.s3),
          Row(children: [
            const SgIcon(SgIcons.lock, size: 16, color: SgColors.goldText),
            const SizedBox(width: SgSpace.s2),
            Expanded(
              child: Text(lockText, style: SgText.caption.copyWith(color: SgColors.goldText, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: SgSpace.s4),
          SgPrimaryButton(label: buttonLabel, onPressed: onConfirm),
        ]),
      );
}

/// A chip floating over the map: "Pickup in 4 min".
class MapChip extends StatelessWidget {
  const MapChip(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: SgSpace.s3),
        decoration: BoxDecoration(
          color: SgColors.bgGlass,
          borderRadius: BorderRadius.circular(SgRadius.pill),
          border: Border.all(color: SgColors.goldLine),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: SgText.caption.copyWith(color: SgColors.ink, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// A fixed green pickup pin whose tip sits on the box centre.
class FixedPickupPin extends StatelessWidget {
  const FixedPickupPin({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Semantics(
          label: 'Pickup',
          child: SizedBox(
            width: 44,
            height: 88,
            child: Column(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: SgColors.pickup.withValues(alpha: 0.2)),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: SgColors.pickup,
                    shape: BoxShape.circle,
                    border: Border.all(color: SgColors.bg000, width: 2),
                  ),
                ),
              ),
              Container(width: 2, height: 44, color: SgColors.pickup),
            ]),
          ),
        ),
      );
}

/// Said only when the quote itself said drivers are near.
String findingSubline({required bool driversNearby}) =>
    driversNearby ? 'Usually under a minute. Drivers nearby.' : 'Usually under a minute.';

/// Finding your Saaradhi: the display line, the locked fare, and a way out.
class FindingSheet extends StatelessWidget {
  const FindingSheet({super.key, required this.subline, required this.fare, required this.onCancel});
  final String subline;
  final SgLockedFareCard fare;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => SgSheetSurface(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _displayLine('Finding your Saaradhi'),
          const SizedBox(height: SgSpace.s2),
          Semantics(liveRegion: true, child: _subline(subline)),
          const SizedBox(height: SgSpace.s4),
          const SgProgressBar(),
          const SizedBox(height: SgSpace.s4),
          fare,
          const SizedBox(height: SgSpace.s3),
          SgGhostButton(label: 'Cancel request', onPressed: onCancel),
        ]),
      );
}

/// Search ended without a driver.
class NoDriverSheet extends StatelessWidget {
  const NoDriverSheet({
    super.key,
    required this.subline,
    required this.fare,
    required this.onTryAgain,
    required this.onChangeRide,
  });
  final String subline;
  final SgLockedFareCard fare;
  final VoidCallback onTryAgain;
  final VoidCallback onChangeRide;

  @override
  Widget build(BuildContext context) => SgSheetSurface(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _displayLine('No Saaradhi nearby right now'),
          const SizedBox(height: SgSpace.s2),
          Semantics(liveRegion: true, child: _subline(subline)),
          const SizedBox(height: SgSpace.s4),
          fare,
          const SizedBox(height: SgSpace.s4),
          SgPrimaryButton(label: 'Try again', onPressed: onTryAgain),
          const SizedBox(height: SgSpace.s2),
          SgGhostButton(label: 'Change ride', onPressed: onChangeRide),
        ]),
      );
}

/// Driver assigned: headline, status badge, driver, PIN, actions.
class ArrivingSheet extends StatelessWidget {
  const ArrivingSheet({
    super.key,
    required this.headline,
    required this.badge,
    required this.driver,
    required this.pin,
    required this.actions,
    this.meetLine,
    this.photoUrl,
    this.onCancel,
  });
  final VoidCallback? onCancel;
  final String headline;
  final String badge;
  final String? meetLine;
  final DriverCardData driver;
  final String? photoUrl;
  final String pin;
  final List<SgActionData> actions;

  @override
  Widget build(BuildContext context) => SgSheetSurface(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(headline, style: SgText.heading.copyWith(fontSize: 22, height: 28 / 22)),
                  if (meetLine != null && meetLine!.isNotEmpty) Text(meetLine!, style: SgText.caption),
                ]),
              ),
              SgBadge(badge),
            ]),
            const SizedBox(height: SgSpace.s3),
            SgDriverCard(driver: driver, photoUrl: photoUrl),
            const SizedBox(height: SgSpace.s3),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('RIDE PIN', style: SgText.label),
                  Text('Share only in the car', style: SgText.caption),
                ]),
              ),
              SgPinBoxes(pin),
            ]),
            const SizedBox(height: SgSpace.s4),
            SgActionsRow(actions),
            if (onCancel != null)
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(kSgTouch)),
                child: Text('Cancel ride', style: SgText.body.copyWith(color: SgColors.inkMuted)),
              ),
          ]),
        ),
      );
}

/// Live trip: where to and how long, a compact driver, Share trip and Safety.
class LiveTripSheet extends StatelessWidget {
  const LiveTripSheet({super.key, required this.headline, required this.driver, required this.actions, this.extra});
  final Widget? extra;
  final String headline;
  final DriverCardData driver;
  final List<SgActionData> actions;

  @override
  Widget build(BuildContext context) => SgSheetSurface(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: SgText.heading.copyWith(fontSize: 22, height: 28 / 22)),
          const SizedBox(height: SgSpace.s3),
          SgDriverCard(driver: driver, compact: true),
          const SizedBox(height: SgSpace.s4),
          SgActionsRow(actions),
          if (extra != null) ...[const SizedBox(height: SgSpace.s3), extra!],
        ]),
      );
}

/// The gold check, "You have arrived", and where and when.
class TripArrivedHeader extends StatelessWidget {
  const TripArrivedHeader({super.key, required this.detailLine});
  final String detailLine;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: SgColors.gold500, shape: BoxShape.circle),
            child: const Center(child: SgIcon(SgIcons.check, size: 28, color: SgColors.onGold)),
          ),
        ),
        const SizedBox(height: SgSpace.s3),
        _displayLine('You have arrived'),
        const SizedBox(height: SgSpace.s2),
        if (detailLine.isNotEmpty) _subline(detailLine),
      ]);
}

/// Trip complete: the header, what was paid (when known), then [below].
class TripCompleteView extends StatelessWidget {
  const TripCompleteView({
    super.key,
    required this.detailLine,
    required this.paidLabel,
    required this.fareText,
    required this.paid,
    required this.below,
  });

  /// "Inorbit Mall · 9:41 pm · 24 min".
  final String detailLine;

  /// "PAID BY UPI".
  final String paidLabel;
  final String? fareText;
  final bool paid;
  final Widget below;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TripArrivedHeader(detailLine: detailLine),
        if (fareText != null) ...[
          const SizedBox(height: SgSpace.s5),
          Container(
            key: const Key('paid_card'),
            padding: const EdgeInsets.all(SgSpace.s4),
            decoration: BoxDecoration(
              color: SgColors.bg200,
              borderRadius: BorderRadius.circular(SgRadius.lg),
              border: Border.all(color: SgColors.goldLine),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(paidLabel, style: SgText.label),
                  const SizedBox(height: 2),
                  Text(fareText!, style: SgText.fare.copyWith(fontSize: 34, height: 40 / 34, letterSpacing: -0.7)),
                ]),
              ),
              if (paid) const SgBadge('Paid'),
            ]),
          ),
        ],
        const SizedBox(height: SgSpace.s5),
        below,
      ]);
}

/// "PAID BY CASH" and friends, from the trip's real payment method; before
/// the money has moved it reads "FARE BY CASH".
String paidLabelFor(String? method, {bool paid = true}) {
  final label = _paidLabel(method);
  return paid ? label : label.replaceFirst('PAID', 'FARE');
}

String _paidLabel(String? method) {
  switch ((method ?? '').trim().toLowerCase()) {
    case 'cash':
      return 'PAID BY CASH';
    case 'wallet':
      return 'PAID FROM WALLET';
    case 'upi':
    case 'upi_card':
    case 'online':
    case 'card':
    case 'razorpay':
    case 'cashfree':
      return 'PAID BY UPI';
  }
  return 'FARE';
}

/// "Inorbit Mall · 9:41 pm · 24 min", skipping what is unknown.
String tripDetailLine(String? drop, DateTime? at, String? duration) {
  String? time;
  if (at != null) {
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    time = '$h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'am' : 'pm'}';
  }
  return [
    if (drop != null && drop.trim().isNotEmpty) drop.split(',').first.trim(),
    ?time,
    if (duration != null && duration.trim().isNotEmpty) minLabel(duration),
  ].join(' $_dot ');
}


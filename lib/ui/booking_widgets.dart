/// Tier 2 booking screens: the fare ticket and pickup (screen 5) and finding a
/// driver (screen 6). Pure views: values in, taps out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/vehicle_classes.dart';
import 'sg_text.dart';
import 'sg_tokens.dart';
import 'sg_widgets.dart';
import 'trip_widgets.dart' show SgGhostButton;

/// A class chip: 14% tint, icon and name in the class colour.
class SgClassChip extends StatelessWidget {
  const SgClassChip({super.key, required this.type, required this.label});
  final String? type;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: SgSpace.s3),
    decoration: BoxDecoration(
      color: vehicleTileColour(type),
      borderRadius: BorderRadius.circular(SgRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          vehicleClassAsset(type),
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            vehicleIconColour(type),
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: SgSpace.s1),
        Text(
          label,
          style: SgText.caption.copyWith(
            color: vehicleIconColour(type),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// The ticket's outline: a rounded card with a half-circle notch cut into
/// each side at [tearAt] from the top.
class TicketShape extends ShapeBorder {
  const TicketShape({
    required this.tearAt,
    this.radius = SgRadius.lg,
    this.notch = 12,
    this.side = BorderSide.none,
  });

  final double tearAt;
  final double radius;
  final double notch;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect r) {
    final y = r.top + tearAt;
    final outer = Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
    final cuts = Path()
      ..addOval(Rect.fromCircle(center: Offset(r.left, y), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(r.right, y), radius: notch));
    return Path.combine(PathOperation.difference, outer, cuts);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      _path(rect.deflate(side.width / 2)),
      side.toPaint()..style = PaintingStyle.stroke,
    );
  }

  @override
  ShapeBorder scale(double t) => TicketShape(
    tearAt: tearAt * t,
    radius: radius * t,
    notch: notch * t,
    side: side.scale(t),
  );
}

/// A dashed horizontal tear line.
class TearLine extends StatelessWidget {
  const TearLine({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    child: CustomPaint(
      painter: _DashPainter(SgColors.lineStrong),
      size: const Size(double.infinity, 2),
    ),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + 5).clamp(0, size.width), size.height / 2),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// "YOUR FARE TICKET": class, fare, the lock promise, a tear line with
/// notches, pickup (with Edit) and drop, and the breakdown link.
class FareTicket extends StatelessWidget {
  const FareTicket({
    super.key,
    required this.eyebrow,
    required this.vehicleType,
    required this.className,
    required this.fareText,
    required this.lockText,
    required this.pickupLabel,
    required this.pickup,
    required this.dropLabel,
    required this.drop,
    required this.editLabel,
    required this.onEditPickup,
    this.breakdownLabel,
    this.onBreakdown,
  });

  final String eyebrow;
  final String? vehicleType;
  final String className;
  final String fareText;
  final String lockText;
  final String pickupLabel;
  final String pickup;
  final String dropLabel;
  final String? drop;
  final String editLabel;
  final VoidCallback onEditPickup;
  final String? breakdownLabel;
  final VoidCallback? onBreakdown;

  /// Height of the part above the tear line: the class row, the fare and
  /// two lines for the lock note, at the type scale and the phone's text size.
  /// It was a fixed 196, which left an empty band once the type adapted.
  static double _topFor(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context).scale(1.0);
    return SgSpace.s4 +
        SgSpace.s3 +
        kSgTouch * (ts < 1 ? 1 : ts) + // the class chip row
        SgSpace.s3 +
        SgText.fareXl.fontSize! * 1.1 * ts +
        SgSpace.s2 +
        2 * SgText.caption.fontSize! * 1.45 * ts;
  }

  @override
  Widget build(BuildContext context) => _build(context, _topFor(context));

  Widget _build(BuildContext context, double top) => Container(
    key: const Key('fare_ticket'),
    decoration: ShapeDecoration(
      color: SgColors.bg200,
      shape: TicketShape(
        tearAt: top,
        side: BorderSide(color: SgColors.goldLine, width: 1),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: top,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SgSpace.s5,
              SgSpace.s4,
              SgSpace.s5,
              SgSpace.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: SgEyebrow(eyebrow)),
                    SgClassChip(type: vehicleType, label: className),
                  ],
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    fareText,
                    key: const Key('ticket_fare'),
                    style: SgText.fareXl,
                  ),
                ),
                const SizedBox(height: SgSpace.s2),
                Row(
                  children: [
                    SgIcon(SgIcons.lock, size: 16, color: SgColors.success),
                    const SizedBox(width: SgSpace.s2),
                    Expanded(
                      child: Text(
                        lockText,
                        style: SgText.caption.copyWith(
                          color: SgColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: SgSpace.s5),
          child: TearLine(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SgSpace.s5,
            SgSpace.s2,
            SgSpace.s3,
            SgSpace.s2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Stop(
                dot: SgColors.pickup,
                label: pickupLabel,
                text: pickup,
                textKey: const Key('pickup_address'),
                action: TextButton(
                  key: const Key('ticket_edit_pickup'),
                  onPressed: onEditPickup,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(kSgTouch, kSgTouch),
                  ),
                  child: Text(
                    editLabel,
                    style: SgText.body.copyWith(
                      color: SgColors.goldText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (drop != null && drop!.isNotEmpty)
                _Stop(
                  dot: SgColors.gold500,
                  square: true,
                  label: dropLabel,
                  text: drop!,
                ),
              if (breakdownLabel != null && onBreakdown != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('ticket_breakdown'),
                    onPressed: onBreakdown,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, kSgTouch),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      breakdownLabel!,
                      style: SgText.body.copyWith(
                        color: SgColors.goldText,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: SgColors.goldText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.dot,
    required this.label,
    required this.text,
    this.square = false,
    this.action,
    this.textKey,
  });
  final Color dot;
  final bool square;
  final String label;
  final String text;
  final Widget? action;
  final Key? textKey;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 52),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dot,
            shape: square ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: square ? BorderRadius.circular(2) : null,
          ),
        ),
        const SizedBox(width: SgSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label.toUpperCase(), style: SgText.label),
              Text(
                text,
                key: textKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SgText.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// The sheet under the pickup map: the ticket and the one gold button.
class FareTicketSheet extends StatelessWidget {
  const FareTicketSheet({
    super.key,
    required this.ticket,
    required this.buttonLabel,
    required this.onConfirm,
    this.notice,
  });
  final Widget ticket;
  final String buttonLabel;
  final VoidCallback? onConfirm;

  /// Why the fare on the ticket changed ("Fare updated to ₹X because time
  /// passed"), or "Updating your fare" while it is being re-quoted.
  final String? notice;

  @override
  Widget build(BuildContext context) => SgSheetSurface(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notice != null) ...[
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                SgIcon(SgIcons.clock, size: 18, color: SgColors.goldText),
                const SizedBox(width: SgSpace.s2),
                Expanded(
                  child: Text(
                    notice!,
                    key: const Key('fare_ticket_notice'),
                    style: SgText.body.copyWith(
                      color: SgColors.goldText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SgSpace.s3),
        ],
        Flexible(child: SingleChildScrollView(child: ticket)),
        const SizedBox(height: SgSpace.s4),
        SgPrimaryButton(
          key: const Key('confirm_and_book'),
          label: buttonLabel,
          onPressed: onConfirm,
        ),
      ],
    ),
  );
}

enum ChecklistState { done, current }

class ChecklistItem {
  const ChecklistItem(this.text, this.state, {this.key});
  final String text;
  final ChecklistState state;
  final Key? key;
}

/// A checklist line: a green tick when done, a spinner when it is the step
/// being waited on.
class SgChecklistRow extends StatelessWidget {
  const SgChecklistRow(this.item, {super.key});
  final ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final done = item.state == ChecklistState.done;
    return ConstrainedBox(
      key: item.key,
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: done
                ? Container(
                    decoration: BoxDecoration(
                      color: SgColors.success.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SgIcon(
                        SgIcons.check,
                        size: 16,
                        color: SgColors.success,
                      ),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.all(4),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: SgColors.gold500,
                    ),
                  ),
          ),
          const SizedBox(width: SgSpace.s3),
          Expanded(
            child: Text(
              item.text,
              style: SgText.body.copyWith(
                fontWeight: done ? FontWeight.w600 : FontWeight.w700,
                color: done ? SgColors.inkMuted : SgColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Finding a driver (screen 6): heading, checklist, note, Cancel request.
class FindingChecklistSheet extends StatelessWidget {
  const FindingChecklistSheet({
    super.key,
    required this.heading,
    required this.items,
    required this.note,
    required this.cancelLabel,
    required this.onCancel,
    this.cancelNote,
  });

  final String heading;
  final List<ChecklistItem> items;
  final String note;
  final String cancelLabel;
  final VoidCallback onCancel;

  /// "Free to cancel", only when the config says so.
  final String? cancelNote;

  @override
  Widget build(BuildContext context) => SgSheetSurface(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              heading,
              key: const Key('finding_heading'),
              style: SgText.heading,
            ),
          ),
          const SizedBox(height: SgSpace.s3),
          for (final i in items) SgChecklistRow(i),
          const SizedBox(height: SgSpace.s3),
          Text(note, style: SgText.caption),
          const SizedBox(height: SgSpace.s4),
          SgGhostButton(label: cancelLabel, onPressed: onCancel),
          if (cancelNote != null) ...[
            const SizedBox(height: SgSpace.s2),
            Text(
              cancelNote!,
              key: const Key('free_to_cancel'),
              textAlign: TextAlign.center,
              style: SgText.caption,
            ),
          ],
        ],
      ),
    ),
  );
}

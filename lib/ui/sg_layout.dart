/// Layouts that adapt to the device (Tier 1).
///
/// * Tablet (shortest side 600 or more): the map on the left and the sheet as
///   a 440 panel on the right ([SgMapSplit]).
/// * Phone: the sheet over or under the map, and it scrolls when it is taller
///   than the room it has (landscape, a 1.3x text size) ([SgScrollingSheet]).
/// * Screens without a map keep a readable width on a tablet
///   ([SgReadableWidth]).
library;

import 'package:flutter/material.dart';

import 'sg_text.dart';
import 'sg_tokens.dart';

/// The width of the sheet panel on a tablet.
const double kSgTabletPanel = 440;

/// The map (with whatever floats over it) beside a 440 panel holding the
/// sheet. The panel scrolls.
class SgMapSplit extends StatelessWidget {
  const SgMapSplit({super.key, required this.map, required this.sheet});

  final Widget map;
  final Widget sheet;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: map),
      SizedBox(
        width: kSgTabletPanel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SgColors.bg100,
            border: Border(left: BorderSide(color: SgColors.line)),
          ),
          child: SafeArea(
            left: false,
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Align(alignment: Alignment.bottomCenter, child: sheet),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// A bottom sheet that never overflows: at most [maxFraction] of the height
/// it is given (the rest stays map), scrolling inside when its content is
/// taller.
class SgScrollingSheet extends StatelessWidget {
  const SgScrollingSheet({
    super.key,
    required this.child,
    this.maxFraction = 0.88,
  });

  final Widget child;
  final double maxFraction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: box.maxHeight * maxFraction),
      child: SingleChildScrollView(child: child),
    ),
  );
}

/// Centres a list-style screen at a readable width on a tablet; a phone uses
/// its full width.
class SgReadableWidth extends StatelessWidget {
  const SgReadableWidth({super.key, required this.child, this.maxWidth = 600});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => sgIsTablet(context)
      ? Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        )
      : child;
}

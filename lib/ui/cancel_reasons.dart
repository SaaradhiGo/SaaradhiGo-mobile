/// Why a rider cancels (matches the web, 11 Nov): nothing preselected, and the
/// reasons follow the trip state. Before a driver is assigned there is no
/// driver to be late or at the wrong point, and the server refuses those two.
library;

import 'package:flutter/material.dart';

import 'sg_text.dart';
import 'sg_tokens.dart';

class CancelReason {
  const CancelReason(this.value, this.label);
  final String value;
  final String label;
}

const List<CancelReason> kCancelBeforeDriver = [
  CancelReason('changed_plans', 'Changed my plans'),
  CancelReason('booked_by_mistake', 'Booked by mistake'),
  CancelReason('too_long', 'The wait is too long'),
  CancelReason('other', 'Something else'),
];

const List<CancelReason> kCancelWithDriver = [
  ...kCancelBeforeDriver,
  CancelReason('no_show', 'The driver did not arrive'),
  CancelReason('wrong_location', 'The pickup point is wrong'),
  CancelReason('safety', 'I feel unsafe'),
];

List<CancelReason> cancelReasonsFor({required bool driverAssigned}) =>
    driverAssigned ? kCancelWithDriver : kCancelBeforeDriver;

/// Asks why. Returns the reason value, or null when the rider backs out.
Future<String?> showCancelReasonSheet(
  BuildContext context, {
  required bool driverAssigned,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: SgColors.bg100,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SgSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why are you cancelling?', style: SgText.title),
            const SizedBox(height: SgSpace.s3),
            for (final r in cancelReasonsFor(driverAssigned: driverAssigned))
              InkWell(
                key: Key('cancel_reason_${r.value}'),
                onTap: () => Navigator.pop(sheet, r.value),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(r.label, style: SgText.body),
                  ),
                ),
              ),
            TextButton(
              key: const Key('cancel_reason_keep'),
              onPressed: () => Navigator.pop(sheet),
              child: Text('Keep my ride', style: SgText.body),
            ),
          ],
        ),
      ),
    ),
  );
}

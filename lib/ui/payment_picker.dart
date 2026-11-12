/// "Pay by": the choice made before booking (11 Nov, matching the web).
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../providers/map_provider.dart';
import 'appearance_settings.dart' show paymentMethodLabel, sgStrings;
import 'sg_text.dart';
import 'sg_tokens.dart';

/// "UPI", "Card" or "Cash", as the booking screen names a method.
String bookingPaymentLabel(AppLocalizations l, String method) =>
    switch (method.trim().toLowerCase()) {
      'upi' => 'UPI',
      'card' => 'Card',
      _ => paymentMethodLabel(l, method),
    };

Future<void> showPaymentPicker(BuildContext context, MapProvider provider) {
  final l = sgStrings(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: SgColors.bg100,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SgSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pay by', style: SgText.title),
            const SizedBox(height: SgSpace.s3),
            for (final m in provider.paymentMethods)
              InkWell(
                key: Key('pay_$m'),
                onTap: () {
                  provider.selectPaymentMethod(m);
                  Navigator.pop(sheet);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          bookingPaymentLabel(l, m),
                          style: SgText.body,
                        ),
                      ),
                      if (provider.selectedPaymentMethod == m)
                        Icon(Icons.check, color: SgColors.goldText),
                    ],
                  ),
                ),
              ),
            if (provider.selectedPaymentMethod != 'cash')
              Padding(
                padding: const EdgeInsets.only(top: SgSpace.s2),
                child: Text(
                  'You pay the locked fare online at the end of the trip. '
                  'If it fails, you can try again or pay cash.',
                  style: SgText.caption,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../ui/sg_tokens.dart';

/// Shown after a trip completes while its payment is still outstanding.
///
/// It sits above the app's navigator (MaterialApp.router builder), so it
/// cannot open a sheet or push a route from its own context. It used to try:
/// "Rate trip" called showModalBottomSheet with no Navigator above it, threw,
/// and did nothing (PRODUCT_AUDIT §2, Home). It now hands the tap to [onOpen],
/// which main.dart routes to the payment summary, where the rider pays and
/// then rates.
class PaymentPendingBanner extends StatelessWidget {
  const PaymentPendingBanner({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SgColors.gold500,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 12,
            left: 16,
            right: 8,
          ),
          child: Row(
            children: [
              const Icon(Icons.payment, color: SgColors.onGold),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Your last ride is waiting for payment',
                  style: TextStyle(
                    color: SgColors.onGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  foregroundColor: SgColors.onGold,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text(
                  'Pay now',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

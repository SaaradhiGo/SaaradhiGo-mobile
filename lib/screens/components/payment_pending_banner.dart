import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/rating_service.dart';
import '../../state/ride_notifier.dart';
import '../../widgets/rate_trip_sheet.dart';

/// Shown after a trip completes, while payment is outstanding.
///
/// It also carries the only rating entry point the rider app has.
/// `/ride/rate-trip/` has been live the whole time and neither app could
/// submit one, so every driver average sat at its default -- the figure both
/// apps display was unchangeable. This is the post-trip moment, so this is
/// where the prompt belongs.
///
/// The prompt is an action, not a modal that appears on its own: a sheet
/// thrown over whatever the rider was doing is one they learn to dismiss
/// without reading, and the average that produces is worse than none.
class PaymentPendingBanner extends ConsumerStatefulWidget {
  const PaymentPendingBanner({super.key, this.ratingService});

  /// Injectable for tests.
  final RatingService? ratingService;

  @override
  ConsumerState<PaymentPendingBanner> createState() =>
      _PaymentPendingBannerState();
}

class _PaymentPendingBannerState extends ConsumerState<PaymentPendingBanner> {
  bool _rated = false;

  Future<void> _rate(String tripId, String? driverName) async {
    final rated = await showRateTripSheet(
      context,
      tripId: tripId,
      driverName: driverName,
      service: widget.ratingService,
    );
    if (!mounted) return;
    if (rated) {
      setState(() => _rated = true);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Thanks for rating your trip.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideNotifierProvider);
    final raw = rideState.rawResponse ?? const <String, dynamic>{};
    final tripId = raw['id']?.toString();
    final driverName = raw['driver_name']?.toString();

    return Material(
      color: Colors.transparent,
      child: Container(
        color: const Color(0xFFEEBD2B),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 12,
          left: 16,
          right: 16,
        ),
        child: Row(
          children: [
            const Icon(Icons.payment, color: Color(0xFF12110E)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Payment Pending for your last ride',
                style: TextStyle(
                  color: Color(0xFF12110E),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            // Only offered when there is a trip to rate. Without an id the
            // server would refuse, and a button that cannot work is worse
            // than no button.
            if (tripId != null && tripId.isNotEmpty && !_rated)
              TextButton(
                onPressed: () => _rate(tripId, driverName),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF12110E),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'Rate trip',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

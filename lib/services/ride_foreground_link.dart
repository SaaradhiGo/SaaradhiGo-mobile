import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/ride_notifier.dart';
import '../state/ride_state.dart';
import 'ongoing_ride_notification_service.dart';

/// Wires the Riverpod RideState into the persistent foreground-service
/// notification.
///
/// India's most popular Android OEMs (Xiaomi/MIUI, Vivo, Oppo/ColorOS,
/// Realme) aggressively kill backgrounded apps. Without a running
/// foreground service the app is reaped within minutes of screen-off
/// during a live ride — the WebSocket dies, ride updates stop, the
/// driver-location dot freezes. A sticky foreground-service notification
/// is the only reliable way to stay alive on those phones.
///
/// The existing OngoingRideNotificationService had the wiring code but
/// was never started anywhere in the app. This function listens to the
/// ride state transitions and starts/updates/stops the service at the
/// right moments.
///
/// Call once from a `riverpod.Consumer` inside MaterialApp.builder; the
/// listener follows the Consumer's lifecycle and is removed when the app
/// is torn down.
void wireRideForegroundService(WidgetRef ref) {
  ref.listen<RideState>(rideNotifierProvider, (previous, next) {
    final prevStatus = previous?.status;
    final nextStatus = next.status;

    final wasActive = previous != null && previous.isActiveRide;
    final isActive = next.isActiveRide;

    if (!wasActive && isActive) {
      // Just entered an active ride: launch the sticky notification.
      OngoingRideNotificationService.startService();
      OngoingRideNotificationService.updateNotification(
        title: _titleFor(nextStatus),
        content: _contentFor(next),
      );
      return;
    }

    if (wasActive && !isActive) {
      // Ride ended (completed / cancelled / payment-pending / rated /
      // back to none). Drop the sticky notification.
      OngoingRideNotificationService.stopService();
      return;
    }

    if (isActive && prevStatus != nextStatus) {
      // Still active but transitioning between sub-statuses — refresh
      // the notification text so the rider can see progress from the
      // shade without unlocking.
      OngoingRideNotificationService.updateNotification(
        title: _titleFor(nextStatus),
        content: _contentFor(next),
      );
    }
  });
}

String _titleFor(RideStatus status) {
  switch (status) {
    case RideStatus.searchingDriver:
      return 'Searching for a driver…';
    case RideStatus.driverAccepted:
      return 'Driver assigned';
    case RideStatus.driverArrived:
      return 'Driver has arrived';
    case RideStatus.rideStarted:
      return 'Ride in progress';
    default:
      return 'SaaradhiGo';
  }
}

String _contentFor(RideState s) {
  final dest = s.destinationAddress ?? s.dropLocation?.name;
  switch (s.status) {
    case RideStatus.searchingDriver:
      return dest != null
          ? 'Finding the nearest driver to take you to $dest'
          : 'Finding the nearest driver';
    case RideStatus.driverAccepted:
      return 'Your driver is on the way to pick you up';
    case RideStatus.driverArrived:
      return 'Your driver is at the pickup point';
    case RideStatus.rideStarted:
      return dest != null ? 'On the way to $dest' : 'On the way';
    default:
      return 'Tap to open SaaradhiGo';
  }
}

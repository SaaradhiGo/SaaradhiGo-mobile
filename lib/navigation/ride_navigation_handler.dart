import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/ride_notifier.dart';
import '../state/ride_state.dart';
import '../services/state_recovery_decision_service.dart';
import '../services/websocket_service.dart';

class RideNavigationHandler extends ConsumerWidget {
  final Widget child;

  const RideNavigationHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to changes in the ride state globally
    ref.listen<RideState>(rideNotifierProvider, (previous, next) {
      if (previous?.status == next.status) return;

      // Use the decision service to determine the appropriate screen
      _handleNavigation(context, ref, next);
    });

    return child;
  }

  /// Converts RideStatus enum to decision service compatible status string
  /// Maps the app's internal RideStatus values to the status strings expected
  /// by the decision service (based on FLUTTER_STATE_RECOVERY.md)
  static String? _convertToDecisionServiceStatus(RideStatus? rideStatus) {
    if (rideStatus == null) return null;

    switch (rideStatus) {
      case RideStatus.searchingDriver:
        return StateRecoveryDecisionService.tripStatusRequested;
      case RideStatus.driverAccepted:
        return StateRecoveryDecisionService.tripStatusAccepted;
      case RideStatus.driverArrived:
        return StateRecoveryDecisionService.tripStatusReached;
      case RideStatus.rideStarted:
        return StateRecoveryDecisionService.tripStatusInProgress;
      case RideStatus.rideCompleted:
        return StateRecoveryDecisionService.tripStatusCompleted;
      case RideStatus.paymentPending:
        // Payment pending is a special case - trip is completed but payment is pending
        return StateRecoveryDecisionService.tripStatusCompleted;
      case RideStatus.rated:
        // Rated means trip is completed and payment is completed
        return StateRecoveryDecisionService.tripStatusCompleted;
      case RideStatus.cancelled:
        return StateRecoveryDecisionService.tripStatusCancelled;
      case RideStatus.none:
        return null; // No active trip
    }
  }

  /// Gets payment status based on RideStatus
  /// In a real implementation, this would come from backend or RideState
  static String _getPaymentStatus(RideStatus? rideStatus) {
    if (rideStatus == null) return 'unpaid';

    switch (rideStatus) {
      case RideStatus.paymentPending:
        return StateRecoveryDecisionService.paymentStatusPending;
      case RideStatus.rated:
        return StateRecoveryDecisionService.paymentStatusCompleted;
      case RideStatus.rideCompleted:
        // Ride completed but payment status unknown - default to pending
        return StateRecoveryDecisionService.paymentStatusPending;
      default:
        // For ongoing trips, payment is not relevant yet
        return 'unpaid';
    }
  }

  /// Gets payment method based on RideState or defaults
  /// In a real implementation, this would come from backend or RideState
  static String _getPaymentMethod(RideState rideState) {
    // Check if ride state has payment method information
    // For now, default to online
    return StateRecoveryDecisionService.paymentMethodOnline;
  }

  void _handleNavigation(
    BuildContext context,
    WidgetRef ref,
    RideState rideState,
  ) {
    // Extract trip information from ride state
    final tripStatus = rideState.status;
    final tripId = rideState.tripId;

    // Determine if there's an active trip
    final hasActiveTrip = rideState.isActiveRide;

    // Convert RideStatus to decision service compatible status
    final decisionServiceStatus = _convertToDecisionServiceStatus(tripStatus);

    // Get payment information
    final paymentStatus = _getPaymentStatus(tripStatus);
    final paymentMethod = _getPaymentMethod(rideState);

    // Determine the appropriate screen using the decision service (static method)
    final screenType = StateRecoveryDecisionService.determineScreen(
      tripStatus: decisionServiceStatus,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      hasActiveTrip: hasActiveTrip,
    );

    // Check if we should show banner instead of navigating for active rides
    if (hasActiveTrip &&
        (decisionServiceStatus ==
                StateRecoveryDecisionService.tripStatusRequested ||
            decisionServiceStatus ==
                StateRecoveryDecisionService.tripStatusAccepted ||
            decisionServiceStatus ==
                StateRecoveryDecisionService.tripStatusReached ||
            decisionServiceStatus ==
                StateRecoveryDecisionService.tripStatusInProgress)) {
      // For active rides, stay on home screen and show banner
      // The banner will be shown by the UI layer (main.dart) based on ride state
      // We need to ensure we're on the home screen
      if (!_isOnHomeScreen(context)) {
        context.go('/home');
      }

      // Start WebSocket listening for the active trip
      if (tripId != null && tripId.isNotEmpty) {
        _startWebSocketListening(ref, tripId);
      }

      return; // Don't navigate to ride screens
    }

    // Get the route path for the screen type
    final routePath = StateRecoveryDecisionService.getRoutePath(
      screenType,
      tripId: tripId,
      tripStatus: decisionServiceStatus,
    );

    // Navigate to the determined route
    if (routePath != null && routePath.isNotEmpty) {
      // Use go() to clear the navigation stack and start fresh
      // This ensures clean backstack on app resume
      context.go(routePath);

      // Start WebSocket listening if required for this screen
      if (StateRecoveryDecisionService.requiresWebSocket(screenType) &&
          tripId != null &&
          tripId.isNotEmpty) {
        _startWebSocketListening(ref, tripId);
      }
    } else {
      // Fallback to original navigation logic if no route determined
      _fallbackNavigation(context, rideState);
    }
  }

  /// Checks if the current route is the home screen
  bool _isOnHomeScreen(BuildContext context) {
    final route = GoRouterState.of(context).uri.path;
    return route == '/home' || route == '/';
  }

  /// Starts WebSocket listening for a trip
  void _startWebSocketListening(WidgetRef ref, String tripId) {
    try {
      // Get the access token from SharedPreferences
      SharedPreferences.getInstance().then((prefs) {
        final token = prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
          // Parse tripId to int for WebSocket connection
          final tripIdInt = int.tryParse(tripId);
          if (tripIdInt != null) {
            // Connect to trip WebSocket
            ref.read(webSocketServiceProvider).connectToTrip(token, tripIdInt);
          }
        }
      });
    } catch (e) {
      debugPrint('Error starting WebSocket listening: $e');
    }
  }

  void _fallbackNavigation(BuildContext context, RideState rideState) {
    // Original navigation logic as fallback
    switch (rideState.status) {
      case RideStatus.searchingDriver:
        context.go('/searching-driver');
        break;
      case RideStatus.driverAccepted:
      case RideStatus.driverArrived:
        context.go('/driver-found');
        break;
      case RideStatus.rideStarted:
        context.go('/tracking');
        break;
      case RideStatus.rideCompleted:
      case RideStatus.paymentPending:
        context.go('/ride-summary');
        break;
      case RideStatus.rated:
      case RideStatus.cancelled:
      case RideStatus.none:
        context.go('/home');
        break;
    }
  }
}

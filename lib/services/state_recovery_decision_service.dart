/// Screen types that can be navigated to
enum ScreenType {
  home,
  tripInProgress,
  paymentSuccess,
  cashPaymentWaiting,
  paymentPending,
  paymentFailed,
  paymentSelection, // For deferred payment selection
}

/// Service that implements decision table logic from FLUTTER_STATE_RECOVERY.md
/// Determines the appropriate screen to navigate to based on trip status,
/// payment status, and payment method.
class StateRecoveryDecisionService {
  /// Trip status values from backend
  static const String tripStatusRequested = 'requested';
  static const String tripStatusAccepted = 'accepted';
  static const String tripStatusReached = 'reached';
  static const String tripStatusInProgress = 'in_progress';
  static const String tripStatusCompleted = 'completed';
  static const String tripStatusCancelled = 'cancelled';

  /// Payment status values
  static const String paymentStatusCompleted = 'completed';
  static const String paymentStatusPending = 'pending';
  static const String paymentStatusFailed = 'failed';
  static const String paymentStatusProcessing = 'processing';

  /// Payment method values
  static const String paymentMethodCash = 'cash';
  static const String paymentMethodOnline = 'online';
  static const String paymentMethodWallet = 'wallet';
  static const String paymentMethodDeferred = 'deferred';

  /// Determines the appropriate screen based on trip data
  /// 
  /// Parameters:
  /// - tripStatus: The status of the trip (e.g., 'requested', 'completed')
  /// - paymentStatus: The status of payment (e.g., 'pending', 'completed')
  /// - paymentMethod: The payment method (e.g., 'cash', 'online', 'wallet')
  /// - hasActiveTrip: Whether there's an active trip (from /trips/active/ endpoint)
  /// 
  /// Returns: ScreenType enum indicating which screen to navigate to
  static ScreenType determineScreen({
    required String? tripStatus,
    required String? paymentStatus,
    required String? paymentMethod,
    required bool hasActiveTrip,
  }) {
    // If no active trip, go to home screen
    if (!hasActiveTrip) {
      return ScreenType.home;
    }

    // If trip status is null, default to home
    if (tripStatus == null) {
      return ScreenType.home;
    }

    // Handle cancelled trips
    if (tripStatus == tripStatusCancelled) {
      return ScreenType.home;
    }

    // Handle ongoing trip statuses (not completed)
    if (tripStatus == tripStatusRequested ||
        tripStatus == tripStatusAccepted ||
        tripStatus == tripStatusReached ||
        tripStatus == tripStatusInProgress) {
      return ScreenType.tripInProgress;
    }

    // Handle completed trips (need to check payment status)
    if (tripStatus == tripStatusCompleted) {
      // If payment status is null, default to payment pending
      if (paymentStatus == null) {
        return ScreenType.paymentPending;
      }

      switch (paymentStatus) {
        case paymentStatusCompleted:
          return ScreenType.paymentSuccess;
        
        case paymentStatusPending:
          // Check payment method for pending payments
          if (paymentMethod == paymentMethodCash) {
            return ScreenType.cashPaymentWaiting;
          } else if (paymentMethod == paymentMethodOnline || 
                     paymentMethod == paymentMethodWallet ||
                     paymentMethod == paymentMethodDeferred) {
            return ScreenType.paymentPending;
          }
          // Default to payment pending for unknown payment methods
          return ScreenType.paymentPending;
        
        case paymentStatusFailed:
          return ScreenType.paymentFailed;
        
        case paymentStatusProcessing:
          if (paymentMethod == paymentMethodOnline) {
            return ScreenType.paymentPending;
          }
          // Default to payment pending for processing with other methods
          return ScreenType.paymentPending;
        
        default:
          // Unknown payment status, default to payment pending
          return ScreenType.paymentPending;
      }
    }

    // Default fallback to home screen
    return ScreenType.home;
  }

  /// Converts ScreenType to a human-readable description
  static String getScreenDescription(ScreenType screenType) {
    switch (screenType) {
      case ScreenType.home:
        return 'Home Screen';
      case ScreenType.tripInProgress:
        return 'Trip In Progress Screen';
      case ScreenType.paymentSuccess:
        return 'Payment Success Screen';
      case ScreenType.cashPaymentWaiting:
        return 'Cash Payment Waiting Screen';
      case ScreenType.paymentPending:
        return 'Payment Pending Screen';
      case ScreenType.paymentFailed:
        return 'Payment Failed Screen';
      case ScreenType.paymentSelection:
        return 'Payment Selection Screen';
    }
  }

  /// Gets the route path for a given ScreenType
  /// This maps to the existing route paths in the app
  static String getRoutePath(ScreenType screenType, {String? tripId, String? tripStatus}) {
    switch (screenType) {
      case ScreenType.home:
        return '/home';
      case ScreenType.tripInProgress:
        // Determine which trip in progress screen based on trip status
        if (tripStatus != null) {
          if (tripStatus == tripStatusRequested) {
            return '/searching-driver';
          } else if (tripStatus == tripStatusAccepted || tripStatus == tripStatusReached) {
            return '/driver-found';
          } else if (tripStatus == tripStatusInProgress) {
            return '/tracking';
          }
        }
        // Default to tracking screen
        return '/tracking';
      case ScreenType.paymentSuccess:
        return '/payment-success';
      case ScreenType.cashPaymentWaiting:
        // Uses ride-summary screen with cash payment mode
        return '/ride-summary';
      case ScreenType.paymentPending:
        return '/ride-summary';
      case ScreenType.paymentFailed:
        // Use payment-status screen with status='failed'
        return '/payment-status';
      case ScreenType.paymentSelection:
        // For deferred payment selection, use ride-summary which has payment selection
        return '/ride-summary';
    }
  }

  /// Extracts trip status, payment status, and payment method from trip data
  /// 
  /// Parameters:
  /// - tripData: Map containing trip data from API response
  /// 
  /// Returns: Map with extracted values
  static Map<String, String?> extractTripInfo(Map<String, dynamic> tripData) {
    // Extract from nested structure if needed
    final data = tripData['data'] ?? tripData;
    
    String? tripStatus = data['status']?.toString();
    String? paymentStatus = data['payment_status']?.toString();
    String? paymentMethod = data['payment_method']?.toString();
    
    // If payment info is nested in a payment object
    if (paymentStatus == null && data['payment'] is Map) {
      paymentStatus = data['payment']['status']?.toString();
      paymentMethod = data['payment']['method']?.toString();
    }
    
    return {
      'tripStatus': tripStatus,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
    };
  }

  /// Determines if WebSocket listening is required for a given screen
  static bool requiresWebSocket(ScreenType screenType) {
    return screenType == ScreenType.tripInProgress ||
           screenType == ScreenType.cashPaymentWaiting ||
           screenType == ScreenType.paymentPending;
  }

  /// Determines if the trip ID should be cleared from storage
  /// Based on FLUTTER_STATE_RECOVERY.md: "After a trip reaches `completed` or `cancelled`, 
  /// clear the stored trip ID from SharedPreferences."
  static bool shouldClearTripId(String? tripStatus, String? paymentStatus) {
    if (tripStatus == tripStatusCancelled) {
      return true;
    }
    
    if (tripStatus == tripStatusCompleted && 
        paymentStatus == paymentStatusCompleted) {
      return true;
    }
    
    return false;
  }
}

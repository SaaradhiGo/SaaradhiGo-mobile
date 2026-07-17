import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/ride_notifier.dart';

class LifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;

  const LifecycleObserver({super.key, required this.child});

  @override
  ConsumerState<LifecycleObserver> createState() => _LifecycleObserverState();
}

class _LifecycleObserverState extends ConsumerState<LifecycleObserver>
    with WidgetsBindingObserver {
  static const String _lastBackgroundTimeKey = 'last_background_time';
  static const String _wasInBackgroundKey = 'was_in_background';
  static const String _lastRouteKey = 'last_route';
  static const String _lastRouteTimestampKey = 'last_route_timestamp';
  static const String _lastDataFetchTimestampKey = 'last_data_fetch_timestamp';
  static const String _activeTripIdKey = 'active_trip_id';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Check if app was killed from background on startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkBackgroundKill();
      // Load persisted state as early as possible
      ref.read(rideNotifierProvider.notifier).loadInitialState();
      // Restore any saved app state
      await _restoreAppState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App is going to background
      _onAppToBackground();
    } else if (state == AppLifecycleState.resumed) {
      // App is coming back to foreground
      _onAppToForeground();
    } else if (state == AppLifecycleState.detached) {
      // App is being terminated (killed)
      _onAppTerminated();
    }
  }

  Future<void> _onAppToBackground() async {
    final prefs = await SharedPreferences.getInstance();
    // Store current time when app goes to background
    await prefs.setInt(
      _lastBackgroundTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setBool(_wasInBackgroundKey, true);

    // Capture current app state before going to background
    await _captureAppState();
  }

  Future<void> _onAppToForeground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wasInBackgroundKey, false);

    // Check if we need to refresh data based on staleness
    final shouldRefresh = await _shouldRefreshData();

    if (shouldRefresh) {
      // Trigger state refresh on resume
      ref.read(rideNotifierProvider.notifier).loadInitialState();
    }

    // Update last data fetch timestamp
    await prefs.setInt(
      _lastDataFetchTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _onAppTerminated() async {
    // App is being terminated - clear background flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wasInBackgroundKey, false);
  }

  Future<void> _checkBackgroundKill() async {
    final prefs = await SharedPreferences.getInstance();
    final wasInBackground = prefs.getBool(_wasInBackgroundKey) ?? false;
    final lastBackgroundTime = prefs.getInt(_lastBackgroundTimeKey);

    if (wasInBackground && lastBackgroundTime != null) {
      // App was in background and now starting fresh
      // This indicates a possible background kill
      final timeSinceBackground =
          DateTime.now().millisecondsSinceEpoch - lastBackgroundTime;

      // If app was in background less than 30 seconds ago and now starting fresh,
      // it was likely killed from background
      if (timeSinceBackground < 30000) {
        // 30 seconds
        // Background kill detected - ensure active ride check happens
        debugPrint('Background kill detected - checking for active ride');
      }

      // Clear the flag for next time
      await prefs.setBool(_wasInBackgroundKey, false);
    }
  }

  Future<void> _captureAppState() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // Capture current route if we have a context
      if (mounted) {
        final router = GoRouter.of(context);
        final currentRoute =
            router.routerDelegate.currentConfiguration.last.matchedLocation;
        if (currentRoute.isNotEmpty) {
          await prefs.setString(_lastRouteKey, currentRoute);
          await prefs.setInt(
            _lastRouteTimestampKey,
            DateTime.now().millisecondsSinceEpoch,
          );
          debugPrint('Captured app state: route=$currentRoute');
        }
      }

      // Capture active trip ID if available
      final rideState = ref.read(rideNotifierProvider);
      if (rideState.tripId != null && rideState.tripId!.isNotEmpty) {
        await prefs.setString(_activeTripIdKey, rideState.tripId!);
      }
    } catch (e) {
      // Silently fail - this is non-critical functionality
      debugPrint('Error capturing app state: $e');
    }
  }

  Future<void> _restoreAppState() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // Check if we have a saved route that's recent (within last 5 minutes)
      final lastRoute = prefs.getString(_lastRouteKey);
      final lastRouteTimestamp = prefs.getInt(_lastRouteTimestampKey);

      if (lastRoute != null && lastRouteTimestamp != null) {
        final timeSinceRouteCapture =
            DateTime.now().millisecondsSinceEpoch - lastRouteTimestamp;

        // Only restore if route was captured recently (within 5 minutes)
        if (timeSinceRouteCapture < 300000 && mounted) {
          // 5 minutes
          final router = GoRouter.of(context);
          final currentRoute =
              router.routerDelegate.currentConfiguration.last.matchedLocation;

          // Only navigate if we're not already on that route
          if (currentRoute != lastRoute) {
            debugPrint('Restoring app state to route: $lastRoute');
            // Use go() to navigate to the saved route
            router.go(lastRoute);
          }
        }
      }
    } catch (e) {
      // Silently fail - this is non-critical functionality
      debugPrint('Error restoring app state: $e');
    }
  }

  Future<bool> _shouldRefreshData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchTimestamp = prefs.getInt(_lastDataFetchTimestampKey);

    if (lastFetchTimestamp == null) {
      // No previous fetch timestamp - refresh
      return true;
    }

    final timeSinceLastFetch =
        DateTime.now().millisecondsSinceEpoch - lastFetchTimestamp;

    // Refresh if data is stale (more than 30 seconds old)
    return timeSinceLastFetch > 30000; // 30 seconds
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

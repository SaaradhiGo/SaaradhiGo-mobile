import 'dart:async';

import 'package:go_router/go_router.dart';

import '../services/session_events.dart';

/// Where Log in says the session ended.
const String kLoginSessionExpired = '/login?expired=1';

/// Sends the rider to Log in, with the reason, whenever the session cannot
/// be recovered. [beforeGo] clears what the signed-in screens held.
StreamSubscription<void> goToLoginOnSessionEnd(
  GoRouter router, {
  Future<void> Function()? beforeGo,
}) {
  return SessionEvents.expired.listen((_) async {
    if (router.routerDelegate.currentConfiguration.uri.path == '/login') {
      return;
    }
    if (beforeGo != null) unawaited(beforeGo());
    router.go(kLoginSessionExpired);
  });
}

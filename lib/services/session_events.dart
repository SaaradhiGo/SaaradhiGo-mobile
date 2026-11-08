import 'dart:async';

/// The longest a signed-in view may show its loading skeleton: after this a
/// section shows its error state with Try again instead of waiting on.
const Duration kLoadTimeout = Duration(seconds: 10);

/// Thrown by a signed-in load that failed, timed out or was refused, so the
/// view shows its error state instead of zeros or an endless spinner.
class LoadFailure implements Exception {
  const LoadFailure(this.reason);
  final String reason;
  @override
  String toString() => 'LoadFailure($reason)';
}

/// Fired when the session cannot be recovered (the refresh token was refused
/// or is gone). The app listens and goes to Log in with a message.
class SessionEvents {
  SessionEvents._();

  static final StreamController<void> _expired =
      StreamController<void>.broadcast();

  static Stream<void> get expired => _expired.stream;

  static void emitExpired() => _expired.add(null);
}

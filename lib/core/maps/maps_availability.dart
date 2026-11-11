/// Whether this build carries a real Google Maps key. Asked once from the
/// platform; until it answers true the branded placeholder map is used.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MapsAvailability {
  MapsAvailability._();

  static const MethodChannel channel = MethodChannel('saaradhigo/maps');

  /// False until the platform says otherwise; listeners rebuild on change.
  static final ValueNotifier<bool> hasKey = ValueNotifier<bool>(false);
  static Future<void>? _asked;

  /// Asks the platform once and caches the answer.
  static Future<void> ensureResolved() => _asked ??= _ask();

  static Future<void> _ask() async {
    try {
      hasKey.value = (await channel.invokeMethod<bool>('hasKey')) ?? false;
    } catch (_) {
      hasKey.value = false;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _asked = null;
    hasKey.value = false;
  }
}

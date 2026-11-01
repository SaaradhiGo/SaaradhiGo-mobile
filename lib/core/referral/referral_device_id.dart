/// The device id sent with a referral code (`POST /promotions/referrals/attach/`
/// `device_id`).
///
/// A random per-install id, made once and kept in secure storage (with a
/// SharedPreferences copy if secure storage is unavailable), so it is the same
/// across app restarts. It is NOT a hardware identifier: never an IMEI, MAC
/// address, advertising id, ANDROID_ID or phone number. The backend only stores
/// a salted hash of whatever it is sent (referrals.device_hash), so nothing
/// more stable is needed and nothing personal is shared.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ReferralDeviceId {
  ReferralDeviceId._();

  static const storageKey = 'referral_install_id_v1';
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String? _cached;

  /// The stable per-install id. Never throws.
  static Future<String> get() async {
    final cached = _cached;
    if (cached != null) return cached;

    String? stored;
    try {
      stored = await _secure.read(key: storageKey);
    } catch (_) {
      stored = null;
    }
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      prefs = null;
    }
    if (stored == null || stored.isEmpty) {
      stored = prefs?.getString(storageKey);
    }
    if (stored == null || stored.isEmpty) {
      stored = 'inst-${const Uuid().v4()}';
    }
    // Write to both, every time: if one store lost the value the other repairs it.
    try {
      await _secure.write(key: storageKey, value: stored);
    } catch (_) {}
    try {
      await prefs?.setString(storageKey, stored);
    } catch (_) {}
    return _cached = stored;
  }

  static void resetCacheForTests() => _cached = null;
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authoritative store for auth tokens.
///
/// Reads/writes the access + refresh tokens out of platform-secure storage
/// (Keychain on iOS, EncryptedSharedPreferences-backed Keystore on Android).
/// `SharedPreferences` previously held these in plain text — fine for a
/// throwaway flag, indefensible for a payment-capable app's credentials.
///
/// Migration strategy:
///   - All NEW writes go to secure storage AND to SharedPreferences. The
///     `prefs` write is a transitional dual-write so the older call sites
///     in the app (notification provider, history provider, ride notifier,
///     etc. — see audit) keep working unchanged.
///   - Reads check secure storage first; if empty, fall back to the
///     prefs value and migrate it across.
///
/// In a follow-up PR every other reader will be migrated to call
/// `TokenStore.accessToken()` instead of reading `prefs.getString(...)`
/// directly, and the prefs fallback can then be removed.
class TokenStore {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  // Platform options. EncryptedSharedPreferences on Android is the modern
  // default; on iOS the keychain is the default and survives reinstall
  // unless we mark `first_unlock_this_device_only`.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  TokenStore._();

  /// Read the access token. Migrates from SharedPreferences on first read.
  static Future<String?> readAccessToken() async {
    return _read(_kAccess);
  }

  /// Read the refresh token. Migrates from SharedPreferences on first read.
  static Future<String?> readRefreshToken() async {
    return _read(_kRefresh);
  }

  /// Persist both tokens. Dual-writes to SharedPreferences for legacy readers.
  static Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secure.write(key: _kAccess, value: accessToken);
    await _secure.write(key: _kRefresh, value: refreshToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, accessToken);
    await prefs.setString(_kRefresh, refreshToken);
  }

  /// Wipe both stores. Called on logout / 401-after-refresh-fails.
  static Future<void> clear() async {
    await _secure.delete(key: _kAccess);
    await _secure.delete(key: _kRefresh);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
  }

  static Future<String?> _read(String key) async {
    final secure = await _secure.read(key: key);
    if (secure != null && secure.isNotEmpty) {
      return secure;
    }
    // First-read migration from prefs → secure. Keeps the prefs copy so
    // legacy call sites continue to work during the transitional period.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        await _secure.write(key: key, value: legacy);
      } catch (_) {
        // Best-effort: if secure storage is unavailable we still return
        // the legacy value so the user isn't logged out.
      }
      return legacy;
    }
    return null;
  }
}

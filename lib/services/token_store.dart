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

  /// Set when a session has been ended but the secure store could not be
  /// proven empty. Never holds a credential -- only the fact that one is void.
  ///
  /// WHY THIS IS NEEDED EVEN THOUGH clear() IS GUARDED
  /// -------------------------------------------------
  /// `clear()` catches a throw from `_secure.delete` so that the prefs copies
  /// are still removed. That closed the half of the hole where prefs survived
  /// a logout. The other half stayed open: the SECURE copy survives, `_read`
  /// consults secure storage FIRST, and the next launch read a token the user
  /// had already logged out of. Blocking the read is what actually closes it,
  /// and it closes both halves at once.
  static const _kRevoked = 'auth_session_revoked';

  /// Authoritative for this process. Null until first consulted.
  static bool? _revoked;

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
    // Guarded for the same reason the read is: secure storage can be
    // unavailable (MissingPluginException in a test binding, and reported
    // keystore failures on some Android builds). Unguarded, the throw
    // happened BEFORE the SharedPreferences dual-write, so a secure-storage
    // fault did not degrade to the fallback -- it failed the whole login and
    // the user saw "invalid OTP".
    //
    // The prefs write always happens, so a session still survives.
    try {
      await _secure.write(key: _kAccess, value: accessToken);
      await _secure.write(key: _kRefresh, value: refreshToken);
    } catch (_) {
      // Best effort. The prefs copy below is what keeps the user signed in.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, accessToken);
    await prefs.setString(_kRefresh, refreshToken);

    // A fresh login lifts any tombstone, or a driver whose store failed once
    // would be locked out of their own app for good.
    await _setRevoked(false);
  }

  /// Wipe both stores. Called on logout / 401-after-refresh-fails.
  static Future<void> clear() async {
    // Tombstone FIRST. Everything after this point may fail; from here on the
    // session is void regardless of what either store does.
    await _setRevoked(true);

    // Each delete is attempted independently: one throw must not shield the
    // key after it.
    var allDeleted = true;
    for (final key in const [_kAccess, _kRefresh]) {
      try {
        await _secure.delete(key: key);
      } catch (_) {
        allDeleted = false;
      }
    }
    if (!allDeleted) {
      // deleteAll can succeed where a per-key delete fails on a corrupt entry.
      try {
        await _secure.deleteAll();
        allDeleted = true;
      } catch (_) {
        // The tombstone stands.
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccess);
      await prefs.remove(_kRefresh);
    } catch (_) {
      allDeleted = false;
    }

    if (allDeleted) {
      // Nothing left to protect, so leave no trace behind.
      await _setRevoked(false);
    }
  }

  static Future<bool> _isRevoked() async {
    final cached = _revoked;
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      return _revoked = prefs.getBool(_kRevoked) ?? false;
    } catch (_) {
      // An unreadable tombstone is exactly the case it exists for: do not
      // assume a live session.
      return _revoked = true;
    }
  }

  static Future<void> _setRevoked(bool value) async {
    _revoked = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value) {
        await prefs.setBool(_kRevoked, true);
      } else {
        await prefs.remove(_kRevoked);
      }
    } catch (_) {
      // In-memory state still holds for the rest of this process.
    }
  }

  /// Resets the in-memory tombstone so each test starts clean.
  static void resetSessionRevocationCacheForTests() => _revoked = null;

  static Future<String?> _read(String key) async {
    // A session that has been ended cannot come back, whatever the stores do.
    if (await _isRevoked()) return null;

    // Guarded for the same reason the write below is: secure storage can be
    // unavailable. `flutter_secure_storage` throws MissingPluginException in a
    // test binding and has been reported to throw on some Android keystore
    // states — and an exception here read as "signed out", which is the exact
    // outcome the fallback exists to prevent. The write was already guarded;
    // the read was not.
    String? secure;
    try {
      secure = await _secure.read(key: key);
    } catch (_) {
      secure = null;
    }
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

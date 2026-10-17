/// A logged-out session must not come back, even when a store fails.
///
/// WHAT WAS ALREADY FIXED, AND WHAT WAS STILL OPEN
/// -----------------------------------------------
/// `TokenStore` dual-writes to secure storage AND SharedPreferences, for the
/// legacy call sites that read prefs directly. `clear()` already caught a
/// throw from `_secure.delete` so that the prefs copies were still removed --
/// that closed the half of the hole where PREFS survived a logout.
///
/// The other half stayed open. If the secure delete fails, the SECURE copy
/// survives, and `_read` consults secure storage FIRST:
///
///     clear()  -> secure.delete throws, prefs cleared
///     restart  -> _read -> secure.read -> the old token, still there
///
/// so the next launch restored a session the rider had ended. On Android that
/// is not hypothetical: a Keystore entry can become undecryptable after an OS
/// upgrade or a biometric enrolment change, and flutter_secure_storage
/// surfaces it as a PlatformException.
///
/// Blocking the READ closes both halves at once, which is what these tests
/// assert.
library;

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/services/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A secure store that holds real values and can be told to fail.
///
/// `FlutterSecureStorage.setMockInitialValues` installs a store that always
/// succeeds, so it cannot express the case this file is about.
class _HostileSecureStorage extends FlutterSecureStoragePlatform {
  _HostileSecureStorage(this.data);

  final Map<String, String> data;

  bool failDelete = false;
  bool failDeleteAll = false;

  final List<String> deleteAttempts = [];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    deleteAttempts.add(key);
    if (failDelete) {
      throw PlatformException(
        code: 'Exception encountered',
        message: 'KeyStoreException: Key user not authenticated',
      );
    }
    data.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    deleteAttempts.add('*');
    if (failDeleteAll) {
      throw PlatformException(code: 'Exception encountered');
    }
    data.clear();
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      data[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      data;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    data[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _HostileSecureStorage store;

  setUp(() {
    store = _HostileSecureStorage({
      'access_token': 'live-access-token',
      'refresh_token': 'live-refresh-token',
    });
    FlutterSecureStoragePlatform.instance = store;
    SharedPreferences.setMockInitialValues({
      'access_token': 'live-access-token',
      'refresh_token': 'live-refresh-token',
    });
    TokenStore.resetSessionRevocationCacheForTests();
  });

  group('a clean logout', () {
    test('empties both stores and leaves no tombstone', () async {
      await TokenStore.clear();

      expect(store.data, isEmpty);
      expect(await TokenStore.readAccessToken(), isNull);
      expect(await TokenStore.readRefreshToken(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getBool('auth_session_revoked'), isNull,
          reason: 'a successful logout should leave no trace');
    });

    test('a later login is readable again', () async {
      await TokenStore.clear();
      await TokenStore.writeTokens(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
      );

      expect(await TokenStore.readAccessToken(), 'new-access');
      expect(await TokenStore.readRefreshToken(), 'new-refresh');
    });
  });

  group('when the secure store refuses to delete', () {
    setUp(() {
      store.failDelete = true;
      store.failDeleteAll = true;
    });

    test('clear does not throw', () async {
      await expectLater(TokenStore.clear(), completes);
    });

    test('it still attempts both keys -- one failure shields neither',
        () async {
      await TokenStore.clear();

      expect(store.deleteAttempts, containsAll(['access_token',
        'refresh_token']));
    });

    test('the prefs copies are still removed', () async {
      // The half that was already fixed. Asserted so it stays fixed.
      await TokenStore.clear();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
    });

    test('the surviving secure token is unreadable', () async {
      await TokenStore.clear();

      // Still physically present...
      expect(store.data['access_token'], 'live-access-token');

      // ...and no longer reachable through the API the app reads.
      expect(await TokenStore.readAccessToken(), isNull);
      expect(await TokenStore.readRefreshToken(), isNull);
    });

    test('it stays unreadable across a restart', () async {
      await TokenStore.clear();

      // A new process: the in-memory tombstone is gone; SharedPreferences and
      // the undeleted secure value both survive.
      TokenStore.resetSessionRevocationCacheForTests();

      expect(store.data['access_token'], 'live-access-token');
      expect(await TokenStore.readAccessToken(), isNull,
          reason: 'this is the cold start that used to restore the session');
    });

    test('the prefs migration path cannot resurrect it either', () async {
      // _read falls back to a legacy prefs value and migrates it across. That
      // path must also be closed, or a stale prefs entry written by an older
      // build would walk straight back in.
      await TokenStore.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', 'legacy-token-from-an-old-build');
      TokenStore.resetSessionRevocationCacheForTests();

      expect(await TokenStore.readAccessToken(), isNull);
    });

    test('a genuine later login still works', () async {
      await TokenStore.clear();
      expect(await TokenStore.readAccessToken(), isNull);

      // Signing in again must lift the tombstone, or a rider is locked out of
      // their own app by a store that failed once.
      await TokenStore.writeTokens(
        accessToken: 'second-session',
        refreshToken: 'second-refresh',
      );

      expect(await TokenStore.readAccessToken(), 'second-session');
    });
  });
}

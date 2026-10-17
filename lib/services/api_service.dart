import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/app_config.dart';
import 'package:image_picker/image_picker.dart';
import 'push_notification_service.dart';
import 'token_store.dart';

abstract class AuthApiClient {
  Future<Map<String, dynamic>?> requestOtp(String phoneNumber, String role);

  /// Email + password sign-in. See the implementation for the contract.
  Future<Map<String, dynamic>?> emailLogin({
    required String email,
    required String password,
    String? mfaCode,
  });

  /// Ask for a password-reset link. True means the request was accepted; it
  /// never reveals whether an account exists.
  Future<bool> requestPasswordReset(String email);

  /// [deviceToken] is the FCM token, or null when this device has none.
  ///
  /// Null must be passed through as an ABSENT key, not a placeholder. The
  /// login view only writes `fcm_token` when the key is present, so omitting
  /// it preserves whatever good token the server already had -- while a
  /// placeholder overwrites it with something that can never receive
  /// anything, and dispatch then counts this rider as push-capable.
  Future<Map<String, dynamic>?> verifyOtpAndLogin(
    String phoneNumber,
    String otp,
    String? deviceToken,
  );

  /// Register a push token obtained outside a login -- after FCM rotates it.
  ///
  /// `fcm_token` is write-only on the profile serializer, so PATCH
  /// /auth/update/ is the supported way to set it.
  Future<bool> registerPushToken(String token);
  Future<Map<String, dynamic>?> updateProfile({
    String? profilePicPath,
    required String fullName,
    required String email,
    required String gender,
    required String dob,
    required String emergencyContact,
    required String houseNo,
    required String street,
    required String city,
    required String zipCode,
  });
  Future<Map<String, dynamic>?> getProfile();
  Future<void> clearSession();
}

class ApiService implements AuthApiClient {
  static String baseUrl = AppConfig.baseUrl;

  // Singleton pattern.
  //
  // `client` exists so a test can replay a REAL captured server response
  // through this class's own parsing — see
  // test/auth_contract_conformance_test.dart. Without an injectable client
  // the only way to test the parsing is to re-implement it in the test,
  // which is precisely the mistake that let the driver app ship a login that
  // could never work: its fixtures used the same wrong key names its code
  // used, so tests and code agreed and both disagreed with the server.
  //
  // Passing nothing returns the singleton and behaves exactly as before.
  static final ApiService _instance = ApiService._internal();

  factory ApiService({http.Client? client}) =>
      client == null ? _instance : ApiService._internal(client: client);

  ApiService._internal({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  String? _accessToken;
  Future<String>? _inflightRefresh;

  Future<void> _loadTokens() async {
    _accessToken = await TokenStore.readAccessToken();
  }

  Future<void> _saveTokens(String access, String refresh) async {
    await TokenStore.writeTokens(accessToken: access, refreshToken: refresh);
    _accessToken = access;
  }

  /// Call POST /auth/refresh/ with the stored refresh token. Returns the
  /// new access token on success, null on failure. Concurrent callers
  /// share the same in-flight request — important during a burst of
  /// 401s when several screens reload at once.
  Future<String?> refreshAccessToken() async {
    if (_inflightRefresh != null) {
      try {
        return await _inflightRefresh!;
      } catch (_) {
        return null;
      }
    }

    final future = () async {
      final refresh = await TokenStore.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        throw Exception('no refresh token');
      }
      final response = await _client.post(
        Uri.parse('$baseUrl${AppConfig.authRefresh}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}),
      );
      if (response.statusCode != 200) {
        throw Exception('refresh failed (${response.statusCode})');
      }
      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      final newAccess = (data is Map<String, dynamic>) ? data['token'] : null;
      final newRefresh = (data is Map<String, dynamic>)
          ? data['refresh_token']
          : null;
      if (newAccess is! String || newAccess.isEmpty) {
        throw Exception('refresh response missing token');
      }
      await TokenStore.writeTokens(
        accessToken: newAccess,
        refreshToken: newRefresh is String && newRefresh.isNotEmpty
            ? newRefresh
            : refresh,
      );
      _accessToken = newAccess;
      return newAccess;
    }();

    _inflightRefresh = future;
    try {
      return await future;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      // Refresh failed — wipe so the next call goes to login.
      await TokenStore.clear();
      _accessToken = null;
      return null;
    } finally {
      _inflightRefresh = null;
    }
  }

  /// Authenticated HTTP wrapper. On HTTP 401 from the server we attempt
  /// a single refresh and retry. Use this from any method that hits a
  /// JWT-protected endpoint instead of calling `http.*` directly.
  Future<http.Response?> authedRequest(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    if (_accessToken == null) await _loadTokens();

    Future<http.Response> doSend(String? token) {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      return send(headers);
    }

    http.Response response;
    try {
      response = await doSend(_accessToken);
    } catch (e) {
      debugPrint('authedRequest network error: $e');
      return null;
    }

    if (response.statusCode == 401) {
      final newToken = await refreshAccessToken();
      if (newToken == null) {
        return response;
      }
      try {
        response = await doSend(newToken);
      } catch (e) {
        debugPrint('authedRequest retry network error: $e');
        return null;
      }
    }
    return response;
  }

  // Request OTP
  @override
  Future<Map<String, dynamic>?> requestOtp(
    String phoneNumber,
    String role,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl${AppConfig.authOtp}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber, 'role': role}),
      );

      // The OTP request body would historically have echoed the OTP back
      // in `response.body`. The backend no longer does that, but logging
      // the full body verbatim is still a foot-gun (any future field that
      // carries a token or PII shows up in logs). Log only the status.
      debugPrint('OTP Request Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('OTP Request Exception: $e');
      return null;
    }
  }

  // Verify OTP & Login
  @override
  Future<Map<String, dynamic>?> verifyOtpAndLogin(
    String phoneNumber,
    String otp,
    String? deviceToken,
  ) async {
    try {
      // The key is omitted, never sent as a placeholder. The caller used to
      // default it to the literal 'dummy_token' whenever FCM was
      // unavailable, which the backend stored verbatim.
      final body = <String, dynamic>{'phone_number': phoneNumber, 'otp': otp};
      if (deviceToken != null && deviceToken.isNotEmpty) {
        body['device_token'] = deviceToken;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl${AppConfig.authLogin}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 'success') {
        return null;
      }

      final sessionData = decoded['data'];
      if (sessionData is Map<String, dynamic>) {
        final accessToken = sessionData['token'];
        final refreshToken = sessionData['refresh_token'];
        if (accessToken is String && refreshToken is String) {
          await _saveTokens(accessToken, refreshToken);
        }
      }

      return decoded;
    } catch (e) {
      debugPrint('OTP Verify Error: $e');
      return null;
    }
  }

  @override
  /// Email + password sign-in.
  ///
  /// Returns the decoded envelope on success and null on any failure. The
  /// server answers every credential failure with one message by design, so
  /// there is nothing to distinguish here either -- the caller shows a single
  /// "check your email and password" line.
  ///
  /// `mfaCode` is only ever needed by an operator account. A rider or driver
  /// leaves it null and never sees the field.
  Future<Map<String, dynamic>?> emailLogin({
    required String email,
    required String password,
    String? mfaCode,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl${AppConfig.authEmailLogin}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          if (mfaCode != null && mfaCode.isNotEmpty) 'mfa_code': mfaCode,
        }),
      );

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      if (response.statusCode != 200 || decoded['status'] != 'success') {
        // Surface the error code so the UI can tell "needs a second factor"
        // apart from "wrong password" -- the only distinction the server
        // makes, and only after a correct password.
        return {
          '_error': decoded['error'] ?? {'code': 'AUTH_FAILED'},
        };
      }

      final sessionData = decoded['data'];
      if (sessionData is Map<String, dynamic>) {
        final accessToken = sessionData['token'];
        final refreshToken = sessionData['refresh_token'];
        if (accessToken is String && refreshToken is String) {
          await _saveTokens(accessToken, refreshToken);
        }
      }
      return decoded;
    } catch (e) {
      debugPrint('Email login error: $e');
      return null;
    }
  }

  @override
  /// Ask for a password-reset link.
  ///
  /// The server answers 200 with the same message whatever the address is, so
  /// this returns true for "the request was accepted" and never reveals
  /// whether an account exists.
  Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl${AppConfig.authPasswordForgot}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Password reset request error: $e');
      return false;
    }
  }

  // Update Profile
  @override
  Future<Map<String, dynamic>?> updateProfile({
    String? profilePicPath,
    required String fullName,
    required String email,
    required String gender,
    required String dob,
    required String emergencyContact,
    required String houseNo,
    required String street,
    required String city,
    required String zipCode,
  }) async {
    if (_accessToken == null) await _loadTokens();

    try {
      final uri = Uri.parse('$baseUrl${AppConfig.authUpdate}');

      http.Response response;

      if (profilePicPath != null && profilePicPath.isNotEmpty) {
        var request = http.MultipartRequest('PATCH', uri);
        request.headers['Authorization'] = 'Bearer $_accessToken';

        request.fields['is_updated'] = 'true';
        request.fields['full_name'] = fullName;
        request.fields['email'] = email;
        request.fields['gender'] = gender;
        request.fields['dob'] = dob;
        request.fields['emergency_contact'] = emergencyContact;
        request.fields['house_no'] = houseNo;
        request.fields['street'] = street;
        request.fields['city'] = city;
        request.fields['zip_code'] = zipCode;

        final xFile = XFile(profilePicPath);
        final bytes = await xFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'avatar',
            bytes,
            filename: xFile.name.isNotEmpty ? xFile.name : 'avatar.jpg',
          ),
        );

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        response = await _client.patch(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessToken',
          },
          body: jsonEncode({
            'is_updated': true,
            'full_name': fullName,
            'email': email,
            'gender': gender,
            'dob': dob,
            'emergency_contact': emergencyContact,
            'house_no': houseNo,
            'street': street,
            'city': city,
            'zip_code': zipCode,
          }),
        );
      }

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('Profile Update Error: $e');
      return null;
    }
  }

  // Get Profile — wrapped via authedRequest so an expired access token
  // is silently refreshed instead of producing a black-hole null return
  // that the UI used to interpret as "logged out".
  /// Tell the server about a rotated FCM token.
  ///
  /// FCM replaces a token on reinstall, on device restore and after a long
  /// idle period. `PushNotificationService` used to listen to
  /// `onTokenRefresh` and only `debugPrint` the new value, so a rotated
  /// rider token was never registered -- the server kept a dead one until
  /// the next login, and every push to this rider silently went nowhere.
  ///
  /// Best effort: a failure costs push until the next login, and must never
  /// surface to a rider who did not ask for anything.
  @override
  Future<bool> registerPushToken(String token) async {
    if (token.isEmpty) return false;
    final response = await authedRequest(
      (headers) => _client.patch(
        Uri.parse('$baseUrl${AppConfig.authUpdate}'),
        headers: headers,
        body: jsonEncode({'fcm_token': token}),
      ),
    );
    if (response == null) return false;
    // The token itself is never logged: anyone holding one can push to that
    // device.
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    debugPrint(
      ok
          ? 'Push token registered with the server'
          : 'Push token registration failed (${response.statusCode})',
    );
    return ok;
  }

  @override
  Future<Map<String, dynamic>?> getProfile() async {
    final response = await authedRequest(
      (headers) => _client.get(
        Uri.parse('$baseUrl${AppConfig.authProfile}'),
        headers: headers,
      ),
    );
    if (response == null || response.statusCode != 200) {
      return null;
    }
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('Get Profile parse error: $e');
      return null;
    }
  }

  /// End the session on the server, then locally.
  ///
  /// This used to be `TokenStore.clear()` alone, so a rider's logout was
  /// local only. Two consequences, both real:
  ///
  ///   * the refresh token stayed valid for its full 14-day life, so a copy
  ///     taken off a lost or sold phone kept minting access tokens long
  ///     after the rider pressed Log out;
  ///   * `POST /auth/logout/` is what clears `fcm_token` server-side, so
  ///     dispatch kept addressing push notifications to that handset -- and
  ///     to whoever held it next.
  ///
  /// The server call is best-effort and deliberately first, while the access
  /// token is still valid. A rider with no signal must still be able to log
  /// out, so a failure here is logged and ignored; the local clear is what
  /// the UI depends on and it cannot throw.
  @override
  Future<void> clearSession() async {
    try {
      final refresh = await TokenStore.readRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        await authedRequest(
          (headers) => _client.post(
            Uri.parse('$baseUrl${AppConfig.authLogout}'),
            headers: headers,
            body: jsonEncode({'refresh_token': refresh}),
          ),
        );
      }
    } catch (e) {
      debugPrint('Server-side logout did not complete; clearing locally: $e');
    }

    // Drop this install's push token too, so the device stops holding a
    // credential for a session that has ended. Independent of the call
    // above on purpose.
    try {
      await PushNotificationService.deleteToken();
    } catch (e) {
      debugPrint('Could not delete the local push token: $e');
    }

    await TokenStore.clear();
    _accessToken = null;
  }
}

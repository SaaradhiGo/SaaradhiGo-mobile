import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/app_config.dart';
import 'package:image_picker/image_picker.dart';
import 'token_store.dart';

abstract class AuthApiClient {
  Future<Map<String, dynamic>?> requestOtp(String phoneNumber, String role);
  Future<Map<String, dynamic>?> verifyOtpAndLogin(
    String phoneNumber,
    String otp,
    String deviceToken,
  );
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

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

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
      final response = await http.post(
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
      final newRefresh = (data is Map<String, dynamic>) ? data['refresh_token'] : null;
      if (newAccess is! String || newAccess.isEmpty) {
        throw Exception('refresh response missing token');
      }
      await TokenStore.writeTokens(
        accessToken: newAccess,
        refreshToken: newRefresh is String && newRefresh.isNotEmpty ? newRefresh : refresh,
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
      String phoneNumber, String role) async {
    try {
      final response = await http.post(
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
    String deviceToken,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl${AppConfig.authLogin}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'otp': otp,
          'device_token': deviceToken,
        }),
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
        request.files.add(http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: xFile.name.isNotEmpty ? xFile.name : 'avatar.jpg',
        ));

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        response = await http.patch(
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
  @override
  Future<Map<String, dynamic>?> getProfile() async {
    final response = await authedRequest((headers) => http.get(
          Uri.parse('$baseUrl${AppConfig.authProfile}'),
          headers: headers,
        ));
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

  @override
  Future<void> clearSession() async {
    await TokenStore.clear();
    _accessToken = null;
  }
}

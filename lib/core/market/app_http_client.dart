/// The one interceptor every API request goes through.
///
/// - Adds `X-App-Version`, `X-App-Platform` and `X-App-Name` to every request
///   (the backend's version gate, platform_ops/versions.py, only acts when
///   they are present).
/// - Watches responses for `426 APP_UPDATE_REQUIRED` and publishes the store
///   link to [UpdateRequiredState]. The response itself is returned UNCHANGED,
///   so nothing else on the request path behaves differently.
///
/// Installed once in `main()` with `http.runWithClient`, which makes both the
/// top-level `http.get(...)` calls and every `http.Client()` use this client.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Who this build is, as the backend wants to hear it.
class AppIdentity {
  AppIdentity._();

  static String name = 'rider';
  static String? _version;
  static Future<String>? _loading;

  /// `1.4.2` from the package info; `0.0.0`-safe fallback if it cannot be read
  /// (the backend ignores an unparseable version, so the request still works).
  static Future<String> version() {
    if (_version != null) return Future.value(_version);
    return _loading ??= () async {
      try {
        _version = (await PackageInfo.fromPlatform()).version;
      } catch (_) {
        _version = '';
      }
      return _version!;
    }();
  }

  /// `android` or `ios`.
  static String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  @visibleForTesting
  static void debugSetVersion(String? v) {
    _version = v;
    _loading = null;
  }
}

/// A 426 the app must show a blocking screen for.
@immutable
class UpdateRequired {
  const UpdateRequired({this.message, this.storeUrl, this.minimumVersion});

  final String? message;
  final String? storeUrl;
  final String? minimumVersion;
}

class UpdateRequiredState extends ChangeNotifier {
  static final UpdateRequiredState instance = UpdateRequiredState();

  UpdateRequired? _info;
  UpdateRequired? get info => _info;

  void report(UpdateRequired info) {
    _info = info;
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    _info = null;
    notifyListeners();
  }
}

/// Reads the 426 envelope: `{status:error, error:{code, message, update:{...}}}`.
UpdateRequired? parseUpdateRequired(String body) {
  try {
    final decoded = jsonDecode(body);
    final error = decoded is Map ? decoded['error'] : null;
    if (error is! Map || error['code'] != 'APP_UPDATE_REQUIRED') return null;
    final update = error['update'];
    String? pick(String k) {
      final v = update is Map ? update[k]?.toString().trim() : null;
      return (v == null || v.isEmpty) ? null : v;
    }

    final message = error['message']?.toString().trim();
    return UpdateRequired(
      message: (message == null || message.isEmpty) ? null : message,
      storeUrl: pick('store_url'),
      minimumVersion: pick('minimum_version'),
    );
  } catch (_) {
    return null;
  }
}

class AppHttpClient extends http.BaseClient {
  AppHttpClient([http.Client? inner, UpdateRequiredState? updateState])
    : _inner = inner ?? http.Client(),
      _update = updateState ?? UpdateRequiredState.instance;

  final http.Client _inner;
  final UpdateRequiredState _update;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final version = await AppIdentity.version();
    if (version.isNotEmpty) {
      request.headers.putIfAbsent('X-App-Version', () => version);
    }
    request.headers.putIfAbsent('X-App-Platform', () => AppIdentity.platform);
    request.headers.putIfAbsent('X-App-Name', () => AppIdentity.name);

    final response = await _inner.send(request);
    if (response.statusCode != 426) return response;

    final bytes = await response.stream.toBytes();
    final info = parseUpdateRequired(utf8.decode(bytes, allowMalformed: true));
    if (info != null) _update.report(info);
    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}

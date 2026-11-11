/// Trusted contacts, auto-share and the trip share link (`/sharing/*`,
/// backend #191, 2026-11-09).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'api_service.dart';

class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.optedOut = false,
  });
  final int id;
  final String name;
  final String phone;

  /// The contact replied STOP: they get no more messages.
  final bool optedOut;

  static TrustedContact? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! int) return null;
    return TrustedContact(
      id: id,
      name: raw['name']?.toString() ?? '',
      phone: raw['phone']?.toString() ?? '',
      optedOut: raw['opted_out'] == true,
    );
  }
}

class TrustedContacts {
  const TrustedContacts({
    required this.contacts,
    required this.max,
    required this.note,
  });
  final List<TrustedContact> contacts;
  final int? max;

  /// The server's privacy line, shown under the list.
  final String note;
}

/// GET/POST/DELETE `/sharing/trips/<id>/share/`.
class TripShareLink {
  const TripShareLink({required this.active, this.url});
  final bool active;
  final String? url;

  static TripShareLink fromJson(Object? raw) {
    if (raw is! Map) return const TripShareLink(active: false);
    final url = raw['url']?.toString().trim() ?? '';
    return TripShareLink(
      active: raw['active'] == true && url.isNotEmpty,
      url: url.isEmpty ? null : url,
    );
  }
}

/// A refused or failed call; [message] is the server's own sentence.
class SharingError implements Exception {
  const SharingError(this.code, {this.status = 0, this.field, this.message});
  final String code;
  final int status;
  final String? field;
  final String? message;

  @override
  String toString() => 'SharingError($code, $status, $field)';
}

class SharingService {
  SharingService({ApiService? api}) : _apiOverride = api;
  final ApiService? _apiOverride;
  ApiService get _api => _apiOverride ?? ApiService();

  static Uri _u(String path) => Uri.parse('${AppConfig.baseUrl}/sharing/$path');

  static Object? _decode(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  static SharingError _errorFrom(http.Response? r) {
    if (r == null) return const SharingError('NETWORK');
    final body = _decode(r.body);
    final err = body is Map ? body['error'] : null;
    if (err is Map) {
      final details = err['details'];
      return SharingError(
        err['code']?.toString() ?? 'HTTP_${r.statusCode}',
        status: r.statusCode,
        field: details is Map ? details['field']?.toString() : null,
        message: err['message']?.toString(),
      );
    }
    return SharingError('HTTP_${r.statusCode}', status: r.statusCode);
  }

  static Map _data(http.Response? r, Set<int> ok) {
    if (r == null || !ok.contains(r.statusCode)) throw _errorFrom(r);
    final body = _decode(r.body);
    final data = body is Map ? body['data'] : null;
    if (data is! Map) throw _errorFrom(r);
    return data;
  }

  Future<TrustedContacts> fetchContacts() async {
    final r = await _api.authedRequest(
      (h) => http.get(_u('contacts/'), headers: h),
    );
    final d = _data(r, {200});
    final list = d['contacts'];
    if (list is! List) throw _errorFrom(r);
    return TrustedContacts(
      contacts: [for (final c in list) ?TrustedContact.fromJson(c)],
      max: d['max'] is int ? d['max'] as int : null,
      note: d['note']?.toString() ?? '',
    );
  }

  Future<TrustedContact> addContact({
    required String name,
    required String phone,
  }) async {
    final r = await _api.authedRequest(
      (h) => http.post(
        _u('contacts/'),
        headers: h,
        body: json.encode({'name': name, 'phone': phone}),
      ),
    );
    final c = TrustedContact.fromJson(_data(r, {200, 201})['contact']);
    if (c == null) throw _errorFrom(r);
    return c;
  }

  Future<void> deleteContact(int id) async {
    final r = await _api.authedRequest(
      (h) => http.delete(_u('contacts/$id/'), headers: h),
    );
    if (r == null || (r.statusCode != 200 && r.statusCode != 204)) {
      throw _errorFrom(r);
    }
  }

  Future<bool> fetchAutoShare() async {
    final r = await _api.authedRequest(
      (h) => http.get(_u('settings/'), headers: h),
    );
    return _data(r, {200})['auto_share'] == true;
  }

  Future<bool> setAutoShare(bool on) async {
    final r = await _api.authedRequest(
      (h) => http.patch(
        _u('settings/'),
        headers: h,
        body: json.encode({'auto_share': on}),
      ),
    );
    return _data(r, {200})['auto_share'] == true;
  }

  Future<TripShareLink> tripShare(String tripId) async {
    final r = await _api.authedRequest(
      (h) => http.get(_u('trips/$tripId/share/'), headers: h),
    );
    return TripShareLink.fromJson(_data(r, {200}));
  }

  /// Starts sharing (or returns the live link). 409 TRIP_NOT_ACTIVE before a
  /// driver is on the way or after the trip.
  Future<TripShareLink> startTripShare(String tripId) async {
    final r = await _api.authedRequest(
      (h) => http.post(_u('trips/$tripId/share/'), headers: h),
    );
    return TripShareLink.fromJson(_data(r, {200, 201}));
  }

  Future<TripShareLink> stopTripShare(String tripId) async {
    final r = await _api.authedRequest(
      (h) => http.delete(_u('trips/$tripId/share/'), headers: h),
    );
    return TripShareLink.fromJson(_data(r, {200}));
  }
}

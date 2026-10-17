/// Rider support tickets, against the API that already existed.
///
/// WHY THIS IS NEW CODE FOR AN OLD ENDPOINT
/// ----------------------------------------
/// `lib/screens/profile/help_support_screen.dart` renders tiles labelled
/// "Ride Issues", "Payment & Wallet", "Safety", "Live Chat" and "Email
/// Support". None of them had a handler. A rider with a problem could reach
/// a screen that looks like support and do nothing from it -- the same shape
/// of defect as the decorative SOS button found earlier: it is worse than an
/// absent feature, because the rider stops looking for another way to get
/// help.
///
/// Meanwhile `/support/tickets/create/` has been live and tested the whole
/// time, and the DRIVER app has used it since its support work. This is the
/// rider side of the same API.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'api_service.dart';
import 'models/support_ticket.dart';

/// What a rider can report. These are the server's own `ISSUE_CHOICES`; a
/// value outside the list is rejected by the model's validation, so they are
/// not free text.
enum SupportIssueType {
  payment('payment', 'Payment issue'),
  fareDispute('fare_dispute', 'Fare dispute'),
  driverBehaviour('driver_behaviour', 'Driver behaviour'),
  lostItem('lost_item', 'Lost item'),
  safety('safety', 'Safety concern'),
  account('account', 'Account / KYC'),
  appBug('app_bug', 'App bug'),
  other('other', 'Something else');

  const SupportIssueType(this.wireValue, this.label);

  /// The value the server stores. Do not change without changing
  /// `servers/support/models.py::ISSUE_CHOICES`.
  final String wireValue;

  /// What the rider reads.
  final String label;
}

/// The outcome of a submission, so the UI can say something true.
class SupportResult {
  const SupportResult.created(this.ticket) : error = null, isCreated = true;
  const SupportResult.failed(this.error) : ticket = null, isCreated = false;

  final SupportTicket? ticket;
  final String? error;
  final bool isCreated;
}

class SupportService {
  SupportService({ApiService? apiService, http.Client? client})
    : _api = apiService ?? ApiService(),
      _client = client ?? http.Client();

  final ApiService _api;
  final http.Client _client;

  /// Raise a ticket. [tripId] attaches it to a trip when the rider is
  /// reporting something about a specific ride.
  ///
  /// Goes through `ApiService.authedRequest`, so an expired access token is
  /// refreshed and the request retried once -- the same reason the
  /// notification list was silently empty before it did the same.
  Future<SupportResult> createTicket({
    required SupportIssueType issueType,
    required String description,
    String? tripId,
  }) async {
    final trimmed = description.trim();
    if (trimmed.isEmpty) {
      // The server requires it; refusing here keeps a pointless round trip
      // off a rider's data plan and gives the field an immediate message.
      return const SupportResult.failed('Please describe the problem.');
    }

    final body = <String, dynamic>{
      'issue_type': issueType.wireValue,
      'description': trimmed,
    };
    if (tripId != null && tripId.isNotEmpty) {
      body['trip_id'] = tripId;
    }

    final response = await _api.authedRequest(
      (headers) => _client.post(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.supportCreateTicket}'),
        headers: headers,
        body: jsonEncode(body),
      ),
    );

    if (response == null) {
      return const SupportResult.failed(
        'Could not reach support. Check your connection and try again.',
      );
    }

    if (response.statusCode == 201 || response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
        if (data is Map<String, dynamic>) {
          return SupportResult.created(SupportTicket.fromJson(data));
        }
      } catch (e) {
        debugPrint('Support ticket created but could not be parsed: $e');
      }
      // Created, but the body was not what we expected. The ticket exists --
      // telling the rider it failed would make them submit it twice.
      return const SupportResult.created(null);
    }

    return SupportResult.failed(_messageFrom(response));
  }

  /// The rider's own tickets, newest first. Returns null on failure so the
  /// caller can tell "no tickets" from "could not load".
  Future<List<SupportTicket>?> listTickets() async {
    final response = await _api.authedRequest(
      (headers) => _client.get(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.supportTickets}'),
        headers: headers,
      ),
    );

    if (response == null || response.statusCode != 200) return null;

    try {
      final decoded = jsonDecode(response.body);
      final rows = _rowsFrom(decoded);
      final tickets = <SupportTicket>[];
      for (final row in rows) {
        try {
          tickets.add(SupportTicket.fromJson(row as Map<String, dynamic>));
        } catch (e) {
          // One malformed ticket must not empty the list.
          debugPrint('Skipping an unparseable ticket: $e');
        }
      }
      return tickets;
    } catch (e) {
      debugPrint('Support ticket list parse error: $e');
      return null;
    }
  }

  /// The list endpoint is paginated and wrapped; accept both shapes rather
  /// than guessing one, because the existing backend test accepts both too.
  static List<dynamic> _rowsFrom(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) return data;
      if (data is Map<String, dynamic> && data['results'] is List) {
        return data['results'] as List<dynamic>;
      }
      if (decoded['results'] is List)
        return decoded['results'] as List<dynamic>;
    }
    return const [];
  }

  /// The server's own words, never a generic substitute.
  static String _messageFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
        if (decoded['message'] is String) return decoded['message'] as String;
      }
    } catch (_) {
      // Fall through to the status-based message.
    }
    return 'Could not submit your request (error ${response.statusCode}).';
  }
}

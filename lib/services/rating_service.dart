/// Rate a completed trip.
///
/// WHY THIS IS NEW CODE FOR AN OLD ENDPOINT
/// ----------------------------------------
/// `/ride/rate-trip/` has been live the whole time: riders rate drivers,
/// drivers rate riders, one rating per user per trip, and the server
/// recomputes the rated user's average. **Neither app had any way to submit
/// one.** The driver profile shows a `ratings` figure and the rider is shown
/// `driver_rating`, so both apps display an average that nothing could ever
/// change -- every driver sits at the default for ever.
///
/// For a pilot where driver quality is the thing being measured, that is the
/// measurement missing.
///
/// THE SERVER'S RULES, which this mirrors rather than re-invents
/// ------------------------------------------------------------
///   * the trip must be `completed`      -> TRIP_NOT_COMPLETED, 400
///   * the rater must be on the trip     -> FORBIDDEN, 403
///   * one rating per user per trip      -> ALREADY_RATED, 409
///   * score is an integer 1-5           -> INVALID_SCORE, 400
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'api_service.dart';

/// Why a rating could not be recorded. The UI treats these differently:
/// `alreadyRated` is not a failure the rider should be nagged about.
enum RatingOutcome { submitted, alreadyRated, notEligible, failed }

class RatingResult {
  const RatingResult(this.outcome, {this.message, this.ratingId});

  final RatingOutcome outcome;
  final String? message;
  final int? ratingId;

  bool get isSubmitted => outcome == RatingOutcome.submitted;

  /// True when there is nothing more for the rider to do: either it worked,
  /// or it was already done. Both mean "stop showing the prompt".
  bool get isSettled =>
      outcome == RatingOutcome.submitted ||
      outcome == RatingOutcome.alreadyRated;
}

class RatingService {
  RatingService({ApiService? apiService, http.Client? client})
    : _api = apiService ?? ApiService(),
      _client = client ?? http.Client();

  final ApiService _api;
  final http.Client _client;

  Future<RatingResult> rateTrip({
    required String tripId,
    required int score,
    String? comments,
  }) async {
    if (score < 1 || score > 5) {
      // Refused here so a mis-wired star widget cannot spend a round trip
      // learning what the server already told us.
      return const RatingResult(
        RatingOutcome.failed,
        message: 'Choose between 1 and 5 stars.',
      );
    }

    final body = <String, dynamic>{'trip_id': tripId, 'score': score};
    final trimmed = comments?.trim() ?? '';
    if (trimmed.isNotEmpty) body['comments'] = trimmed;

    final response = await _api.authedRequest(
      (headers) => _client.post(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.rateTrip}'),
        headers: headers,
        body: jsonEncode(body),
      ),
    );

    if (response == null) {
      return const RatingResult(
        RatingOutcome.failed,
        message: 'Could not reach the server. Your rating was not saved.',
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return RatingResult(
        RatingOutcome.submitted,
        ratingId: _ratingIdFrom(response.body),
      );
    }

    final code = _codeFrom(response.body);
    if (response.statusCode == 409 || code == 'ALREADY_RATED') {
      // Not an error worth showing: the rating exists, which is what the
      // rider wanted. Treated as settled so the prompt stops appearing.
      return RatingResult(
        RatingOutcome.alreadyRated,
        message: _messageFrom(response.body),
      );
    }
    if (code == 'TRIP_NOT_COMPLETED' || code == 'FORBIDDEN') {
      return RatingResult(
        RatingOutcome.notEligible,
        message: _messageFrom(response.body),
      );
    }
    return RatingResult(
      RatingOutcome.failed,
      message:
          _messageFrom(response.body) ??
          'Could not save your rating (error ${response.statusCode}).',
    );
  }

  static int? _ratingIdFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      final raw = data is Map<String, dynamic> ? data['rating_id'] : null;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw);
    } catch (e) {
      debugPrint('Rating response parse error: $e');
    }
    return null;
  }

  static String? _codeFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map && error['code'] is String) {
          return error['code'] as String;
        }
      }
    } catch (_) {
      // Not JSON; the status code is all we have.
    }
    return null;
  }

  /// The server's own words. A rating refusal is specific -- "You can only
  /// rate a completed trip" -- and a generic substitute would be worse.
  static String? _messageFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
        if (decoded['message'] is String) return decoded['message'] as String;
      }
    } catch (_) {
      // Fall through.
    }
    return null;
  }
}

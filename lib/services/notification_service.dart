import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'models/notification_model.dart';
import '../core/app_config.dart';

class NotificationService {
  NotificationService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static final String _baseUrl = AppConfig.baseUrl;

  /// Fetch a page of notifications.
  ///
  /// Returns `notifications`, `hasNext` and **`statusCode`**. The status is
  /// new and it matters: this used to answer `{notifications: [], hasNext:
  /// false}` for every non-200, so an expired access token was
  /// indistinguishable from an empty inbox. Access tokens live 15 minutes, so
  /// a rider opening this screen after a short pause was reliably told they
  /// had no notifications. `statusCode == 0` means the request never
  /// completed.
  Future<Map<String, dynamic>> fetchNotifications(
    String token, {
    int page = 1,
  }) async {
    final String url = '$_baseUrl${AppConfig.riderNotifications}?page=$page';

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        List<dynamic> results = [];
        bool hasNext = false;

        if (data is Map<String, dynamic>) {
          // Handle standard DRF pagination
          if (data['results'] != null) {
            results = data['results'];
            hasNext = data['next'] != null;
          }
          // Handle custom wrapped response if it exists
          else if (data['status'] == 'success' && data['data'] != null) {
            final innerData = data['data'];
            if (innerData is Map<String, dynamic> &&
                innerData['results'] != null) {
              results = innerData['results'];
              hasNext = innerData['next'] != null;
            }
          }
        } else if (data is List) {
          results = data;
          hasNext = false;
        }

        // Each row is parsed defensively: one malformed notification must
        // not empty the whole list, which is what an exception here did --
        // the caller caught it and showed "no notifications".
        final parsed = <NotificationModel>[];
        for (final json in results) {
          try {
            parsed.add(NotificationModel.fromJson(json));
          } catch (e) {
            debugPrint('Skipping an unparseable notification: $e');
          }
        }

        return {
          'notifications': parsed,
          'hasNext': hasNext,
          'statusCode': response.statusCode,
        };
      }
      return {
        'notifications': <NotificationModel>[],
        'hasNext': false,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      debugPrint('Fetch Notifications error: $e');
      return {
        'notifications': <NotificationModel>[],
        'hasNext': false,
        'statusCode': 0,
      };
    }
  }

  Future<bool> markAsRead(String token, int notificationId) async {
    final String url = '$_baseUrl/rider/notifications/$notificationId/read/';

    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Mark Notification as Read error: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead(String token) async {
    final String url = '$_baseUrl/rider/notifications/read-all/';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Mark All Notifications as Read error: $e');
      return false;
    }
  }
}

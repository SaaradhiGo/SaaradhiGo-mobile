import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/token_store.dart';
import '../services/models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;

  NotificationProvider({
    NotificationService? notificationService,
    ApiService? apiService,
  }) : _notificationService = notificationService ?? NotificationService(),
       _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static int _statusOf(Map<String, dynamic> result) {
    final raw = result['statusCode'];
    if (raw is int) return raw;
    // A fake or an older service that does not report one: treat a populated
    // result as success rather than inventing a failure.
    return 200;
  }

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _hasNextPage = false;
  int _currentPage = 1;
  int _unreadCount = 0;
  String? _error;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get isFetchingMore => _isFetchingMore;
  bool get hasNextPage => _hasNextPage;
  int get unreadCount => _unreadCount;

  /// Why the last fetch failed, or null.
  ///
  /// There was no such thing, and the screen has only a loading state and an
  /// "empty" state -- so a failed fetch rendered as "you have no
  /// notifications", which is a lie a rider cannot act on. An expired access
  /// token produced it reliably: tokens live 15 minutes, the service returned
  /// an empty list for every non-200, and nothing retried.
  String? get error => _error;

  /// Nothing to show, and nothing went wrong.
  bool get isEmpty => _notifications.isEmpty && _error == null && !_isLoading;

  Future<void> fetchNotifications({bool isRefresh = true}) async {
    if (isRefresh) {
      _isLoading = true;
      _currentPage = 1;
    } else {
      if (!_hasNextPage || _isFetchingMore) return;
      _isFetchingMore = true;
    }
    notifyListeners();

    try {
      // TokenStore, not a raw SharedPreferences read. The prefs copy is a
      // transitional dual-write, and reading it directly bypassed the
      // revocation tombstone -- so a logged-out session could still present
      // a token here.
      var token = await TokenStore.readAccessToken() ?? '';
      if (token.isEmpty) {
        _error = null;
        _notifications = isRefresh ? [] : _notifications;
        return;
      }

      var result = await _notificationService.fetchNotifications(
        token,
        page: _currentPage,
      );

      // Refresh once on 401 and retry. Access tokens live 15 minutes and
      // nothing here refreshed them, so this screen simply stopped working a
      // quarter of an hour into every session.
      if (_statusOf(result) == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed != null && refreshed.isNotEmpty) {
          token = refreshed;
          result = await _notificationService.fetchNotifications(
            token,
            page: _currentPage,
          );
        }
      }

      final status = _statusOf(result);
      if (status != 200) {
        _error = status == 0
            ? 'Could not reach the server. Check your connection.'
            : 'Could not load notifications (error $status).';
        return;
      }

      // Defensive: an unexpected shape used to throw an implicit downcast
      // error that the catch below swallowed, leaving an empty list and no
      // explanation.
      final raw = result['notifications'];
      final newNotifications = raw is List
          ? raw.whereType<NotificationModel>().toList()
          : <NotificationModel>[];
      _hasNextPage = result['hasNext'] == true;
      _error = null;

      if (isRefresh) {
        _notifications = newNotifications;
      } else {
        _notifications.addAll(newNotifications);
        _currentPage++;
      }

      _updateUnreadCount();
    } catch (e) {
      debugPrint('NotificationProvider fetch error: $e');
      _error = 'Could not load notifications.';
    } finally {
      if (isRefresh) {
        _isLoading = false;
      } else {
        _isFetchingMore = false;
      }
      notifyListeners();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      if (token.isNotEmpty) {
        final success = await _notificationService.markAsRead(
          token,
          notificationId,
        );
        if (success) {
          // Update local state for immediate feedback
          final index = _notifications.indexWhere(
            (n) => n.id == notificationId,
          );
          if (index != -1) {
            final n = _notifications[index];
            _notifications[index] = NotificationModel(
              id: n.id,
              title: n.title,
              message: n.message,
              isRead: true,
              createdAt: n.createdAt,
            );
            _updateUnreadCount();
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationProvider markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      if (token.isNotEmpty) {
        final success = await _notificationService.markAllAsRead(token);
        if (success) {
          // Update local state
          _notifications = _notifications
              .map(
                (n) => NotificationModel(
                  id: n.id,
                  title: n.title,
                  message: n.message,
                  isRead: true,
                  createdAt: n.createdAt,
                ),
              )
              .toList();
          _unreadCount = 0;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('NotificationProvider markAllAsRead error: $e');
    }
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }
}

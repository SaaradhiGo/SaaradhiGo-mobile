import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/ride_notifier.dart';
import 'api_service.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize(ProviderContainer container) async {
    try {
      // Foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');

        if (message.data.isNotEmpty) {
          container
              .read(rideNotifierProvider.notifier)
              .updateFromNotification(message.data);
        }

        if (message.notification != null) {
          debugPrint(
            'Message also contained a notification: ${message.notification?.title}',
          );
        }
      });

      // When app is opened from a notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
        if (message.data.isNotEmpty) {
          container
              .read(rideNotifierProvider.notifier)
              .updateFromNotification(message.data);
        }
      });

      // When app is launched from terminated state via a notification
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null && initialMessage.data.isNotEmpty) {
        container
            .read(rideNotifierProvider.notifier)
            .updateFromNotification(initialMessage.data);
      }

      // Register the rotation with the server.
      //
      // This used to only debugPrint the new value. FCM replaces a token on
      // reinstall, on device restore and after a long idle period, so the
      // server kept a dead token until the rider next logged in -- and every
      // push in between went nowhere, silently. The token is never printed:
      // anyone holding one can push to that device.
      _messaging.onTokenRefresh.listen((newToken) {
        if (newToken.isEmpty) return;
        debugPrint('FCM token rotated; registering with the server');
        ApiService().registerPushToken(newToken);
      });
    } catch (e) {
      debugPrint('Error initializing PushNotificationService: $e');
    }
  }

  /// Invalidate this install's token at logout.
  ///
  /// The server clears its own copy inside `POST /auth/logout/`, which is the
  /// half that stops dispatch addressing this handset. This is the device
  /// half: it stops the install holding a credential for a session that has
  /// ended, which matters on a shared or resold phone. Never throws.
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  static Future<String?> getToken() async {
    try {
      // Ensure we have permissions before requesting token
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        String? token = await _messaging.getToken();
        // NOT the token. A push token is a credential: anyone holding it can
        // send this device notifications, and logcat is readable by adb and
        // by crash reporters. The API client already redacts `fcm_token` in
        // request bodies; printing it here put it straight back in the log.
        debugPrint(
          token == null
              ? 'FCM token unavailable'
              : 'FCM token retrieved (${token.length} chars)',
        );
        return token;
      } else {
        debugPrint(
          'User declined or has not accepted notification permissions',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }
}

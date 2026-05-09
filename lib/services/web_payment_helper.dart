// ignore_for_file: avoid_web_libraries_in_flutter, undefined_function, deprecated_member_use
import 'dart:js' as js;
import 'package:js/js.dart' as js_pkg;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'payment_service.dart';

class WebPaymentHelper {
  static Future<GatewaySuccessResponse?> launchCashfree(
      Map<String, dynamic> options) {
    final completer = Completer<GatewaySuccessResponse?>();

    void successCallback(String orderId) {
      debugPrint('WebPaymentHelper: Success - $orderId');
      completer.complete(GatewaySuccessResponse(orderId, '', ''));
    }

    void errorCallback(dynamic code, String message) {
      debugPrint('WebPaymentHelper: Error - $code : $message');
      completer.complete(null);
    }

    try {
      if (js.context.hasProperty('launchCashfree')) {
        js.context.callMethod('launchCashfree', [
          js.JsObject.jsify(options),
          js_pkg.allowInterop(successCallback),
          js_pkg.allowInterop(errorCallback),
        ]);
      } else {
        debugPrint('WebPaymentHelper Error: launchCashfree not found in JS context');
        completer.complete(null);
      }
    } catch (e) {
      debugPrint('WebPaymentHelper Exception: $e');
      completer.complete(null);
    }

    return completer.future;
  }
}

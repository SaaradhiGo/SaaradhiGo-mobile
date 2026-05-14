// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfdropcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import '../core/app_config.dart';
import 'package:google_fonts/google_fonts.dart';

import 'web_payment_stub.dart' if (dart.library.html) 'web_payment_helper.dart';

class GatewaySuccessResponse {
  final String orderId;
  final String paymentId;
  final String signature;
  
  GatewaySuccessResponse(this.orderId, this.paymentId, this.signature);
}

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;

  final CFPaymentGatewayService _cashfreeService = CFPaymentGatewayService();
  Completer<GatewaySuccessResponse?>? _paymentCompleter;

  PaymentService._internal() {
    _cashfreeService.setCallback(verifyPayment, onError);
  }

  void verifyPayment(String orderId) {
    debugPrint('PaymentService: Payment Success for Order: $orderId');
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(GatewaySuccessResponse(orderId, '', ''));
    }
  }

  void onError(CFErrorResponse errorResponse, String orderId) {
    debugPrint('PaymentService: Payment Error - ${errorResponse.getMessage()} : $orderId');
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(null);
    }
  }

  Future<GatewaySuccessResponse?> startPayment({
    required double amount,
    required String name,
    required String description,
    required String orderId,
    required String cashfreePaymentSessionId,
    Map<String, String>? prefill,
    Duration timeout = const Duration(minutes: 2),
    BuildContext? context,
  }) async {
    _paymentCompleter = Completer<GatewaySuccessResponse?>();

    if (orderId.isEmpty || cashfreePaymentSessionId.isEmpty) {
      debugPrint('PaymentService Error: orderId or sessionId is empty.');
      if (!_paymentCompleter!.isCompleted) {
        _paymentCompleter!.complete(null);
      }
      return null;
    }

    OverlayEntry? overlayEntry;
    if (context != null && mounted(context)) {
      overlayEntry = _createOverlayEntry(context);
      Overlay.of(context).insert(overlayEntry);
    }

    try {
      if (kIsWeb) {
        final options = {
          'session_id': cashfreePaymentSessionId,
          'order_id': orderId,
          'environment': AppConfig.cashfreeEnvironment,
        };
        final response = await WebPaymentHelper.launchCashfree(options);
        overlayEntry?.remove();
        return response;
      }

      CFEnvironment environment = AppConfig.cashfreeEnvironment.toLowerCase() == 'production' 
          ? CFEnvironment.PRODUCTION 
          : CFEnvironment.SANDBOX;

      CFSessionBuilder sessionBuilder = CFSessionBuilder()
        ..setEnvironment(environment)
        ..setOrderId(orderId)
        ..setPaymentSessionId(cashfreePaymentSessionId);

      CFSession session = sessionBuilder.build();

      CFThemeBuilder themeBuilder = CFThemeBuilder()
        ..setNavigationBarBackgroundColorColor('#EEBD2B')
        ..setNavigationBarTextColor('#FFFFFF')
        ..setButtonBackgroundColor('#EEBD2B')
        ..setButtonTextColor('#FFFFFF')
        ..setPrimaryTextColor('#000000')
        ..setSecondaryTextColor('#000000');

      CFTheme theme = themeBuilder.build();

      CFDropCheckoutPaymentBuilder dropCheckoutBuilder = CFDropCheckoutPaymentBuilder()
        ..setSession(session)
        ..setTheme(theme);

      CFDropCheckoutPayment dropCheckoutPayment = dropCheckoutBuilder.build();

      _cashfreeService.doPayment(dropCheckoutPayment);
      
      final result = await _paymentCompleter!.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('PaymentService: Payment timed out');
          if (!_paymentCompleter!.isCompleted) {
            _paymentCompleter!.complete(null);
          }
          return null;
        },
      );
      
      overlayEntry?.remove();
      return result;
    } catch (e) {
      debugPrint('PaymentService Exception: $e');
      if (!_paymentCompleter!.isCompleted) {
        _paymentCompleter!.complete(null);
      }
      overlayEntry?.remove();
      return null;
    }
  }

  bool mounted(BuildContext context) {
    try {
      return (context as dynamic).mounted;
    } catch (_) {
      return true;
    }
  }

  OverlayEntry _createOverlayEntry(BuildContext context) {
    return OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFEEBD2B)),
              const SizedBox(height: 20),
              Material(
                color: Colors.transparent,
                child: Text(
                  'Initiating secure payment...',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void dispose() {
    // nothing needed for cashfree
  }
}

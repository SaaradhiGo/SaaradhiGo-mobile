/// Online payment of a finished trip, provider by provider.
///
/// The backend picks the gateway per country and says which one it picked in
/// the create-order response (`gateway`, servers/payments/views.py). The app
/// branches on that and nothing else:
///
///   `razorpay`  open Razorpay Checkout with `order_id`, `key_id`,
///               `amount_paise`, `currency` and `prefill`; on success post
///               `razorpay_order_id`, `razorpay_payment_id` and
///               `razorpay_signature` to verify.
///   `cashfree`  the existing Cashfree path, unchanged. Providers are swappable
///               by backend config, so this stays.
///   anything else, or no order at all
///               "online payment unavailable": the message the backend gave
///               (or the generic one), never a checkout.
///
/// `409 NOT_CHARGED` on create-order means the rider owes nothing (a promo
/// covered the fare, or ops ended the trip as a safety incident or platform
/// fault). It is never a failure and it never opens a checkout.
///
/// Both SDKs are behind small seams so the flow is tested without a device.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'ride_service.dart';

/// The wording of the generic "could not start an online payment" message, as
/// the screen has always shown it.
const String kPaymentUnavailableMessage =
    'Failed to initiate payment. Please try again.';

const String kNotChargedMessage = 'Not charged';

// ---------------------------------------------------------------------------
// The create-order response
// ---------------------------------------------------------------------------

sealed class PaymentOrder {
  const PaymentOrder();
}

/// 409 NOT_CHARGED.
class NotChargedOrder extends PaymentOrder {
  const NotChargedOrder(this.message);
  final String message;
}

/// No usable order: a refusal, an unknown gateway, a missing field.
class UnavailableOrder extends PaymentOrder {
  const UnavailableOrder(this.message);
  final String message;
}

class RazorpayOrder extends PaymentOrder {
  const RazorpayOrder({
    required this.orderId,
    required this.keyId,
    required this.amountMinor,
    required this.currency,
    required this.description,
    required this.prefill,
  });

  final String orderId;
  final String keyId;
  final int amountMinor;
  final String currency;
  final String description;

  /// Only the keys the server filled in (`name`, `contact`, `email`).
  final Map<String, String> prefill;
}

class CashfreeOrder extends PaymentOrder {
  const CashfreeOrder({
    required this.orderId,
    required this.sessionId,
    required this.description,
    required this.prefill,
  });

  final String orderId;
  final String sessionId;
  final String description;
  final Map<String, String> prefill;
}

Map<String, dynamic>? _asMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

String? _nonEmpty(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty || s == 'null') ? null : s;
}

/// The error object of a failed response, if there is one.
Map<String, dynamic>? errorOf(Map<String, dynamic>? body) =>
    _asMap(body?['error']);

/// Reads a create-order response (success body, or the decoded error body the
/// service hands back).
PaymentOrder parseCreateOrder(Map<String, dynamic>? body) {
  final err = errorOf(body);
  if (err != null) {
    final code = _nonEmpty(err['code']);
    final message = _nonEmpty(err['message']);
    if (code == 'NOT_CHARGED') {
      return NotChargedOrder(message ?? 'You were not charged for this trip.');
    }
    return UnavailableOrder(message ?? kPaymentUnavailableMessage);
  }
  if (body == null) return const UnavailableOrder(kPaymentUnavailableMessage);

  final data = _asMap(body['data']) ?? body;
  final gateway = _nonEmpty(data['gateway'])?.toLowerCase();
  final prefillRaw = _asMap(data['prefill']) ?? const <String, dynamic>{};
  final prefill = <String, String>{
    for (final k in const ['name', 'contact', 'email'])
      if (_nonEmpty(prefillRaw[k]) != null) k: _nonEmpty(prefillRaw[k])!,
  };
  final tripId = _nonEmpty(data['trip_id']);
  final description =
      _nonEmpty(data['description']) ??
      (tripId != null ? 'Payment for Trip #$tripId' : 'SaaradhiGo ride');

  if (gateway == 'razorpay') {
    final orderId =
        _nonEmpty(data['order_id']) ?? _nonEmpty(data['gateway_order_id']);
    final keyId = _nonEmpty(data['key_id']);
    final amount = int.tryParse(_nonEmpty(data['amount_paise']) ?? '');
    final currency = _nonEmpty(data['currency']);
    if (orderId == null ||
        keyId == null ||
        amount == null ||
        amount <= 0 ||
        currency == null) {
      return const UnavailableOrder(kPaymentUnavailableMessage);
    }
    return RazorpayOrder(
      orderId: orderId,
      keyId: keyId,
      amountMinor: amount,
      currency: currency,
      description: description,
      prefill: prefill,
    );
  }

  // `cashfree`, or an older backend that predates the `gateway` key and sends
  // only the Cashfree session: exactly what the app has always done.
  final sessionId = _nonEmpty(data['cashfree_payment_session_id']);
  if (gateway == 'cashfree' || (gateway == null && sessionId != null)) {
    final orderId =
        _nonEmpty(data['gateway_order_id']) ?? _nonEmpty(data['id']);
    if (orderId == null) {
      return const UnavailableOrder(kPaymentUnavailableMessage);
    }
    return CashfreeOrder(
      orderId: orderId,
      sessionId: sessionId ?? '',
      description: description,
      prefill: prefill,
    );
  }

  // Unknown gateway, or none: cash only.
  return const UnavailableOrder(kPaymentUnavailableMessage);
}

// ---------------------------------------------------------------------------
// SDK seams
// ---------------------------------------------------------------------------

sealed class CheckoutResult {
  const CheckoutResult();
}

class CheckoutSuccess extends CheckoutResult {
  const CheckoutSuccess({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });
  final String orderId;
  final String paymentId;
  final String signature;
}

class CheckoutCancelled extends CheckoutResult {
  const CheckoutCancelled();
}

class CheckoutFailed extends CheckoutResult {
  const CheckoutFailed(this.message);
  final String message;
}

abstract class RazorpayLauncher {
  Future<CheckoutResult> open(RazorpayOrder order);
}

/// The real thing: `razorpay_flutter` 1.4.7.
class RazorpaySdkLauncher implements RazorpayLauncher {
  @override
  Future<CheckoutResult> open(RazorpayOrder order) {
    final razorpay = Razorpay();
    final done = Completer<CheckoutResult>();
    void finish(CheckoutResult r) {
      if (!done.isCompleted) done.complete(r);
      razorpay.clear();
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      finish(
        CheckoutSuccess(
          orderId: r.orderId ?? order.orderId,
          paymentId: r.paymentId ?? '',
          signature: r.signature ?? '',
        ),
      );
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (r.code == Razorpay.PAYMENT_CANCELLED) {
        finish(const CheckoutCancelled());
      } else {
        finish(CheckoutFailed(r.message ?? 'The payment could not be completed.'));
      }
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      // The rider picked an external wallet app: the result still arrives as
      // success or error on this same checkout.
      debugPrint('Razorpay: external wallet ${r.walletName}');
    });

    try {
      razorpay.open(razorpayOptions(order));
    } catch (e) {
      finish(CheckoutFailed('Could not open the payment screen.'));
    }
    return done.future;
  }
}

/// The options map `Razorpay.open` takes. Public for the tests.
Map<String, dynamic> razorpayOptions(RazorpayOrder order) => {
  'key': order.keyId,
  'order_id': order.orderId,
  'amount': order.amountMinor,
  'currency': order.currency,
  'name': 'SaaradhiGo',
  'description': order.description,
  if (order.prefill.isNotEmpty)
    'prefill': {
      if (order.prefill['contact'] != null) 'contact': order.prefill['contact'],
      if (order.prefill['email'] != null) 'email': order.prefill['email'],
    },
  'theme': {'color': '#EEBD2B'},
};

/// Runs the Cashfree checkout and returns its order id on success.
typedef CashfreeStarter = Future<String?> Function(CashfreeOrder order);

// ---------------------------------------------------------------------------
// The flow
// ---------------------------------------------------------------------------

enum OnlinePaymentOutcome {
  /// The server confirmed the payment.
  paid,

  /// 409 NOT_CHARGED: nothing is owed.
  notCharged,

  /// The rider closed Checkout.
  cancelled,

  /// Checkout or verification failed.
  failed,

  /// Paid at the gateway, not yet captured: confirmation is pending.
  confirming,

  /// No usable gateway: online payment is not available.
  unavailable,
}

class OnlinePaymentResult {
  const OnlinePaymentResult(this.outcome, [this.message]);
  final OnlinePaymentOutcome outcome;
  final String? message;
}

const String kPaymentConfirmingMessage = 'Payment received, confirming...';
const String kPaymentStillConfirmingMessage =
    "Your payment was received and is still being confirmed. We'll update you "
    'shortly; you do not need to pay again.';

class OnlinePaymentFlow {
  OnlinePaymentFlow({
    required this.rides,
    required this.razorpay,
    required this.cashfree,
    this.pollInterval = const Duration(seconds: 3),
    this.maxPolls = 8,
    this.onConfirming,
  });

  final RideService rides;
  final RazorpayLauncher razorpay;
  final CashfreeStarter cashfree;

  /// How often, and at most how many times, the trip is re-read after a
  /// `409 PAYMENT_NOT_CAPTURED`. Bounded: the screen never waits forever.
  final Duration pollInterval;
  final int maxPolls;

  /// Called once when the screen should say "Payment received, confirming...".
  final VoidCallback? onConfirming;

  Future<OnlinePaymentResult> pay({
    required String token,
    required int tripId,
  }) async {
    final body = await rides.createTripPaymentOrder(token, tripId);
    final order = parseCreateOrder(body);
    switch (order) {
      case NotChargedOrder():
        return OnlinePaymentResult(
          OnlinePaymentOutcome.notCharged,
          order.message,
        );
      case UnavailableOrder():
        return OnlinePaymentResult(
          OnlinePaymentOutcome.unavailable,
          order.message,
        );
      case RazorpayOrder():
        return _razorpay(token, tripId, order);
      case CashfreeOrder():
        return _cashfree(token, order);
    }
  }

  Future<OnlinePaymentResult> _razorpay(
    String token,
    int tripId,
    RazorpayOrder order,
  ) async {
    final result = await razorpay.open(order);
    switch (result) {
      case CheckoutCancelled():
        return const OnlinePaymentResult(
          OnlinePaymentOutcome.cancelled,
          'Payment cancelled.',
        );
      case CheckoutFailed():
        return OnlinePaymentResult(OnlinePaymentOutcome.failed, result.message);
      case CheckoutSuccess():
        final verify = await rides.verifyRazorpayPayment(
          token,
          result.orderId,
          result.paymentId,
          result.signature,
        );
        if (verify.isSuccess) {
          return const OnlinePaymentResult(OnlinePaymentOutcome.paid);
        }
        if (verify.code == 'PAYMENT_NOT_CAPTURED') {
          onConfirming?.call();
          return _pollUntilPaid(token, tripId);
        }
        return const OnlinePaymentResult(
          OnlinePaymentOutcome.failed,
          'Payment verification failed.',
        );
    }
  }

  Future<OnlinePaymentResult> _pollUntilPaid(String token, int tripId) async {
    for (var i = 0; i < maxPolls; i++) {
      await Future<void>.delayed(pollInterval);
      final status = await rides.getTripPaymentStatus(token, tripId);
      if (status == 'completed' || status == 'paid') {
        return const OnlinePaymentResult(OnlinePaymentOutcome.paid);
      }
    }
    return const OnlinePaymentResult(
      OnlinePaymentOutcome.confirming,
      kPaymentStillConfirmingMessage,
    );
  }

  Future<OnlinePaymentResult> _cashfree(
    String token,
    CashfreeOrder order,
  ) async {
    final paidOrderId = await cashfree(order);
    if (paidOrderId == null) {
      // The Cashfree callback does not tell cancel from failure; it never did.
      return const OnlinePaymentResult(OnlinePaymentOutcome.cancelled);
    }
    final verify = await rides.verifyTripPayment(token, order.orderId, '', '');
    if (verify != null &&
        (verify['status'] == 'success' || verify['status'] == 'paid')) {
      return const OnlinePaymentResult(OnlinePaymentOutcome.paid);
    }
    return const OnlinePaymentResult(
      OnlinePaymentOutcome.failed,
      'Payment verification failed.',
    );
  }
}

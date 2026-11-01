/// Payloads for the money phase, in the exact shape the backend sends them.
///
/// Copied from the backend's own serializers and tests, not invented here:
///   * create-order:  servers/payments/views.py::create_order and
///                    tests/test_payment_gateway_contract.py (Razorpay / Cashfree)
///   * NOT_CHARGED:   create_order, tests/test_promotions_covered_and_operator_end.py
///   * verify:        servers/payments/views.py::verify_payment
///   * trip_created:  servers/consumers.py (promo_code, discount_amount, rider_payable)
///   * promo apply:   servers/ride/promos.py::PromoResult.to_dict
///   * trip detail:   servers/ride/serializers.py::TripDetailSerializer
///   * ops end/cancel socket frames: servers/ride/operator_end.py, admin_trips.py
///
/// Tokens and ids are obvious placeholders.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

http.Response json(int status, Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> success(Map<String, dynamic> data) => {
  'status': 'success',
  'data': data,
  'meta': {'timestamp': '2026-11-01T09:00:00+05:30'},
};

Map<String, dynamic> failure(String code, String message) => {
  'status': 'error',
  'error': {'code': code, 'message': message, 'field': 'trip_id'},
};

/// create-order for a Razorpay trip (201).
Map<String, dynamic> razorpayOrder() => success({
  'payment_id': 11,
  'gateway': 'razorpay',
  'gateway_order_id': 'order_TestPlaceholder01',
  'amount': '150.00',
  'amount_paise': 15000,
  'currency': 'INR',
  'trip_id': 991,
  'description': 'Payment for Trip #991',
  'prefill': {
    'name': 'Test Rider',
    'contact': '+910000000001',
    'email': 'rider@example.test',
  },
  'cashfree_payment_session_id': null,
  'cashfree_app_id': '',
  'order_token': null,
  'order_id': 'order_TestPlaceholder01',
  'key_id': 'rzp_test_placeholder',
});

/// create-order for a Cashfree trip (201): the shape that has always shipped.
Map<String, dynamic> cashfreeOrder() => success({
  'payment_id': 12,
  'gateway': 'cashfree',
  'gateway_order_id': 'cf_order_placeholder_1',
  'amount': '150.00',
  'amount_paise': '15000',
  'currency': 'INR',
  'trip_id': 991,
  'description': 'Payment for Trip #991',
  'prefill': {'name': 'Test Rider', 'contact': '', 'email': ''},
  'cashfree_payment_session_id': 'session_fake_1',
  'cashfree_app_id': 'app_placeholder',
  'order_token': null,
});

/// The same Cashfree order from a backend that predates the `gateway` key.
Map<String, dynamic> legacyCashfreeOrder() {
  final body = cashfreeOrder();
  (body['data'] as Map<String, dynamic>).remove('gateway');
  return body;
}

Map<String, dynamic> notChargedPromo() => failure(
  'NOT_CHARGED',
  'A promotion covered this trip, so you were not charged.',
);

Map<String, dynamic> notChargedOpsEnd() => failure(
  'NOT_CHARGED',
  'This trip was ended by SaaradhiGo and you were not charged.',
);

Map<String, dynamic> noGateway() => failure(
  'PAYMENT_GATEWAY_ERROR',
  'No payment gateway configured',
);

Map<String, dynamic> verifyOk() => success({
  'message': 'Payment verified successfully',
  'payment_id': 11,
  'status': 'completed',
  'amount': '150.00',
  'gateway': 'razorpay',
});

Map<String, dynamic> paymentNotCaptured() => failure(
  'PAYMENT_NOT_CAPTURED',
  'Your payment is still being confirmed. Please check again shortly.',
);

Map<String, dynamic> signatureInvalid() => failure(
  'SIGNATURE_INVALID',
  'Payment verification failed',
);

/// The booking socket's `trip_created` frame with a promo held on the trip.
Map<String, dynamic> tripCreatedWithPromo() => {
  'type': 'trip_created',
  'trip_id': 991,
  'estimated_fare': '169.02',
  'currency': 'INR',
  'promo_code': 'WELCOME50',
  'discount_amount': '50.00',
  'rider_payable': '119.02',
  'reused': false,
  'message': 'Searching for nearby drivers...',
};

/// The promo covers the whole fare.
Map<String, dynamic> tripCreatedFullyCovered() => {
  'type': 'trip_created',
  'trip_id': 991,
  'estimated_fare': '200.00',
  'currency': 'INR',
  'promo_code': 'ALLOFIT',
  'discount_amount': '200.00',
  'rider_payable': '0.00',
  'reused': false,
  'message': 'Searching for nearby drivers...',
};

Map<String, dynamic> tripCreatedPlain() => {
  'type': 'trip_created',
  'trip_id': 991,
  'estimated_fare': '169.02',
  'currency': 'INR',
  'reused': false,
  'message': 'Searching for nearby drivers...',
};

/// `PromoResult.to_dict()` for an accepted code (the apply preview, data).
Map<String, dynamic> promoApplied() => {
  'ok': true,
  'code': 'WELCOME50',
  'discount_amount': '50.00',
  'final_fare': '119.02',
  'description': 'Welcome offer',
  'reason': '',
};

/// The apply preview's refusal, as PromoService returns it.
Map<String, dynamic> promoRefused(String code) => {
  'ok': false,
  'reason': code,
  'description': 'backend wording, not shown to riders',
};

/// The ride-request socket's refusal when a code stopped applying.
Map<String, dynamic> bookingPromoRefusal(String code) => {
  'type': 'error',
  'code': code,
  'message':
      'That promo code can no longer be applied. Please check the fare and '
      'try again.',
};

/// Socket frame: support ended a started trip (operator_end.py).
Map<String, dynamic> opsEndedFrame() => {
  'type': 'trip_update',
  'trip_id': 991,
  'status': 'complete',
  'message': 'Your ride was ended by SaaradhiGo support.',
  'driver_id': 5,
  'driver_name': '',
};

/// Socket frame: support cancelled a trip the driver never reached.
Map<String, dynamic> opsCancelledFrame() => {
  'type': 'trip_update',
  'trip_id': 991,
  'status': 'cancel',
  'message': 'Your ride was cancelled by support.',
  'driver_id': null,
  'driver_name': '',
};

/// Trip detail after a standard operator end: the fare for the distance
/// driven, capped at the quote.
Map<String, dynamic> tripDetailOpsEndedStandard() => success({
  'id': 991,
  'currency': 'INR',
  'status': 'completed',
  'estimated_fare': '169.02',
  'final_fare': '92.40',
  'actual_distance_km': '4.60',
  'payment_method': 'online',
  'payment_status': 'pending',
  'promo_discount': null,
  'rider_payable': null,
});

/// Trip detail after a platform-funded end (safety incident / platform fault):
/// final fare 0 and payment waived (operator_end.py).
Map<String, dynamic> tripDetailOpsEndedNotCharged() => success({
  'id': 991,
  'currency': 'INR',
  'status': 'completed',
  'estimated_fare': '169.02',
  'final_fare': '0.00',
  'actual_distance_km': '6.25',
  'payment_method': 'online',
  'payment_status': 'waived',
  'promo_discount': null,
  'rider_payable': null,
});

Map<String, dynamic> tripDetailPaid() => success({
  'id': 991,
  'currency': 'INR',
  'status': 'completed',
  'estimated_fare': '150.00',
  'final_fare': '150.00',
  'actual_distance_km': '8.10',
  'payment_method': 'online',
  'payment_status': 'completed',
});

Map<String, dynamic> tripDetailPending() => success({
  'id': 991,
  'currency': 'INR',
  'status': 'completed',
  'final_fare': '150.00',
  'payment_status': 'processing',
});

/// A US quote: additive tax, a per-trip regulatory fee
/// (servers/ride/views.py::estimate_fare, fare 20.00 USD, tax 8.25%, fee 0.50;
/// the totals match the AUDIT 27.63 worked example: the rider pays 22.15).
Map<String, dynamic> usQuote() => {
  'estimated_fare': '22.15',
  'currency': 'USD',
  'distance_unit': 'mi',
  'fare_breakdown': {
    'base_fare': '3.00',
    'distance_fare': '14.00',
    'time_fare': '3.00',
    'surge_multiplier': '1.0',
    'min_fare_applied': false,
    'tax_mode': 'additive',
    'tax_label': 'Sales tax',
    'tax_percent': '8.25',
    'tax_amount': '1.65',
    'per_trip_fee': '0.50',
  },
  'fare_adjustments': <dynamic>[],
};

/// An India quote: inclusive tax, nothing added on top.
Map<String, dynamic> indiaQuote() => {
  'estimated_fare': '169.02',
  'currency': 'INR',
  'distance_unit': 'km',
  'fare_breakdown': {
    'base_fare': '60.00',
    'distance_fare': '55.59',
    'time_fare': '19.62',
    'surge_multiplier': '1.0',
    'min_fare_applied': false,
    'tax_mode': 'inclusive',
    'tax_label': 'GST',
    'tax_percent': '5.00',
    'tax_amount': '8.05',
    'per_trip_fee': '0.00',
  },
  'fare_adjustments': <dynamic>[],
};

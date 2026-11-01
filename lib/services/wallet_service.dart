// ignore_for_file: use_null_aware_elements
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'models/wallet_model.dart';
import '../core/app_config.dart';
import '../utils/log_redaction.dart';

class WalletService {
  WalletService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl = AppConfig.baseUrl;

  Future<Wallet?> fetchWalletBalance(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rider/wallet/balance/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final walletData = data['data'];
          if (walletData != null) {
            return Wallet.fromJson(walletData);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Fetch Wallet Balance error: $e');
      return null;
    }
  }

  Future<List<Transaction>> fetchTransactionHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rider/wallet/transactions/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic>? results;

        if (data is Map<String, dynamic>) {
          if (data['results'] != null) {
            results = data['results'];
          } else if (data['status'] == 'success' && data['data'] != null) {
            if (data['data'] is List) {
              results = data['data'];
            } else if (data['data']['results'] != null) {
              results = data['data']['results'];
            }
          }
        }

        if (results != null) {
          return results.map((json) => Transaction.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Fetch Transaction History error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createTopUpOrder(
    String token,
    double amount,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rider/wallet/create-order/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'amount': amount.toStringAsFixed(2)}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      try {
        final errorData = jsonDecode(response.body);
        debugPrint(
          'Create TopUp Order API Error: ${response.statusCode} - $errorData',
        );
        return errorData; // Return error data so UI can show message
      } catch (_) {
        debugPrint(
          'Create TopUp Order Error: ${response.statusCode} - ${redactedBody(response.body)}',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Create TopUp Order error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifyTopUpPayment(
    String token,
    String orderId,
    String paymentId,
    String signature,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rider/wallet/verify/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'gateway_order_id': orderId,
          'gateway_payment_id': paymentId,
          'gateway_signature': signature,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Verify TopUp Payment error: $e');
      return null;
    }
  }

  /// Pay a completed trip from the wallet.
  /// POST /rider/wallet/payment/
  ///
  /// The server is the only authority on the amount: the body carries the
  /// trip (`trip_id`, plus the legacy `reference_id`) and NO amount and NO
  /// idempotency key. The server charges once per trip and answers a repeat
  /// with 200 and `duplicate: true`.
  Future<Map<String, dynamic>?> directWalletPayment({
    required String token,
    required int tripId,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/rider/wallet/payment/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'trip_id': tripId,
          'reference_id': tripId.toString(),
        }),
      );

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (response.statusCode != 201 && response.statusCode != 200) {
        debugPrint(
          'Direct Wallet Payment Error: ${response.statusCode} - $decoded',
        );
      }
      return decoded;
    } catch (e) {
      debugPrint('Direct Wallet Payment error: $e');
      return null;
    }
  }
}

/// What a wallet payment attempt came to. Only [paid] means money moved (or
/// had already moved for this very trip).
class WalletPayOutcome {
  const WalletPayOutcome({
    required this.paid,
    this.duplicate = false,
    this.code,
    this.data = const {},
  });

  final bool paid;

  /// True when the server replayed the first charge (200, same transaction).
  final bool duplicate;

  /// The server's error code when refused (`ALREADY_PAID`, ...).
  final String? code;
  final Map<String, dynamic> data;

  static const alreadyPaidMessage = 'This trip has already been paid.';
  static const neutralFailureMessage =
      "Couldn't pay from your wallet. Please try again or choose another way to pay.";

  bool get alreadyPaid => code == 'ALREADY_PAID';
  bool get insufficientBalance => code == 'INSUFFICIENT_BALANCE';

  /// The amount the SERVER charged, null when the response lacks one.
  double? get serverAmount => double.tryParse('${data['amount'] ?? ''}');

  Object? get transactionId => data['transaction_id'];
  Object? get newBalance => data['new_balance'];

  /// Rider-facing text for a refusal; never claims money was taken.
  String get failureMessage =>
      alreadyPaid ? alreadyPaidMessage : neutralFailureMessage;

  /// Reads the response envelope. `{status: success, data}` is paid; anything
  /// else (including a null/garbled reply) is a refusal.
  factory WalletPayOutcome.fromResponse(Map<String, dynamic>? body) {
    if (body == null) return const WalletPayOutcome(paid: false);
    final data = body['data'];
    if (body['status'] == 'success' &&
        data is Map<String, dynamic> &&
        data['transaction_id'] != null) {
      return WalletPayOutcome(
        paid: true,
        duplicate: data['duplicate'] == true,
        data: data,
      );
    }
    final error = body['error'];
    final code = error is Map ? error['code']?.toString() : null;
    return WalletPayOutcome(paid: false, code: code);
  }
}

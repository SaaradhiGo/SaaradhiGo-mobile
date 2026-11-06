import '../../core/market/market_config_store.dart';
import 'package:flutter/material.dart';
import '../../ui/sg_tokens.dart';

class Wallet {
  final double balance;

  /// A reward held for review, as the API's decimal string (null when the API
  /// sent none or zero, so no line is shown). It is not spendable yet.
  final String? pendingReview;

  /// The ISO currency the API names for the balance (null: the market's).
  final String? currency;

  Wallet({required this.balance, this.pendingReview, this.currency});

  bool get hasPendingReview => pendingReview != null;

  factory Wallet.fromJson(Map<String, dynamic> json) {
    var balanceValue = json['balance'];
    double parsedBalance = 0.0;

    if (balanceValue is num) {
      parsedBalance = balanceValue.toDouble();
    } else if (balanceValue is String) {
      parsedBalance = double.tryParse(balanceValue) ?? 0.0;
    }

    final held = json['rewards_pending_review']?.toString().trim();
    final heldValue = held == null ? null : double.tryParse(held);
    final currency = json['currency']?.toString().trim();
    return Wallet(
      balance: parsedBalance,
      pendingReview: heldValue != null && heldValue > 0 ? held : null,
      currency: currency == null || currency.isEmpty ? null : currency,
    );
  }
}

class Transaction {
  final int id;
  final String title;
  final String amount;
  final bool isCredit;
  final DateTime dateTime;
  final String status;
  final String transactionId;
  final String type; // 'payment', 'recharge', 'refund', 'cashback'

  /// The API's plain-words label for a line that needs one (a recovery of a
  /// reward reads "Recovery of reward (reviewed)"); null for ordinary lines.
  final String? label;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.isCredit,
    required this.dateTime,
    required this.status,
    required this.transactionId,
    required this.type,
    this.label,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Determine title based on metadata if available, otherwise fallback
    final amountRaw = json['amount'];
    String amountStr = '0.00';

    if (amountRaw is num) {
      amountStr = amountRaw.toStringAsFixed(2);
    } else if (amountRaw is String) {
      amountStr = amountRaw;
    }

    final type =
        json['txn_type'] ?? json['type'] ?? 'payment'; // Default to payment

    return Transaction(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title:
          _label(json['label']) ??
          json['description'] ??
          (type == 'payment' ? 'Ride Payment' : 'Wallet Top-up'),
      amount: amountStr,
      isCredit:
          type == 'credit' ||
          type == 'topup' ||
          type == 'recharge' ||
          type == 'cashback',
      dateTime: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'completed',
      transactionId:
          json['gateway_order_id'] ??
          json['transaction_id'] ??
          json['id'].toString(),
      type: type,
      label: _label(json['label']),
    );
  }

  static String? _label(Object? raw) {
    final s = raw?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  String get formattedDate {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedAmount {
    return '${isCredit ? '+' : '-'}${MarketConfigStore.instance.current.currencySymbol}$amount';
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
        return SgColors.success;
      case 'pending':
        return SgColors.goldText;
      case 'failed':
        return SgColors.danger;
      default:
        return SgColors.inkMuted;
    }
  }
}

class TransactionResponse {
  final List<Transaction> transactions;
  final int currentPage;
  final int totalPages;
  final int totalTransactions;
  final bool hasMore;

  TransactionResponse({
    required this.transactions,
    required this.currentPage,
    required this.totalPages,
    required this.totalTransactions,
    required this.hasMore,
  });

  factory TransactionResponse.fromJson(Map<String, dynamic> json) {
    final transactionsList = (json['transactions'] as List? ?? [])
        .map((item) => Transaction.fromJson(item))
        .toList();

    return TransactionResponse(
      transactions: transactionsList,
      currentPage: json['current_page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
      totalTransactions: json['total_transactions'] ?? transactionsList.length,
      hasMore: json['has_more'] ?? false,
    );
  }
}

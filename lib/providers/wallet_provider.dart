import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/session_events.dart';
import '../services/wallet_service.dart';
import '../services/payment_service.dart';
import '../services/models/wallet_model.dart';

class WalletProvider extends ChangeNotifier {
  WalletProvider({WalletService? walletService})
    : _walletService = walletService ?? WalletService();

  final WalletService _walletService;
  final PaymentService _paymentService = PaymentService();

  Wallet? _wallet;
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  Wallet? get wallet => _wallet;
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get balance => _wallet?.balance ?? 0.0;

  bool _balanceFailed = false;
  bool _transactionsLoaded = false;

  /// The balance could not be loaded (and none is on screen): show the error
  /// with Try again, never a balance of zero.
  bool get balanceFailed => _balanceFailed;

  /// The transactions list came back from the server at least once, so an
  /// empty list really means "No transactions yet".
  bool get transactionsLoaded => _transactionsLoaded;

  /// Loads the balance and the transactions independently, each capped at
  /// kLoadTimeout: one failing does not hide the other. A refused session
  /// is handled by ApiService (sign-out to Log in).
  Future<void> refreshWallet() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('access_token') == null) {
      // No session at all: say so, and let the app take the rider to Log in.
      _balanceFailed = _wallet == null;
      _errorMessage = "We couldn't load your transactions.";
      _isLoading = false;
      notifyListeners();
      SessionEvents.emitExpired();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _balanceFailed = false;
    notifyListeners();

    await Future.wait([
      _walletService.loadBalance().then((w) => _wallet = w).catchError((
        Object e,
      ) {
        debugPrint('Wallet balance failed: $e');
        if (_wallet == null) _balanceFailed = true;
        return _wallet ?? Wallet(balance: 0);
      }),
      _walletService
          .loadTransactions()
          .then((t) {
            _transactions = t;
            _transactionsLoaded = true;
            return t;
          })
          .catchError((Object e) {
            debugPrint('Wallet transactions failed: $e');
            _errorMessage = "We couldn't load your transactions.";
            return _transactions;
          }),
    ]);
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> topUp(double amount, BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return false;

      final orderData = await _walletService.createTopUpOrder(token, amount);

      // Extract order ID with robust fallback paths
      final orderId =
          orderData?['gateway_order_id']?.toString() ??
          orderData?['id']?.toString() ??
          orderData?['data']?['gateway_order_id']?.toString() ??
          orderData?['data']?['id']?.toString();

      final sessionId =
          orderData?['cashfree_payment_session_id']?.toString() ??
          orderData?['data']?['cashfree_payment_session_id']?.toString() ??
          '';

      if (orderId == null || orderId.isEmpty) {
        final backendError = orderData?['error'];
        _errorMessage =
            (backendError != null && backendError['message'] != null)
            ? backendError['message']
            : (orderData?['message'] ?? 'Failed to create top-up order.');
        notifyListeners();
        return false;
      }

      // Use server-provided prefill if available (handle data wrapper)
      final serverPrefill =
          (orderData?['data']?['prefill'] ?? orderData?['prefill'])
              as Map<String, dynamic>?;
      final prefill = {
        'name': serverPrefill?['name']?.toString() ?? 'Rider',
        'contact': serverPrefill?['contact']?.toString() ?? '9876543210',
        'email': serverPrefill?['email']?.toString() ?? 'rider@saaradhigo.com',
      };

      // Extract description with data wrapper fallback
      final description =
          orderData?['data']?['description']?.toString() ??
          orderData?['description']?.toString() ??
          'Wallet Top Up';

      try {
        final successResponse = await _paymentService.startPayment(
          amount: amount,
          name: 'SaaradhiGo',
          description: description,
          orderId: orderId,
          cashfreePaymentSessionId: sessionId,
          prefill: prefill,
          context: context,
        );

        if (successResponse != null) {
          // Verify payment
          final verifyResult = await _walletService.verifyTopUpPayment(
            token,
            orderId,
            successResponse.paymentId,
            successResponse.signature,
          );

          if (verifyResult != null &&
              (verifyResult['status'] == 'success' ||
                  verifyResult['status'] == 'paid')) {
            await refreshWallet();
            return true;
          }
        }
        return false;
      } catch (e) {
        debugPrint('Top Up Payment Error: $e');
        return false;
      }
    } catch (e) {
      debugPrint('Top Up Order Error: $e');
      return false;
    }
  }

  /// Pay for a ride directly from the wallet. The server picks the amount;
  /// the outcome carries what it charged.
  Future<WalletPayOutcome> payForRide({required int tripId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return const WalletPayOutcome(paid: false);

      final outcome = WalletPayOutcome.fromResponse(
        await _walletService.directWalletPayment(token: token, tripId: tripId),
      );

      if (outcome.paid) {
        final newBalance = outcome.newBalance;
        if (_wallet != null && newBalance != null) {
          _wallet = Wallet(
            balance: double.tryParse(newBalance.toString()) ?? _wallet!.balance,
            pendingReview: _wallet!.pendingReview,
            currency: _wallet!.currency,
          );
          notifyListeners();
        }
      }
      return outcome;
    } catch (e) {
      debugPrint('payForRide error: $e');
      return const WalletPayOutcome(paid: false);
    }
  }
}

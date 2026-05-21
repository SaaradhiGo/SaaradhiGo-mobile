import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';

/// Fetches server-controlled feature flags from `GET /api/v1/config/`
/// once at app start. Lets us flip behavior (e.g. enable wallet
/// top-ups when the PPI partnership goes live) without shipping a
/// new app build.
///
/// Conservative defaults: every flag assumes the *safer* posture
/// (closed-loop wallet) until the server response arrives.
class RemoteConfigProvider extends ChangeNotifier {
  bool _walletTopupsEnabled = false;
  bool _walletCreditsOnly = true;
  String _walletBalanceCap = '2000.00';
  String _walletDisplayName = 'VahanGo Credits';
  List<String> _refundModes = const ['original'];
  bool _loaded = false;
  String? _error;

  bool get walletTopupsEnabled => _walletTopupsEnabled;
  bool get walletCreditsOnly => _walletCreditsOnly;
  String get walletBalanceCap => _walletBalanceCap;
  String get walletDisplayName => _walletDisplayName;
  List<String> get refundModes => List.unmodifiable(_refundModes);
  bool get loaded => _loaded;
  String? get error => _error;

  bool get refundToCreditSupported => _refundModes.contains('credit');

  Future<void> fetch() async {
    _error = null;
    try {
      final resp = await http
          .get(Uri.parse('${AppConfig.baseUrl}/config/'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) {
        _error = 'config HTTP ${resp.statusCode}';
        _loaded = true;
        notifyListeners();
        return;
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (body['data'] ?? body) as Map<String, dynamic>;
      final wallet = (data['wallet'] ?? const {}) as Map<String, dynamic>;
      _walletTopupsEnabled = wallet['topups_enabled'] == true;
      _walletCreditsOnly =
          wallet['credits_only'] == true || !_walletTopupsEnabled;
      _walletBalanceCap = (wallet['balance_cap'] ?? '2000.00').toString();
      _walletDisplayName =
          (wallet['display_name'] ?? 'VahanGo Credits').toString();
      final modes = wallet['refund_modes'];
      if (modes is List) {
        _refundModes = modes.map((e) => e.toString()).toList();
      }
    } catch (e) {
      // Keep the safe defaults; surface the error for diagnostics
      // but never block the app on a missing config endpoint.
      _error = e.toString();
      debugPrint('RemoteConfigProvider.fetch failed: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }
}

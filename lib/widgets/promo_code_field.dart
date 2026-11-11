import '../ui/appearance_settings.dart' show sgStrings;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/promo/promo_messages.dart';
import '../services/promo_service.dart';
import '../utils/money.dart';

import '../ui/sg_tokens.dart';
import '../ui/sg_text.dart';

/// Inline promo-code entry for the fare screen.
///
/// SHOWN ONLY WHEN THE BACKEND SAYS A PROMO IS AVAILABLE (app-config
/// `promos_available`, see `MarketConfig.promosAvailable`): the host decides
/// whether to build this widget at all. On apply it calls
/// POST /api/v1/ride/promo/apply/ and shows what the server says: the
/// discount and what the rider pays (`discount_amount`, `final_fare`), or one
/// plain sentence for the refusal. The app computes nothing: the amounts are
/// the server's strings.
///
/// The host keeps the applied code and sends it as `promo_code` on the booking
/// frame; the booking re-validates it, so the preview is never the authority.
class PromoCodeField extends StatefulWidget {
  final double fare;
  final double? pickupLat;
  final double? pickupLong;

  /// ISO code of the quote the fare belongs to; the amounts are shown in it.
  final String? currencyCode;

  /// The vehicle class being quoted (the US preview needs it for tax).
  final String? vehicleType;

  /// Called with every outcome: an applied code (`ok`) or a refusal.
  final void Function(PromoApplyResult result) onApplied;

  /// Called when the rider removes an applied code.
  final VoidCallback? onRemoved;

  /// The code already applied (the host keeps it across rebuilds).
  final PromoApplyResult? applied;

  /// Test seam: replaces the network call. Returns the same map
  /// [PromoService.applyPromo] returns.
  final Future<Map<String, dynamic>?> Function(String code)? applyOverride;

  const PromoCodeField({
    super.key,
    required this.fare,
    required this.onApplied,
    this.onRemoved,
    this.applied,
    this.pickupLat,
    this.pickupLong,
    this.currencyCode,
    this.vehicleType,
    this.applyOverride,
  });

  @override
  State<PromoCodeField> createState() => _PromoCodeFieldState();
}

class PromoApplyResult {
  final bool ok;
  final String code;
  final String discountAmount;
  final String finalFare;
  final String reason;
  final String description;

  PromoApplyResult({
    required this.ok,
    required this.code,
    required this.discountAmount,
    required this.finalFare,
    required this.reason,
    required this.description,
  });

  factory PromoApplyResult.fromMap(Map<String, dynamic> data) {
    return PromoApplyResult(
      ok: data['ok'] == true,
      code: (data['code'] ?? '').toString(),
      discountAmount: (data['discount_amount'] ?? '0').toString(),
      finalFare: (data['final_fare'] ?? '0').toString(),
      reason: (data['reason'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
    );
  }
}

class _PromoCodeFieldState extends State<PromoCodeField> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _refusal;

  Future<Map<String, dynamic>?> _call(String code) async {
    final override = widget.applyOverride;
    if (override != null) return override(code);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return null;
    return PromoService().applyPromo(
      token: token,
      code: code,
      fare: widget.fare,
      pickupLat: widget.pickupLat,
      pickupLong: widget.pickupLong,
      vehicleType: widget.vehicleType,
    );
  }

  Future<void> _apply() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _refusal = null;
    });
    Map<String, dynamic>? raw;
    try {
      raw = await _call(code);
    } catch (_) {
      raw = null;
    }
    if (!mounted) return;
    if (raw == null) {
      setState(() {
        _busy = false;
        _refusal = "We couldn't check that code. Try again.";
      });
      return;
    }
    final res = PromoApplyResult.fromMap(raw);
    setState(() {
      _busy = false;
      _refusal = res.ok ? null : promoRefusalMessage(res.reason);
    });
    widget.onApplied(res);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _applied(PromoApplyResult a) {
    final cur = widget.currencyCode;
    final saved = formatServerMoney(a.discountAmount, cur) ?? a.discountAmount;
    final pay = formatServerMoney(a.finalFare, cur) ?? a.finalFare;
    return Container(
      key: const Key('promo_applied'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SgColors.bg300,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SgColors.success.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${a.code} applied',
                  style: TextStyle(
                    color: SgColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: SgText.sizeSmall,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Discount -$saved',
                  key: const Key('promo_discount_text'),
                  style: TextStyle(
                    color: SgColors.ink,
                    fontSize: SgText.sizeSmall,
                  ),
                ),
                Text(
                  'You pay $pay',
                  key: const Key('promo_payable_text'),
                  style: TextStyle(
                    color: SgColors.ink,
                    fontSize: SgText.sizeSmall,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('promo_remove'),
            onPressed: widget.onRemoved,
            child: Text(
              sgStrings(context).remove,
              style: TextStyle(color: SgColors.goldText),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final applied = widget.applied;
    if (applied != null && applied.ok) return _applied(applied);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('promo_input'),
                controller: _ctrl,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: SgColors.ink),
                decoration: InputDecoration(
                  hintText: sgStrings(context).promoCodeHint,
                  hintStyle: TextStyle(color: SgColors.inkMuted),
                  filled: true,
                  fillColor: SgColors.bg300,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              key: const Key('promo_apply'),
              onPressed: _busy ? null : _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: SgColors.gold500,
                foregroundColor: SgColors.onGold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SgColors.bg000,
                      ),
                    )
                  : const Text(
                      'Apply',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
        if (_refusal != null) ...[
          const SizedBox(height: 6),
          Text(
            _refusal!,
            key: const Key('promo_refusal'),
            style: TextStyle(
              color: SgColors.danger,
              fontSize: SgText.sizeSmall,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/promo_service.dart';

/// Inline promo-code entry widget for the fare-estimate screen.
///
/// Drop it under the fare breakdown. On apply, calls POST
/// /api/v1/ride/promo/apply/ and reports back via [onApplied] with
/// either the discount amount (success) or a server reason code
/// (failure). The host screen wires the discount into the displayed
/// fare and stores the code so the eventual booking request can pass
/// it through to redemption.
class PromoCodeField extends StatefulWidget {
  final double fare;
  final double? pickupLat;
  final double? pickupLong;
  final void Function(PromoApplyResult result) onApplied;

  const PromoCodeField({
    super.key,
    required this.fare,
    required this.onApplied,
    this.pickupLat,
    this.pickupLong,
  });

  @override
  State<PromoCodeField> createState() => _PromoCodeFieldState();
}

class PromoApplyResult {
  final bool ok;
  final String code;
  final double discountAmount;
  final double finalFare;
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
      discountAmount:
          double.tryParse((data['discount_amount'] ?? '0').toString()) ?? 0,
      finalFare: double.tryParse((data['final_fare'] ?? '0').toString()) ?? 0,
      reason: (data['reason'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
    );
  }
}

class _PromoCodeFieldState extends State<PromoCodeField> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _status;
  bool _success = false;

  Future<void> _apply() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      setState(() {
        _busy = false;
        _status = 'Sign in first to apply a promo code.';
        _success = false;
      });
      return;
    }
    final raw = await PromoService().applyPromo(
      token: token,
      code: code,
      fare: widget.fare,
      pickupLat: widget.pickupLat,
      pickupLong: widget.pickupLong,
    );
    if (!mounted) return;
    if (raw == null) {
      setState(() {
        _busy = false;
        _status = 'Could not check that code. Try again.';
        _success = false;
      });
      return;
    }
    final res = PromoApplyResult.fromMap(raw);
    setState(() {
      _busy = false;
      _success = res.ok;
      _status = res.ok
          ? 'Saved Rs.${res.discountAmount.toStringAsFixed(2)}.'
          : (res.description.isNotEmpty
                ? res.description
                : 'That code did not work.');
    });
    widget.onApplied(res);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Promo code',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF24211C),
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
              onPressed: _busy ? null : _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEBD2B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Apply',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
        if (_status != null) ...[
          const SizedBox(height: 6),
          Text(
            _status!,
            style: GoogleFonts.inter(
              color: _success
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

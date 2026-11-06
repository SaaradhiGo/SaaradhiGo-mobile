import '../../core/market/market_config_store.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/account_widgets.dart';
import '../../ui/appearance_settings.dart' show sgStrings;
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../../ui/sg_widgets.dart';
import '../../ui/trip_widgets.dart' show exactMoney;

class PaymentStatusScreen extends StatelessWidget {
  final String status;
  final double? amount;
  final String? transactionId;
  final double? newBalance;
  final String? errorMessage;

  const PaymentStatusScreen({
    super.key,
    required this.status,
    this.amount,
    this.transactionId,
    this.newBalance,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = status == 'success';
    if (!isSuccess) return _failed(context);

    return Scaffold(
      backgroundColor: SgColors.bg000,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              _buildIcon(isSuccess),
              const SizedBox(height: 32),
              _buildTitle(isSuccess),
              const SizedBox(height: 16),
              if (isSuccess) ...[
                _buildAmount(),
                const SizedBox(height: 8),
                if (transactionId != null) _buildTransactionId(),
                const SizedBox(height: 8),
                if (newBalance != null) _buildNewBalance(),
              ] else ...[
                if (errorMessage != null) _buildErrorMessage(errorMessage!),
              ],
              const Spacer(),
              if (isSuccess)
                _buildSuccessButtons(context)
              else
                _buildFailureButtons(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Payment failed (Tier 2 spec, screen 12).
  Widget _failed(BuildContext context) {
    final l = sgStrings(context);
    final market = MarketConfigStore.instance.current;
    return Scaffold(
      backgroundColor: SgColors.bg000,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SgSpace.s4,
                  SgSpace.s5,
                  SgSpace.s4,
                  SgSpace.s4,
                ),
                children: [
                  Container(
                    key: const Key('payment_failed_banner'),
                    padding: const EdgeInsets.all(SgSpace.s4),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        SgColors.danger.withValues(alpha: 0.14),
                        SgColors.bg100,
                      ),
                      borderRadius: BorderRadius.circular(SgRadius.lg),
                      border: Border.all(color: SgColors.danger),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: SgColors.danger),
                            const SizedBox(width: SgSpace.s2),
                            Expanded(
                              child: Text(
                                l.paymentFailed,
                                style: SgText.title.copyWith(
                                  color: SgColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: SgSpace.s2),
                          Text(errorMessage!, style: SgText.body),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: SgSpace.s4),
                  // The gateway does not confirm whether money moved, so this
                  // never says "No money left your account".
                  Text(l.moneyComesBack, style: SgText.body),
                  // TODO(data): without cancel_policy.refund_days the time
                  // it takes is not said.
                  if (market.refundDays != null)
                    Text(
                      l.refundWithin(market.refundDays!),
                      key: const Key('payment_refund_days'),
                      style: SgText.caption,
                    ),
                  if (amount != null) ...[
                    const SizedBox(height: SgSpace.s5),
                    SgEyebrow(l.stillToPay, color: SgColors.inkSubtle),
                    const SizedBox(height: SgSpace.s1),
                    Text(
                      exactMoney(amount!, market.currency.code),
                      key: const Key('payment_still_to_pay'),
                      style: SgText.fareXl.copyWith(fontSize: 44, height: 1),
                    ),
                  ],
                  const SizedBox(height: SgSpace.s5),
                  SgListGroup([
                    SgListRow(
                      key: const Key('payment_support'),
                      icon: SgIcons.help,
                      label: l.talkSupportPayment,
                      chevron: true,
                      onTap: () => context.push('/help-support'),
                    ),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SgSpace.s4,
                SgSpace.s2,
                SgSpace.s4,
                SgSpace.s4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back to the payment choices: retry, or switch method.
                  SgPrimaryButton(
                    key: const Key('payment_try_again'),
                    label: l.tryAnotherWay,
                    onPressed: () => context.pop(),
                  ),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(kSgTouch),
                    ),
                    child: Text(
                      l.goHome,
                      style: SgText.body.copyWith(color: SgColors.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(bool isSuccess) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSuccess
            ? SgColors.gold500.withValues(alpha: 0.2)
            : SgColors.danger.withValues(alpha: 0.2),
        border: Border.all(
          color: isSuccess ? SgColors.goldText : SgColors.danger,
          width: 3,
        ),
      ),
      child: Icon(
        isSuccess ? Icons.check : Icons.close,
        size: 64,
        color: isSuccess ? SgColors.goldText : SgColors.danger,
      ),
    );
  }

  Widget _buildTitle(bool isSuccess) {
    return Text(
      isSuccess ? 'Payment Successful' : 'Payment Failed',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: SgColors.ink,
      ),
    );
  }

  Widget _buildAmount() {
    return Text(
      '${MarketConfigStore.instance.current.currencySymbol}${amount?.toStringAsFixed(2) ?? '0.00'}',
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: SgColors.goldText,
      ),
    );
  }

  Widget _buildTransactionId() {
    return Text(
      'Transaction ID: ${transactionId ?? "N/A"}',
      style: TextStyle(fontSize: 14, color: SgColors.inkMuted),
    );
  }

  Widget _buildNewBalance() {
    return Text(
      'New Balance: ${MarketConfigStore.instance.current.currencySymbol}${newBalance?.toStringAsFixed(2) ?? "0.00"}',
      style: TextStyle(fontSize: 16, color: SgColors.ink),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: SgColors.inkMuted),
      ),
    );
  }

  Widget _buildSuccessButtons(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.go('/home'),
        style: ElevatedButton.styleFrom(
          backgroundColor: SgColors.gold500,
          foregroundColor: SgColors.onGold,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Go Home',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFailureButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: SgColors.gold500,
              foregroundColor: SgColors.onGold,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              context.go('/home');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: SgColors.ink,
              side: BorderSide(color: SgColors.lineStrong),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Use UPI/Card',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

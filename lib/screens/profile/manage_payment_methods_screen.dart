import '../components/market_overlays.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';

import '../../ui/sg_tokens.dart';

class ManagePaymentMethodsScreen extends StatelessWidget {
  const ManagePaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SgColors.bg200,
      appBar: AppBar(
        backgroundColor: SgColors.bg100.withValues(alpha: 0.80),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: SgColors.bg200,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: SgColors.ink, size: 20),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Text(
          'Payment Methods',
          style: TextStyle(
            color: SgColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<WalletProvider>(
        builder: (context, provider, child) {
          final formatter = NumberFormat.currency(
            symbol: marketOf(context).currencySymbol,
            decimalDigits: 2,
          );

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'SAVED METHODS',
                style: TextStyle(
                  color: SgColors.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _PaymentTile(
                title: 'SaaradhiGo Wallet',
                subtitle: 'Balance: ${formatter.format(provider.balance)}',
                icon: Icons.account_balance_wallet,
                isWallet: true,
                onTap: () {
                  context.go('/home?tab=2');
                },
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add New Payment Method'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  foregroundColor: SgColors.goldText,
                  side: BorderSide(
                    color: SgColors.goldText.withValues(alpha: 0.4),
                  ),
                  backgroundColor: const Color(
                    0xFF8B6508,
                  ).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isWallet = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isWallet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isWallet ? SgColors.goldSoft : SgColors.bg300,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWallet
                ? SgColors.goldText.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: SgColors.shadow.withValues(alpha: 0.04),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isWallet ? SgColors.goldSoft : SgColors.bg200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isWallet ? SgColors.goldText : SgColors.inkMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: SgColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: SgColors.inkMuted, fontSize: 13),
                      children: [
                        if (isWallet) const TextSpan(text: 'Balance: '),
                        if (isWallet)
                          TextSpan(
                            text: subtitle.split(': ').last,
                            style: TextStyle(
                              color: SgColors.goldText,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          TextSpan(text: subtitle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: SgColors.goldText, size: 20),
          ],
        ),
      ),
    );
  }
}

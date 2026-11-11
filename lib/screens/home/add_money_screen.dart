import '../components/market_overlays.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';

import '../../ui/sg_tokens.dart';
import '../../ui/sg_text.dart';

class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();
  final List<int> _quickAmounts = [100, 200, 500, 1000];
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _handleQuickAmount(int amount) {
    setState(() {
      _amountController.text = amount.toString();
    });
  }

  Future<void> _proceedToPay() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null) return;

    if (amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum amount is ${marketOf(context, listen: false).currencySymbol}100',
          ),
        ),
      );
      return;
    }
    if (amount > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum amount is ${marketOf(context, listen: false).currencySymbol}2000',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<WalletProvider>();
      final success = await provider.topUp(amount, context);
      if (success == true && mounted) {
        final routerExtra =
            GoRouterState.of(context).extra as Map<String, dynamic>?;
        final returnRoute = routerExtra?['returnRoute'] as String?;
        context.push('/payment-success', extra: {'returnRoute': returnRoute});
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              style: TextStyle(color: SgColors.onDanger),
              provider.errorMessage ?? 'Payment failed. Please try again.',
            ),
            backgroundColor: SgColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      symbol: marketOf(context).currencySymbol,
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: SgColors.bg000,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: SgColors.ink, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add Money',
          style: TextStyle(
            color: SgColors.ink,
            fontSize: SgText.sizeTitle,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<WalletProvider>(
        builder: (context, provider, child) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Current Balance Header
                  Text(
                    'Current Balance',
                    style: TextStyle(
                      color: SgColors.inkMuted,
                      fontSize: SgText.sizeSmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatter.format(provider.balance),
                    style: TextStyle(
                      color: SgColors.ink,
                      fontSize: SgText.sizeDisplay,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Amount Input
                  Text(
                    'Top up amount',
                    style: TextStyle(
                      color: SgColors.inkMuted,
                      fontSize: SgText.sizeSmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: SgColors.goldText,
                      fontSize: SgText.sizeDisplay,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      prefixText: '${marketOf(context).currencySymbol} ',
                      prefixStyle: TextStyle(
                        color: SgColors.goldText,
                        fontSize: SgText.sizeDisplay,
                        fontWeight: FontWeight.w600,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: SgColors.goldLine),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: SgColors.goldText),
                      ),
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: SgColors.goldText,
                        fontSize: SgText.sizeDisplay,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Amount Chips
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _quickAmounts.map((amount) {
                      return InkWell(
                        onTap: () => _handleQuickAmount(amount),
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFEEBD2B,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: const Color(
                                0xFFEEBD2B,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '+ ${marketOf(context).currencySymbol}$amount',
                            style: TextStyle(
                              color: SgColors.goldText,
                              fontSize: SgText.sizeSmall,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const Spacer(),

                  // Proceed Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _proceedToPay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SgColors.gold500,
                        foregroundColor: SgColors.onGold,
                        disabledBackgroundColor: const Color(
                          0xFFEEBD2B,
                        ).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: SgColors.bg000,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Proceed to Pay',
                              style: TextStyle(
                                fontSize: SgText.sizeBody,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

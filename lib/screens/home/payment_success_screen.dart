import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/sg_tokens.dart';
import '../../ui/sg_text.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SgColors.bg000,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: SgColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: SgColors.success,
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Payment Successful',
                style: TextStyle(
                  color: SgColors.ink,
                  fontSize: SgText.px(24),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final extra =
                      GoRouterState.of(context).extra as Map<String, dynamic>?;
                  final returnRoute = extra?['returnRoute'] as String?;
                  return Text(
                    returnRoute != null
                        ? 'Your wallet has been topped up. Continue to complete your ride payment.'
                        : 'Your wallet balance has been updated successfully.',
                    style: TextStyle(
                      color: SgColors.inkMuted,
                      fontSize: SgText.px(16),
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const Spacer(),
              Builder(
                builder: (context) {
                  final extra =
                      GoRouterState.of(context).extra as Map<String, dynamic>?;
                  final returnRoute = extra?['returnRoute'] as String?;
                  final hasReturnRoute =
                      returnRoute != null && returnRoute.isNotEmpty;

                  return SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (hasReturnRoute) {
                          context.go(returnRoute);
                        } else {
                          context.go('/home');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SgColors.gold500,
                        foregroundColor: SgColors.onGold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        hasReturnRoute ? 'Continue to Payment' : 'Back to Home',
                        style: TextStyle(
                          fontSize: SgText.px(16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

import 'market_overlays.dart';

import '../../ui/sg_tokens.dart';

class ComingSoonOverlay extends StatelessWidget {
  const ComingSoonOverlay({super.key});

  /// The configured live cities ("Hyderabad"), or "our service area" when the
  /// server has named none.
  static String _areaNames(BuildContext context) {
    final names = marketOf(context).cityNames;
    return names.isEmpty ? 'our service area' : names;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GestureDetector(
        onTap: () {},
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: SgColors.bg100.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: SgColors.line, width: 1),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: SgColors.gold500.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: SgColors.goldText,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "We're coming soon to your area!",
                  style: TextStyle(
                    color: SgColors.ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Our services are currently available only in ${_areaNames(context)}.\nWe\'ll expand to your location soon!',
                  style: TextStyle(
                    color: SgColors.inkMuted,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _GoldGradientButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: SgColors.onGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldGradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _GoldGradientButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SgColors.gold500,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

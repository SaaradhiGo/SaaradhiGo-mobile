import 'package:flutter/material.dart';

import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';

class CancelledOverlay extends StatelessWidget {
  const CancelledOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: SgColors.bg000.withValues(alpha: 0.9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, color: SgColors.danger, size: 64),
              SizedBox(height: 24),
              Text(
                'Ride Cancelled',
                style: TextStyle(
                  color: SgColors.ink,
                  fontWeight: FontWeight.bold,
                  fontFamily: SgText.sans,
                  fontSize: 24,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Returning to home...',
                style: TextStyle(color: SgColors.inkSubtle, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

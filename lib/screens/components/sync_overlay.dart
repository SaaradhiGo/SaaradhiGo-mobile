import 'package:flutter/material.dart';

import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';

class SyncOverlay extends StatelessWidget {
  const SyncOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: SgColors.bg000.withValues(alpha: 0.8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(SgColors.goldText),
              ),
              SizedBox(height: 24),
              Text(
                'Syncing your ride...',
                style: TextStyle(
                  color: SgColors.ink,
                  fontFamily: SgText.sans,
                  fontSize: SgText.px(16),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

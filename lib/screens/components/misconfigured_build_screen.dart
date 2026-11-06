import 'package:flutter/material.dart';

import '../../core/app_config.dart';

import '../../ui/sg_tokens.dart';
import '../../ui/sg_text.dart';

/// Shown instead of the app when a release build was compiled wrong.
///
/// The alternative is worse than an error screen. A store build that silently
/// talked to QA would let riders book rides that do not exist, against drivers who
/// are not there, and pay for them -- with no indication anywhere that none of it
/// counted. Refusing to start is loud, cheap and impossible to miss in a smoke test
/// before submission.
///
/// Deliberately plain: no branding, no retry. There is nothing the person holding
/// the phone can do, so the message is aimed at whoever cut the build.
class MisconfiguredBuildScreen extends StatelessWidget {
  const MisconfiguredBuildScreen({required this.reason, super.key});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: SgColors.bg000,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    size: 64,
                    color: SgColors.danger,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Build not configured',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SgColors.ink,
                      fontSize: SgText.px(22),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SgColors.inkMuted,
                      fontSize: SgText.px(15),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'This build will not run so it cannot be mistaken for a '
                    'working one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SgColors.inkSubtle, fontSize: SgText.px(13)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small, always-visible marker on any build that is not production.
///
/// Exists because "which environment is this phone on?" was previously
/// unanswerable without rebuilding. A tester holding two identical-looking APKs
/// can now tell them apart.
class EnvironmentBadge extends StatelessWidget {
  const EnvironmentBadge({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.showEnvironmentBadge) return child;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: Material(
                color: SgColors.danger,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  // Excluded from semantics: a screen-reader user on a QA build
                  // does not need this read out before every screen.
                  child: ExcludeSemantics(
                    child: Text(
                      AppConfig.environmentLabel,
                      style: TextStyle(
                        color: SgColors.ink,
                        fontSize: SgText.px(10),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

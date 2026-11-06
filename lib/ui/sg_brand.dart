/// The SaaradhiGo marks (spec 1.4). Badge assets are a DRAFT, to be redrawn by
/// the illustrator; swap the files in assets/brand and nothing else changes.
///
/// * Badge cuts ([SgBrandBadge]): `full` at 96px and above, `small` at 33-95px.
/// * [SgBrandLockup]: app headers. Small badge + "Saaradhi Go" in Cinzel 600.
/// * [SgFullLogo]: sign-in and splash. Gold on dark, deep gold on light.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'sg_text.dart';
import 'sg_tokens.dart';

const kBadgeSmallAsset = 'assets/brand/badge-small-gold.svg';
const kBadgeFullAsset = 'assets/brand/badge-full-gold.svg';
const kLogoGoldAsset = 'assets/brand/saaradhigo-logo-gold.svg';
const kLogoDarkGoldAsset = 'assets/brand/saaradhigo-logo-dark-gold.svg';

/// The badge alone, in gold-text colour (#FFD700 on dark, #7A6000 on light).
class SgBrandBadge extends StatelessWidget {
  const SgBrandBadge({super.key, this.size = 32, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    size >= 96 ? kBadgeFullAsset : kBadgeSmallAsset,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color ?? SgColors.goldText, BlendMode.srcIn),
    semanticsLabel: 'SaaradhiGo',
  );
}

/// Badge + "Saaradhi Go", for headers. Badge 32-48px.
class SgBrandLockup extends StatelessWidget {
  const SgBrandLockup({super.key, this.badgeSize = 32});
  final double badgeSize;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'SaaradhiGo',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SgBrandBadge(size: badgeSize),
        SizedBox(width: badgeSize / 4),
        Text('Saaradhi Go', style: SgText.brandLockup(badgeSize * 0.56)),
      ],
    ),
  );
}

/// The full logo (horse, rider, wheel and lettering).
class SgFullLogo extends StatelessWidget {
  const SgFullLogo({super.key, this.height = 160});
  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    SgColors.isDark ? kLogoGoldAsset : kLogoDarkGoldAsset,
    height: height,
    semanticsLabel: 'SaaradhiGo',
  );
}

/// The fare-first home (Tier 2 spec, screen 3): header, headline, the From/To
/// card, "Fares from here, right now", the lock line and the bottom tab bar.
/// Pure views: values in, taps out.
library;

import 'appearance_settings.dart' show sgStrings;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/vehicle_classes.dart';
import 'account_widgets.dart' show SgAvatar;
import 'sg_brand.dart';
import 'sg_text.dart';
import 'sg_tokens.dart';
import 'sg_widgets.dart';

/// "Ravi Kumar" -> "Ravi": the full name split on the first space.
String homeFirstName(String? fullName) {
  final t = (fullName ?? '').trim();
  if (t.isEmpty) return '';
  final i = t.indexOf(' ');
  return i < 0 ? t : t.substring(0, i);
}

/// "24 min", "1 h 05 min".
String durationLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '${minutes ~/ 60} h $m min';
}

/// Badge and name, the language chip, the account avatar.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.languageShort,
    required this.onLanguage,
    required this.name,
    required this.onAccount,
    this.avatarUrl,
  });

  final String languageShort;
  final VoidCallback onLanguage;
  final String? name;
  final String? avatarUrl;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SgBrandLockup(badgeSize: 32),
      const Spacer(),
      Semantics(
        button: true,
        label: sgStrings(context).language,
        child: InkWell(
          key: const Key('home_language_chip'),
          onTap: onLanguage,
          borderRadius: BorderRadius.circular(SgRadius.pill),
          child: Container(
            height: kSgTouch,
            padding: const EdgeInsets.symmetric(horizontal: SgSpace.s3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SgRadius.pill),
              border: Border.all(color: SgColors.lineStrong),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SgIcon(SgIcons.language, size: 18, color: SgColors.ink),
                const SizedBox(width: SgSpace.s1),
                Text(
                  languageShort,
                  style: SgText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: SgSpace.s2),
      Semantics(
        button: true,
        label: sgStrings(context).tabAccount,
        child: InkWell(
          key: const Key('home_account_avatar'),
          onTap: onAccount,
          customBorder: const CircleBorder(),
          child: SgAvatar(name: name, url: avatarUrl, size: kSgTouch),
        ),
      ),
    ],
  );
}

/// From (the pickup, with "You are here" when it is the current location)
/// over To (the large destination field). The fields are the screen's own, so
/// their behaviour is untouched.
class HomeFromToCard extends StatelessWidget {
  const HomeFromToCard({
    super.key,
    required this.from,
    required this.to,
    this.youAreHere,
    this.results,
  });

  final Widget from;
  final Widget to;

  /// "You are here", or null to leave the tag out.
  final String? youAreHere;

  /// Search results, under the fields while one has focus.
  final Widget? results;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: SgColors.bg100,
      borderRadius: BorderRadius.circular(SgRadius.lg),
      border: Border.all(color: SgColors.line),
    ),
    padding: const EdgeInsets.fromLTRB(
      SgSpace.s4,
      SgSpace.s2,
      SgSpace.s3,
      SgSpace.s3,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: SgColors.pickup,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: SgSpace.s3),
              Expanded(child: from),
              if (youAreHere != null)
                Container(
                  key: const Key('home_you_are_here'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SgSpace.s2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SgColors.pickup.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(SgRadius.pill),
                  ),
                  child: Text(
                    youAreHere!,
                    style: SgText.caption.copyWith(
                      color: SgColors.pickup,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Container(width: 2, height: 10, color: SgColors.line),
          ),
        ),
        const SizedBox(height: SgSpace.s1),
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: SgSpace.s3),
          decoration: BoxDecoration(
            color: SgColors.bg300,
            borderRadius: BorderRadius.circular(SgRadius.md),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: SgColors.gold500,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: SgSpace.s3),
              Expanded(child: to),
            ],
          ),
        ),
        ?results,
      ],
    ),
  );
}

/// One class on a home fare card: 14% class tint tile, the class name in its
/// colour, the fare.
class HomeClassChip extends StatelessWidget {
  const HomeClassChip({
    super.key,
    required this.type,
    required this.fareText,
    required this.onTap,
  });

  final String type;
  final String fareText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${vehicleClassName(type)} $fareText',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SgRadius.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(
          horizontal: SgSpace.s2,
          vertical: SgSpace.s2,
        ),
        decoration: BoxDecoration(
          color: vehicleTileColour(type),
          borderRadius: BorderRadius.circular(SgRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  vehicleClassAsset(type),
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    vehicleIconColour(type),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: SgSpace.s1),
                Flexible(
                  child: Text(
                    vehicleClassName(type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SgText.caption.copyWith(
                      color: vehicleIconColour(type),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              fareText,
              style: SgText.fare.copyWith(fontSize: 18, height: 22 / 18),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A place on "Fares from here, right now": its name, distance and time, and
/// up to three classes. While loading, a thin spinner; when quoting failed,
/// "Tap to see fares".
class HomeFareCard extends StatelessWidget {
  const HomeFareCard({
    super.key,
    required this.name,
    required this.onTap,
    this.meta,
    this.chips = const [],
    this.loading = false,
    this.fallback,
  });

  final String name;

  /// "6.2 km · 18 min".
  final String? meta;
  final List<HomeClassChip> chips;
  final bool loading;

  /// "Tap to see fares": shown when there are no chips and nothing loading.
  final String? fallback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: SgColors.bg100,
    borderRadius: BorderRadius.circular(SgRadius.lg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SgRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(SgSpace.s4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SgRadius.lg),
          border: Border.all(color: SgColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SgIcon(SgIcons.pin, size: 20, color: SgColors.goldText),
                const SizedBox(width: SgSpace.s2),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SgText.title,
                  ),
                ),
                if (meta != null)
                  Text(
                    meta!,
                    style: SgText.caption.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: SgSpace.s3),
            if (chips.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: SgSpace.s2),
                    Expanded(child: chips[i]),
                  ],
                  for (var i = chips.length; i < 3; i++) ...[
                    const SizedBox(width: SgSpace.s2),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              )
            else if (loading)
              const SizedBox(
                height: 64,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SgColors.gold500,
                    ),
                  ),
                ),
              )
            else if (fallback != null)
              Text(
                fallback!,
                style: SgText.body.copyWith(
                  color: SgColors.goldText,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// The lock icon and "The fare you book is the fare you pay."
class FareLockLine extends StatelessWidget {
  const FareLockLine(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SgColors.inkMuted;
    return Row(
      children: [
        SgIcon(SgIcons.lock, size: 16, color: c),
        const SizedBox(width: SgSpace.s2),
        Expanded(
          child: Text(
            text,
            style: SgText.caption.copyWith(
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class SgTabItem {
  const SgTabItem({required this.key, required this.icon, required this.label});
  final Key key;
  final String icon;
  final String label;
}

/// The bottom tab bar: Ride, Trips, Account.
class SgTabBar extends StatelessWidget {
  const SgTabBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<SgTabItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: SgColors.bg100,
      border: Border(top: BorderSide(color: SgColors.line)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  label: items[i].label,
                  excludeSemantics: true,
                  child: InkWell(
                    key: items[i].key,
                    onTap: () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SgIcon(
                          items[i].icon,
                          size: 24,
                          color: i == selected
                              ? SgColors.goldText
                              : SgColors.inkSubtle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].label,
                          style: SgText.caption.copyWith(
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w700,
                            color: i == selected
                                ? SgColors.goldText
                                : SgColors.inkSubtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

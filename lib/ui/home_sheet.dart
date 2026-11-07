/// The "Where to?" sheet on the home screen (design: MobileBooking, Home).
library;

import 'appearance_settings.dart' show sgStrings;
import 'package:flutter/material.dart';

import 'sg_text.dart';
import 'sg_tokens.dart';
import 'sg_widgets.dart';

class SavedChipData {
  const SavedChipData({
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.icon,
  });
  final String label;
  final String? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
}

class RecentPlaceData {
  const RecentPlaceData({
    required this.name,
    required this.address,
    required this.onTap,
    this.onLongPress,
    this.distance,
  });
  final String name;
  final String address;
  final String? distance;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
}

String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Inorbit Mall, Madhapur" -> name "Inorbit Mall", address "Madhapur".
({String name, String address}) splitPlace(String full) {
  final parts = full
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return (name: full, address: '');
  return (name: parts.first, address: parts.skip(1).join(', '));
}

class HomeSheet extends StatelessWidget {
  const HomeSheet({
    super.key,
    required this.greeting,
    required this.search,
    required this.chips,
    required this.recents,
    this.banner,
    this.loading = false,
    this.expanded = false,
  });

  final String greeting;

  /// The destination field, built by the screen so its behaviour is untouched.
  final Widget search;
  final List<SavedChipData> chips;
  final List<RecentPlaceData> recents;

  /// An ongoing-ride tile, shown above the places when a trip is live.
  final Widget? banner;
  final bool loading;

  /// Searching: only the fields and their results show.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return SgSheetSurface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!expanded) ...[
              Text(greeting, style: SgText.caption),
              Text(sgStrings(context).whereTo, style: SgText.display),
              const SizedBox(height: SgSpace.s3),
            ],
            // Keyed: opening the search removes the lines above it, and an
            // unkeyed field would be rebuilt there, losing focus and the keyboard.
            KeyedSubtree(key: const ValueKey('home-search'), child: search),
            if (expanded)
              const SizedBox.shrink()
            else ...[
              if (banner != null) ...[
                const SizedBox(height: SgSpace.s3),
                banner!,
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: SgSpace.s3),
                SizedBox(
                  height: kSgTouch,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final c in chips)
                        Padding(
                          padding: const EdgeInsets.only(right: SgSpace.s2),
                          child: _Chip(data: c),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: SgSpace.s2),
              if (loading && recents.isEmpty && chips.isEmpty)
                Padding(
                  padding: EdgeInsets.all(SgSpace.s4),
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
              else if (recents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: SgSpace.s3),
                  child: Text(
                    sgStrings(context).placesAppearHere,
                    style: SgText.caption,
                  ),
                )
              else
                for (var i = 0; i < recents.length; i++)
                  _Place(data: recents[i], last: i == recents.length - 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.data});
  final SavedChipData data;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(SgRadius.pill),
      onTap: data.onTap,
      onLongPress: data.onLongPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: kSgTouch, maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: SgSpace.s4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SgRadius.pill),
          border: Border.all(color: SgColors.lineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SgIcon(
              data.icon ?? SgIcons.pin,
              size: 16,
              color: SgColors.goldText,
            ),
            const SizedBox(width: SgSpace.s2),
            Flexible(
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SgText.body,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Place extends StatelessWidget {
  const _Place({required this.data, required this.last});
  final RecentPlaceData data;
  final bool last;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: data.onTap,
    onLongPress: data.onLongPress,
    child: Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: SgColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SgColors.bg200,
              shape: BoxShape.circle,
            ),
            child: const Center(child: SgIcon(SgIcons.clock, size: 18)),
          ),
          const SizedBox(width: SgSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SgText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                if (data.address.isNotEmpty)
                  Text(
                    data.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SgText.caption,
                  ),
              ],
            ),
          ),
          if (data.distance != null)
            Text(
              data.distance!,
              style: SgText.caption.copyWith(
                color: SgColors.inkSubtle,
                fontSize: SgText.sizeSmall,
              ),
            ),
        ],
      ),
    ),
  );
}

/// The search field's look: gold square, text, "Now" chip. The screen puts its
/// TextField in [field].
class SgSearchBar extends StatelessWidget {
  const SgSearchBar({super.key, required this.field});
  final Widget field;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: SgSpace.s4),
    decoration: BoxDecoration(
      color: SgColors.bg300,
      borderRadius: BorderRadius.circular(SgRadius.md),
    ),
    child: Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: SgColors.gold500,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: SgSpace.s3),
        Expanded(child: field),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: SgColors.bg100,
            borderRadius: BorderRadius.circular(SgRadius.pill),
          ),
          child: Text(
            'Now',
            style: SgText.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

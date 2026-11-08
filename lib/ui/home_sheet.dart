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

/// The home's bottom sheet (signed-in design rider-app-home): "Where to?",
/// the destination field, saved-place chips and the recent places.
class HomeSheet extends StatelessWidget {
  const HomeSheet({
    super.key,
    required this.search,
    required this.chips,
    required this.recents,
    this.banner,
    this.loading = false,
    this.failed = false,
    this.onRetry,
    this.expanded = false,
  });

  /// The destination field, built by the screen so its behaviour is untouched.
  final Widget search;
  final List<SavedChipData> chips;
  final List<RecentPlaceData> recents;

  /// An ongoing-ride tile, shown above the places when a trip is live.
  final Widget? banner;
  final bool loading;

  /// Recent places could not be loaded: the error and Try again ([onRetry]).
  final bool failed;
  final VoidCallback? onRetry;

  /// Searching: only the fields and their results show.
  final bool expanded;

  static Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: SgColors.bg200,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SgSheetSurface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!expanded) ...[
              Text(
                sgStrings(context).whereTo,
                key: const Key('home_where_to'),
                style: SgText.title,
              ),
              const SizedBox(height: SgSpace.s4),
            ],
            // Keyed: opening the search removes the lines above it, and an
            // unkeyed field would be rebuilt there, losing focus and the keyboard.
            KeyedSubtree(key: const ValueKey('home-search'), child: search),
            if (!expanded) ...[
              if (banner != null) ...[
                const SizedBox(height: SgSpace.s4),
                banner!,
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: SgSpace.s4),
                Wrap(
                  spacing: SgSpace.s2,
                  runSpacing: SgSpace.s2,
                  children: [for (final c in chips) _Chip(data: c)],
                ),
              ],
              const SizedBox(height: SgSpace.s4),
              if (loading && recents.isEmpty && chips.isEmpty)
                Column(
                  key: const Key('home_places_loading'),
                  children: [
                    for (var i = 0; i < 2; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: SgSpace.s2,
                        ),
                        child: Row(
                          children: [
                            _bar(36, 36),
                            const SizedBox(width: SgSpace.s3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _bar(140, 14),
                                  const SizedBox(height: 6),
                                  _bar(200, 12),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              else if (failed && recents.isEmpty)
                Row(
                  key: const Key('home_places_error'),
                  children: [
                    Expanded(
                      child: Text(
                        sgStrings(context).loadErrPlaces,
                        style: SgText.caption,
                      ),
                    ),
                    TextButton(
                      key: const Key('home_places_retry'),
                      onPressed: onRetry,
                      child: Text(
                        sgStrings(context).tryAgain,
                        style: SgText.body.copyWith(
                          color: SgColors.goldText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
                for (final r in recents) _Place(data: r),
            ],
          ],
        ),
      ),
    );
  }
}

/// A 36px pill: gold-text icon, 14px semibold label.
class _Chip extends StatelessWidget {
  const _Chip({required this.data});
  final SavedChipData data;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: SgColors.bg100,
      shape: StadiumBorder(side: BorderSide(color: SgColors.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: data.onTap,
        onLongPress: data.onLongPress,
        child: Container(
          height: 36,
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SgIcon(
                data.icon ?? SgIcons.pin,
                size: 18,
                color: SgColors.goldText,
              ),
              const SizedBox(width: SgSpace.s2),
              Flexible(
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SgText.caption.copyWith(
                    color: SgColors.ink,
                    fontWeight: FontWeight.w600,
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

/// A recent place: clock tile, name, address; a hairline under each row.
class _Place extends StatelessWidget {
  const _Place({required this.data});
  final RecentPlaceData data;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: data.onTap,
    onLongPress: data.onLongPress,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: SgSpace.s3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: SgColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SgColors.bg200,
              borderRadius: BorderRadius.circular(SgSpace.s3),
            ),
            child: Center(
              child: SgIcon(SgIcons.clock, size: 20, color: SgColors.inkMuted),
            ),
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
            Text(data.distance!, style: SgText.caption),
        ],
      ),
    ),
  );
}

/// The destination field's look (design `.field`): 52 high, bg-200, 12
/// corners, an ink square before the text. The screen puts its TextField in
/// [field].
class SgSearchBar extends StatelessWidget {
  const SgSearchBar({super.key, required this.field});
  final Widget field;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: SgSpace.s4),
    decoration: BoxDecoration(
      color: SgColors.bg200,
      borderRadius: BorderRadius.circular(SgSpace.s3),
    ),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: SgColors.ink,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: SgSpace.s3),
        Expanded(child: field),
      ],
    ),
  );
}

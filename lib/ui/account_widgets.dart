/// Rider group C: the menu and account screens on the design system. Pure
/// views; the screens pass in what to show.
library;

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'sg_text.dart';
import 'sg_tokens.dart';
import 'sg_widgets.dart';
import 'trip_widgets.dart' show SgStar, initialsOf;

const kCardIcon =
    '<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M3 10h18"/>';
const kGiftIcon =
    '<rect x="4" y="9" width="16" height="11" rx="1"/><path d="M12 9v11M4 13h16M12 9c-2-4-6-3-5 0M12 9c2-4 6-3 5 0"/>';
const kChevronIcon = '<path d="M9 5l7 7-7 7"/>';
const kLogoutIcon = '<path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10"/>';

/// The page title used by Your rides, Wallet and Profile.
class SgPageTitle extends StatelessWidget {
  const SgPageTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: SgSpace.s2, bottom: SgSpace.s5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SgText.heading),
        if (subtitle != null) ...[
          const SizedBox(height: SgSpace.s1),
          Text(
            subtitle!,
            style: SgText.body.copyWith(color: SgColors.inkMuted),
          ),
        ],
      ],
    ),
  );
}

/// A photo when the rider has one, their initials otherwise. Never a stock face.
class SgAvatar extends StatelessWidget {
  const SgAvatar({super.key, this.name, this.url, this.size = 56});

  final String? name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name);
    final fallback = Center(
      child: initials.isEmpty
          ? SgIcon(SgIcons.user, size: size * 0.45, color: SgColors.ink)
          : Text(
              initials,
              style: (size >= 56
                  ? SgText.title
                  : SgText.label.copyWith(color: SgColors.ink)),
            ),
    );
    final photo = url?.trim() ?? '';
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SgColors.bg300,
        shape: BoxShape.circle,
        border: Border.all(color: SgColors.goldLine),
      ),
      child: photo.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: photo,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// Name with rating under it; the rating line is left out when there is none.
class SgPersonHeader extends StatelessWidget {
  const SgPersonHeader({
    super.key,
    required this.name,
    this.rating,
    this.avatarUrl,
    this.onTap,
  });

  final String? name;
  final String? rating;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shown = (name ?? '').trim();
    final r = double.tryParse(rating ?? '');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SgRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SgSpace.s2),
        child: Row(
          children: [
            SgAvatar(name: shown, url: avatarUrl),
            const SizedBox(width: SgSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shown.isEmpty ? 'Add your name' : shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SgText.title,
                  ),
                  if (r != null && r > 0)
                    Row(
                      children: [
                        SgStar(size: 14, color: SgColors.gold500),
                        const SizedBox(width: SgSpace.s1),
                        Text(
                          r.toStringAsFixed(2),
                          key: const Key('person_rating'),
                          style: SgText.caption,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in the menu or the account list: icon, label, optional count.
class SgListRow extends StatelessWidget {
  const SgListRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.count = 0,
    this.chevron = false,
    this.danger = false,
    this.value,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final int count;
  final bool chevron;
  final bool danger;

  /// The current setting, shown before the chevron ("Dark", "English").
  final String? value;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: count > 0
        ? '$label, $count unread'
        : (value != null ? '$label, $value' : label),
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SgRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            SgIcon(
              icon,
              size: 22,
              color: danger ? SgColors.danger : SgColors.inkMuted,
            ),
            const SizedBox(width: SgSpace.s4),
            Expanded(
              child: Text(
                label,
                style: SgText.body.copyWith(
                  color: danger ? SgColors.danger : SgColors.ink,
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SgColors.bg300,
                  borderRadius: BorderRadius.circular(SgRadius.pill),
                ),
                child: Text(
                  '$count',
                  style: SgText.caption.copyWith(color: SgColors.ink),
                ),
              ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: SgSpace.s2,
                  right: SgSpace.s1,
                ),
                child: Text(value!, style: SgText.caption),
              ),
            if (chevron)
              SgIcon(kChevronIcon, size: 18, color: SgColors.inkSubtle),
          ],
        ),
      ),
    ),
  );
}

/// Rows grouped on one panel with hairlines between them.
class SgListGroup extends StatelessWidget {
  const SgListGroup(this.rows, {super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: SgSpace.s4),
    decoration: BoxDecoration(
      color: SgColors.bg100,
      borderRadius: BorderRadius.circular(SgRadius.lg),
      border: Border.all(color: SgColors.line),
    ),
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: SgColors.line),
          rows[i],
        ],
      ],
    ),
  );
}

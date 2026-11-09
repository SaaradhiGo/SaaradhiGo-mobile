/// Account > Saved places (GET /rider/places/): Home, Work and the others,
/// each with Edit and Delete, and Add a place.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/app_localizations.dart';
import '../../services/favorite_location_service.dart';
import '../../services/models/location_model.dart';
import '../../services/session_events.dart' show kLoadTimeout;
import '../../ui/appearance_settings.dart' show sgStrings;
import '../../ui/home_sheet.dart' show splitPlace;
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../../ui/sg_widgets.dart';
import 'place_sheet.dart';

/// The server's notice, in the rider's language when it is the known line.
String placeNotice(AppLocalizations l, FavoriteLocation p) {
  final n = p.notice;
  if (n == null) return '';
  return n == 'Outside our service area for now' ? l.placeOutsideArea : n;
}

/// A place's title: Home, Work, or the rider's name for it.
String placeTitle(AppLocalizations l, FavoriteLocation p) => switch (p.label) {
  'home' => l.navHome,
  'work' => l.savedWork,
  _ => p.name.isNotEmpty ? p.name : splitPlace(p.addressText).name,
};

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({
    super.key,
    this.service,
    this.search,
    this.onChanged,
    this.near,
  });

  final FavoriteLocationService? service;
  final PlaceSearch? search;

  /// Called with the fresh list after every load, so Home's chips follow.
  final ValueChanged<List<FavoriteLocation>>? onChanged;

  /// Where the place sheet's map starts when nothing is chosen.
  final LatLng? near;

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  late final FavoriteLocationService _service =
      widget.service ?? FavoriteLocationService();
  SavedPlaces? _data;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    SavedPlaces? data;
    try {
      data = await _service.fetchPlaces().timeout(kLoadTimeout);
    } catch (e) {
      debugPrint('Saved places failed: $e');
      data = null;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = data == null;
      if (data != null) _data = data;
    });
    if (data != null) widget.onChanged?.call(data.places);
  }

  Future<void> _open({
    FavoriteLocation? existing,
    String label = 'other',
  }) async {
    final saved = await showPlaceSheet(
      context,
      service: _service,
      existing: existing,
      label: label,
      near: widget.near,
      limits: _data?.limits ?? const {},
      search: widget.search,
    );
    if (saved != null && mounted) await _load();
  }

  Future<void> _delete(FavoriteLocation p) async {
    final l = sgStrings(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: SgColors.bg100,
        title: Text(l.placeDeleteTitle, style: SgText.title),
        content: Text(l.placeDeleteBody(placeTitle(l, p)), style: SgText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel, style: SgText.body),
          ),
          TextButton(
            key: const Key('place_delete_confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              l.placeDelete,
              style: SgText.body.copyWith(
                color: SgColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await _service.deletePlace(p.id).timeout(kLoadTimeout);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.placeDeleteFailed)));
      return;
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = sgStrings(context);
    final data = _data;
    final Widget body;
    if (_loading && data == null) {
      body = Center(
        key: const Key('places_loading'),
        child: CircularProgressIndicator(color: SgColors.gold500),
      );
    } else if (_failed && data == null) {
      body = Center(
        key: const Key('places_error'),
        child: Padding(
          padding: const EdgeInsets.all(SgSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.loadErrPlaces,
                style: SgText.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SgSpace.s3),
              TextButton(
                key: const Key('places_retry'),
                onPressed: _load,
                child: Text(
                  l.tryAgain,
                  style: SgText.body.copyWith(
                    color: SgColors.goldText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final d = data!;
      final home = d.byLabel('home'), work = d.byLabel('work');
      final others = d.others;
      final otherMax = d.limits['other'];
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, SgSpace.s6),
        children: [
          if (d.places.isEmpty)
            Padding(
              key: const Key('places_empty'),
              padding: const EdgeInsets.only(bottom: SgSpace.s3),
              child: Text(l.accountNoSavedPlaces, style: SgText.caption),
            ),
          home == null
              ? _SetRow(
                  key: const Key('places_set_home'),
                  icon: SgIcons.home,
                  label: l.placeSetHome,
                  onTap: () => _open(label: 'home'),
                )
              : _PlaceRow(
                  key: const Key('places_home'),
                  place: home,
                  icon: SgIcons.home,
                  onEdit: () => _open(existing: home),
                  onDelete: () => _delete(home),
                ),
          work == null
              ? _SetRow(
                  key: const Key('places_set_work'),
                  icon: SgIcons.work,
                  label: l.placeSetWork,
                  onTap: () => _open(label: 'work'),
                )
              : _PlaceRow(
                  key: const Key('places_work'),
                  place: work,
                  icon: SgIcons.work,
                  onEdit: () => _open(existing: work),
                  onDelete: () => _delete(work),
                ),
          for (final p in others)
            _PlaceRow(
              key: Key('places_other_${p.id}'),
              place: p,
              icon: SgIcons.pin,
              onEdit: () => _open(existing: p),
              onDelete: () => _delete(p),
            ),
          const SizedBox(height: SgSpace.s5),
          if (otherMax == null || others.length < otherMax)
            SgPrimaryButton(
              key: const Key('places_add'),
              label: l.placeAdd,
              onPressed: () => _open(),
            )
          else
            Text(l.placeLimitOther(otherMax), style: SgText.caption),
        ],
      );
    }
    return Scaffold(
      backgroundColor: SgColors.bg000,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                SgSpace.s4,
                20,
                SgSpace.s3,
              ),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Back',
                      child: InkWell(
                        key: const Key('places_back'),
                        onTap: () => Navigator.of(context).maybePop(),
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 32,
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SgIcon(
                              SgIcons.back,
                              size: 20,
                              color: SgColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(l.accountSavedPlaces, style: SgText.title),
                  ],
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

Widget _tile(String icon) => Container(
  width: 40,
  height: 40,
  decoration: BoxDecoration(
    color: SgColors.bg200,
    borderRadius: BorderRadius.circular(SgSpace.s3),
  ),
  child: Center(child: SgIcon(icon, size: 20, color: SgColors.ink)),
);

/// A saved place: icon tile, title, address, the server's notice when there
/// is one; tap to edit, the bin to delete.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    super.key,
    required this.place,
    required this.icon,
    required this.onEdit,
    required this.onDelete,
  });
  final FavoriteLocation place;
  final String icon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = sgStrings(context);
    final notice = placeNotice(l, place);
    return InkWell(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: SgSpace.s3),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: SgColors.divider)),
        ),
        child: Row(
          children: [
            _tile(icon),
            const SizedBox(width: SgSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    placeTitle(l, place),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SgText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (place.addressText.isNotEmpty)
                    Text(
                      place.addressText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SgText.caption,
                    ),
                  if (notice.isNotEmpty)
                    Text(
                      notice,
                      key: Key('place_notice_${place.id}'),
                      style: SgText.caption.copyWith(color: SgColors.danger),
                    ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: l.placeDelete,
              child: InkWell(
                key: Key('place_delete_${place.id}'),
                customBorder: const CircleBorder(),
                onTap: onDelete,
                child: SizedBox(
                  width: kSgTouch,
                  height: kSgTouch,
                  child: Center(
                    child: SgIcon(
                      SgIcons.close,
                      size: 18,
                      color: SgColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Set home" / "Set work" when that label is not saved yet.
class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: SgSpace.s3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: SgColors.divider)),
      ),
      child: Row(
        children: [
          _tile(icon),
          const SizedBox(width: SgSpace.s3),
          Expanded(
            child: Text(
              label,
              style: SgText.body.copyWith(
                color: SgColors.goldText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

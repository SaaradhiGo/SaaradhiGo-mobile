/// Add or edit a saved place (POST/PATCH /rider/places/): an address search,
/// a pin on a small map to adjust the spot, Home / Work / Other with a name,
/// and Save.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../core/maps/sg_map.dart';
import '../../l10n/app_localizations.dart';
import '../../services/favorite_location_service.dart';
import '../../services/location_service.dart';
import '../../services/models/location_model.dart';
import '../../services/session_events.dart' show kLoadTimeout;
import '../../ui/appearance_settings.dart' show sgStrings;
import '../../ui/home_sheet.dart' show SgSearchBar;
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../../ui/sg_widgets.dart';

/// The address search the sheet uses; the app's /ride/maps/* proxy by
/// default, a fake in tests.
abstract class PlaceSearch {
  Future<List<PlaceSuggestion>> suggest(String query, {LatLng? near});
  Future<PlaceDetails?> details(String placeId);
  Future<String?> addressAt(LatLng at);
}

class LocationPlaceSearch implements PlaceSearch {
  LocationPlaceSearch([LocationService? service])
    : _service = service ?? LocationService();
  final LocationService _service;
  String _session = const Uuid().v4();

  @override
  Future<List<PlaceSuggestion>> suggest(String query, {LatLng? near}) =>
      _service.getPlaceAutocomplete(query, _session, near: near);

  @override
  Future<PlaceDetails?> details(String placeId) async {
    final d = await _service.getPlaceDetails(placeId, _session);
    _session = const Uuid().v4(); // a pick ends the billing session
    return d;
  }

  @override
  Future<String?> addressAt(LatLng at) =>
      _service.getAddressFromCoordinates(at.latitude, at.longitude);
}

/// Opens the sheet. Returns the saved place, or null when closed unsaved.
Future<FavoriteLocation?> showPlaceSheet(
  BuildContext context, {
  required FavoriteLocationService service,
  FavoriteLocation? existing,
  String label = 'other',
  String? address,
  LatLng? at,
  String? name,
  LatLng? near,
  Map<String, int> limits = const {},
  PlaceSearch? search,
}) {
  return showModalBottomSheet<FavoriteLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: PlaceSheet(
        service: service,
        existing: existing,
        label: label,
        address: address,
        at: at,
        name: name,
        near: near,
        limits: limits,
        search: search ?? LocationPlaceSearch(),
      ),
    ),
  );
}

class PlaceSheet extends StatefulWidget {
  const PlaceSheet({
    super.key,
    required this.service,
    required this.search,
    this.existing,
    this.label = 'other',
    this.address,
    this.at,
    this.name,
    this.near,
    this.limits = const {},
  });

  final FavoriteLocationService service;
  final PlaceSearch search;
  final FavoriteLocation? existing;
  final String label;
  final String? address;
  final LatLng? at;
  final String? name;

  /// Where to centre the map and bias the search when nothing is chosen yet.
  final LatLng? near;
  final Map<String, int> limits;

  @override
  State<PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<PlaceSheet> {
  static const _maxName = 40;

  late final TextEditingController _query;
  late final TextEditingController _name;
  late String _label;
  String _address = '';
  LatLng? _at;
  SgMapController? _map;
  Timer? _debounce;
  int _searchSeq = 0;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searched = false;
  bool _dragged = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = e?.label ?? widget.label;
    _address = e?.addressText ?? widget.address ?? '';
    final lat = e?.latitude, lng = e?.longitude;
    _at = (lat != null && lng != null && (lat != 0 || lng != 0))
        ? LatLng(lat, lng)
        : widget.at;
    _query = TextEditingController(text: _address);
    var n = e?.name ?? widget.name ?? '';
    if (n.length > _maxName) n = n.substring(0, _maxName);
    _name = TextEditingController(text: n);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _name.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final seq = ++_searchSeq;
      final text = q.trim();
      if (text.length < 3) {
        if (!mounted) return;
        setState(() {
          _suggestions = const [];
          _searched = false;
        });
        return;
      }
      List<PlaceSuggestion> found;
      try {
        found = await widget.search
            .suggest(text, near: _at ?? widget.near)
            .timeout(kLoadTimeout);
      } catch (_) {
        found = const [];
      }
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = found.take(5).toList();
        _searched = true;
      });
    });
  }

  Future<void> _pick(PlaceSuggestion s) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _searched = false;
    });
    PlaceDetails? d;
    try {
      d = await widget.search.details(s.placeId).timeout(kLoadTimeout);
    } catch (_) {
      d = null;
    }
    if (!mounted || d == null || (d.latitude == 0 && d.longitude == 0)) return;
    final at = LatLng(d.latitude, d.longitude);
    final address = d.formattedAddress.trim().isNotEmpty
        ? d.formattedAddress.trim()
        : s.description;
    setState(() {
      _at = at;
      _address = address;
      _query.text = address;
      _dragged = false;
      _error = null;
    });
    _map?.moveTo(at);
  }

  Future<void> _onIdle() async {
    if (!_dragged) return;
    _dragged = false;
    final at = _at;
    if (at == null) return;
    String? address;
    try {
      address = await widget.search.addressAt(at).timeout(kLoadTimeout);
    } catch (_) {
      address = null;
    }
    if (!mounted || at != _at || (address ?? '').trim().isEmpty) return;
    setState(() {
      _address = address!.trim();
      _query.text = _address;
    });
  }

  bool get _canSave =>
      !_saving &&
      _at != null &&
      _address.trim().isNotEmpty &&
      (_label != 'other' || _name.text.trim().isNotEmpty);

  String _messageFor(AppLocalizations l, PlaceError e) {
    if (e.code == 'PLACE_LIMIT') {
      return switch (_label) {
        'home' => l.placeLimitHome,
        'work' => l.placeLimitWork,
        _ => l.placeLimitOther(widget.limits['other'] ?? 10),
      };
    }
    if (e.code == 'VALIDATION_ERROR' && e.field == 'name') {
      return l.placeNameRequired;
    }
    return l.placeSaveFailed;
  }

  Future<void> _save() async {
    final l = sgStrings(context);
    final at = _at;
    if (at == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = _label == 'other' ? _name.text.trim() : null;
    try {
      final e = widget.existing;
      final saved =
          await (e == null
                  ? widget.service.createPlace(
                      label: _label,
                      name: name ?? '',
                      addressText: _address.trim(),
                      latitude: at.latitude,
                      longitude: at.longitude,
                    )
                  : widget.service.updatePlace(
                      e.id,
                      label: _label,
                      name: name,
                      addressText: _address.trim(),
                      latitude: at.latitude,
                      longitude: at.longitude,
                    ))
              .timeout(kLoadTimeout);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on PlaceError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _messageFor(l, e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l.placeSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = sgStrings(context);
    final center = _at ?? widget.near ?? const LatLng(17.385044, 78.4867);
    return SgSheetSurface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? l.placeAdd : l.placeEdit,
              style: SgText.title,
            ),
            const SizedBox(height: SgSpace.s4),
            SgSearchBar(
              field: TextField(
                key: const Key('place_search'),
                controller: _query,
                style: SgText.body,
                maxLines: 1,
                onChanged: _onQuery,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: l.placeSearchHint,
                  hintStyle: SgText.body.copyWith(color: SgColors.inkMuted),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_suggestions.isNotEmpty)
              for (final s in _suggestions)
                InkWell(
                  key: Key('place_suggestion_${s.placeId}'),
                  onTap: () => _pick(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: SgSpace.s3),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: SgColors.divider),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.mainText.isNotEmpty ? s.mainText : s.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SgText.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (s.secondaryText.isNotEmpty)
                          Text(
                            s.secondaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SgText.caption,
                          ),
                      ],
                    ),
                  ),
                )
            else if (_searched)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SgSpace.s3),
                child: Text(l.placeNoResults, style: SgText.caption),
              ),
            const SizedBox(height: SgSpace.s3),
            ClipRRect(
              borderRadius: BorderRadius.circular(SgSpace.s3),
              child: SizedBox(
                height: 160,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SgMap(
                        initialCenter: center,
                        initialZoom: 16,
                        onMapCreated: (c) => _map = c,
                        onCameraMove: (camera) {
                          if (!camera.byGesture) return;
                          _dragged = true;
                          _at = camera.center;
                        },
                        onCameraIdle: _onIdle,
                      ),
                    ),
                    // The pin stays put; the map slides under it.
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: const Offset(0, -14),
                          child: SgIcon(
                            SgIcons.pin,
                            size: 28,
                            color: SgColors.goldText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SgSpace.s2),
            Text(l.placeDragHint, style: SgText.caption),
            const SizedBox(height: SgSpace.s4),
            Text(
              l.placeLabel,
              style: SgText.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: SgSpace.s2),
            Wrap(
              spacing: SgSpace.s2,
              runSpacing: SgSpace.s2,
              children: [
                _LabelChip(
                  key: const Key('place_label_home'),
                  icon: SgIcons.home,
                  text: l.navHome,
                  selected: _label == 'home',
                  onTap: () => setState(() => _label = 'home'),
                ),
                _LabelChip(
                  key: const Key('place_label_work'),
                  icon: SgIcons.work,
                  text: l.savedWork,
                  selected: _label == 'work',
                  onTap: () => setState(() => _label = 'work'),
                ),
                _LabelChip(
                  key: const Key('place_label_other'),
                  icon: SgIcons.pin,
                  text: l.placeOther,
                  selected: _label == 'other',
                  onTap: () => setState(() => _label = 'other'),
                ),
              ],
            ),
            if (_label == 'other') ...[
              const SizedBox(height: SgSpace.s3),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: SgSpace.s4),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: SgColors.bg200,
                  borderRadius: BorderRadius.circular(SgSpace.s3),
                ),
                child: TextField(
                  key: const Key('place_name'),
                  controller: _name,
                  style: SgText.body,
                  maxLines: 1,
                  maxLength: _maxName,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    counterText: '',
                    hintText: l.placeNameHint,
                    hintStyle: SgText.body.copyWith(color: SgColors.inkMuted),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: SgSpace.s3),
              Text(
                _error!,
                key: const Key('place_error'),
                style: SgText.caption.copyWith(color: SgColors.danger),
              ),
            ],
            const SizedBox(height: SgSpace.s4),
            SgPrimaryButton(
              key: const Key('place_save'),
              label: l.placeSave,
              onPressed: _canSave ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Home / Work / Other: a 36px pill, gold-soft when chosen.
class _LabelChip extends StatelessWidget {
  const _LabelChip({
    super.key,
    required this.icon,
    required this.text,
    required this.selected,
    required this.onTap,
  });
  final String icon;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? SgColors.goldSoft : SgColors.bg100,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? SgColors.goldLine : SgColors.line),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SgIcon(icon, size: 18, color: SgColors.goldText),
              const SizedBox(width: SgSpace.s2),
              Text(
                text,
                style: SgText.caption.copyWith(
                  color: SgColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

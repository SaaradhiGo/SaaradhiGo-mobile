import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('display_name')) {
      // OSM Fallback (if still used somehow)
      final displayName = json['display_name'] as String? ?? '';
      final parts = displayName.split(',');
      final mainText = parts.isNotEmpty ? parts[0].trim() : '';
      final secondaryText = parts.length > 1
          ? parts.skip(1).join(',').trim()
          : '';

      final lat = json['lat'];
      final lon = json['lon'];
      final pId = (lat != null && lon != null)
          ? '$lat,$lon'
          : json['place_id'].toString();

      return PlaceSuggestion(
        placeId: pId,
        description: displayName,
        mainText: mainText,
        secondaryText: secondaryText,
      );
    } else {
      // Google Places Autocomplete format
      final structuredFormatting = json['structured_formatting'] ?? {};
      final description = (json['description'] ?? '').toString();
      var mainText = (structuredFormatting['main_text'] ?? '').toString();
      var secondaryText = (structuredFormatting['secondary_text'] ?? '')
          .toString();
      if (mainText.trim().isEmpty) {
        // Places (New) sends only `description`, and a cached answer from
        // before the backend added the parts still does. Every row rendered
        // blank (PRODUCT_AUDIT §2, "Where to"): split the description instead.
        final comma = description.indexOf(',');
        mainText = comma < 0 ? description : description.substring(0, comma);
        if (secondaryText.trim().isEmpty && comma >= 0) {
          secondaryText = description.substring(comma + 1).trim();
        }
      }
      return PlaceSuggestion(
        placeId: json['place_id'],
        description: description,
        mainText: mainText.trim(),
        secondaryText: secondaryText.trim(),
      );
    }
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final result = json['result'] ?? json;
    final geometry = result['geometry'];
    final location = geometry != null
        ? geometry['location']
        : (json['geometry'] != null ? json['geometry']['location'] : null);

    return PlaceDetails(
      placeId: result['place_id'] ?? '',
      name: result['name'] ?? '',
      formattedAddress: result['formatted_address'] ?? '',
      latitude: location != null ? location['lat'] : 0.0,
      longitude: location != null ? location['lng'] : 0.0,
    );
  }
}

class FavoriteLocation {
  final int id;
  final String addressText;
  final double latitude;
  final double longitude;

  /// `home`, `work` or `other` when the server labels the place (Night 2
  /// field); null when it does not.
  final String? label;

  /// The rider's name for an `other` place (GET /rider/places/); empty for
  /// Home, Work and places from the older /rider/locations/ list.
  final String name;

  /// False when the place is outside the service area; [notice] then carries
  /// the server's line to show under it.
  final bool inServiceArea;
  final String? notice;

  FavoriteLocation({
    required this.id,
    required this.addressText,
    required this.latitude,
    required this.longitude,
    this.label,
    this.name = '',
    this.inServiceArea = true,
    this.notice,
  });

  static String? _label(Object? raw) {
    final v = raw?.toString().trim().toLowerCase();
    return const {'home', 'work', 'other'}.contains(v) ? v : null;
  }

  factory FavoriteLocation.fromJson(Map<String, dynamic> json) {
    return FavoriteLocation(
      id: json['id'] as int,
      addressText: json['address_text'] as String? ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '0.0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0.0') ?? 0.0,
      label: _label(json['label']),
      name: (json['name'] as String?)?.trim() ?? '',
      inServiceArea: json['in_service_area'] != false,
      notice: (json['notice'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['notice'] as String).trim(),
    );
  }
}

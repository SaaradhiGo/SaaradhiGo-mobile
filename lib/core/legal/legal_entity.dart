/// The company that operates SaaradhiGo in a market, from
/// `GET /api/v1/config/` -> `data.legal.<IN|US>`.
///
/// Every field but the name is optional and absent when it is not configured;
/// nothing here is ever invented. When the call fails or the server predates
/// the field, only the name for the market is shown ([LegalEntity.fallback]).
library;

class LegalEntity {
  const LegalEntity({
    required this.legalName,
    this.registeredAddress = '',
    this.cin = '',
    this.supportEmail = '',
    this.supportPhone = '',
    this.gstin = '',
    this.gstRegistered = false,
  });

  final String legalName;
  final String registeredAddress;
  final String cin;
  final String supportEmail;
  final String supportPhone;
  final String gstin;
  final bool gstRegistered;

  /// The operator's name per market, shown before (or without) the config.
  static const Map<String, String> _names = {
    'IN': 'DeepTrics Software Solutions Pvt Ltd',
    'US': 'DeepTrics LLC',
  };

  static LegalEntity fallback(String countryCode) => LegalEntity(
    legalName: _names[countryCode.toUpperCase()] ?? _names['IN']!,
  );

  /// Null when [json] is not a map with a usable name.
  static LegalEntity? fromJson(Object? json) {
    if (json is! Map) return null;
    String s(String k) => (json[k] ?? '').toString().trim();
    final name = s('legal_name');
    if (name.isEmpty) return null;
    return LegalEntity(
      legalName: name,
      registeredAddress: s('registered_address'),
      cin: s('cin'),
      supportEmail: s('support_email'),
      supportPhone: s('support_phone'),
      gstin: s('gstin'),
      gstRegistered: json['gst_registered'] == true,
    );
  }

  /// "© 2026 SaaradhiGo. Operated by DeepTrics LLC."
  String copyright(int year) => '© $year SaaradhiGo. Operated by $legalName.';
}

/// `data.legal` -> entities by market code. Unreadable input gives none.
Map<String, LegalEntity> parseLegal(Object? legal) {
  final out = <String, LegalEntity>{};
  if (legal is! Map) return out;
  for (final e in legal.entries) {
    final entity = LegalEntity.fromJson(e.value);
    if (entity != null) out[e.key.toString().toUpperCase()] = entity;
  }
  return out;
}

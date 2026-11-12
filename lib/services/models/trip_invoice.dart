/// The `invoice` block of the trip detail (`GET /ride/trip/<id>/`), read
/// defensively: the title, issuer and tax fields arrive with the legal-entity
/// change and are absent on older servers.
library;

class InvoiceLine {
  const InvoiceLine(this.label, this.amount);
  final String label;
  final String amount;
}

class TripInvoice {
  const TripInvoice({
    required this.title,
    required this.companyName,
    this.companyAddress = '',
    this.gstin = '',
    this.cin = '',
    this.supportEmail = '',
    this.supportPhone = '',
    this.number = '',
    this.taxShown = false,
    this.lines = const [],
    this.taxable,
    this.taxLabel = '',
    this.taxAmount,
    this.taxIncluded = true,
    this.extras = const [],
    this.total,
    this.currency,
  });

  /// "Receipt" while GST is off, "Tax invoice" when on.
  final String title;
  final String companyName;
  final String companyAddress;
  final String gstin;
  final String cin;
  final String supportEmail;
  final String supportPhone;
  final String number;

  /// False: show no taxable-value or GST lines.
  final bool taxShown;
  final List<InvoiceLine> lines;
  final String? taxable;
  final String taxLabel;
  final String? taxAmount;
  final bool taxIncluded;
  final List<InvoiceLine> extras;
  final String? total;
  final String? currency;

  /// Null when the trip has no usable invoice.
  static TripInvoice? fromTrip(Object? trip) {
    final inv = trip is Map ? trip['invoice'] : null;
    if (inv is! Map) return null;
    String s(Object? m, String k) =>
        (m is Map ? (m[k] ?? '') : '').toString().trim();
    final company = inv['company'];
    final breakdown = inv['breakdown'];
    List<InvoiceLine> list(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is Map && s(e, 'label').isNotEmpty)
            InvoiceLine(s(e, 'label'), s(e, 'amount')),
    ];
    final tax = breakdown is Map ? breakdown['tax'] : null;
    final title = s(inv, 'title').isNotEmpty
        ? s(inv, 'title')
        : s(breakdown, 'title');
    return TripInvoice(
      // Older servers send no title: a receipt, never a claim of GST.
      title: title.isEmpty ? 'Receipt' : title,
      companyName: s(company, 'name'),
      companyAddress: s(company, 'address'),
      gstin: s(company, 'gstin'),
      cin: s(company, 'cin'),
      supportEmail: s(company, 'support_email'),
      supportPhone: s(company, 'support_phone'),
      number: s(inv, 'number'),
      // Absent means not shown: never print tax the server did not vouch for.
      taxShown: breakdown is Map && breakdown['tax_shown'] == true,
      lines: list(breakdown is Map ? breakdown['lines'] : null),
      taxable: breakdown is Map ? breakdown['taxable']?.toString() : null,
      taxLabel: tax is Map
          ? '${s(tax, 'label')} ${s(tax, 'percent')}%'.trim()
          : '',
      taxAmount: tax is Map ? tax['amount']?.toString() : null,
      taxIncluded: tax is Map ? tax['included'] != false : true,
      extras: list(breakdown is Map ? breakdown['extras'] : null),
      total:
          (breakdown is Map ? breakdown['total'] : null)?.toString() ??
          inv['total']?.toString(),
      currency: inv['currency']?.toString(),
    );
  }
}

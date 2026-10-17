/// One support ticket, as `SupportTicketSerializer` sends it.
///
/// Parsed defensively on purpose: a ticket list that throws on one unexpected
/// row would leave a rider looking at an empty screen while their open
/// complaint sat on the server.
library;

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.issueType,
    required this.status,
    this.description,
    this.createdAt,
    this.tripId,
  });

  final int id;
  final String issueType;

  /// `OPEN`, `IN_PROGRESS`, `RESOLVED`, `CLOSED` -- the server's own
  /// STATUS_CHOICES. Kept as the wire value and mapped for display, so an
  /// added status shows as itself rather than as nothing.
  final String status;

  final String? description;
  final DateTime? createdAt;
  final int? tripId;

  bool get isOpen =>
      status.toUpperCase() != 'CLOSED' && status.toUpperCase() != 'RESOLVED';

  /// A label a rider can read, for the statuses we know about.
  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return 'Open';
      case 'IN_PROGRESS':
        return 'Being looked at';
      case 'RESOLVED':
        return 'Resolved';
      case 'CLOSED':
        return 'Closed';
      default:
        return status;
    }
  }

  static SupportTicket fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    if (id == null) {
      throw FormatException('support ticket has no usable id: $json');
    }
    return SupportTicket(
      id: id,
      issueType: (json['issue_type'] ?? 'other').toString(),
      status: (json['status'] ?? 'OPEN').toString(),
      description: json['description']?.toString(),
      createdAt: _asDate(json['created_at']),
      tripId: _asInt(json['trip_id']),
    );
  }

  static int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    // The serializer may nest the trip rather than flattening its id.
    if (raw is Map && raw['id'] != null) return _asInt(raw['id']);
    return null;
  }

  static DateTime? _asDate(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

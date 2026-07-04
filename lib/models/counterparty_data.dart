/// TS18/US60 — nested counterparty object embedded by the backend in
/// ReservationResource ("renter"/"owner") and ConversationResource ("owner"/"renter"),
/// alongside the existing bare *Id fields (additive, non-breaking).
class CounterpartyData {
  final int id;
  final String fullName;
  final bool kycVerified;

  const CounterpartyData({
    required this.id,
    required this.fullName,
    required this.kycVerified,
  });

  factory CounterpartyData.fromJson(Map<String, dynamic> json) {
    return CounterpartyData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name']?.toString() ?? json['fullName']?.toString() ?? 'Usuario sin nombre registrado',
      kycVerified: json['kyc_verified'] as bool? ?? json['kycVerified'] as bool? ?? false,
    );
  }

  /// Parses the nested object if present; returns null if the backend hasn't sent it yet
  /// (e.g. an older cached response) — callers must fall back to a raw-ID display in that
  /// case, never crash.
  static CounterpartyData? tryParse(dynamic json) {
    if (json is Map<String, dynamic>) {
      return CounterpartyData.fromJson(json);
    }
    return null;
  }
}

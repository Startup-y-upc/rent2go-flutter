
class CounterpartyData {
  final int id;
  final String fullName;
  final bool kycVerified;
  final bool dniVerified;
  final bool licenseVerified;
  final String? profileImageUrl;

  const CounterpartyData({
    required this.id,
    required this.fullName,
    required this.kycVerified,
    this.dniVerified = false,
    this.licenseVerified = false,
    this.profileImageUrl,
  });

  factory CounterpartyData.fromJson(Map<String, dynamic> json) {
    return CounterpartyData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name']?.toString() ?? json['fullName']?.toString() ?? 'Usuario sin nombre registrado',
      kycVerified: json['kyc_verified'] as bool? ?? json['kycVerified'] as bool? ?? false,
      dniVerified: json['dni_verified'] as bool? ?? json['dniVerified'] as bool? ?? false,
      licenseVerified: json['license_verified'] as bool? ?? json['licenseVerified'] as bool? ?? false,
      profileImageUrl: json['profile_image_url']?.toString() ?? json['profileImageUrl']?.toString(),
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

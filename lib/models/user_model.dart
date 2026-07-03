class UserModel {
  final String token;
  final int userId;
  final String email;
  final String username;
  final String fullName;
  final String phone;
  final String accountType;
  final String status;
  final bool emailVerified;
  final bool phoneVerified;
  final bool twoFactorEnabled;
  final bool kycVerified;
  final String? profileImageUrl;

  UserModel({
    required this.token,
    required this.userId,
    required this.email,
    required this.username,
    required this.fullName,
    required this.phone,
    required this.accountType,
    required this.status,
    required this.emailVerified,
    required this.phoneVerified,
    required this.twoFactorEnabled,
    this.kycVerified = false,
    this.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      token: json['token'] ?? '',
      userId: json['userId'] ?? json['id'] ?? 0,
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      accountType: json['accountType'] ?? json['account_type'] ?? '',
      status: json['status'] ?? '',
      emailVerified: json['emailVerified'] ?? json['email_verified'] ?? false,
      phoneVerified: json['phoneVerified'] ?? json['phone_verified'] ?? false,
      twoFactorEnabled: json['twoFactorEnabled'] ?? json['two_factor_enabled'] ?? false,
      // Campo real del backend: siempre serializado como 'kyc_verified' (snake_case,
      // forzado con @JsonProperty en UserResource.java, confirmado por lectura directa).
      kycVerified: json['kyc_verified'] ?? json['kycVerified'] ?? false,
      profileImageUrl: json['profileImageUrl'] ?? json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'userId': userId,
      'email': email,
      'username': username,
      'fullName': fullName,
      'phone': phone,
      'accountType': accountType,
      'status': status,
      'emailVerified': emailVerified,
      'phoneVerified': phoneVerified,
      'twoFactorEnabled': twoFactorEnabled,
      'kyc_verified': kycVerified,
      'profileImageUrl': profileImageUrl,
    };
  }
}
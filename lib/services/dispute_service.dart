import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Categorías reales de reseña — deben coincidir exactamente con
/// ReviewCategory.java (backend): VEHICLE, RENTAL_EXPERIENCE, DRIVER, COMMUNICATION.
enum ReviewCategoryOption {
  vehicle('VEHICLE', 'Vehículo'),
  rentalExperience('RENTAL_EXPERIENCE', 'Experiencia de alquiler'),
  driver('DRIVER', 'Conductor'),
  communication('COMMUNICATION', 'Comunicación');

  final String code;
  final String label;
  const ReviewCategoryOption(this.code, this.label);
}

/// TrustReportResource exacto devuelto por el backend (US41/US42).
class DisputeData {
  final int id;
  final String? subjectType;
  final int? subjectId;
  final int? reservationId;
  final int? reviewId;
  final int? reportedUserId;
  final int reporterId;
  final String reason;
  final String? status;
  final String? moderationNote;
  final String? createdAt;
  final String? updatedAt;

  DisputeData({
    required this.id,
    this.subjectType,
    this.subjectId,
    this.reservationId,
    this.reviewId,
    this.reportedUserId,
    required this.reporterId,
    required this.reason,
    this.status,
    this.moderationNote,
    this.createdAt,
    this.updatedAt,
  });

  factory DisputeData.fromJson(Map<String, dynamic> json) {
    return DisputeData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      subjectType: json['subjectType']?.toString(),
      subjectId: (json['subjectId'] as num?)?.toInt(),
      reservationId: (json['reservationId'] as num?)?.toInt(),
      reviewId: (json['reviewId'] as num?)?.toInt(),
      reportedUserId: (json['reportedUserId'] as num?)?.toInt(),
      reporterId: (json['reporterId'] as num?)?.toInt() ?? 0,
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString(),
      moderationNote: json['moderationNote']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}

class DisputeException implements Exception {
  final String message;
  DisputeException(this.message);
  @override
  String toString() => message;
}

class DisputeService {
  static const String baseUrl = 'https://rent2go-backend-production.up.railway.app/api/v1';

  static Map<String, String> _authHeaders(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// POST /api/v1/community-trust/reservations/{reservationId}/disputes
  /// (OpenReservationDisputeResource exacto: reporterId + reason).
  /// La "categoría" del formulario se antepone al texto libre del motivo
  /// porque el backend no tiene un campo de categoría dedicado para disputas.
  static Future<DisputeData> reportIssue({
    required int reservationId,
    required int reporterId,
    required String category,
    required String description,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/community-trust/reservations/$reservationId/disputes');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'reporterId': reporterId,
        'reason': '[$category] $description',
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return DisputeData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw DisputeException('No se pudo enviar el reporte. Intenta nuevamente.');
  }

  /// GET /api/v1/community-trust/users/{userId}/disputes — US42, autoservicio.
  static Future<List<DisputeData>> getMyDisputes(int userId) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/community-trust/users/$userId/disputes');
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => DisputeData.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw DisputeException('No se pudieron cargar tus reportes.');
  }

  /// POST /api/v1/community-trust/reviews (SubmitReviewResource exacto).
  static Future<void> submitReview({
    required int reservationId,
    required int vehicleId,
    required int reviewerId,
    int? reviewedUserId,
    required ReviewCategoryOption category,
    required int rating,
    String? comment,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/community-trust/reviews');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'reservationId': reservationId,
        'vehicleId': vehicleId,
        'reviewerId': reviewerId,
        if (reviewedUserId != null) 'reviewedUserId': reviewedUserId,
        'category': category.code,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw DisputeException('No se pudo enviar tu calificación. Intenta nuevamente.');
    }
  }
}

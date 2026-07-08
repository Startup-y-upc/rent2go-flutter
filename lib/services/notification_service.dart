import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// NotificationResource exacto del backend (TS11/US50/US51/US52):
/// GET /api/v1/notifications/users/{userId}, PATCH /api/v1/notifications/{id}/read.
class NotificationData {
  final int id;
  final int userId;
  final String? type;
  final String message;
  final String? readAt;
  final String? createdAt;

  NotificationData({
    required this.id,
    required this.userId,
    this.type,
    required this.message,
    this.readAt,
    this.createdAt,
  });

  bool get isRead => readAt != null && readAt!.isNotEmpty;

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString(),
      message: json['message']?.toString() ?? '',
      readAt: json['readAt']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class PagedNotifications {
  final List<NotificationData> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  PagedNotifications({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory PagedNotifications.fromJson(Map<String, dynamic> json) {
    return PagedNotifications(
      content: (json['content'] as List? ?? [])
          .map((e) => NotificationData.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  factory PagedNotifications.empty() =>
      PagedNotifications(content: [], page: 1, size: 20, totalElements: 0, totalPages: 0);
}

class NotificationException implements Exception {
  final String message;
  NotificationException(this.message);
  @override
  String toString() => message;
}

/// Service responsible for managing user in-app notifications.
/// Integrates with the backend notifications API to fetch paginated alerts
/// and mark them as read.
class NotificationService {
  static const String baseUrl = 'https://rent2go-backend-production.up.railway.app/api/v1';

  static Map<String, String> _authHeaders(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// GET /api/v1/notifications/users/{userId} — paginado, orden cronológico
  /// descendente (más reciente primero) según el backend.
  static Future<PagedNotifications> getMyNotifications({
    required int userId,
    int page = 1,
    int size = 20,
  }) async {
    final token = await AuthService.getToken();
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    final uri = Uri.parse('$baseUrl/notifications/users/$userId').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      return PagedNotifications.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    if (response.statusCode == 403) {
      throw NotificationException('No tienes permiso para ver estas notificaciones.');
    }
    throw NotificationException('No se pudieron cargar tus notificaciones.');
  }

  /// PATCH /api/v1/notifications/{id}/read?userId=... — marca como leída.
  static Future<NotificationData> markAsRead({
    required int notificationId,
    required int userId,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/notifications/$notificationId/read').replace(queryParameters: {'userId': userId.toString()});
    final response = await http.patch(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      return NotificationData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    if (response.statusCode == 403) {
      throw NotificationException('No tienes permiso para modificar esta notificación.');
    }
    throw NotificationException('No se pudo marcar la notificación como leída.');
  }
}

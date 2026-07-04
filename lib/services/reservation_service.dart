import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/counterparty_data.dart';

/// ReservationResource exacto devuelto por el backend
/// (ReservationController.java — campos verificados directamente).
class ReservationData {
  final int id;
  final String reservationCode;
  final int vehicleId;
  final int renterId;
  final int ownerId;
  final String startDate;
  final String endDate;
  final double totalAmount;
  final String status;
  final String? pickupConfirmedAt;
  final String? returnConfirmedAt;
  final String pickupLocation;
  final String returnLocation;
  final String coveragePlan;
  final List<String> pickupPhotos;
  final List<String> returnPhotos;
  final String? damageReport;
  // TS18/US60 — nested counterparty objects (real name + KYC status), additive
  // alongside renterId/ownerId. Null when the backend hasn't sent them yet.
  final CounterpartyData? renter;
  final CounterpartyData? owner;

  ReservationData({
    required this.id,
    required this.reservationCode,
    required this.vehicleId,
    required this.renterId,
    required this.ownerId,
    required this.startDate,
    required this.endDate,
    required this.totalAmount,
    required this.status,
    this.pickupConfirmedAt,
    this.returnConfirmedAt,
    required this.pickupLocation,
    required this.returnLocation,
    required this.coveragePlan,
    required this.pickupPhotos,
    required this.returnPhotos,
    this.damageReport,
    this.renter,
    this.owner,
  });

  /// Nombre a mostrar del arrendatario: nombre real si el backend lo envió,
  /// fallback explícito con el ID (nunca solo el ID sin contexto) — US60 AC3.
  String get renterDisplayName => renter?.fullName ?? 'Cliente #$renterId';
  String get ownerDisplayName => owner?.fullName ?? 'Propietario #$ownerId';

  factory ReservationData.fromJson(Map<String, dynamic> json) {
    return ReservationData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reservationCode: json['reservationCode']?.toString() ?? '',
      vehicleId: (json['vehicleId'] as num?)?.toInt() ?? 0,
      renterId: (json['renterId'] as num?)?.toInt() ?? 0,
      ownerId: (json['ownerId'] as num?)?.toInt() ?? 0,
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? '',
      pickupConfirmedAt: json['pickupConfirmedAt']?.toString(),
      returnConfirmedAt: json['returnConfirmedAt']?.toString(),
      pickupLocation: json['pickupLocation']?.toString() ?? '',
      returnLocation: json['returnLocation']?.toString() ?? '',
      coveragePlan: json['coveragePlan']?.toString() ?? 'NONE',
      pickupPhotos: (json['pickupPhotos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      returnPhotos: (json['returnPhotos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      damageReport: json['damageReport']?.toString(),
      renter: CounterpartyData.tryParse(json['renter']),
      owner: CounterpartyData.tryParse(json['owner']),
    );
  }
}

class PagedReservations {
  final List<ReservationData> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  PagedReservations({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory PagedReservations.fromJson(Map<String, dynamic> json) {
    return PagedReservations(
      content: (json['content'] as List? ?? [])
          .map((e) => ReservationData.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  factory PagedReservations.empty() =>
      PagedReservations(content: [], page: 1, size: 20, totalElements: 0, totalPages: 0);
}

class ReservationException implements Exception {
  final String message;
  ReservationException(this.message);
  @override
  String toString() => message;
}

class ReservationService {
  static const String baseUrl = 'https://rent2go-backend-production.up.railway.app/api/v1';

  static Map<String, String> _authHeaders(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// POST /api/v1/reservations — crea la reserva real (CreateReservationResource exacto).
  static Future<ReservationData> createReservation({
    required int vehicleId,
    required int renterId,
    required String startDate,
    required String endDate,
    required double totalAmount,
    required String pickupLocation,
    required String returnLocation,
    required String coveragePlan,
    List<String> pickupPhotos = const [],
    List<String> returnPhotos = const [],
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/reservations');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'vehicleId': vehicleId,
        'renterId': renterId,
        'startDate': startDate,
        'endDate': endDate,
        'totalAmount': totalAmount,
        'pickupLocation': pickupLocation,
        'returnLocation': returnLocation,
        'coveragePlan': coveragePlan,
        'pickupPhotos': pickupPhotos,
        'returnPhotos': returnPhotos,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ReservationData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ReservationException(
        'El pago se procesó pero no se pudo crear la reserva. Contacta a soporte con este código de referencia.');
  }

  /// GET /api/v1/reservations?renterId=... — vista de renter, siempre este endpoint
  /// desde pantallas role-fixed de renter (bookings_screen.dart).
  static Future<PagedReservations> getMyReservationsAsRenter({
    required int renterId,
    String? status,
    int page = 1,
    int size = 20,
  }) async {
    final token = await AuthService.getToken();
    final queryParams = <String, String>{
      'renterId': renterId.toString(),
      'page': page.toString(),
      'size': size.toString(),
      if (status != null) 'status': status,
    };
    final uri = Uri.parse('$baseUrl/reservations').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      return PagedReservations.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    return PagedReservations.empty();
  }

  /// GET /api/v1/reservations/owner?ownerId=... — vista de owner, siempre este
  /// endpoint desde pantallas role-fixed de owner (owner_dashboard_screen.dart).
  static Future<PagedReservations> getMyReservationsAsOwner({
    required int ownerId,
    String? status,
    int page = 1,
    int size = 20,
  }) async {
    final token = await AuthService.getToken();
    final queryParams = <String, String>{
      'ownerId': ownerId.toString(),
      'page': page.toString(),
      'size': size.toString(),
      if (status != null) 'status': status,
    };
    final uri = Uri.parse('$baseUrl/reservations/owner').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      return PagedReservations.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    return PagedReservations.empty();
  }

  /// GET /api/v1/reservations/{id}
  static Future<ReservationData?> getReservation(int id) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/reservations/$id');
    final response = await http.get(uri, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      return ReservationData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    return null;
  }

  /// POST /api/v1/reservations/{id}/confirm — "Aceptar" (acción terminal real del backend).
  static Future<ReservationData> confirmReservation(int id) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/reservations/$id/confirm');
    final response = await http.post(uri, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      return ReservationData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ReservationException('No se pudo confirmar la reserva.');
  }

  /// POST /api/v1/reservations/{id}/cancel — "Rechazar" usa cancel; no existe un
  /// endpoint de "reject" dedicado en el backend (confirmado por lectura directa).
  static Future<ReservationData> cancelReservation({
    required int id,
    required int requestedById,
    required String reason,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/reservations/$id/cancel');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'requestedById': requestedById, 'reason': reason}),
    );
    if (response.statusCode == 200) {
      return ReservationData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ReservationException('No se pudo rechazar la reserva.');
  }

  /// POST /api/v1/reservations/{id}/activate — US37: transiciona una reserva
  /// CONFIRMED a ACTIVE (entrega del vehículo). Sin body; 400 si la transición
  /// no es válida (ReservationController.activateReservation exacto).
  static Future<ReservationData> activateReservation(int id) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/reservations/$id/activate');
    final response = await http.post(uri, headers: _authHeaders(token));
    if (response.statusCode == 200) {
      return ReservationData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ReservationException('No se pudo confirmar la entrega del vehículo.');
  }

  /// POST /api/v1/reservations/{id}/confirm-return — US37: transiciona una
  /// reserva ACTIVE a completada tras la devolución (ConfirmReturnResource
  /// exacto: solo requiere actorId).
  static Future<ReservationData> confirmReturn({
    required int id,
    required int actorId,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/reservations/$id/confirm-return');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'actorId': actorId}),
    );
    if (response.statusCode == 200) {
      return ReservationData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ReservationException('No se pudo confirmar la devolución del vehículo.');
  }

  /// GET /api/v1/reservations/owner/paged — US36: historial paginado de
  /// reservas del owner (repository pagination real, distinto del endpoint
  /// /reservations/owner ya usado por owner_dashboard_screen.dart).
  static Future<PagedReservations> getOwnerReservationHistory({
    required int ownerId,
    String? status,
    int page = 1,
    int size = 20,
  }) async {
    final token = await AuthService.getToken();
    final queryParams = <String, String>{
      'ownerId': ownerId.toString(),
      'page': page.toString(),
      'size': size.toString(),
      if (status != null) 'status': status,
    };
    final uri = Uri.parse('$baseUrl/reservations/owner/paged').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _authHeaders(token));

    if (response.statusCode == 200) {
      return PagedReservations.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    return PagedReservations.empty();
  }
}

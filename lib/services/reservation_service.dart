import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'auth_service.dart';
import '../models/counterparty_data.dart';

/// Formatea un timestamp ISO 8601 crudo del backend (ej.
/// "2026-07-10T14:00:00.000Z") a un string legible en hora local
/// (ej. "10/07/2026 14:00"), consistente con el formato dd/MM/yyyy ya usado
/// en availability_screen.dart. Convierte a hora local antes de formatear
/// porque el backend envía las fechas de reserva en UTC.
///
/// Usado por reservation_detail_screen.dart, bookings_screen.dart,
/// owner_dashboard_screen.dart y owner_reservation_history_screen.dart para
/// evitar mostrar el string ISO crudo en la UI. Si el string no es una fecha
/// válida, se devuelve tal cual para no ocultar datos inesperados del backend.
final DateFormat _reservationDateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

String formatReservationDateTime(String rawIsoDate) {
  if (rawIsoDate.isEmpty) return rawIsoDate;
  final parsed = DateTime.tryParse(rawIsoDate);
  if (parsed == null) return rawIsoDate;
  return _reservationDateTimeFormat.format(parsed.toLocal());
}

/// Rediseño de reservation_detail_screen.dart (Box 2 — fechas de recogida y
/// devolución): formato corto en español "Lun 06 jul 2026" (día de la semana
/// abreviado + día + mes abreviado en minúsculas + año), distinto del
/// dd/MM/yyyy HH:mm de [formatReservationDateTime] usado en el resto de la
/// pantalla (confirmaciones, listados). Requiere que
/// `initializeDateFormatting('es')` se haya ejecutado antes (ver main.dart);
/// si el locale 'es' no está inicializado, DateFormat lanza al primer uso, así
/// que se envuelve en try/catch y se degrada al formato dd/MM/yyyy neutro para
/// nunca romper la pantalla por un problema de inicialización de locale.
final DateFormat _reservationDayLabelFormatEs = DateFormat('EEE dd MMM yyyy', 'es');
final DateFormat _reservationDayLabelFormatFallback = DateFormat('dd/MM/yyyy');

String formatReservationDayLabel(String rawIsoDate) {
  if (rawIsoDate.isEmpty) return rawIsoDate;
  final parsed = DateTime.tryParse(rawIsoDate);
  if (parsed == null) return rawIsoDate;
  final local = parsed.toLocal();
  try {
    final formatted = _reservationDayLabelFormatEs.format(local);
    // DateFormat abbreviations come back capitalized per-word (e.g. "Lun 06
    // Jul 2026"); the requested style only capitalizes the weekday.
    final parts = formatted.split(' ');
    if (parts.length == 4) {
      parts[2] = parts[2].toLowerCase();
      return parts.join(' ');
    }
    return formatted;
  } catch (_) {
    return _reservationDayLabelFormatFallback.format(local);
  }
}

/// Conteo total de días de la reserva (Box 2), a partir de las mismas fechas
/// crudas ISO ya usadas para el rango de recogida/devolución. Se redondea al
/// alza (`ceil`) para que una reserva de pocas horas siga contando como
/// mínimo 1 día en lugar de mostrar "0 días".
int reservationDurationInDays(String rawStartIsoDate, String rawEndIsoDate) {
  final start = DateTime.tryParse(rawStartIsoDate);
  final end = DateTime.tryParse(rawEndIsoDate);
  if (start == null || end == null) return 0;
  final diff = end.difference(start).inHours / 24;
  final days = diff.ceil();
  return days < 1 ? 1 : days;
}

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
  // additive: the vehicle's catalog photo, sourced from
  // Vehicle.primaryImageUrl via ReservationResource's "vehicle_image" field.
  // Null when the vehicle has no registered image.
  final String? vehicleImage;

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
    this.vehicleImage,
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
      vehicleImage: json['vehicle_image']?.toString() ?? json['vehicleImage']?.toString(),
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

/// Service responsible for managing booking reservations, status transitions (approvals, handovers),
/// and fetching user booking histories (both for renters and owners).
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

    // Bugfix: el backend valida disponibilidad de fechas en el servidor (RES-02 —
    // overlap contra reservas en estado PENDING/CONFIRMED/ACTIVE/RETURN_PENDING/
    // RETURN_CONFIRMED) y responde 409 CONFLICT con un mensaje de negocio claro
    // ("El vehículo ya tiene una reserva para las fechas solicitadas.") vía
    // GlobalExceptionHandler. Antes este mensaje se descartaba y se mostraba
    // siempre el genérico de abajo, lo que ocultaba al usuario la causa real
    // (conflicto de fechas) — ahora se propaga el mensaje real del backend
    // cuando está disponible.
    if (response.statusCode == 409) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map && (body['error'] != null || body['message'] != null)) {
          throw ReservationException((body['error'] ?? body['message']).toString());
        }
      } catch (e) {
        if (e is ReservationException) rethrow;
      }
      throw ReservationException(
          'El vehículo ya no está disponible en las fechas seleccionadas. Elige otras fechas e inténtalo de nuevo.');
    }

    throw ReservationException(
        'El pago se procesó pero no se pudo crear la reserva. Contacta a soporte con este código de referencia.');
  }

  /// GET /api/v1/reservations?renterId=... — vista de renter, siempre este endpoint
  /// desde pantallas role-fixed de renter (bookings_screen.dart).
  ///
  /// Perf fix (2026-07-06): este endpoint YA NO pagina en el backend — siempre devuelve
  /// la lista COMPLETA de reservas del renter, ordenada con las no-terminales
  /// (PENDING/CONFIRMED/ACTIVE/RETURN_PENDING/RETURN_CONFIRMED) primero y las terminales
  /// (COMPLETED/CANCELLED/EXPIRED) al final, más recientes primero dentro de cada grupo.
  /// Los parámetros [page]/[size] se mantienen en esta firma solo por compatibilidad de
  /// llamada (dejan de tener efecto: el servidor los ignora silenciosamente ya que el
  /// controller ya no los declara), pero ya no reflejan paginación real — `content` siempre
  /// trae todas las reservas y `totalPages` siempre es 1. Se recomienda dejar de pasarlos
  /// desde los call sites y actualizar la UI para no asumir "carga de más páginas".
  static Future<PagedReservations> getMyReservationsAsRenter({
    required int renterId,
    String? status,
    @Deprecated('El backend ya no pagina este endpoint; se ignora silenciosamente.') int page = 1,
    @Deprecated('El backend ya no pagina este endpoint; se ignora silenciosamente.') int size = 20,
  }) async {
    final token = await AuthService.getToken();
    final queryParams = <String, String>{
      'renterId': renterId.toString(),
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

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/vehicle_models.dart';
import '../models/counterparty_data.dart';
import 'auth_service.dart';

class VehicleService {
  static const String baseUrl = 'https://rent2go-backend-production.up.railway.app/api/v1';

  /// GET /api/v1/vehicles/me — vehículos publicados por el propietario actual
  /// (primera página únicamente; usado por callers que no necesitan paginación).
  static Future<List<VehicleData>> getMyVehicles({int page = 0, int size = 20}) async {
    final paged = await getMyVehiclesPaged(page: page, size: size);
    return paged.content;
  }

  /// GET /api/v1/vehicles/me — versión paginada completa (US75/TS22).
  /// A diferencia de [getMyVehicles], expone `page`/`totalPages`/`totalElements`
  /// del `PagedResponse` para que la UI pueda implementar "cargar más".
  static Future<PagedVehicles> getMyVehiclesPaged({int page = 0, int size = 20}) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/vehicles/me?page=$page&size=$size');
    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PagedVehicles.fromJson(data);
    }
    throw Exception('No se pudieron cargar tus vehículos');
  }

  /// GET /api/v1/vehicles/{id} — detalle público de un vehículo por id.
  ///
  /// Issue 5 (reservation detail parity): reservation_detail_screen.dart solo tenía
  /// ReservationData.vehicleId, sin foto/ubicación/detalles del vehículo. Este endpoint ya
  /// existe y es público (VehicleController#getVehicleDetails, sin filtro de autorización) —
  /// igual al que usa Kotlin (VehicleRepositoryImpl.getVehicleById) para la misma pantalla.
  /// Se prefiere este fetch cliente-a-endpoint-existente en vez de embeber un resumen del
  /// vehículo en ReservationResource (como se hizo para renter/owner en TS18): a diferencia
  /// del counterparty, que requiere una consulta cross-contexto autenticada a /users/{id},
  /// el vehículo ya es 100% público vía este endpoint, así que no hay N+1 ni auth que evitar.
  static Future<VehicleData> getVehicleById(int vehicleId) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/vehicles/$vehicleId');
    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return VehicleData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('No se pudo cargar la información del vehículo');
  }

  /// GET /api/v1/vehicles/{id}/owner-summary — US76 closure (Sprint 5 fixes remaining scope).
  ///
  /// Public-safe read: name + verification badges (KYC/DNI/license) + profile photo for the
  /// vehicle's owner, resolvable BEFORE any reservation exists — closes the pre-booking gap
  /// that [CounterpartyData] (until now only embedded in ReservationResource/ConversationResource,
  /// both post-booking) could not fill. Same response shape as those, reused as-is here.
  ///
  /// Returns null if the vehicle itself is not found (404) or the response cannot be parsed —
  /// callers must show an explicit "no verification info available" state, never crash.
  static Future<CounterpartyData?> getVehicleOwnerSummary(int vehicleId) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/vehicles/$vehicleId/owner-summary');
    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return CounterpartyData.tryParse(jsonDecode(response.body));
    }
    return null;
  }

  /// GET /api/v1/vehicles/categories
  static Future<List<VehicleCategory>> getCategories() async {
    final uri = Uri.parse('$baseUrl/vehicles/categories');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((c) => VehicleCategory.fromJson(c)).toList();
    }
    return [];
  }

  /// POST /api/v1/vehicles/with-image — publica un vehículo nuevo con foto.
  /// Todos los campos van como query params (multipart/form fields), y la
  /// imagen va como archivo binario bajo la clave 'file'
  static Future<VehicleData> createVehicle({
    required String licensePlate,
    required String make,
    required String model,
    required int year,
    required String vin,
    required double dailyPrice,
    required int categoryId,
    required String location,
    String? description,
    int? seats,
    required String transmission,
    required String fuelType,
    double? latitude,
    double? longitude,
    List<String>? featureNames,
    required Uint8List imageBytes,
    required String imageFilename,
  }) async {
    final token = await AuthService.getToken();

    final queryParams = {
      'licensePlate': licensePlate,
      'make': make,
      'model': model,
      'year': year.toString(),
      'vin': vin,
      'dailyPrice': dailyPrice.toString(),
      'categoryId': categoryId.toString(),
      'location': location,
      if (description != null) 'description': description,
      if (seats != null) 'seats': seats.toString(),
      'transmission': transmission,
      'fuelType': fuelType,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
    };

    final uri = Uri.parse('$baseUrl/vehicles/with-image').replace(queryParameters: queryParams);

    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    if (featureNames != null) {
      for (final f in featureNames) {
        request.fields['featureNames'] = f;
      }
    }

    request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: imageFilename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return VehicleData.fromJson(jsonDecode(response.body));
    }

    String message = 'No se pudo publicar el vehículo';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && (body['message'] != null || body['error'] != null)) {
        message = (body['message'] ?? body['error']).toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  /// GET /api/v1/vehicles — búsqueda de vehículos disponibles (paginado)
  /// Usado por la vista de arrendatario para mostrar el catálogo real.
  /// US63/TS19: acepta filtros estructurados (precio/asientos/transmisión/combustible)
  /// y búsqueda por radio geográfico — mismos query params que ya acepta el backend
  /// (VehicleController.searchAvailableVehicles) y que Kotlin ya usa.
  static Future<List<VehicleData>> getAvailableVehicles({
    int page = 0,
    int size = 50,
    double? minPrice,
    double? maxPrice,
    int? seats,
    String? transmission,
    String? fuelType,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusKm,
  }) async {
    final paged = await getAvailableVehiclesPaged(
      page: page,
      size: size,
      minPrice: minPrice,
      maxPrice: maxPrice,
      seats: seats,
      transmission: transmission,
      fuelType: fuelType,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      radiusKm: radiusKm,
    );
    return paged.content;
  }

  /// GET /api/v1/vehicles — versión paginada completa (US75/TS22).
  /// Igual que [getAvailableVehicles] pero expone el `PagedResponse` completo
  /// (page/size/totalElements/totalPages) para alimentar scroll-triggered
  /// "load more" en explore_screen.dart, mirroring Kotlin's
  /// VehicleListViewModel.loadNextPage semantics (page-index tracking,
  /// hasMorePages = page < totalPages - 1).
  static Future<PagedVehicles> getAvailableVehiclesPaged({
    int page = 0,
    int size = 50,
    double? minPrice,
    double? maxPrice,
    int? seats,
    String? transmission,
    String? fuelType,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusKm,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      if (minPrice != null) 'minPrice': minPrice.toString(),
      if (maxPrice != null) 'maxPrice': maxPrice.toString(),
      if (seats != null) 'seats': seats.toString(),
      if (transmission != null && transmission.isNotEmpty) 'transmission': transmission,
      if (fuelType != null && fuelType.isNotEmpty) 'fuelType': fuelType,
      if (centerLatitude != null) 'centerLatitude': centerLatitude.toString(),
      if (centerLongitude != null) 'centerLongitude': centerLongitude.toString(),
      if (radiusKm != null) 'radiusKm': radiusKm.toString(),
    };
    final uri = Uri.parse('$baseUrl/vehicles').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PagedVehicles.fromJson(data);
    }
    throw Exception('No se pudieron cargar los vehículos disponibles');
  }

  /// PATCH /api/v1/vehicles/{id}/status
  static Future<void> updateStatus(int vehicleId, String status) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/vehicles/$vehicleId/status?status=$status');
    await http.patch(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
  }

  /// PUT /api/v1/vehicles/{id} — actualiza los datos del vehículo.
  /// A diferencia de la creación (multipart/query params), este endpoint
  /// recibe JSON puro en el body
  static Future<VehicleData> updateVehicle({
    required int id,
    required int categoryId,
    required String make,
    required String model,
    required int year,
    required String location,
    String? description,
    int? seats,
    required String transmission,
    required String fuelType,
    List<String>? features,
    double? latitude,
    double? longitude,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/vehicles/$id');

    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'categoryId': categoryId,
        'make': make,
        'model': model,
        'year': year,
        'location': location,
        'description': description ?? '',
        'seats': seats ?? 0,
        'transmission': transmission,
        'fuelType': fuelType,
        'features': features ?? [],
        // US65 fix: omit lat/lon when not provided instead of defaulting to 0.0
        // (the Gulf of Guinea) — the backend treats these fields as optional
        // (RegisterVehicleWithImageResource has no @NotNull on them).
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      }),
    );

    if (response.statusCode == 200) {
      return VehicleData.fromJson(jsonDecode(response.body));
    }

    String message = 'No se pudo actualizar el vehículo';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && (body['message'] != null || body['error'] != null)) {
        message = (body['message'] ?? body['error']).toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  /// PUT /api/v1/vehicles/{id}/price — actualiza solo el precio diario.
  static Future<void> updatePrice(int vehicleId, double dailyPrice) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/vehicles/$vehicleId/price');
    await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'dailyPrice': dailyPrice}),
    );
  }

  /// DELETE /api/v1/vehicles/{id} — elimina un vehículo del propietario.
  /// El backend responde 409 si el vehículo tiene historial de reservas;
  /// ese caso se traduce a un mensaje amigable para el usuario (US17).
  static Future<void> deleteVehicle(int vehicleId) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/vehicles/$vehicleId');
    final response = await http.delete(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    if (response.statusCode == 409) {
      throw Exception(
          'No se puede eliminar: este vehículo tiene reservas asociadas.');
    }

    String message = 'No se pudo eliminar el vehículo';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && (body['message'] != null || body['error'] != null)) {
        message = (body['message'] ?? body['error']).toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  /// GET /api/v1/availability/vehicle/{vehicleId}/blocks — US13/US15.
  /// Devuelve los rangos de fechas bloqueados manualmente por el propietario
  /// (o ya reservados) para un vehículo, para pintar el calendario.
  static Future<List<AvailabilityBlock>> getAvailabilityBlocks(int vehicleId) async {
    final uri = Uri.parse('$baseUrl/availability/vehicle/$vehicleId/blocks');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((b) => AvailabilityBlock.fromJson(b)).toList();
    }
    throw Exception('No se pudo cargar la disponibilidad del vehículo');
  }

  /// POST /api/v1/availability/block — US13.
  /// Bloquea un rango de fechas para que no pueda reservarse (mantenimiento,
  /// uso personal, etc). El backend rechaza el rango si se solapa con una
  /// reserva ya confirmada (409/400, mensaje estandarizado).
  static Future<void> blockAvailability({
    required int vehicleId,
    required DateTime startDate,
    required DateTime endDate,
    required int requestedBy,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/availability/block');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'vehicleId': vehicleId,
        'startDate': _dateOnly(startDate),
        'endDate': _dateOnly(endDate),
        'requestedBy': requestedBy,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    String message = 'No se pudo bloquear el rango de fechas';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && (body['message'] != null || body['error'] != null)) {
        message = (body['message'] ?? body['error']).toString();
      }
    } catch (_) {}
    if (response.statusCode == 409 || response.statusCode == 400) {
      throw Exception('Ese rango se solapa con una reserva confirmada. Elige otras fechas.');
    }
    throw Exception(message);
  }

  /// DELETE /api/v1/availability/vehicle/{vehicleId}/range — US13.
  /// Libera (desbloquea) un rango de fechas previamente bloqueado.
  static Future<void> unblockAvailabilityRange({
    required int vehicleId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/availability/vehicle/$vehicleId/range').replace(
      queryParameters: {
        'startDate': _dateOnly(startDate),
        'endDate': _dateOnly(endDate),
      },
    );
    final response = await http.delete(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw Exception('No se pudo liberar el rango de fechas');
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class AvailabilityBlock {
  final int id;
  final DateTime startDate;
  final DateTime endDate;

  AvailabilityBlock({required this.id, required this.startDate, required this.endDate});

  factory AvailabilityBlock.fromJson(Map<String, dynamic> json) {
    return AvailabilityBlock(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      startDate: DateTime.parse(json['startDate'].toString()),
      endDate: DateTime.parse(json['endDate'].toString()),
    );
  }
}
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/vehicle_models.dart';
import 'auth_service.dart';

class VehicleService {
  static const String baseUrl = 'https://rent2go-backend-production.up.railway.app/api/v1';

  /// GET /api/v1/vehicles/me — vehículos publicados por el propietario actual
  static Future<List<VehicleData>> getMyVehicles({int page = 0, int size = 20}) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/vehicles/me?page=$page&size=$size');
    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List;
      return content.map((v) => VehicleData.fromJson(v)).toList();
    }
    throw Exception('No se pudieron cargar tus vehículos');
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
  /// Usado por la vista de arrendatario para mostrar el catálogo real
  static Future<List<VehicleData>> getAvailableVehicles({int page = 0, int size = 50}) async {
    final uri = Uri.parse('$baseUrl/vehicles?page=$page&size=$size');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List;
      return content.map((v) => VehicleData.fromJson(v)).toList();
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
        'latitude': latitude ?? 0,
        'longitude': longitude ?? 0,
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
}
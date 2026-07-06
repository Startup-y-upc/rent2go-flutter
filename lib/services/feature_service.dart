import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vehicle_models.dart';

/// Cliente para el catálogo de features/amenidades de vehículo.
///
/// GET /api/v1/features — lectura, usada para poblar la selección múltiple en
/// add_vehicle_screen.dart / edit_vehicle_screen.dart.
/// POST /api/v1/features — permite crear un feature nuevo directamente desde
/// el formulario de vehículo cuando el usuario no encuentra el que necesita
/// en el catálogo existente (queda disponible para futuros vehículos también).
class FeatureService {
  static const String baseUrl = 'https://rent2go-backend-production.up.railway.app/api/v1';

  /// GET /api/v1/features — lista todos los features disponibles.
  /// Devuelve lista vacía en caso de error para que la UI degrade con
  /// gracia (la selección de features es opcional, no bloquea el formulario).
  static Future<List<VehicleFeature>> getFeatures() async {
    final uri = Uri.parse('$baseUrl/features');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((f) => VehicleFeature.fromJson(f as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Sin conexión o backend caído: se degrada a lista vacía.
    }
    return [];
  }

  /// POST /api/v1/features — crea un nuevo feature en el catálogo.
  /// Body: { "name": "..." } (description/iconUrl son opcionales en el
  /// backend, no se envían desde este formulario).
  /// Devuelve el VehicleFeature creado con el id real asignado por el
  /// backend. Lanza Exception con un mensaje de usuario si falla (409 = ya
  /// existe un feature con ese nombre, u otro error de red/servidor).
  static Future<VehicleFeature> createFeature(String name) async {
    final uri = Uri.parse('$baseUrl/features');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 201) {
      return VehicleFeature.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    if (response.statusCode == 409) {
      throw Exception('Ya existe una característica con ese nombre');
    }
    throw Exception('No se pudo crear la característica');
  }
}

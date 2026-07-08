import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vehicle_models.dart';

/// Cliente para el catálogo de features/amenidades de vehículo.
///
/// GET /api/v1/features — lectura, usada para poblar la selección múltiple en
/// add_vehicle_screen.dart / edit_vehicle_screen.dart.
///
/// No expone creación de features por separado: los nombres de features
/// nuevos que el usuario escribe en el formulario de vehículo se mantienen en
/// memoria y se envían junto con los ya seleccionados del catálogo en el
/// mismo payload de creación/actualización del vehículo
/// (VehicleService.createVehicle/updateVehicle), sin llamar a este servicio.
/// Service responsible for fetching and handling the catalog of vehicle features/amenities.
/// Helps populate option selectors in forms where vehicles are added or updated.
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
}

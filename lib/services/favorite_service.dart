import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vehicle_models.dart';
import 'auth_service.dart';

/// Favorito de un vehículo, tal como lo devuelve el backend
/// (FavoritesController — booking_reservations context).
class FavoriteData {
  final int id;
  final int userId;
  final int vehicleId;

  const FavoriteData({required this.id, required this.userId, required this.vehicleId});

  factory FavoriteData.fromJson(Map<String, dynamic> json) {
    return FavoriteData(
      id: json['id'] as int? ?? 0,
      userId: json['userId'] as int? ?? 0,
      vehicleId: json['vehicleId'] as int? ?? 0,
    );
  }
}

/// Vehículo favorito enriquecido con los datos del vehículo, para alimentar
/// favorites_screen.dart sin que la UI tenga que hacer el join manualmente.
class FavoriteVehicle {
  final FavoriteData favorite;
  final VehicleData vehicle;
  const FavoriteVehicle({required this.favorite, required this.vehicle});
}

/// Cliente para el endpoint de favoritos del backend
/// (BookingReservations.FavoritesController, `/api/v1/favorites`):
///   POST   /api/v1/favorites               body {userId, vehicleId}
///   DELETE /api/v1/favorites?userId=&vehicleId=
///   GET    /api/v1/favorites?userId=&page=&size=  -> PagedResponse<FavoriteResource>
class FavoriteService {
  static const String baseUrl = 'https://rent2go-backend-production.up.railway.app/api/v1';

  /// POST /api/v1/favorites — agrega el vehículo a los favoritos del usuario.
  static Future<FavoriteData> addFavorite({required int userId, required int vehicleId}) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/favorites');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'userId': userId, 'vehicleId': vehicleId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return FavoriteData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('No se pudo agregar a favoritos');
  }

  /// DELETE /api/v1/favorites?userId=&vehicleId= — quita el vehículo de favoritos.
  static Future<void> removeFavorite({required int userId, required int vehicleId}) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/favorites').replace(queryParameters: {
      'userId': userId.toString(),
      'vehicleId': vehicleId.toString(),
    });
    final response = await http.delete(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw Exception('No se pudo quitar de favoritos');
  }

  /// GET /api/v1/favorites?userId=&page=&size= — lista paginada de favoritos
  /// del usuario (page inicia en 1, según el controller del backend).
  static Future<List<FavoriteData>> getFavorites(int userId, {int page = 1, int size = 100}) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/favorites').replace(queryParameters: {
      'userId': userId.toString(),
      'page': page.toString(),
      'size': size.toString(),
    });
    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (data['content'] as List? ?? []);
      return content.map((f) => FavoriteData.fromJson(f as Map<String, dynamic>)).toList();
    }
    throw Exception('No se pudieron cargar tus favoritos');
  }

  /// Conveniencia usada por car_detail_screen.dart: determina si `vehicleId`
  /// ya está en favoritos del usuario. El backend no expone un endpoint
  /// "check one" ni un campo `isFavorite` en el detalle del vehículo, así que
  /// se resuelve trayendo la lista completa de favoritos (ya paginada/acotada)
  /// y buscando el id — mismo costo que ya paga favorites_screen.dart, sin
  /// llamadas adicionales duplicadas en la pantalla de detalle.
  static Future<bool> isFavorite({required int userId, required int vehicleId}) async {
    final favorites = await getFavorites(userId);
    return favorites.any((f) => f.vehicleId == vehicleId);
  }

  /// Lista de favoritos enriquecida con el vehículo completo, para
  /// favorites_screen.dart. Hace un fetch por vehículo (GET /vehicles/{id},
  /// ya público) porque FavoriteResource solo trae el id — se descartan los
  /// favoritos cuyo vehículo ya no pueda cargarse en vez de romper la lista.
  static Future<List<FavoriteVehicle>> getFavoriteVehicles(int userId) async {
    final favorites = await getFavorites(userId);
    final results = <FavoriteVehicle>[];
    for (final favorite in favorites) {
      try {
        final uri = Uri.parse('$baseUrl/vehicles/${favorite.vehicleId}');
        final token = await AuthService.getToken();
        final response = await http.get(
          uri,
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final vehicle = VehicleData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
          results.add(FavoriteVehicle(favorite: favorite, vehicle: vehicle));
        }
      } catch (_) {
        // Vehículo eliminado o inaccesible: se omite en vez de romper la lista.
      }
    }
    return results;
  }
}

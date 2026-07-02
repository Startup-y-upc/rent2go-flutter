import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Reporte de ganancias de un propietario (US24), obtenido de
/// GET /api/v1/payments/owners/{ownerId}/earnings.
class OwnerEarningsReport {
  final double totalAmount;
  final int paymentsCount;
  final String currency;

  OwnerEarningsReport({
    required this.totalAmount,
    required this.paymentsCount,
    required this.currency,
  });

  factory OwnerEarningsReport.fromJson(Map<String, dynamic> json) {
    return OwnerEarningsReport(
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentsCount: (json['paymentsCount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
    );
  }

  /// Reporte vacío — se usa cuando el propietario no tiene historial de pagos,
  /// mostrando ceros en vez de un error (AC de US24).
  factory OwnerEarningsReport.empty() =>
      OwnerEarningsReport(totalAmount: 0, paymentsCount: 0, currency: 'USD');
}

/// Métricas de desempeño de un vehículo (US24), obtenidas de
/// GET /api/v1/payments/vehicles/{vehicleId}/performance.
class VehiclePerformanceReport {
  final int vehicleId;
  final int reservationCount;
  final double totalRevenue;
  final String currency;
  final double occupancyPercentage;

  VehiclePerformanceReport({
    required this.vehicleId,
    required this.reservationCount,
    required this.totalRevenue,
    required this.currency,
    required this.occupancyPercentage,
  });

  factory VehiclePerformanceReport.fromJson(Map<String, dynamic> json) {
    return VehiclePerformanceReport(
      vehicleId: (json['vehicleId'] as num?)?.toInt() ?? 0,
      reservationCount: (json['reservationCount'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      occupancyPercentage: (json['occupancyPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Reporte vacío — se usa cuando la petición falla; se muestran ceros
  /// en vez de romper la lista "Por vehículo" (mismo criterio que US24 owner earnings).
  factory VehiclePerformanceReport.empty(int vehicleId) => VehiclePerformanceReport(
        vehicleId: vehicleId,
        reservationCount: 0,
        totalRevenue: 0,
        currency: 'USD',
        occupancyPercentage: 0,
      );
}

class PaymentsService {
  static const String baseUrl = 'https://rent2go-backend-production.up.railway.app/api/v1';

  /// GET /api/v1/payments/owners/{ownerId}/earnings?from=...&to=...
  /// Por defecto consulta los últimos 7 meses, para alinear con la vista
  /// "Últimos 7 meses" de owner_earnings_screen.dart.
  static Future<OwnerEarningsReport> getOwnerEarnings({
    required int ownerId,
    DateTime? from,
    DateTime? to,
  }) async {
    final token = await AuthService.getToken();
    final now = to ?? DateTime.now();
    final start = from ?? DateTime(now.year, now.month - 6, 1);

    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse(
        '$baseUrl/payments/owners/$ownerId/earnings?from=${fmt(start)}&to=${fmt(now)}');
    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return OwnerEarningsReport.fromJson(data);
    }

    // Sin historial de pagos u otro estado no exitoso: no se muestra error,
    // se retorna un reporte vacío (US24 AC — cero, no falla).
    return OwnerEarningsReport.empty();
  }

  /// GET /api/v1/payments/vehicles/{vehicleId}/performance?from=...&to=...
  /// Sin parámetros de fecha consulta todo el histórico del vehículo
  /// (el backend usa la fecha de publicación del vehículo como inicio por defecto).
  static Future<VehiclePerformanceReport> getVehiclePerformance({
    required int vehicleId,
    DateTime? from,
    DateTime? to,
  }) async {
    final token = await AuthService.getToken();

    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final queryParams = <String, String>{
      if (from != null) 'from': fmt(from),
      if (to != null) 'to': fmt(to),
    };

    final uri = Uri.parse('$baseUrl/payments/vehicles/$vehicleId/performance')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return VehiclePerformanceReport.fromJson(data);
    }

    // Vehículo sin historial u otro estado no exitoso: cero, no falla,
    // para no romper el listado "Por vehículo" de owner_earnings_screen.dart.
    return VehiclePerformanceReport.empty(vehicleId);
  }
}

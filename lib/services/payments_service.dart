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
}

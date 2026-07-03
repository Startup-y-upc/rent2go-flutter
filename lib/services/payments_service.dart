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

/// Plan de cobertura devuelto por GET /api/v1/payments/coverage-plans.
/// Códigos reales del backend: BASIC/STANDARD/PREMIUM/NONE (no inventar otros).
class CoveragePlan {
  final String code;
  final String name;
  final String description;
  final double dailyRateUsd;

  CoveragePlan({
    required this.code,
    required this.name,
    required this.description,
    required this.dailyRateUsd,
  });

  factory CoveragePlan.fromJson(Map<String, dynamic> json) {
    return CoveragePlan(
      code: json['code']?.toString() ?? 'NONE',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      dailyRateUsd: (json['dailyRateUSD'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Desglose de tarifa devuelto por POST /api/v1/payments/calculate
/// (MoneyResource exacto del backend).
class FareBreakdown {
  final double amount;
  final String currency;
  final double subtotal;
  final double serviceFee;
  final double coverageFee;
  final double discount;
  final double taxes;
  final double total;

  FareBreakdown({
    required this.amount,
    required this.currency,
    required this.subtotal,
    required this.serviceFee,
    required this.coverageFee,
    required this.discount,
    required this.taxes,
    required this.total,
  });

  factory FareBreakdown.fromJson(Map<String, dynamic> json) {
    return FareBreakdown(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'USD',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 0.0,
      coverageFee: (json['coverageFee'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      taxes: (json['taxes'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Respuesta de POST /api/v1/payments/create-intent (CreateIntentResponse exacto).
class PaymentIntentResult {
  final String clientSecret;
  final String id;
  PaymentIntentResult({required this.clientSecret, required this.id});

  factory PaymentIntentResult.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResult(
      clientSecret: json['clientSecret']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
    );
  }
}

/// Excepción específica de pagos para diferenciar el estado de error visible
/// (Fase 1, F1) de un SnackBar silencioso.
class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
  @override
  String toString() => message;
}

class PaymentsService {
  static const String baseUrl = 'https://rent2go-backend-production.up.railway.app/api/v1';

  /// GET /api/v1/payments/coverage-plans — códigos y precios reales del backend.
  static Future<List<CoveragePlan>> getCoveragePlans() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/payments/coverage-plans');
    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => CoveragePlan.fromJson(e as Map<String, dynamic>)).toList();
    }

    throw PaymentException('No se pudieron cargar los planes de cobertura.');
  }

  /// POST /api/v1/payments/calculate — total real, no un cálculo local.
  static Future<FareBreakdown> calculateFare({
    required double baseAmount,
    required String coveragePlan,
    String currency = 'USD',
    String? promoCode,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/payments/calculate');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'baseAmount': baseAmount,
        'currency': currency,
        'coveragePlan': coveragePlan,
        if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
      }),
    );

    if (response.statusCode == 200) {
      return FareBreakdown.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw PaymentException('No se pudo calcular el precio de la reserva.');
  }

  /// POST /api/v1/payments/create-intent — crea el PaymentIntent real en el backend.
  static Future<PaymentIntentResult> createPaymentIntent({
    required int reservationId,
    required int amountCents,
    String currency = 'usd',
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw PaymentException('No hay sesión activa para procesar el pago.');
    }
    final uri = Uri.parse('$baseUrl/payments/create-intent');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'reservationId': reservationId,
        'amountCents': amountCents,
        'currency': currency,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return PaymentIntentResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw PaymentException('No se pudo iniciar el cobro. Intenta nuevamente.');
  }

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

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Reporte de ganancias de un propietario (US24), obtenido de
/// GET /api/v1/payments/owners/{ownerId}/earnings.
class OwnerEarningsReport {
  final double totalAmount;
  final int paymentsCount;
  final String currency;
  final int availablePayoutCents;
  final int pendingPayoutCents;

  OwnerEarningsReport({
    required this.totalAmount,
    required this.paymentsCount,
    required this.currency,
    this.availablePayoutCents = 0,
    this.pendingPayoutCents = 0,
  });

  double get availablePayoutAmount => availablePayoutCents / 100.0;

  factory OwnerEarningsReport.fromJson(Map<String, dynamic> json) {
    return OwnerEarningsReport(
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentsCount: (json['paymentsCount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'PEN',
      availablePayoutCents: (json['availablePayoutCents'] as num?)?.toInt() ?? 0,
      pendingPayoutCents: (json['pendingPayoutCents'] as num?)?.toInt() ?? 0,
    );
  }

  /// Reporte vacío — se usa cuando el propietario no tiene historial de pagos,
  /// mostrando ceros en vez de un error (AC de US24).
  factory OwnerEarningsReport.empty() =>
      OwnerEarningsReport(totalAmount: 0, paymentsCount: 0, currency: 'PEN');
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
      currency: json['currency'] as String? ?? 'PEN',
      occupancyPercentage: (json['occupancyPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Reporte vacío — se usa cuando la petición falla; se muestran ceros
  /// en vez de romper la lista "Por vehículo" (mismo criterio que US24 owner earnings).
  factory VehiclePerformanceReport.empty(int vehicleId) => VehiclePerformanceReport(
        vehicleId: vehicleId,
        reservationCount: 0,
        totalRevenue: 0,
        currency: 'PEN',
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
      currency: json['currency']?.toString() ?? 'PEN',
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

/// EarningsMovementResource exacto del backend (US47/TS12):
/// GET /payments/owners/{ownerId}/earnings/movements.
class EarningsMovement {
  final int? reservationId;
  final int amountCents;
  final String? status;
  final String? createdAt;

  EarningsMovement({
    required this.reservationId,
    required this.amountCents,
    required this.status,
    required this.createdAt,
  });

  double get amount => amountCents / 100.0;

  factory EarningsMovement.fromJson(Map<String, dynamic> json) {
    return EarningsMovement(
      reservationId: (json['reservationId'] as num?)?.toInt(),
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

/// WithdrawalResource exacto del backend (US48/US49).
class WithdrawalData {
  final int id;
  final int ownerId;
  final int amountCents;
  final String? payoutDestinationNote;
  final String? status;
  final String? requestedAt;

  WithdrawalData({
    required this.id,
    required this.ownerId,
    required this.amountCents,
    this.payoutDestinationNote,
    this.status,
    this.requestedAt,
  });

  double get amount => amountCents / 100.0;

  factory WithdrawalData.fromJson(Map<String, dynamic> json) {
    return WithdrawalData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ownerId: (json['ownerId'] as num?)?.toInt() ?? 0,
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      payoutDestinationNote: json['payoutDestinationNote']?.toString(),
      status: json['status']?.toString(),
      requestedAt: json['requestedAt']?.toString(),
    );
  }
}

class PagedWithdrawals {
  final List<WithdrawalData> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  PagedWithdrawals({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory PagedWithdrawals.fromJson(Map<String, dynamic> json) {
    return PagedWithdrawals(
      content: (json['content'] as List? ?? [])
          .map((e) => WithdrawalData.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  factory PagedWithdrawals.empty() =>
      PagedWithdrawals(content: [], page: 1, size: 20, totalElements: 0, totalPages: 0);
}

/// Excepción específica de retiros — distingue el caso de saldo insuficiente
/// (400 del backend) para mostrar un mensaje claro y accionable.
class WithdrawalException implements Exception {
  final String message;
  final bool insufficientBalance;
  WithdrawalException(this.message, {this.insufficientBalance = false});
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
    String currency = 'PEN',
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
  ///
  /// Issue 2 fix: el default de moneda era 'pen' (Soles), pero el proyecto opera con una
  /// cuenta de Stripe en modo TEST configurada en USD (ver Kotlin's Constants.kt/
  /// CreateIntentRequest, que siempre usa "usd", y GET /coverage-plans, cuyo dailyRateUSD
  /// confirma que las tarifas del backend están en dólares). Cobrar con currency='pen' sobre
  /// un amountCents calculado a partir de una tarifa en USD habría cobrado un monto real
  /// distinto (o habría sido rechazado por Stripe si la cuenta no tiene PEN habilitado) —
  /// bug latente, no disparado aún porque ningún pago de Flutter había llegado a completarse
  /// exitosamente. Alineado con Kotlin/backend: default ahora es 'usd'.
  static Future<PaymentIntentResult> createPaymentIntent({
    required int reservationId,
    required int amountCents,
    String currency = 'usd',
  }) async {
    // Issue 1 fix (applied defensively here too, per Issue 2's side-by-side audit): the
    // backend's CreateIntentRequest requires reservationId > 0 and amountCents > 0
    // (@Positive) — reject client-side before the round-trip so a 0/invalid value never
    // silently reaches the backend as an undiagnosable HTTP 422.
    if (reservationId <= 0) {
      throw PaymentException('ID de reserva inválido: no se puede iniciar el cobro.');
    }
    if (amountCents <= 0) {
      throw PaymentException('Monto a cobrar inválido: no se puede iniciar el cobro.');
    }

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

    // Previously the response body was discarded entirely on failure, making any real
    // validation error (backend's GlobalExceptionHandler returns field+message detail on a
    // 422) invisible to both developers and users. Now surfaced when present.
    String detail = '';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        detail = ' (${body['message']})';
      } else if (body is Map && body['errors'] != null) {
        detail = ' (${body['errors']})';
      }
    } catch (_) {
      // Non-JSON or empty body — ignore, keep the generic message.
    }
    throw PaymentException('No se pudo iniciar el cobro. Intenta nuevamente.$detail');
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

  /// GET /api/v1/payments/owners/{ownerId}/earnings/movements?from=...&to=...
  /// US47/TS12: reemplaza el placeholder "Desglose mensual: próximamente".
  static Future<List<EarningsMovement>> getEarningsMovements({
    required int ownerId,
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
    final uri = Uri.parse('$baseUrl/payments/owners/$ownerId/earnings/movements')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => EarningsMovement.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (response.statusCode == 403) {
      throw PaymentException('No tienes permiso para ver estos movimientos.');
    }
    throw PaymentException('No se pudo cargar el desglose de movimientos.');
  }

  /// POST /api/v1/payments/owners/{ownerId}/withdrawals — US48/US49.
  /// (CreateWithdrawalRequest exacto: amountCents + payoutDestinationNote).
  static Future<WithdrawalData> requestWithdrawal({
    required int ownerId,
    required int amountCents,
    String? payoutDestinationNote,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/payments/owners/$ownerId/withdrawals');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'amountCents': amountCents,
        if (payoutDestinationNote != null && payoutDestinationNote.isNotEmpty)
          'payoutDestinationNote': payoutDestinationNote,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return WithdrawalData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    if (response.statusCode == 403) {
      throw WithdrawalException('No tienes permiso para retirar de esta cuenta.');
    }
    if (response.statusCode == 400) {
      throw WithdrawalException(
        'El monto solicitado supera tu saldo disponible o no es válido.',
        insufficientBalance: true,
      );
    }
    throw WithdrawalException('No se pudo procesar el retiro. Intenta nuevamente.');
  }

  /// GET /api/v1/payments/owners/{ownerId}/withdrawals — US49, historial paginado.
  static Future<PagedWithdrawals> getWithdrawalHistory({
    required int ownerId,
    int page = 1,
    int size = 20,
  }) async {
    final token = await AuthService.getToken();
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    final uri = Uri.parse('$baseUrl/payments/owners/$ownerId/withdrawals').replace(queryParameters: queryParams);
    final response = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return PagedWithdrawals.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    if (response.statusCode == 403) {
      throw WithdrawalException('No tienes permiso para ver este historial.');
    }
    return PagedWithdrawals.empty();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/vehicle_models.dart';
import '../services/auth_service.dart';
import '../services/payments_service.dart';
import '../services/reservation_service.dart';
import '../services/vehicle_service.dart';
import '../widgets/common_widgets.dart';

class ConfirmBookingScreen extends StatefulWidget {
  final VehicleData vehicle;
  final DateTime? startDate;
  final DateTime? endDate;
  const ConfirmBookingScreen({super.key, required this.vehicle, this.startDate, this.endDate});
  @override
  State<ConfirmBookingScreen> createState() => _ConfirmBookingScreenState();
}

enum _LoadState { loading, ready, error }
enum _SubmitState {
  idle,
  processingPayment,
  creatingReservation,
  success,
  paymentFailed,
  reservationFailed,
  paymentAbandoned,
}

class _ConfirmBookingScreenState extends State<ConfirmBookingScreen> {
  late DateTime _startDate;
  late DateTime _endDate;

  _LoadState _loadState = _LoadState.loading;
  List<CoveragePlan> _coverages = [];
  int _coverageIndex = 0;
  FareBreakdown? _fare;
  bool _calculating = false;
  String? _loadError;

  // Bloqueos de disponibilidad del vehículo consultados vía GET
  // /api/v1/availability/vehicle/{id}/blocks (VehicleService.getAvailabilityBlocks).
  //
  // IMPORTANTE (leído directamente del backend — AvailabilityController /
  // VehicleAvailabilityQueryServiceImpl.findByVehicleId): este endpoint solo
  // devuelve bloqueos MANUALES del propietario (tabla VehicleAvailability,
  // ej. mantenimiento/uso personal). NO incluye reservas de otros renters —
  // no existe ningún endpoint que exponga las reservas de un vehículo por
  // vehicleId al cliente Flutter (ReservationController solo permite listar
  // por renterId/ownerId). Por eso esta pantalla NO puede detectar de forma
  // 100% confiable un choque contra la reserva de otro renter antes de
  // enviar el POST — para eso ya existe una validación autoritativa en el
  // backend (ReservationCommandServiceImpl.handle(CreateReservationCommand),
  // regla RES-02), que responde 409 CONFLICT con mensaje claro si hay
  // solape; ese mensaje ahora se propaga literal en el catch de
  // ReservationException en _payAndReserve.
  //
  // Esta pantalla SÍ puede bloquear con certeza dos casos con la información
  // disponible localmente:
  //  1. Solape contra un bloqueo manual del propietario.
  //  2. Violación del margen de 1 día de mantenimiento entre el fin de un
  //     bloqueo/reserva conocido y el inicio de la nueva reserva (regla de
  //     negocio nueva, no aplicada por el backend).
  // Por eso el conflicto detectado aquí SÍ bloquea el botón "Pagar y
  // reservar" (a diferencia del comportamiento anterior, que solo advertía).
  List<AvailabilityBlock> _availabilityBlocks = [];
  bool _loadingAvailability = false;
  bool _availabilityCheckFailed = false;
  String? _dateConflictError;

  /// Días de margen que el propietario necesita entre el fin de una reserva/
  /// bloqueo y el inicio de la siguiente, para inspección y mantenimiento.
  static const int _maintenanceBufferDays = 0;

  _SubmitState _submitState = _SubmitState.idle;
  String? _submitError;

  int get _days => _endDate.difference(_startDate).inDays.clamp(1, 365);

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate ?? DateTime.now().add(const Duration(days: 2));
    _endDate = widget.endDate ?? _startDate.add(const Duration(days: 2));
    _loadCoveragePlans();
    _loadAvailabilityBlocks();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadAvailabilityBlocks() async {
    setState(() {
      _loadingAvailability = true;
      _availabilityCheckFailed = false;
    });
    try {
      final blocks = await VehicleService.getAvailabilityBlocks(widget.vehicle.id);
      if (!mounted) return;
      setState(() {
        _availabilityBlocks = blocks;
        _loadingAvailability = false;
        _availabilityCheckFailed = false;
      });
      _checkDateConflict();
    } catch (_) {
      // Manejo de error de red consistente con el resto de la pantalla
      // (_loadCoveragePlans/_recalculateFare): no dejamos al usuario sin
      // poder reservar nunca por un fallo transitorio, pero tampoco nos
      // saltamos la validación en silencio — se muestra una advertencia
      // explícita y se ofrece reintentar antes de permitir continuar.
      if (!mounted) return;
      setState(() {
        _loadingAvailability = false;
        _availabilityCheckFailed = true;
        _dateConflictError = null;
      });
    }
  }

  /// Bloquea el botón "Pagar y reservar" si el rango [_startDate, _endDate]
  /// elegido por el usuario:
  ///  a) se solapa directamente con un bloqueo/reserva conocido, o
  ///  b) empieza dentro del margen de mantenimiento de
  ///     [_maintenanceBufferDays] día(s) después de que termine uno de ellos.
  ///
  /// Ejemplo del margen: si un bloqueo existente termina el día 10, el
  /// próximo `startDate` válido es el día 12 en adelante — el día 11 se
  /// considera bloqueado como buffer de mantenimiento.
  ///
  /// Esta es una validación de mejor esfuerzo hecha con los bloqueos
  /// manuales visibles localmente (ver comentario en `_availabilityBlocks`);
  /// la validación final y autoritativa contra reservas de otros renters
  /// ocurre en el backend al enviar el POST.
  void _checkDateConflict() {
    AvailabilityBlock? conflicting;
    for (final b in _availabilityBlocks) {
      final blockStart = _dateOnly(b.startDate);
      final blockEnd = _dateOnly(b.endDate);
      final bufferEnd = blockEnd.add(const Duration(days: _maintenanceBufferDays));
      // Comparación inclusiva en ambos extremos, extendiendo el fin del
      // bloqueo con el margen de mantenimiento: con recogida y devolución en
      // el mismo día (rango de ancho cero), el día elegido debe seguir
      // detectándose como conflicto si cae dentro del bloqueo existente o de
      // su margen posterior, incluyendo si coincide exactamente con
      // blockStart o bufferEnd.
      final overlapsOrInBuffer = !_startDate.isAfter(bufferEnd) && !_endDate.isBefore(blockStart);
      if (overlapsOrInBuffer) {
        conflicting = b;
        break;
      }
    }

    setState(() {
      _dateConflictError = conflicting == null
          ? null
          : 'Este vehículo no está disponible en las fechas seleccionadas. '
              'Ya existe una reserva o mantenimiento del ${_fmt(conflicting.startDate)} al ${_fmt(conflicting.endDate)}.';
    });
  }

  Future<void> _pickStartDate() async {
    if (_isSubmitting) return;
    final today = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(today) ? today : _startDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Fecha de recogida',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = picked;
      // La devolución puede coincidir con la recogida (mismo día = 1 día de
      // alquiler, no 0). Solo la re-ajustamos si quedó ANTES de la nueva
      // recogida, nunca forzamos que sea un día distinto.
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
    _checkDateConflict();
    await _recalculateFare();
  }

  Future<void> _pickEndDate() async {
    if (_isSubmitting) return;
    // La devolución puede ser el mismo día que la recogida (mínimo 1 día de
    // alquiler) — no forzamos un día posterior.
    final minEnd = _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(minEnd) ? minEnd : _endDate,
      firstDate: minEnd,
      lastDate: minEnd.add(const Duration(days: 365)),
      helpText: 'Fecha de devolución',
    );
    if (picked == null || !mounted) return;
    setState(() => _endDate = picked);
    _checkDateConflict();
    await _recalculateFare();
  }

  Future<void> _loadCoveragePlans() async {
    setState(() => _loadState = _LoadState.loading);
    try {
      final plans = await PaymentsService.getCoveragePlans();
      if (!mounted) return;
      setState(() {
        _coverages = plans;
        _loadState = _LoadState.ready;
      });
      await _recalculateFare();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadState = _LoadState.error;
        _loadError = 'No se pudieron cargar los planes de cobertura.';
      });
    }
  }

  /// Copy educativo estático por plan, usado solo como respaldo cuando el
  /// backend no trae `description` (campo vacío) para el plan. Cuando el
  /// backend sí trae descripción, esa es la que se muestra (ver el `Text`
  /// que consume este método) — este texto nunca sustituye datos reales de
  /// la API (nombre/deducible/precio), solo el copy narrativo del plan.
  String _coverageFallbackDescription(String code) {
    switch (code) {
      case 'NONE':
        return 'Sin protección adicional: asumes el 100% del costo ante daños, pérdida o robo.';
      case 'BASIC':
        return 'Responsabilidad civil y daños menores. Pagas un deducible; el resto lo cubre la aseguradora.';
      case 'STANDARD':
        return 'Responsabilidad civil, colisión y robo, con un deducible reducido frente al plan Básico.';
      case 'PREMIUM':
        return 'Cobertura integral: responsabilidad civil, colisión, robo y asistencia en carretera, sin deducible.';
      default:
        return 'Protección adicional durante el alquiler, sujeta a los términos del plan.';
    }
  }

  /// Bottom sheet con la explicación general de cómo funciona la cobertura,
  /// para el ícono de información (i) junto al encabezado "Cobertura".
  void _showCoverageInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('¿Qué significa la cobertura?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'El plan de cobertura no es el seguro completo del vehículo: es una '
                  'protección adicional y opcional que se contrata junto con la reserva, '
                  'válida solo durante el período del alquiler.\n\n'
                  'Pagas un monto extra por día (según el plan) sumado al precio del '
                  'alquiler. Si ocurre un accidente, robo o daño, el plan determina cuánto '
                  'pagas tú de tu bolsillo (deducible) y cuánto cubre la aseguradora o la '
                  'plataforma.\n\n'
                  'Para el propietario, esto reduce su riesgo al prestar el vehículo, ya que '
                  'los costos de incidentes cubiertos los asume la aseguradora/plataforma en '
                  'vez de tener que reclamarte el monto completo directamente.',
                  style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('confirmBooking_coverageInfoMoreLink'),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.push('/help');
                    },
                    child: const Text('Ver más en Ayuda'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _recalculateFare() async {
    if (_coverages.isEmpty) return;
    setState(() => _calculating = true);
    try {
      final base = widget.vehicle.dailyPrice * _days;
      final fare = await PaymentsService.calculateFare(
        baseAmount: base,
        coveragePlan: _coverages[_coverageIndex].code,
      );
      if (!mounted) return;
      setState(() {
        _fare = fare;
        _calculating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calculating = false;
        _loadError = 'No se pudo calcular el precio total.';
      });
    }
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _payAndReserve() async {
    final fare = _fare;
    if (fare == null) return;

    // Bloqueo duro: si ya detectamos un conflicto de disponibilidad local
    // (solape o margen de mantenimiento), no se permite continuar. El botón
    // ya está deshabilitado en este caso, pero se revalida aquí por si el
    // estado cambiara entre el build y el tap.
    if (_dateConflictError != null) {
      await _showAvailabilityBlockedDialog(_dateConflictError!);
      return;
    }

    // Si la verificación de disponibilidad falló por red, no bloqueamos
    // silenciosamente el flujo (el backend sigue validando de forma
    // autoritativa al crear la reserva), pero sí advertimos explícitamente
    // y pedimos confirmación explícita antes de continuar.
    if (_availabilityCheckFailed) {
      final proceed = await _confirmProceedWithoutAvailabilityCheck();
      if (!proceed) return;
    }

    setState(() {
      _submitState = _SubmitState.processingPayment;
      _submitError = null;
    });

    final user = await AuthService.getCurrentUser();
    if (user == null) {
      setState(() {
        _submitState = _SubmitState.paymentFailed;
        _submitError = 'No hay sesión activa. Inicia sesión nuevamente.';
      });
      return;
    }

    // Paso 1: crear la reserva real primero — el backend exige un reservationId
    // válido y positivo en /payments/create-intent (CreateIntentRequest.reservationId
    // es @NotNull @Positive y el intent se persiste contra esa reserva), por lo que
    // el orden correcto es reserva -> intent, no al revés.
    setState(() => _submitState = _SubmitState.creatingReservation);
    late final ReservationData reservation;
    try {
      reservation = await ReservationService.createReservation(
        vehicleId: widget.vehicle.id,
        renterId: user.userId,
        startDate: _fmt(_startDate),
        endDate: _fmt(_endDate),
        totalAmount: fare.total,
        pickupLocation: widget.vehicle.location,
        returnLocation: widget.vehicle.location,
        coveragePlan: _coverages[_coverageIndex].code,
      );
    } on ReservationException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitState = _SubmitState.reservationFailed;
        _submitError = e.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitState = _SubmitState.reservationFailed;
        _submitError = 'No se pudo crear la reserva. No se realizó ningún cargo.';
      });
      return;
    }

    // Paso 2: crear el PaymentIntent real en el backend contra la reserva ya creada, y
    // confirmarlo con Stripe PaymentSheet (US58/TS16) — ya no basta con que el intent
    // exista: el pago solo se considera exitoso si Stripe confirma el cargo (modo test).
    setState(() => _submitState = _SubmitState.processingPayment);
    try {
      final intent = await PaymentsService.createPaymentIntent(
        reservationId: reservation.id,
        amountCents: (fare.total * 100).round(),
      );
      if (intent.clientSecret.isEmpty) {
        throw PaymentException('El pago no pudo iniciarse.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          merchantDisplayName: 'Rent2Go',
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      // presentPaymentSheet() only completes without throwing once Stripe has confirmed
      // the charge — a declined card or an error surfaces as a StripeException below,
      // and the user closing the sheet surfaces as a StripeException with code Canceled.
      //
      // Bugfix (US58 follow-up): force-sync the reservation's payment status with the backend
      // before navigating away. Stripe's `payment_intent.succeeded` webhook is asynchronous and
      // can still be in flight at this point — without this sync, the very next screen
      // (bookings_screen.dart) could read the reservation as still PENDING and show a stale
      // "pay now" prompt despite the charge having just succeeded.
      await PaymentsService.syncPayment(reservation.id);

      if (!mounted) return;
      setState(() => _submitState = _SubmitState.success);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reserva ${reservation.reservationCode} creada y pago confirmado'), backgroundColor: Colors.green),
      );
      context.go('/bookings');
    } on StripeException catch (e) {
      if (!mounted) return;
      final isUserCancelled = e.error.code == FailureCode.Canceled;
      if (isUserCancelled) {
        // Escenario 3 de US58: el usuario cerró la hoja de pago sin completarla —
        // la reserva sigue en su estado previo (pendiente), no se marca pagada ni fallida.
        setState(() {
          _submitState = _SubmitState.paymentAbandoned;
          _submitError = 'Pago cancelado. La reserva ${reservation.reservationCode} quedó pendiente de pago; '
              'puedes reintentarlo cuando quieras desde "Mis reservas".';
        });
      } else {
        // Escenario 2 de US58: tarjeta rechazada u otro error de Stripe — estado de
        // error visible, con el código de la reserva ya creada, permitiendo reintentar.
        setState(() {
          _submitState = _SubmitState.paymentFailed;
          _submitError = 'La reserva ${reservation.reservationCode} se creó, pero el cobro falló: '
              '${e.error.localizedMessage ?? e.error.message ?? "tarjeta rechazada"}. '
              'Revisa "Mis reservas" para reintentar el pago.';
        });
      }
    } on PaymentException catch (e) {
      // Riesgo explícito del plan: la reserva se creó pero el cobro falló —
      // se muestra un estado de error visible con el código de la reserva ya
      // creada, en vez de un SnackBar silencioso seguido de navegación a home.
      if (!mounted) return;
      setState(() {
        _submitState = _SubmitState.paymentFailed;
        _submitError = 'La reserva ${reservation.reservationCode} se creó, pero el cobro falló: ${e.message} '
            'Revisa "Mis reservas" para reintentar el pago.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitState = _SubmitState.paymentFailed;
        _submitError = 'La reserva ${reservation.reservationCode} se creó, pero no se pudo procesar el cobro. '
            'Revisa "Mis reservas" para reintentar el pago.';
      });
    }
  }

  /// Diálogo bloqueante: informa el conflicto de disponibilidad detectado y
  /// no ofrece continuar, solo cerrarlo (el usuario debe cambiar de fechas).
  Future<void> _showAvailabilityBlockedDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.event_busy, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(child: Text('Vehículo no disponible')),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Elegir otras fechas', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  /// Diálogo no bloqueante: la verificación de disponibilidad falló por red.
  /// Se advierte explícitamente y se exige confirmación explícita del
  /// usuario para continuar, en vez de saltarse la validación en silencio o
  /// dejarlo sin poder reservar por un fallo transitorio.
  Future<bool> _confirmProceedWithoutAvailabilityCheck() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('No se pudo verificar disponibilidad')),
          ],
        ),
        content: const Text(
          'No pudimos confirmar por conexión que el vehículo esté libre en estas fechas. '
          'El sistema igual validará la disponibilidad al confirmar la reserva. ¿Deseas continuar?',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continuar de todos modos', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  bool get _isSubmitting =>
      _submitState == _SubmitState.processingPayment || _submitState == _SubmitState.creatingReservation;

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(onTap: () => context.pop(), child: const Icon(Icons.arrow_back, color: Colors.black)),
        title: const Text('Confirmar reserva', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: _buildBody(vehicle),
    );
  }

  Widget _buildBody(VehicleData vehicle) {
    if (_loadState == _LoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadState == _LoadState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(_loadError ?? 'Error al cargar', style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadCoveragePlans, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: vehicle.primaryImageUrl != null && vehicle.primaryImageUrl!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: vehicle.primaryImageUrl!, width: 72, height: 56, fit: BoxFit.cover,
                          placeholder: (_, __) => Container(width: 72, height: 56, color: Colors.grey[200]),
                          errorWidget: (_, __, ___) => Container(width: 72, height: 56, color: const Color(0xFF1A1A2E), child: const Icon(Icons.directions_car, color: Colors.white54)))
                      : Container(width: 72, height: 56, color: const Color(0xFF1A1A2E), child: const Icon(Icons.directions_car, color: Colors.white54)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    Text(vehicle.categoryName, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Recogida',
            value: _fmt(_startDate),
            onTap: _isSubmitting ? null : _pickStartDate,
            testKey: const Key('confirmBooking_startDateRow'),
          ),
          _DetailRow(
            icon: Icons.access_time_outlined,
            label: 'Devolución',
            value: _fmt(_endDate),
            onTap: _isSubmitting ? null : _pickEndDate,
            testKey: const Key('confirmBooking_endDateRow'),
          ),
          _DetailRow(icon: Icons.location_on_outlined, label: 'Punto de encuentro', value: vehicle.location),
          if (_loadingAvailability) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('Verificando disponibilidad…', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ],
          if (_dateConflictError != null) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('confirmBooking_dateConflictWarning'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.event_busy, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_dateConflictError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ] else if (_availabilityCheckFailed) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('confirmBooking_availabilityCheckFailedWarning'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No se pudo verificar la disponibilidad del vehículo por un problema de conexión.',
                      style: TextStyle(color: Colors.deepOrange, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadingAvailability ? null : _loadAvailabilityBlocks,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    child: const Text('Reintentar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Cobertura', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
              const SizedBox(width: 4),
              InkWell(
                key: const Key('confirmBooking_coverageInfoButton'),
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showCoverageInfoSheet(context),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.info_outline, size: 18, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ..._coverages.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: _isSubmitting ? null : () {
                setState(() => _coverageIndex = e.key);
                _recalculateFare();
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _coverageIndex == e.key ? kCyan : Colors.grey.shade200, width: _coverageIndex == e.key ? 2 : 1)),
                child: Row(
                  children: [
                    Radio<int>(value: e.key, groupValue: _coverageIndex, onChanged: _isSubmitting ? null : (v) {
                      setState(() => _coverageIndex = v!);
                      _recalculateFare();
                    }, activeColor: kCyan),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                          Text(
                            e.value.description.isNotEmpty
                                ? e.value.description
                                : _coverageFallbackDescription(e.value.code),
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(e.value.dailyRateUsd == 0 ? r'S/ 0' : 'S/ ${e.value.dailyRateUsd.toStringAsFixed(2)}/día', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                  ],
                ),
              ),
            ),
          )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: _calculating || _fare == null
                ? const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator()))
                : Column(
                    children: [
                      _PriceRow(label: '${vehicle.dailyPrice.toStringAsFixed(0)} × $_days días', value: 'S/ ${_fare!.subtotal.toStringAsFixed(2)}'),
                      _PriceRow(label: 'Cobertura ${_coverages[_coverageIndex].name}', value: 'S/ ${_fare!.coverageFee.toStringAsFixed(2)}'),
                      _PriceRow(label: 'Tasa de servicio', value: 'S/ ${_fare!.serviceFee.toStringAsFixed(2)}'),
                      if (_fare!.discount > 0) _PriceRow(label: 'Descuento', value: '-S/ ${_fare!.discount.toStringAsFixed(2)}'),
                      if (_fare!.taxes > 0) _PriceRow(label: 'Impuestos', value: 'S/ ${_fare!.taxes.toStringAsFixed(2)}'),
                      const Divider(height: 20),
                      _PriceRow(label: 'Total', value: 'S/ ${_fare!.total.toStringAsFixed(2)}', bold: true),
                    ],
                  ),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_submitError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              key: const Key('confirmBooking_payButton'),
              // Bloqueo duro: con un conflicto de disponibilidad detectado
              // localmente (solape o margen de mantenimiento) el botón queda
              // deshabilitado y no dispara el flujo de pago/reserva.
              onPressed: (_isSubmitting || _fare == null || _dateConflictError != null) ? null : _payAndReserve,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white70,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(
                      _dateConflictError != null
                          ? 'Vehículo no disponible'
                          : _submitState == _SubmitState.reservationFailed
                              ? 'Reintentar reserva'
                              : (_submitState == _SubmitState.paymentFailed ||
                                      _submitState == _SubmitState.paymentAbandoned)
                                  ? 'Reintentar pago'
                                  : 'Pagar y reservar',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  final Key? testKey;
  const _DetailRow({required this.icon, required this.label, required this.value, this.onTap, this.testKey});
  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: Colors.black54)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black)),
            ],
          ),
        ),
        if (onTap != null) const Icon(Icons.edit_calendar_outlined, size: 18, color: Colors.black45),
      ],
    );
    return Padding(
      key: testKey,
      padding: const EdgeInsets.only(bottom: 12),
      child: onTap == null
          ? row
          : InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: row),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _PriceRow({required this.label, required this.value, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: bold ? Colors.black : Colors.grey[600], fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 15 : 13)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 15 : 13, color: Colors.black)),
      ],
    ),
  );
}

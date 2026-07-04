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

  // Bloqueos de disponibilidad del vehículo (reservas/bloqueos existentes),
  // usados solo para advertir de conflictos al elegir fechas en esta pantalla
  // — no reemplaza la validación autoritativa del backend en POST /reservations.
  List<AvailabilityBlock> _availabilityBlocks = [];
  bool _loadingAvailability = false;
  String? _dateConflictWarning;

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
    setState(() => _loadingAvailability = true);
    try {
      final blocks = await VehicleService.getAvailabilityBlocks(widget.vehicle.id);
      if (!mounted) return;
      setState(() {
        _availabilityBlocks = blocks;
        _loadingAvailability = false;
      });
      _checkDateConflict();
    } catch (_) {
      // Nice-to-have: si no se puede cargar la disponibilidad, no bloqueamos
      // el flujo de reserva — el backend sigue siendo la validación autoritativa.
      if (!mounted) return;
      setState(() => _loadingAvailability = false);
    }
  }

  /// Advierte (no bloquea) si el rango elegido se solapa con un bloqueo o
  /// reserva existente — la validación real ocurre en el backend al crear
  /// la reserva (POST /api/v1/reservations), esto es solo feedback temprano.
  void _checkDateConflict() {
    final conflict = _availabilityBlocks.any((b) {
      final blockStart = _dateOnly(b.startDate);
      final blockEnd = _dateOnly(b.endDate);
      // Comparación inclusiva en ambos extremos: con recogida y devolución en
      // el mismo día (rango de ancho cero), el día elegido debe seguir
      // detectándose como conflicto si cae dentro de un bloqueo existente,
      // incluyendo si coincide exactamente con blockStart o blockEnd.
      return !_startDate.isAfter(blockEnd) && !_endDate.isBefore(blockStart);
    });
    setState(() {
      _dateConflictWarning = conflict
          ? 'Las fechas elegidas se solapan con una reserva o bloqueo existente de este vehículo. Puedes continuar, pero el backend podría rechazar la reserva.'
          : null;
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
          if (_dateConflictWarning != null) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('confirmBooking_dateConflictWarning'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_dateConflictWarning!, style: const TextStyle(color: Colors.deepOrange, fontSize: 12))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Cobertura', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
          const SizedBox(height: 12),
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
                          Text(e.value.description, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(e.value.dailyRateUsd == 0 ? r'$0' : '\$${e.value.dailyRateUsd.toStringAsFixed(2)}/día', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
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
                      _PriceRow(label: '${vehicle.dailyPrice.toStringAsFixed(0)} × $_days días', value: '\$${_fare!.subtotal.toStringAsFixed(2)}'),
                      _PriceRow(label: 'Cobertura ${_coverages[_coverageIndex].name}', value: '\$${_fare!.coverageFee.toStringAsFixed(2)}'),
                      _PriceRow(label: 'Tasa de servicio', value: '\$${_fare!.serviceFee.toStringAsFixed(2)}'),
                      if (_fare!.discount > 0) _PriceRow(label: 'Descuento', value: '-\$${_fare!.discount.toStringAsFixed(2)}'),
                      if (_fare!.taxes > 0) _PriceRow(label: 'Impuestos', value: '\$${_fare!.taxes.toStringAsFixed(2)}'),
                      const Divider(height: 20),
                      _PriceRow(label: 'Total', value: '\$${_fare!.total.toStringAsFixed(2)}', bold: true),
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
              onPressed: (_isSubmitting || _fare == null) ? null : _payAndReserve,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _isSubmitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(
                      _submitState == _SubmitState.reservationFailed
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

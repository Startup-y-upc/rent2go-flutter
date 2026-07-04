import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import '../services/payments_service.dart';
import '../services/reservation_service.dart';
import '../widgets/common_widgets.dart';

/// Vista de detalle de una reserva real (ReservationResource), abierta desde
/// "Abrir" en bookings_screen.dart (renter) u owner_dashboard_screen.dart (owner).
///
/// StatefulWidget (antes StatelessWidget) porque, además de mostrar datos,
/// ahora permite reintentar el pago de una reserva PENDING cuyo cobro falló o
/// se abandonó en confirm_booking_screen.dart — el estado local de la reserva
/// se actualiza tras un pago exitoso sin depender de una navegación completa.
class ReservationDetailScreen extends StatefulWidget {
  final ReservationData reservation;
  const ReservationDetailScreen({super.key, required this.reservation});

  @override
  State<ReservationDetailScreen> createState() => _ReservationDetailScreenState();
}

enum _PaymentRetryState { idle, processing, success, failed, abandoned }

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  late ReservationData _reservation;
  _PaymentRetryState _retryState = _PaymentRetryState.idle;
  String? _retryError;

  @override
  void initState() {
    super.initState();
    _reservation = widget.reservation;
  }

  bool get _isProcessing => _retryState == _PaymentRetryState.processing;

  /// PENDING es el único estado en el que el backend crea la reserva sin que el
  /// pago se haya confirmado (ver Reservation.create -> BookingStatus.PENDING()
  /// y el webhook de Stripe, que es lo único que transiciona PENDING -> CONFIRMED
  /// vía markPaid()). Por eso el botón de reintento de pago solo se ofrece aquí.
  bool get _needsPayment => _reservation.status.toUpperCase() == 'PENDING';

  /// Reutiliza la misma secuencia de confirm_booking_screen.dart (_payAndReserve):
  /// crear PaymentIntent contra la reserva YA EXISTENTE (no se crea una reserva
  /// nueva) y presentar Stripe PaymentSheet, manejando los mismos 3 desenlaces
  /// de US58: éxito, rechazo/error y hoja cerrada sin completar.
  Future<void> _retryPayment() async {
    setState(() {
      _retryState = _PaymentRetryState.processing;
      _retryError = null;
    });

    try {
      final intent = await PaymentsService.createPaymentIntent(
        reservationId: _reservation.id,
        amountCents: (_reservation.totalAmount * 100).round(),
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

      // Igual que en confirm_booking_screen.dart: llegar aquí sin excepción
      // significa que Stripe confirmó el cargo. Refrescamos la reserva desde
      // el backend para reflejar el nuevo estado (CONFIRMED tras el webhook).
      if (!mounted) return;
      final refreshed = await ReservationService.getReservation(_reservation.id);
      if (!mounted) return;
      setState(() {
        _retryState = _PaymentRetryState.success;
        if (refreshed != null) _reservation = refreshed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pago confirmado para la reserva ${_reservation.reservationCode}'), backgroundColor: Colors.green),
      );
    } on StripeException catch (e) {
      if (!mounted) return;
      final isUserCancelled = e.error.code == FailureCode.Canceled;
      if (isUserCancelled) {
        // Hoja cerrada sin completar: la reserva sigue pendiente, sin cambio de estado.
        setState(() {
          _retryState = _PaymentRetryState.abandoned;
          _retryError = 'Pago cancelado. La reserva ${_reservation.reservationCode} sigue pendiente de pago.';
        });
      } else {
        setState(() {
          _retryState = _PaymentRetryState.failed;
          _retryError = 'El cobro falló: ${e.error.localizedMessage ?? e.error.message ?? "tarjeta rechazada"}. Puedes reintentarlo.';
        });
      }
    } on PaymentException catch (e) {
      if (!mounted) return;
      setState(() {
        _retryState = _PaymentRetryState.failed;
        _retryError = '${e.message} Puedes reintentarlo.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _retryState = _PaymentRetryState.failed;
        _retryError = 'No se pudo procesar el cobro. Puedes reintentarlo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(onTap: () => context.pop(), child: const Icon(Icons.arrow_back, color: Colors.black)),
        title: const Text('Detalle de reserva', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reserva ${_reservation.reservationCode}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: kCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(_reservation.status, style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 20),
            _row('Recogida', _reservation.startDate),
            _row('Devolución', _reservation.endDate),
            _row('Punto de recogida', _reservation.pickupLocation),
            _row('Punto de devolución', _reservation.returnLocation),
            _row('Cobertura', _reservation.coveragePlan),
            _row('Total', '\$${_reservation.totalAmount.toStringAsFixed(2)}'),
            if (_reservation.damageReport != null && _reservation.damageReport!.isNotEmpty)
              _row('Reporte de daños', _reservation.damageReport!),
            if (_retryError != null) ...[
              const SizedBox(height: 8),
              Container(
                key: const Key('reservation_detail_payment_error'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_retryError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  /// US41/US43: entry points de reporte y calificación. "Calificar" solo se
  /// muestra sobre una reserva COMPLETED (no tiene sentido antes).
  /// Bugfix (reportado por Renter): agrega "Reintentar pago", visible solo
  /// cuando la reserva está PENDING — antes esta pantalla era de solo lectura
  /// y el mensaje de error de confirm_booking_screen.dart pedía "revisar tu
  /// reserva" sin ofrecer ninguna acción real.
  Widget _buildActionButtons(BuildContext context) {
    final isCompleted = _reservation.status.toUpperCase() == 'COMPLETED';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_needsPayment) ...[
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              key: const Key('reservation_detail_retry_payment_button'),
              onPressed: _isProcessing ? null : _retryPayment,
              icon: _isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Icon(Icons.payment, size: 18),
              label: Text(_isProcessing ? 'Procesando pago...' : 'Reintentar pago'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          key: const Key('reservation_detail_report_issue_button'),
          onPressed: () => context.push('/report-issue', extra: _reservation),
          icon: const Icon(Icons.report_problem_outlined, size: 18),
          label: const Text('Reportar un problema'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (isCompleted) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            key: const Key('reservation_detail_rate_button'),
            onPressed: () => context.push('/rate-reservation', extra: _reservation),
            icon: const Icon(Icons.star_outline, size: 18),
            label: const Text('Calificar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

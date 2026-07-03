import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/reservation_service.dart';
import '../widgets/common_widgets.dart';

/// Vista de detalle de una reserva real (ReservationResource), abierta desde
/// "Abrir" en bookings_screen.dart (renter) u owner_dashboard_screen.dart (owner).
class ReservationDetailScreen extends StatelessWidget {
  final ReservationData reservation;
  const ReservationDetailScreen({super.key, required this.reservation});

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
            Text('Reserva ${reservation.reservationCode}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: kCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(reservation.status, style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 20),
            _row('Recogida', reservation.startDate),
            _row('Devolución', reservation.endDate),
            _row('Punto de recogida', reservation.pickupLocation),
            _row('Punto de devolución', reservation.returnLocation),
            _row('Cobertura', reservation.coveragePlan),
            _row('Total', '\$${reservation.totalAmount.toStringAsFixed(2)}'),
            if (reservation.damageReport != null && reservation.damageReport!.isNotEmpty)
              _row('Reporte de daños', reservation.damageReport!),
            const SizedBox(height: 12),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  /// US41/US43: entry points de reporte y calificación. "Calificar" solo se
  /// muestra sobre una reserva COMPLETED (no tiene sentido antes).
  Widget _buildActionButtons(BuildContext context) {
    final isCompleted = reservation.status.toUpperCase() == 'COMPLETED';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('reservation_detail_report_issue_button'),
          onPressed: () => context.push('/report-issue', extra: reservation),
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
            onPressed: () => context.push('/rate-reservation', extra: reservation),
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

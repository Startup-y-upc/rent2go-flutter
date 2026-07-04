import 'package:flutter/material.dart';
import 'owner_invoices_screen.dart';
import 'withdrawal_history_screen.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/payments_service.dart';
import '../services/vehicle_service.dart';
import '../models/vehicle_models.dart';

/// Fila "Por vehículo" ya resuelta: combina los datos del vehículo con sus
/// métricas de desempeño (US24), evitando volver a tejer ambas fuentes en el widget.
class _VehicleEarningsRow {
  final VehicleData vehicle;
  final VehiclePerformanceReport performance;

  _VehicleEarningsRow({required this.vehicle, required this.performance});
}

class OwnerEarningsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const OwnerEarningsScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<OwnerEarningsScreen> createState() => _OwnerEarningsScreenState();
}

class _OwnerEarningsScreenState extends State<OwnerEarningsScreen> {
  bool _loading = true;
  bool _loadingVehicles = true;
  bool _loadingMovements = true;
  String? _movementsError;
  OwnerEarningsReport _report = OwnerEarningsReport.empty();
  List<_VehicleEarningsRow> _vehicleRows = [];
  List<EarningsMovement> _movements = [];
  int? _ownerId;

  @override
  void initState() {
    super.initState();
    _load();
    _loadVehiclePerformance();
    _loadMovements();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await AuthService.getCurrentUser();
    _ownerId = user?.userId;
    final report = user != null
        ? await PaymentsService.getOwnerEarnings(ownerId: user.userId)
        : OwnerEarningsReport.empty();
    if (mounted) {
      setState(() {
        _report = report;
        _loading = false;
      });
    }
  }

  /// US47: reemplaza el placeholder "Desglose mensual: próximamente" con
  /// datos reales de GET /payments/owners/{id}/earnings/movements.
  Future<void> _loadMovements() async {
    setState(() {
      _loadingMovements = true;
      _movementsError = null;
    });
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingMovements = false;
          _movementsError = 'No hay sesión activa.';
        });
      }
      return;
    }
    try {
      final movements = await PaymentsService.getEarningsMovements(ownerId: user.userId);
      if (mounted) {
        setState(() {
          _movements = movements;
          _loadingMovements = false;
        });
      }
    } on PaymentException catch (e) {
      if (mounted) {
        setState(() {
          _loadingMovements = false;
          _movementsError = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingMovements = false;
          _movementsError = 'No se pudo cargar el desglose de movimientos.';
        });
      }
    }
  }

  /// US48/US49: abre el flujo de confirmación de retiro (monto vs. saldo
  /// disponible) y llama a POST /payments/owners/{id}/withdrawals.
  Future<void> _openWithdrawDialog() async {
    final ownerId = _ownerId;
    if (ownerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay sesión activa.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool submitting = false;
    String? dialogError;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Solicitar retiro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saldo disponible: S/ ${_report.availablePayoutAmount.toStringAsFixed(2)} ${_report.currency}'),
              const SizedBox(height: 12),
              TextField(
                key: const Key('withdrawal_amount_field'),
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto a retirar (PEN)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('withdrawal_note_field'),
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Nota de destino (opcional)', border: OutlineInputBorder()),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(dialogError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const Key('withdrawal_confirm_button'),
              onPressed: submitting
                  ? null
                  : () async {
                      final amount = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.'));
                      if (amount == null || amount <= 0) {
                        setDialogState(() => dialogError = 'Ingresa un monto válido.');
                        return;
                      }
                      final amountCents = (amount * 100).round();
                      if (amountCents > _report.availablePayoutCents) {
                        setDialogState(() => dialogError = 'El monto supera tu saldo disponible.');
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        dialogError = null;
                      });
                      try {
                        await PaymentsService.requestWithdrawal(
                          ownerId: ownerId,
                          amountCents: amountCents,
                          payoutDestinationNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                        );
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Retiro solicitado con éxito.'), backgroundColor: Colors.green),
                          );
                          await _load();
                        }
                      } on WithdrawalException catch (e) {
                        setDialogState(() {
                          submitting = false;
                          dialogError = e.message;
                        });
                      } catch (_) {
                        setDialogState(() {
                          submitting = false;
                          dialogError = 'No se pudo conectar al servidor.';
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  /// US24: carga los vehículos del propietario y, para cada uno, sus métricas
  /// de desempeño (GET /payments/vehicles/{id}/performance), reemplazando el
  /// desglose "Por vehículo" que antes era 100% mock.
  Future<void> _loadVehiclePerformance() async {
    setState(() => _loadingVehicles = true);
    try {
      final vehicles = await VehicleService.getMyVehicles();
      final rows = await Future.wait(vehicles.map((v) async {
        final performance = await PaymentsService.getVehiclePerformance(vehicleId: v.id);
        return _VehicleEarningsRow(vehicle: v, performance: performance);
      }));
      if (mounted) {
        setState(() {
          _vehicleRows = rows;
          _loadingVehicles = false;
        });
      }
    } catch (_) {
      // Sin vehículos o error de red: se muestra la sección vacía en vez de
      // romper la pantalla de ganancias (mismo criterio de tolerancia a fallos que US24).
      if (mounted) {
        setState(() {
          _vehicleRows = [];
          _loadingVehicles = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([_load(), _loadVehiclePerformance(), _loadMovements()]),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _loading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: CircularProgressIndicator(color: kCyan)),
                          )
                        : _buildChartSection(),
                    const SizedBox(height: 24),
                    const Text(
                      'Por vehículo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildVehiclesEarnings(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B2F),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: widget.onBack,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ganancias',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Saldo disponible',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Row(
            key: const Key('owner_earnings_balance'),
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _loading ? '—' : _report.totalAmount.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _loading ? '' : _report.currency,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // F6 (Fase 4 diferida — sin endpoint de desglose mensual real todavía):
          // se retira la fecha específica fabricada ("vie 16 May") en vez de
          // presentarla como un dato real. Ver docs/planning/03-backlog-ado.md
          // para el estado formal de este finding.
          const Text(
            'Próximo ingreso: próximamente',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildActionButton('Retirar', true, _openWithdrawDialog, key: 'owner_earnings_withdraw_button'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton('Facturas', false, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OwnerInvoicesScreen()),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            key: const Key('owner_earnings_withdrawal_history_link'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WithdrawalHistoryScreen()),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Ver historial de retiros', style: TextStyle(color: kCyan, fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: kCyan, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, bool isPrimary, VoidCallback onTap, {String? key}) {
    return GestureDetector(
      key: key != null ? Key(key) : null,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isPrimary ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Últimos 7 meses',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Text(
            '${_report.totalAmount.toStringAsFixed(2)} ${_report.currency} · ${_report.paymentsCount} pagos',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Desglose de movimientos',
            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          // US47: reemplaza el placeholder "Desglose mensual: próximamente"
          // con datos reales de GET /payments/owners/{id}/earnings/movements.
          _buildMovementsSection(),
        ],
      ),
    );
  }

  Widget _buildMovementsSection() {
    if (_loadingMovements) {
      return const Padding(
        key: Key('owner_earnings_movements_loading'),
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: kCyan)),
      );
    }
    if (_movementsError != null) {
      return Container(
        key: const Key('owner_earnings_movements_error'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_movementsError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
            TextButton(onPressed: _loadMovements, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_movements.isEmpty) {
      return const Padding(
        key: Key('owner_earnings_movements_empty'),
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Aún no tienes movimientos registrados.', style: TextStyle(color: Colors.grey)),
      );
    }
    return Column(
      key: const Key('owner_earnings_movements_list'),
      children: [
        for (int i = 0; i < _movements.length; i++) ...[
          if (i > 0) const Divider(height: 16),
          _buildMovementRow(_movements[i]),
        ],
      ],
    );
  }

  Widget _buildMovementRow(EarningsMovement movement) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movement.reservationId != null ? 'Reserva #${movement.reservationId}' : 'Movimiento',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black),
              ),
              if (movement.createdAt != null)
                Text(movement.createdAt!, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
        ),
        Text(
          movement.status ?? '',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        ),
        const SizedBox(width: 12),
        Text(
          'S/ ${movement.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildVehiclesEarnings() {
    if (_loadingVehicles) {
      return const Padding(
        key: Key('owner_earnings_vehicles_loading'),
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: kCyan)),
      );
    }

    if (_vehicleRows.isEmpty) {
      return Container(
        key: const Key('owner_earnings_vehicles_empty'),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          'Aún no tienes vehículos publicados con historial.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      key: const Key('owner_earnings_vehicles_list'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _vehicleRows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _buildVehicleRow(_vehicleRows[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleRow(_VehicleEarningsRow row) {
    final vehicle = row.vehicle;
    final performance = row.performance;
    final trips = performance.reservationCount == 1
        ? '1 viaje · ${performance.occupancyPercentage.toStringAsFixed(0)}% ocupación'
        : '${performance.reservationCount} viajes · ${performance.occupancyPercentage.toStringAsFixed(0)}% ocupación';

    return Padding(
      key: Key('owner_earnings_vehicle_row_${vehicle.id}'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: vehicle.primaryImageUrl != null
                ? Image.network(vehicle.primaryImageUrl!, width: 64, height: 48, fit: BoxFit.cover)
                : Container(
                    width: 64,
                    height: 48,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.directions_car, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                Text(trips, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${performance.totalRevenue.toStringAsFixed(2)} ${performance.currency}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

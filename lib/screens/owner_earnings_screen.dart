import 'package:flutter/material.dart';
import 'owner_invoices_screen.dart';
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
  OwnerEarningsReport _report = OwnerEarningsReport.empty();
  List<_VehicleEarningsRow> _vehicleRows = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadVehiclePerformance();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await AuthService.getCurrentUser();
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
        onRefresh: () => Future.wait([_load(), _loadVehiclePerformance()]),
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
          const Text(
            'Próximo ingreso · vie 16 May',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildActionButton('Retirar', true, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Procesando retiro a su cuenta bancaria...')),
                  );
                }),
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
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, bool isPrimary, VoidCallback onTap) {
    return GestureDetector(
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
          const SizedBox(height: 20),
          // Distribución mensual — pendiente de endpoint de desglose mensual;
          // se mantiene el diseño visual mientras el total mostrado arriba es real (US24).
          Container(
            height: 150,
            width: double.infinity,
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(40, 'Nov'),
                _buildBar(60, 'Dic'),
                _buildBar(45, 'Ene'),
                _buildBar(80, 'Feb'),
                _buildBar(90, 'Mar'),
                _buildBar(70, 'Abr'),
                _buildBar(100, 'May', isActive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double heightFactor, String label, {bool isActive = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: heightFactor,
          decoration: BoxDecoration(
            color: isActive ? kCyan : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.black : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
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

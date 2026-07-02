import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/vehicle_models.dart';
import '../widgets/common_widgets.dart';

class ConfirmBookingScreen extends StatefulWidget {
  final VehicleData vehicle;
  const ConfirmBookingScreen({super.key, required this.vehicle});
  @override
  State<ConfirmBookingScreen> createState() => _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends State<ConfirmBookingScreen> {
  int _coverage = 1;

  final _coverages = [
    _Coverage(name: 'Esencial', desc: 'Franquicia 1.500 €', price: 0),
    _Coverage(name: 'Plus', desc: 'Sin franquicia · Recomendada', price: 8, popular: true),
    _Coverage(name: 'Premium', desc: 'Sin franquicia + asistencia ilimitada', price: 14),
  ];

  double get _total {
    final base = widget.vehicle.dailyPrice * 2;
    final coverageExtra = _coverages[_coverage].price * 2;
    const serviceFee = 9.40;
    return base + coverageExtra + serviceFee;
  }

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
      body: SingleChildScrollView(
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
            _DetailRow(icon: Icons.calendar_today_outlined, label: 'Recogida', value: 'Mar 12 May · 10:00'),
            _DetailRow(icon: Icons.access_time_outlined, label: 'Devolución', value: 'Jue 14 May · 18:00'),
            _DetailRow(icon: Icons.location_on_outlined, label: 'Punto de encuentro', value: vehicle.location),
            const SizedBox(height: 20),
            const Text('Cobertura', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
            const SizedBox(height: 12),
            ..._coverages.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _coverage = e.key),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _coverage == e.key ? kCyan : Colors.grey.shade200, width: _coverage == e.key ? 2 : 1)),
                  child: Row(
                    children: [
                      Radio<int>(value: e.key, groupValue: _coverage, onChanged: (v) => setState(() => _coverage = v!), activeColor: kCyan),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(e.value.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                              if (e.value.popular) ...[
                                const SizedBox(width: 8),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: kCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                    child: const Text('Popular', style: TextStyle(color: kCyan, fontSize: 11, fontWeight: FontWeight.bold))),
                              ],
                            ]),
                            Text(e.value.desc, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(e.value.price == 0 ? '0 €' : '${e.value.price} €/día', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                    ],
                  ),
                ),
              ),
            )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  _PriceRow(label: '${vehicle.dailyPrice.toInt()}€ × 2 días', value: '${(vehicle.dailyPrice * 2).toStringAsFixed(2)} €'),
                  _PriceRow(label: 'Cobertura ${_coverages[_coverage].name}', value: _coverages[_coverage].price == 0 ? '0 €' : '${(_coverages[_coverage].price * 2).toStringAsFixed(2)} €'),
                  const _PriceRow(label: 'Tasa de servicio', value: '9,40 €'),
                  const Divider(height: 20),
                  _PriceRow(label: 'Total', value: '${_total.toStringAsFixed(2)} €', bold: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Reserva confirmada! 🎉'), backgroundColor: Colors.green));
                  context.go('/home');
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Pagar y reservar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Coverage {
  final String name, desc;
  final double price;
  final bool popular;
  const _Coverage({required this.name, required this.desc, required this.price, this.popular = false});
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: Colors.black54)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black)),
          ],
        ),
      ],
    ),
  );
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
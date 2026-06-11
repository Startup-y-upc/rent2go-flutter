import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/common_widgets.dart';
import 'explore_screen.dart';

class CarDetailScreen extends StatelessWidget {
  final CarData car;
  const CarDetailScreen({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: car.imageUrl,
                      height: 280,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 280,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 280,
                        color: const Color(0xFF1A1A2E),
                        child: const Center(
                          child: Icon(Icons.directions_car,
                              color: Colors.white30, size: 80)),
                      ),
                    ),
                    Positioned(
                      top: 48, left: 16,
                      child: _CircleBtn(icon: Icons.arrow_back, onTap: () => context.pop()),
                    ),
                    Positioned(
                      top: 48, right: 56,
                      child: _CircleBtn(icon: Icons.share_outlined, onTap: () {}),
                    ),
                    Positioned(
                      top: 48, right: 16,
                      child: _CircleBtn(icon: Icons.favorite_border, onTap: () {}),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _Badge(
                          label: car.fuel,
                          color: car.fuel == 'Eléctrico'
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF8E1),
                          textColor: car.fuel == 'Eléctrico'
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFF57F17),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(car.rating.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 4),
                        Text('· ${car.trips} viajes',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      ]),
                      const SizedBox(height: 10),
                      Text(car.name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(height: 4),
                      Text('${car.type} · ${car.year}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(car.address,
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ]),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _SpecItem(
                              icon: car.fuel == 'Eléctrico' ? Icons.bolt : Icons.local_gas_station_outlined,
                              label: car.range == '–' ? car.fuel : car.range,
                              sublabel: car.fuel == 'Eléctrico' ? 'Autonomía' : 'Combustible',
                            ),
                            _Divider(),
                            _SpecItem(icon: Icons.people_outline, label: '${car.seats}', sublabel: 'Plazas'),
                            _Divider(),
                            _SpecItem(
                              icon: Icons.settings_outlined,
                              label: car.type.contains('Auto') ? 'Auto' : 'Manual',
                              sublabel: 'Cambio',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.teal.shade100,
                              child: Text(
                                car.owner.substring(0, 2).toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(car.owner,
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                                    const SizedBox(width: 8),
                                    Text('Verificado',
                                        style: TextStyle(color: Colors.teal[400], fontSize: 12)),
                                  ]),
                                  Text('Anfitrión · Responde en ~1h',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Mensaje', style: TextStyle(fontSize: 12, color: Colors.black)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _Badge(label: '✓ DNI verificado',
                            color: const Color(0xFFE3F2FD), textColor: const Color(0xFF1565C0)),
                        _Badge(label: '✓ Carnet validado',
                            color: const Color(0xFFE3F2FD), textColor: const Color(0xFF1565C0)),
                        _Badge(label: '✓ Teléfono',
                            color: const Color(0xFFE3F2FD), textColor: const Color(0xFF1565C0)),
                      ]),
                      const SizedBox(height: 20),
                      const Text('SOBRE EL COCHE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                              color: Colors.grey, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(car.description,
                          style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5)),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${car.price.toInt()}€/día',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                      Text('2 días · Total ${(car.price * 2).toInt()}€',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push('/confirm-booking', extra: car),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Reservar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Icon(icon, size: 18, color: Colors.black87),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color, textColor;
  const _Badge({required this.label, required this.color, required this.textColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500)),
  );
}

class _SpecItem extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  const _SpecItem({required this.icon, required this.label, required this.sublabel});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: Colors.black87, size: 22),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
      Text(sublabel, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
    ],
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: Colors.grey.shade200);
}
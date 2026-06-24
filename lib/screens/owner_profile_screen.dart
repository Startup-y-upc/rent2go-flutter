import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';
import '../services/car_service.dart';
import 'explore_screen.dart';

class OwnerProfileScreen extends StatelessWidget {
  final VoidCallback onNavigateToEarnings;

  const OwnerProfileScreen({
    super.key,
    required this.onNavigateToEarnings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: ValueListenableBuilder<List<CarData>>(
        valueListenable: CarService().carsNotifier,
        builder: (context, cars, _) {
          final myCars = cars.where((c) => c.owner == 'Diego Sánchez').toList();
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context, myCars.length.toString()),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVerificationSection(),
                      const SizedBox(height: 24),
                      const Text(
                        'Mi negocio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildBusinessSection(myCars),
                      const SizedBox(height: 24),
                      _buildEarningsButton(),
                      const SizedBox(height: 24),
                      _buildOptionRow(Icons.swap_horiz, 'Cambiar a modo Arrendatario', () => context.go('/home')),
                      _buildOptionRow(Icons.logout, 'Cerrar sesión', () async {
                        context.go('/login');
                      }, color: Colors.red),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String vehicleCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B2F),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Diego Sánchez',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Anfitrión desde 2023',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Abriendo ajustes de anfitrión...')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(vehicleCount, 'Vehículos'),
                _buildStatItem('64', 'Viajes'),
                _buildStatItem('4.49', 'Rating'),
                _buildStatItem('100%', 'Respuesta'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessSection(List<CarData> myCars) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: myCars.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No hay vehículos registrados', style: TextStyle(color: Colors.grey)),
                )
              ]
            : myCars.map((car) => Column(
                children: [
                  _buildBusinessItem(car.name, 'Publicado', car.imageUrl),
                  if (car != myCars.last) const Divider(height: 1),
                ],
              )).toList(),
      ),
    );
  }

  Widget _buildBusinessItem(String title, String subtitle, String imageUrl) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(imageUrl, width: 48, height: 36, fit: BoxFit.cover),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {},
    );
  }

  Widget _buildEarningsButton() {
    return GestureDetector(
      onTap: onNavigateToEarnings,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text(
              'Ganancias',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

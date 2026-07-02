import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/common_widgets.dart';
import '../services/car_service.dart';
import 'add_car_screen.dart';
import 'explore_screen.dart';

class OwnerVehiclesScreen extends StatefulWidget {
  const OwnerVehiclesScreen({super.key});

  @override
  State<OwnerVehiclesScreen> createState() => _OwnerVehiclesScreenState();
}

class _OwnerVehiclesScreenState extends State<OwnerVehiclesScreen> {
  String _selectedFilter = 'Todos';
  final List<String> _filters = ['Todos', 'Activos', 'Borradores', 'Revisión'];

  void _addVehicle() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCarScreen()),
    );
  }

  Widget _buildAddStep(int step, String title, String desc, bool active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: active ? kCyan : Colors.grey[100],
            child: Text(step.toString(), style: TextStyle(color: active ? Colors.black : Colors.grey, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              Text(desc, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          const Spacer(),
          Icon(Icons.chevron_right, color: Colors.grey[300]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mis vehículos',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _addVehicle,
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<CarData>>(
        valueListenable: CarService().carsNotifier,
        builder: (context, allCars, _) {
          final myCars = allCars.where((c) => c.owner == 'Diego Sánchez').toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${myCars.length} publicados · ${myCars.where((c) => c.trips > 0).length} en alquiler ahora',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              _buildFilters(),
              const SizedBox(height: 16),
              Expanded(
                child: myCars.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text('No tienes vehículos publicados', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: myCars.length,
                        itemBuilder: (context, i) {
                          final car = myCars[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildVehicleCard(
                              name: car.name,
                              km: '0 KM', // Mock
                              rating: car.rating,
                              occupancy: 0, // Mock
                              bookings: 0, // Mock
                              monthlyEarnings: 0, // Mock
                              status: 'Disponible',
                              statusColor: Colors.green,
                              imageUrl: car.imageUrl,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final active = _filters[i] == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = _filters[i]),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: active ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? Colors.black : Colors.grey.shade300),
              ),
              child: Text(
                _filters[i],
                style: TextStyle(
                  color: active ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVehicleCard({
    required String name,
    required String km,
    required double rating,
    required int occupancy,
    required int bookings,
    required double monthlyEarnings,
    required String status,
    required Color statusColor,
    required String imageUrl,
  }) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Abriendo detalles de $name...'), duration: const Duration(seconds: 1)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            km,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniStat('${occupancy}%', 'Ocupación'),
                        _buildDivider(),
                        _buildMiniStat(bookings.toString(), 'Reservas'),
                        _buildDivider(),
                        _buildMiniStat('${monthlyEarnings.toInt()} €', 'Mes'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Calendario - 30 días',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      Text(
                        '${occupancy}% ocupado',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: occupancy / 100,
                    backgroundColor: Colors.grey.shade200,
                    color: kCyan,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.grey.shade200,
    );
  }
}

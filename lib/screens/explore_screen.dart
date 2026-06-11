import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/common_widgets.dart';

class CarData {
  final String id, name, type, owner, fuel, range, imageUrl, address, description;
  final double rating, price;
  final int trips, seats, year;
  final LatLng location;

  const CarData({
    required this.id,
    required this.name,
    required this.type,
    required this.owner,
    required this.price,
    required this.rating,
    required this.trips,
    required this.fuel,
    required this.seats,
    required this.range,
    required this.year,
    required this.imageUrl,
    required this.location,
    required this.address,
    required this.description,
  });
}

final List<CarData> demoCars = [
  CarData(
    id: '1',
    name: 'Tesla Model 3',
    type: 'Eléctrico · Auto',
    owner: 'Lucía M.',
    price: 49,
    rating: 4.96,
    trips: 142,
    fuel: 'Eléctrico',
    seats: 5,
    range: '498 km',
    year: 2024,
    imageUrl: 'https://images.unsplash.com/photo-1560958089-b8a1929cea89?w=600&q=80',
    location: const LatLng(40.4168, -3.7038),
    address: 'Calle Gran Vía 45, Madrid',
    description: 'Coche impecable, ideal para escapadas. Cargador Type 2 incluido y acceso a la red Supercharger. Asientos calefactables, piloto automático y techo panorámico.',
  ),
  CarData(
    id: '2',
    name: 'Mini Cooper S',
    type: 'Gasolina · Manual',
    owner: 'Andrés R.',
    price: 35,
    rating: 4.82,
    trips: 89,
    fuel: 'Gasolina',
    seats: 4,
    range: '–',
    year: 2022,
    imageUrl: 'https://images.unsplash.com/photo-1617469767933-0d27272fb22c?w=600&q=80',
    location: const LatLng(40.4200, -3.6950),
    address: 'Calle Serrano 12, Madrid',
    description: 'Mini en perfecto estado, muy divertido de conducir por la ciudad. Ideal para 2-4 personas.',
  ),
  CarData(
    id: '3',
    name: 'BMW Serie 3',
    type: 'Gasolina · Auto',
    owner: 'Carlos V.',
    price: 65,
    rating: 4.91,
    trips: 203,
    fuel: 'Gasolina',
    seats: 5,
    range: '–',
    year: 2023,
    imageUrl: 'https://images.unsplash.com/photo-1555215695-3004980ad54e?w=600&q=80',
    location: const LatLng(40.4100, -3.7100),
    address: 'Paseo del Prado 8, Madrid',
    description: 'BMW Serie 3 en excelente estado. Perfecto para viajes largos o negocios.',
  ),
  CarData(
    id: '4',
    name: 'Volkswagen Golf',
    type: 'Diesel · Manual',
    owner: 'María S.',
    price: 28,
    rating: 4.75,
    trips: 56,
    fuel: 'Diesel',
    seats: 5,
    range: '–',
    year: 2021,
    imageUrl: 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?w=600&q=80',
    location: const LatLng(40.4250, -3.6800),
    address: 'Calle Alcalá 100, Madrid',
    description: 'Golf económico y cómodo. Muy bajo consumo, ideal para moverse por la ciudad.',
  ),
];

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _tab = 0;
  int? _selectedCar;
  final _mapController = MapController();
  static const _madridCenter = LatLng(40.4168, -3.7038);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          //Mapa OpenStreetMap
          Positioned.fill(
            bottom: 290,
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _madridCenter,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rent2go.app',
                ),
                MarkerLayer(
                  markers: demoCars.asMap().entries.map((e) {
                    final selected = _selectedCar == e.key;
                    return Marker(
                      point: e.value.location,
                      width: selected ? 90 : 75,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCar = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? kCyan : Colors.black,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${e.value.price.toInt()}€/día',
                            style: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.12), blurRadius: 10)
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Madrid · Centro',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.black)),
                        Text('Mar 12 May → Jue 14 May',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.tune, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text('${demoCars.length} coches cerca',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15,
                                color: Colors.black)),
                        const Spacer(),
                        Text('Ver todos',
                            style: TextStyle(
                                color: kCyan,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: demoCars.length,
                      itemBuilder: (_, i) => _CarCard(
                        car: demoCars[i],
                        selected: _selectedCar == i,
                        onTap: () {
                          setState(() => _selectedCar = i);
                          _mapController.move(demoCars[i].location, 15);
                        },
                        onDetail: () =>
                            context.push('/car-detail', extra: demoCars[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onTap: (i) {
          setState(() => _tab = i);
          if (i == 1) context.go('/bookings');
          if (i == 2) context.go('/messages');
          if (i == 3) context.go('/profile');
        },
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  final CarData car;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetail;

  const _CarCard({
    required this.car,
    required this.selected,
    required this.onTap,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 200,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kCyan : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: CachedNetworkImage(
                imageUrl: car.imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 100,
                  color: Colors.grey[200],
                  child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 100,
                  color: Colors.grey[200],
                  child: const Icon(Icons.directions_car,
                      color: Colors.grey, size: 40),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(car.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black)),
                  Text(car.type,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 11)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(car.rating.toString(),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black)),
                      const Spacer(),
                      Text('${car.price.toInt()}€/día',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: onDetail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Ver detalles',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.explore_outlined, 'Explorar'),
      (Icons.calendar_today_outlined, 'Reservas'),
      (Icons.chat_bubble_outline, 'Mensajes'),
      (Icons.person_outline, 'Perfil'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: items.asMap().entries.map((e) {
            final active = e.key == current;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(e.key),
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(e.value.$1,
                          color: active ? kCyan : Colors.grey, size: 22),
                      const SizedBox(height: 4),
                      Text(e.value.$2,
                          style: TextStyle(
                              fontSize: 11,
                              color: active ? kCyan : Colors.grey)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
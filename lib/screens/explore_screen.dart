import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/vehicle_models.dart';
import '../services/vehicle_service.dart';
import '../widgets/common_widgets.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int? _selectedIndex;
  final _mapController = MapController();
  static const _madridCenter = LatLng(40.4168, -3.7038);

  List<VehicleData> _vehicles = [];
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final vehicles = await VehicleService.getAvailableVehicles();
      // Solo mostramos vehículos con coordenadas válidas en el mapa.
      if (mounted) setState(() { _vehicles = vehicles; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = 'No se pudieron cargar los vehículos.'; });
    }
  }

  void _goToBottomNav(int i) {
    switch (i) {
      case 0: context.go('/home'); break;
      case 1: context.go('/bookings'); break;
      case 2: context.go('/messages'); break;
      case 3: context.go('/profile'); break;
    }
  }

  void _openAllVehicles() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AllVehiclesSheet(
        vehicles: _vehicles,
        onSelect: (v) {
          Navigator.pop(context);
          context.push('/car-detail', extra: v);
        },
      ),
    );
  }

  LatLng _locationOf(VehicleData v) {
    if (v.latitude != null && v.longitude != null && (v.latitude != 0 || v.longitude != 0)) {
      return LatLng(v.latitude!, v.longitude!);
    }
    return _madridCenter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 290,
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(initialCenter: _madridCenter, initialZoom: 13),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rent2go.app',
                ),
                MarkerLayer(
                  markers: _vehicles.asMap().entries.map((e) {
                    final selected = _selectedIndex == e.key;
                    return Marker(
                      point: _locationOf(e.value),
                      width: selected ? 90 : 75,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedIndex = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? kCyan : Colors.black,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Text(
                            '${e.value.dailyPrice.toInt()}€/día',
                            style: TextStyle(color: selected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
            top: 48, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Madrid · Centro', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black)),
                        Text('Mar 12 May → Jue 14 May', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.tune, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 300,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          _loading ? 'Cargando...' : '${_vehicles.length} coches cerca',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                        ),
                        const Spacer(),
                        if (_vehicles.isNotEmpty)
                          GestureDetector(
                            onTap: _openAllVehicles,
                            child: Text('Ver todos', style: TextStyle(color: kCyan, fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: kCyan))
                        : _errorMsg != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_errorMsg!, style: TextStyle(color: Colors.grey[600])),
                                    TextButton(onPressed: _load, child: const Text('Reintentar')),
                                  ],
                                ),
                              )
                            : _vehicles.isEmpty
                                ? Center(child: Text('No hay vehículos disponibles por ahora', style: TextStyle(color: Colors.grey[400])))
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: _vehicles.length,
                                    itemBuilder: (_, i) => _CarCard(
                                      vehicle: _vehicles[i],
                                      selected: _selectedIndex == i,
                                      onTap: () {
                                        setState(() => _selectedIndex = i);
                                        _mapController.move(_locationOf(_vehicles[i]), 15);
                                      },
                                      onDetail: () => context.push('/car-detail', extra: _vehicles[i]),
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
      bottomNavigationBar: BottomNavBar(current: 0, onTap: _goToBottomNav),
    );
  }
}

class _AllVehiclesSheet extends StatelessWidget {
  final List<VehicleData> vehicles;
  final ValueChanged<VehicleData> onSelect;
  const _AllVehiclesSheet({required this.vehicles, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Text('${vehicles.length} coches disponibles', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black)),
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: vehicles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final v = vehicles[i];
                  return GestureDetector(
                    onTap: () => onSelect(v),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                            child: v.primaryImageUrl != null && v.primaryImageUrl!.isNotEmpty
                                ? CachedNetworkImage(imageUrl: v.primaryImageUrl!, width: 100, height: 80, fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(width: 100, height: 80, color: Colors.grey[200], child: const Icon(Icons.directions_car, color: Colors.grey)))
                                : Container(width: 100, height: 80, color: Colors.grey[200], child: const Icon(Icons.directions_car, color: Colors.grey)),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                                  Text('${v.categoryName} · ${v.transmission ?? ''}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('${v.dailyPrice.toInt()}€/día', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CarCard extends StatelessWidget {
  final VehicleData vehicle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetail;
  const _CarCard({required this.vehicle, required this.selected, required this.onTap, required this.onDetail});

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
          border: Border.all(color: selected ? kCyan : Colors.grey.shade200, width: selected ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: vehicle.primaryImageUrl != null && vehicle.primaryImageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: vehicle.primaryImageUrl!, height: 100, width: double.infinity, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(height: 100, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                      errorWidget: (_, __, ___) => Container(height: 100, color: Colors.grey[200], child: const Icon(Icons.directions_car, color: Colors.grey, size: 40)),
                    )
                  : Container(height: 100, color: Colors.grey[200], child: const Icon(Icons.directions_car, color: Colors.grey, size: 40)),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                  Text('${vehicle.categoryName} · ${vehicle.transmission ?? ''}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(child: Text(vehicle.location, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${vehicle.dailyPrice.toInt()}€/día', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity, height: 28,
                    child: ElevatedButton(
                      onPressed: onDetail,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                      child: const Text('Ver detalles', style: TextStyle(fontSize: 11)),
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

class BottomNavBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const BottomNavBar({super.key, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.explore_outlined, 'Explorar'),
      (Icons.calendar_today_outlined, 'Reservas'),
      (Icons.chat_bubble_outline, 'Mensajes'),
      (Icons.person_outline, 'Perfil'),
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
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
                      Icon(e.value.$1, color: active ? kCyan : Colors.grey, size: 22),
                      const SizedBox(height: 4),
                      Text(e.value.$2, style: TextStyle(fontSize: 11, color: active ? kCyan : Colors.grey)),
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
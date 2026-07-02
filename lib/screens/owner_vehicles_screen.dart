import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/vehicle_models.dart';
import '../services/vehicle_service.dart';
import '../widgets/common_widgets.dart';
import 'add_vehicle_screen.dart';
import 'edit_vehicle_screen.dart';

class OwnerVehiclesScreen extends StatefulWidget {
  const OwnerVehiclesScreen({super.key});
  @override
  State<OwnerVehiclesScreen> createState() => _OwnerVehiclesScreenState();
}

class _OwnerVehiclesScreenState extends State<OwnerVehiclesScreen> {
  List<VehicleData> _vehicles = [];
  bool _loading = true;
  String? _errorMsg;
  int _filter = 0; // 0=Todos 1=Activos 2=Borradores 3=Revisión

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
      final vehicles = await VehicleService.getMyVehicles();
      if (mounted) setState(() { _vehicles = vehicles; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = 'No se pudieron cargar tus vehículos.'; });
    }
  }

  List<VehicleData> get _filtered {
    if (_filter == 1) return _vehicles.where((v) {
      final s = v.status.toUpperCase();
      return s == 'ACTIVE' || s == 'AVAILABLE';
    }).toList();
    if (_filter == 2) return _vehicles.where((v) => v.status.toUpperCase() == 'DRAFT').toList();
    if (_filter == 3) return _vehicles.where((v) => v.status.toUpperCase() == 'PENDING_REVIEW').toList();
    return _vehicles;
  }

  Future<void> _goToEdit(VehicleData vehicle) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditVehicleScreen(vehicle: vehicle)),
    );
    if (updated == true) _load();
  }

  Future<void> _goToAdd() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _togglePause(VehicleData vehicle) async {
    final isActive = vehicle.status.toUpperCase() == 'ACTIVE' ||
        vehicle.status.toUpperCase() == 'AVAILABLE';
    final newStatus = isActive ? 'MAINTENANCE' : 'AVAILABLE';
    try {
      await VehicleService.updateStatus(vehicle.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isActive ? 'Vehículo pausado' : 'Vehículo reactivado')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el estado del vehículo.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(VehicleData vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar vehículo'),
        content: Text('¿Seguro que deseas eliminar "${vehicle.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await VehicleService.deleteVehicle(vehicle.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehículo eliminado')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _vehicles.where((v) => v.status.toUpperCase() == 'ACTIVE').length;
    return Scaffold(
      backgroundColor: const Color(0xFFD9E5E3),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mis vehículos',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                          const SizedBox(height: 2),
                          Text(
                            '${_vehicles.length} publicados · $activeCount en alquiler ahora',
                            style: TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _goToAdd,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: ['Todos', 'Activos', 'Borradores', 'Revisión'].asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _filter == e.key ? Colors.black : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(e.value, style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: _filter == e.key ? Colors.white : Colors.grey[600])),
                      ),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: kCyan))
                    : _errorMsg != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_errorMsg!, style: TextStyle(color: Colors.grey[600])),
                                const SizedBox(height: 8),
                                TextButton(onPressed: _load, child: const Text('Reintentar')),
                              ],
                            ),
                          )
                        : _filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.directions_car_outlined, size: 48, color: Colors.black26),
                                    const SizedBox(height: 12),
                                    Text('Aún no tienes vehículos aquí',
                                        style: TextStyle(color: Colors.black54)),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: _goToAdd,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Publicar vehículo'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black, foregroundColor: Colors.white),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 16),
                                itemBuilder: (_, i) => _VehicleCard(
                                  vehicle: _filtered[i],
                                  onTap: () => _goToEdit(_filtered[i]),
                                  onPause: () => _togglePause(_filtered[i]),
                                  onDelete: () => _confirmDelete(_filtered[i]),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final VehicleData vehicle;
  final VoidCallback onTap;
  final VoidCallback onPause;
  final VoidCallback onDelete;
  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.onPause,
    required this.onDelete,
  });

  bool get _isActive => vehicle.status.toUpperCase() == 'ACTIVE';
  bool get _isAvailable => vehicle.status.toUpperCase() == 'AVAILABLE';

  String get _statusLabel {
    switch (vehicle.status.toUpperCase()) {
      case 'ACTIVE': return 'En alquiler';
      case 'AVAILABLE': return 'Disponible';
      case 'DRAFT': return 'Borrador';
      case 'PENDING_REVIEW': return 'En revisión';
      case 'MAINTENANCE': return 'Mantenimiento';
      default: return vehicle.status;
    }
  }

  Color get _statusColor {
    if (_isActive) return Colors.blue;
    if (_isAvailable) return Colors.green;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(color: const Color(0xFFEFF3F1), borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(child: Text(_statusLabel, style: TextStyle(color: Colors.black54, fontSize: 12))),
            PopupMenuButton<String>(
              key: Key('vehicle_actions_menu_${vehicle.id}'),
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.black54),
              onSelected: (value) {
                if (value == 'pause') onPause();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'pause',
                  child: Text(_isActive || _isAvailable ? 'Pausar' : 'Reactivar'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: vehicle.primaryImageUrl != null && vehicle.primaryImageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: vehicle.primaryImageUrl!,
                    height: 150, width: double.infinity, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        height: 150, color: Colors.grey[300],
                        child: const Icon(Icons.directions_car, size: 50, color: Colors.grey)),
                  )
                : Container(
                    height: 150, width: double.infinity, color: Colors.grey[300],
                    child: const Icon(Icons.directions_car, size: 50, color: Colors.grey),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    Text(vehicle.licensePlate, style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 2),
              const Text('—', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatChip(value: vehicle.categoryName.isEmpty ? '—' : vehicle.categoryName, label: 'Categoría')),
              Container(width: 1, height: 30, color: Colors.black12),
              Expanded(child: _StatChip(value: '${vehicle.seats ?? '—'}', label: 'Asientos')),
              Container(width: 1, height: 30, color: Colors.black12),
              Expanded(child: _StatChip(value: '${vehicle.dailyPrice.toStringAsFixed(0)} €', label: '/día')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.local_gas_station_outlined, size: 13, color: Colors.black45),
                const SizedBox(width: 4),
                Text(vehicle.fuelType ?? '—', style: TextStyle(color: Colors.black45, fontSize: 11)),
              ]),
              Row(children: [
                const Icon(Icons.settings_outlined, size: 13, color: Colors.black45),
                const SizedBox(width: 4),
                Text(vehicle.transmission ?? '—', style: TextStyle(color: Colors.black45, fontSize: 11)),
              ]),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value, label;
  const _StatChip({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
      Text(label, style: TextStyle(color: Colors.black45, fontSize: 11)),
    ],
  );
}

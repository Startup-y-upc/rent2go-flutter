import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/vehicle_models.dart';
import '../services/vehicle_service.dart';
import '../widgets/common_widgets.dart';
import 'add_vehicle_screen.dart';
import 'edit_vehicle_screen.dart';
import 'availability_screen.dart';

class OwnerVehiclesScreen extends StatefulWidget {
  const OwnerVehiclesScreen({super.key});
  @override
  State<OwnerVehiclesScreen> createState() => _OwnerVehiclesScreenState();
}

class _OwnerVehiclesScreenState extends State<OwnerVehiclesScreen> {
  List<VehicleData> _vehicles = [];
  bool _loading = true;
  String? _errorMsg;

  final _scrollController = ScrollController();
  int _currentPage = 0;
  bool _hasMorePages = false;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      _loadNextPage();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final paged = await VehicleService.getMyVehiclesPaged(page: 0);
      if (mounted) {
        setState(() {
          _vehicles = paged.content;
          _loading = false;
          _currentPage = paged.page;
          _hasMorePages = paged.hasMorePages;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = 'No se pudieron cargar tus vehículos.'; });
    }
  }

  /// US75/TS22 — loads the next page and appends results, mirroring Kotlin's
  /// VehicleListViewModel.loadNextPage: guarded against concurrent in-flight
  /// requests (_isLoadingMore) and against calling past the last page
  /// (_hasMorePages), matching Kotlin's `hasMorePages = page < totalPages - 1`.
  Future<void> _loadNextPage() async {
    if (!_hasMorePages || _isLoadingMore || _loading) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;
    try {
      final paged = await VehicleService.getMyVehiclesPaged(page: nextPage);
      if (mounted) {
        setState(() {
          _vehicles = [..._vehicles, ...paged.content];
          _currentPage = paged.page;
          _hasMorePages = paged.hasMorePages;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  List<VehicleData> get _activeVehicles {
    return _vehicles.where((v) {
      final s = v.status.toUpperCase();
      return s == 'ACTIVE' || s == 'AVAILABLE';
    }).toList();
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

  Future<void> _goToAvailability(VehicleData vehicle) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AvailabilityScreen(vehicle: vehicle)),
    );
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
    final activeCount = _activeVehicles.length;
    return Scaffold(
      backgroundColor: const Color(0xFFD9E5E3),
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
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
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black54,
                  indicator: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(text: 'Todos'),
                    Tab(text: 'Activos'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildVehicleList(
                      vehicles: _vehicles,
                      emptyMessage: 'Aún no tienes vehículos aquí',
                      scrollController: _scrollController,
                      showLoadMore: true,
                    ),
                    _buildVehicleList(
                      vehicles: _activeVehicles,
                      emptyMessage: 'No tienes vehículos activos',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleList({
    required List<VehicleData> vehicles,
    required String emptyMessage,
    ScrollController? scrollController,
    bool showLoadMore = false,
  }) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kCyan));
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMsg!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (vehicles.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          children: [
            const SizedBox(height: 80),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car_outlined, size: 48, color: Colors.black26),
                  const SizedBox(height: 12),
                  Text(emptyMessage, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _goToAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Publicar vehículo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final showSpinner = showLoadMore && _hasMorePages;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        key: showLoadMore ? const Key('owner_vehicle_list') : null,
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: vehicles.length + (showSpinner ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, i) {
          if (i >= vehicles.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: kCyan)),
              ),
            );
          }
          return _VehicleCard(
            vehicle: vehicles[i],
            onTap: () => _goToEdit(vehicles[i]),
            onPause: () => _togglePause(vehicles[i]),
            onDelete: () => _confirmDelete(vehicles[i]),
            onAvailability: () => _goToAvailability(vehicles[i]),
          );
        },
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final VehicleData vehicle;
  final VoidCallback onTap;
  final VoidCallback onPause;
  final VoidCallback onDelete;
  final VoidCallback onAvailability;
  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.onPause,
    required this.onDelete,
    required this.onAvailability,
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
            Expanded(child: Text(_statusLabel, style: const TextStyle(color: Colors.black54, fontSize: 12))),
            PopupMenuButton<String>(
              key: Key('vehicle_actions_menu_${vehicle.id}'),
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.black54),
              onSelected: (value) {
                if (value == 'pause') onPause();
                if (value == 'delete') onDelete();
                if (value == 'availability') onAvailability();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'pause',
                  child: Text(_isActive || _isAvailable ? 'Pausar' : 'Reactivar'),
                ),
                const PopupMenuItem(
                  value: 'availability',
                  child: Text('Disponibilidad'),
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
          /* Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    Text(vehicle.licensePlate, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 2),
              const Text('—', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ), */
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatChip(value: vehicle.categoryName.isEmpty ? '—' : vehicle.categoryName, label: 'Categoría')),
              Container(width: 1, height: 30, color: Colors.black12),
              Expanded(child: _StatChip(value: '${vehicle.seats ?? '—'}', label: 'Asientos')),
              Container(width: 1, height: 30, color: Colors.black12),
              Expanded(child: _StatChip(value: '${vehicle.dailyPrice.toStringAsFixed(0)} S/', label: '/día')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.local_gas_station_outlined, size: 13, color: Colors.black45),
                const SizedBox(width: 4),
                Text(vehicle.fuelType ?? '—', style: const TextStyle(color: Colors.black45, fontSize: 11)),
              ]),
              Row(children: [
                const Icon(Icons.settings_outlined, size: 13, color: Colors.black45),
                const SizedBox(width: 4),
                Text(vehicle.transmission ?? '—', style: const TextStyle(color: Colors.black45, fontSize: 11)),
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
      Text(label, style: const TextStyle(color: Colors.black45, fontSize: 11)),
    ],
  );
}

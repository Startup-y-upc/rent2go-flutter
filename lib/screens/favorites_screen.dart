import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/favorite_service.dart';

const _kCyan = Color(0xFF00E5FF);

/// Requisito 3 (Sprint 5 fixes) — lista de vehículos favoritos del renter,
/// accesible desde profile_screen.dart ("Mis favoritos"). Consume
/// GET /api/v1/favorites?userId= (FavoritesController) enriquecido con el
/// detalle de cada vehículo vía FavoriteService.getFavoriteVehicles.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _loading = true;
  String? _error;
  List<FavoriteVehicle> _favorites = const [];
  int? _userId;
  final Set<int> _removing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final me = await AuthService.getCurrentUser();
    final userId = me?.userId;
    if (userId == null || userId == 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Debes iniciar sesión para ver tus favoritos.';
      });
      return;
    }
    try {
      final favorites = await FavoriteService.getFavoriteVehicles(userId);
      if (!mounted) return;
      setState(() {
        _userId = userId;
        _favorites = favorites;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar tus favoritos.';
      });
    }
  }

  Future<void> _removeFavorite(FavoriteVehicle item) async {
    final userId = _userId;
    if (userId == null || _removing.contains(item.vehicle.id)) return;

    setState(() => _removing.add(item.vehicle.id));
    try {
      await FavoriteService.removeFavorite(userId: userId, vehicleId: item.vehicle.id);
      if (!mounted) return;
      setState(() {
        _favorites = _favorites.where((f) => f.vehicle.id != item.vehicle.id).toList();
        _removing.remove(item.vehicle.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _removing.remove(item.vehicle.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo quitar de favoritos. Intenta de nuevo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Mis favoritos'),
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kCyan));
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Text(_error!, style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            ),
          ),
        ],
      );
    }
    if (_favorites.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Icon(Icons.favorite_border, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text('Aún no tienes vehículos favoritos', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      key: const Key('favorites_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: _favorites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final item = _favorites[i];
        final vehicle = item.vehicle;
        final isRemoving = _removing.contains(vehicle.id);
        return GestureDetector(
          onTap: () => context.push('/car-detail', extra: vehicle),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  child: vehicle.primaryImageUrl != null && vehicle.primaryImageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: vehicle.primaryImageUrl!, width: 100, height: 80, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(width: 100, height: 80, color: Colors.grey[200], child: const Icon(Icons.directions_car, color: Colors.grey)),
                        )
                      : Container(width: 100, height: 80, color: Colors.grey[200], child: const Icon(Icons.directions_car, color: Colors.grey)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vehicle.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                        Text('${vehicle.categoryName} · ${vehicle.transmission ?? ''}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('S/ ${vehicle.dailyPrice.toInt()}/día', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: isRemoving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.redAccent),
                          tooltip: 'Quitar de favoritos',
                          onPressed: () => _removeFavorite(item),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

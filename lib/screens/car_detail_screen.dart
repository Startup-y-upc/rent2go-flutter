import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/vehicle_models.dart';
import '../services/auth_service.dart';
import '../services/dispute_service.dart';

class CarDetailScreen extends StatefulWidget {
  final VehicleData vehicle;
  const CarDetailScreen({super.key, required this.vehicle});

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  VehicleData get vehicle => widget.vehicle;

  bool _reviewsLoading = true;
  String? _reviewsError;
  VehicleRatingData? _rating;
  List<VehicleReviewData> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _reviewsLoading = true;
      _reviewsError = null;
    });
    try {
      final results = await Future.wait([
        DisputeService.getVehicleRating(vehicle.id),
        DisputeService.getVehicleReviews(vehicle.id),
      ]);
      if (!mounted) return;
      final rating = results[0] as VehicleRatingData;
      final reviews = (results[1] as List<VehicleReviewData>)
          // Solo reseñas aprobadas — el backend no filtra por status en este
          // endpoint (a diferencia de /rating, que sí excluye no-aprobadas).
          .where((r) => r.status == null || r.status!.toUpperCase() == 'APPROVED')
          .toList();
      setState(() {
        _rating = rating;
        _reviews = reviews;
        _reviewsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewsError = 'No se pudieron cargar las reseñas.';
        _reviewsLoading = false;
      });
    }
  }

  Future<void> _openChat(BuildContext context) async {
    final me = await AuthService.getCurrentUser();
    final myId = me?.userId ?? 0;
    if (!context.mounted) return;
    context.push('/chat', extra: {
      'name': 'Propietario',
      'car': vehicle.name,
      'isOnline': false,
      'ownerId': vehicle.ownerId,
      'renterId': myId,
      'vehicleId': vehicle.id,
      'reservationId': null,
    });
  }

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
                    vehicle.primaryImageUrl != null && vehicle.primaryImageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: vehicle.primaryImageUrl!, height: 280, width: double.infinity, fit: BoxFit.cover,
                            placeholder: (_, __) => Container(height: 280, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                            errorWidget: (_, __, ___) => Container(height: 280, color: const Color(0xFF1A1A2E), child: const Center(child: Icon(Icons.directions_car, color: Colors.white30, size: 80))),
                          )
                        : Container(height: 280, color: const Color(0xFF1A1A2E), child: const Center(child: Icon(Icons.directions_car, color: Colors.white30, size: 80))),
                    Positioned(top: 48, left: 16, child: _CircleBtn(icon: Icons.arrow_back, onTap: () => context.pop())),
                    Positioned(top: 48, right: 56, child: _CircleBtn(icon: Icons.share_outlined, onTap: () {})),
                    Positioned(top: 48, right: 16, child: _CircleBtn(icon: Icons.favorite_border, onTap: () {})),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _Badge(
                          label: vehicle.fuelType ?? '—',
                          color: (vehicle.fuelType ?? '').toUpperCase() == 'ELECTRIC' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                          textColor: (vehicle.fuelType ?? '').toUpperCase() == 'ELECTRIC' ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text(vehicle.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(height: 4),
                      Text('${vehicle.categoryName} · ${vehicle.year}', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text(vehicle.location, style: TextStyle(color: Colors.grey[500], fontSize: 12))),
                      ]),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _SpecItem(icon: Icons.people_outline, label: '${vehicle.seats ?? "—"}', sublabel: 'Plazas'),
                            _Divider(),
                            _SpecItem(icon: Icons.settings_outlined, label: vehicle.transmission ?? '—', sublabel: 'Cambio'),
                            _Divider(),
                            _SpecItem(icon: Icons.local_gas_station_outlined, label: vehicle.fuelType ?? '—', sublabel: 'Combustible'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 22, backgroundColor: Colors.teal.shade100, child: const Icon(Icons.person, color: Colors.teal)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Propietario', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                                  Text('ID #${vehicle.ownerId}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _openChat(context),
                              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero),
                              child: const Text('Mensaje', style: TextStyle(fontSize: 12, color: Colors.black)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (vehicle.description != null && vehicle.description!.isNotEmpty) ...[
                        const Text('SOBRE EL COCHE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text(vehicle.description!, style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5)),
                      ],
                      if (vehicle.features.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text('CARACTERÍSTICAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: vehicle.features.map((f) => Chip(label: Text(f, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.grey[100])).toList(),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Text('RESEÑAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _ReviewsSection(
                        key: const Key('car_detail_reviews_section'),
                        loading: _reviewsLoading,
                        error: _reviewsError,
                        rating: _rating,
                        reviews: _reviews,
                        onRetry: _loadReviews,
                      ),
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
              decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('S/ ${vehicle.dailyPrice.toInt()}/día', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                      Text('2 días · Total S/${(vehicle.dailyPrice * 2).toInt()}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push('/confirm-booking', extra: vehicle),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
    child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Icon(icon, size: 18, color: Colors.black87)),
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
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: Colors.grey.shade200);
}

/// Sección de reseñas/calificación del vehículo — antes inexistente en Flutter.
/// Consume GET /community-trust/vehicles/{id}/rating y
/// GET /community-trust/reviews/vehicle/{id} (ver dispute_service.dart).
/// Un vehículo sin reseñas es un resultado vacío válido, no un error.
class _ReviewsSection extends StatelessWidget {
  final bool loading;
  final String? error;
  final VehicleRatingData? rating;
  final List<VehicleReviewData> reviews;
  final VoidCallback onRetry;

  const _ReviewsSection({
    super.key,
    required this.loading,
    required this.error,
    required this.rating,
    required this.reviews,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('reviews_section_container'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (loading) {
      return const Center(
        key: Key('reviews_loading_state'),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (error != null) {
      return Column(
        key: const Key('reviews_error_state'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('reviews_retry_button'),
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    final hasRating = rating != null && rating!.count > 0;
    final hasReviews = reviews.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasRating) ...[
          Row(
            key: const Key('reviews_rating_summary'),
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 6),
              Text(
                '${rating!.average.toStringAsFixed(1)} · ${rating!.count} reseña${rating!.count == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (!hasReviews)
          const Text(
            'Este vehículo aún no tiene reseñas',
            key: Key('reviews_empty_state'),
            style: TextStyle(fontSize: 13, color: Colors.grey),
          )
        else
          Column(
            key: const Key('reviews_list'),
            children: [
              for (int i = 0; i < reviews.length && i < 5; i++) ...[
                if (i > 0) Divider(height: 16, color: Colors.grey.shade200),
                _ReviewTile(review: reviews[i]),
              ],
            ],
          ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final VehicleReviewData review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${review.rating}/5', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black)),
              if (review.comment != null && review.comment!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(review.comment!, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
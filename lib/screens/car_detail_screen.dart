import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/vehicle_models.dart';
import '../models/counterparty_data.dart';
import '../services/auth_service.dart';
import '../services/dispute_service.dart';
import '../services/favorite_service.dart';
import '../services/vehicle_service.dart';
import '../widgets/common_widgets.dart' show kCyan;

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

  // US76 closure (Sprint 5 fixes remaining scope): owner identity + verification badges,
  // resolvable pre-booking via GET /api/v1/vehicles/{id}/owner-summary. `_ownerLoading`
  // tracks the fetch explicitly so the UI can show a loading state instead of a blank/crash
  // if the fetch is slow, and `_ownerError` covers the vehicle-not-found/parse-failure case —
  // never a raw exception surfaced to the user.
  bool _ownerLoading = true;
  bool _ownerError = false;
  CounterpartyData? _owner;

  // Bug 2 (Sprint 5 fixes) — favorite toggle backed by the real backend
  // endpoint (FavoritesController, /api/v1/favorites). `_favoriteLoading`
  // covers the initial "is this already a favorite?" check so the icon
  // doesn't flash filled->empty; `_favoriteBusy` guards the toggle itself
  // against double-taps while the optimistic update is in flight.
  bool _favorite = false;
  bool _favoriteLoading = true;
  bool _favoriteBusy = false;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _loadOwnerSummary();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final me = await AuthService.getCurrentUser();
    final userId = me?.userId;
    if (userId == null || userId == 0) {
      if (!mounted) return;
      setState(() {
        _currentUserId = null;
        _favoriteLoading = false;
      });
      return;
    }
    try {
      final isFav = await FavoriteService.isFavorite(userId: userId, vehicleId: vehicle.id);
      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
        _favorite = isFav;
        _favoriteLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
        _favoriteLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final userId = _currentUserId;
    if (userId == null || _favoriteBusy) return;

    final previous = _favorite;
    setState(() {
      _favorite = !previous;
      _favoriteBusy = true;
    });

    try {
      if (_favorite) {
        await FavoriteService.addFavorite(userId: userId, vehicleId: vehicle.id);
      } else {
        await FavoriteService.removeFavorite(userId: userId, vehicleId: vehicle.id);
      }
      if (!mounted) return;
      setState(() => _favoriteBusy = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _favorite = previous;
        _favoriteBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar favoritos. Intenta de nuevo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _loadOwnerSummary() async {
    setState(() {
      _ownerLoading = true;
      _ownerError = false;
    });
    try {
      final owner = await VehicleService.getVehicleOwnerSummary(vehicle.id);
      if (!mounted) return;
      setState(() {
        _owner = owner;
        _ownerLoading = false;
        _ownerError = owner == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ownerLoading = false;
        _ownerError = true;
      });
    }
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
      final reviews = results[1] as List<VehicleReviewData>;
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      // Bugfix: colorScheme.surface resolves to the app's dark-theme navy
      // (0xFF16213E, see main.dart's ColorScheme.dark), which reads as a wrong
      // blue background here. Every other renter-facing screen in this app
      // (reservation_detail_screen.dart, bookings_screen.dart) uses a plain
      // white/light background instead of trusting the global dark ColorScheme
      // — this screen must match that established convention.
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Stack(
                  children: [
                    vehicle.primaryImageUrl != null && vehicle.primaryImageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: vehicle.primaryImageUrl!, height: 280, width: double.infinity, fit: BoxFit.cover,
                            placeholder: (_, __) => Container(height: 280, color: colorScheme.surfaceContainerHighest, child: const Center(child: CircularProgressIndicator())),
                            errorWidget: (_, __, ___) => Container(height: 280, color: const Color(0xFF1A1A2E), child: const Center(child: Icon(Icons.directions_car, color: Colors.white30, size: 80))),
                          )
                        : Container(height: 280, color: const Color(0xFF1A1A2E), child: const Center(child: Icon(Icons.directions_car, color: Colors.white30, size: 80))),
                    // US78 — gradient scrim behind the top-positioned circular overlay
                    // buttons so they stay legible over any vehicle photo, regardless
                    // of the photo's dominant color.
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 110,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x99000000), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(top: 48, left: 16, child: _CircleBtn(icon: Icons.arrow_back, onTap: () => context.pop())),
                    Positioned(
                      top: 48, right: 16,
                      child: _CircleBtn(
                        key: const Key('car_detail_favorite_button'),
                        icon: _favorite ? Icons.favorite : Icons.favorite_border,
                        iconColor: _favorite ? Colors.redAccent : null,
                        onTap: _favoriteLoading || _currentUserId == null ? null : _toggleFavorite,
                      ),
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
                          label: vehicle.fuelType ?? '—',
                          color: (vehicle.fuelType ?? '').toUpperCase() == 'ELECTRIC' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                          textColor: (vehicle.fuelType ?? '').toUpperCase() == 'ELECTRIC' ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text(vehicle.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(height: 4),
                      Text('${vehicle.categoryName} · ${vehicle.year}', style: TextStyle(color: Colors.black, fontSize: 14)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.black),
                        const SizedBox(width: 4),
                        Expanded(child: Text(vehicle.location, style: TextStyle(color: Colors.black, fontSize: 12))),
                      ]),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.outlineVariant)),
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
                        key: const Key('owner_info_box'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.outlineVariant)),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 22, backgroundColor: colorScheme.tertiaryContainer, child: Icon(Icons.person, color: colorScheme.onTertiaryContainer)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _ownerLoading
                                              ? 'Propietario'
                                              : (_owner?.fullName ?? 'Propietario'),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                                        ),
                                      ),
                                      if (!_ownerLoading && _owner?.kycVerified == true) ...[
                                        const SizedBox(width: 4),
                                        const Tooltip(message: 'Verificado', child: Icon(Icons.verified, size: 14, color: kCyan)),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    'Propietario del vehículo',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _openChat(context),
                              style: OutlinedButton.styleFrom(side: BorderSide(color: colorScheme.outlineVariant), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero),
                              child: Text('Mensaje', style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (vehicle.description != null && vehicle.description!.isNotEmpty) ...[
                        Text('SOBRE EL COCHE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text(vehicle.description!, style: TextStyle(color: Colors.black, fontSize: 14, height: 1.5)),
                      ],
                      if (vehicle.features.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('CARACTERÍSTICAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: vehicle.features.map((f) => Chip(label: Text(f, style: const TextStyle(fontSize: 12)), backgroundColor: colorScheme.surfaceContainerHighest)).toList(),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text('RESEÑAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _ReviewsSection(
                        key: const Key('car_detail_reviews_section'),
                        loading: _reviewsLoading,
                        error: _reviewsError,
                        rating: _rating,
                        reviews: _reviews,
                        onRetry: _loadReviews,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
      // Bug 1 fix (Sprint 5 fixes): this bar used to be a `Positioned` widget
      // stacked over the scrolling body with a hardcoded `bottom: 28` padding
      // guess at the home indicator/gesture bar — it floated with extra dead
      // space on devices with a shorter safe-area inset (most Android phones)
      // and could still clip under the home indicator on devices with a
      // taller one. Using `Scaffold.bottomNavigationBar` anchors it correctly
      // below the body on every device by construction, and wrapping it in
      // `SafeArea` (top: false, since only the bottom inset matters here)
      // reserves exactly the real inset — the iOS home indicator or the
      // Android 3-button/gesture nav bar — instead of a guessed constant.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(color: colorScheme.surface, border: Border(top: BorderSide(color: colorScheme.outlineVariant))),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('S/ ${vehicle.dailyPrice.toInt()}/día', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                  Text('2 días · Total S/${(vehicle.dailyPrice * 2).toInt()}', style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/confirm-booking', extra: vehicle),
                  style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Reservar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  const _CircleBtn({super.key, required this.icon, required this.onTap, this.iconColor});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 36, height: 36, decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(18)), child: Icon(icon, size: 18, color: iconColor ?? colorScheme.onSurface)),
    );
  }
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: colorScheme.onSurface, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)),
        Text(sublabel, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }
}

class _VerificationCheckItem extends StatelessWidget {
  final String label;
  final bool verified;
  final Color color;
  const _VerificationCheckItem({required this.label, required this.verified, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(verified ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: verified ? kCyan : color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color)),
    ],
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: Theme.of(context).colorScheme.outlineVariant);
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('reviews_section_container'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.outlineVariant)),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
          Text(error!, style: TextStyle(color: colorScheme.error, fontSize: 13)),
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (!hasReviews)
          Text(
            'Este vehículo aún no tiene reseñas',
            key: const Key('reviews_empty_state'),
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          )
        else
          Column(
            key: const Key('reviews_list'),
            children: [
              for (int i = 0; i < reviews.length && i < 5; i++) ...[
                if (i > 0) Divider(height: 16, color: colorScheme.outlineVariant),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${review.rating}/5', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colorScheme.onSurface)),
              if (review.comment != null && review.comment!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(review.comment!, style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
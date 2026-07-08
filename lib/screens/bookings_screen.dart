import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/counterparty_data.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/reservation_service.dart';
import 'explore_screen.dart' show BottomNavBar;


Widget _vehicleThumb(ReservationData reservation, {required double width, required double height}) {
  final imageUrl = (reservation.vehicleImage != null && reservation.vehicleImage!.isNotEmpty)
      ? reservation.vehicleImage
      : (reservation.pickupPhotos.isNotEmpty ? reservation.pickupPhotos.first : null);
  if (imageUrl == null || imageUrl.isEmpty) {
    return Container(width: width, height: height, color: Colors.grey[800], child: const Icon(Icons.directions_car, color: Colors.white38));
  }
  return CachedNetworkImage(
    imageUrl: imageUrl,
    width: width, height: height, fit: BoxFit.cover,
    errorWidget: (_, __, ___) => Container(width: width, height: height, color: Colors.grey[800], child: const Icon(Icons.directions_car, color: Colors.white38)),
  );
}

class _CounterpartyAvatar extends StatelessWidget {
  final CounterpartyData? counterparty;
  final double radius;
  final Color fallbackColor;
  final Color iconColor;
  const _CounterpartyAvatar({
    required this.counterparty,
    required this.radius,
    required this.fallbackColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = counterparty?.profileImageUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: fallbackColor,
        backgroundImage: CachedNetworkImageProvider(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    final name = counterparty?.fullName;
    if (name != null && name.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: fallbackColor,
        child: Text(name[0].toUpperCase(), style: TextStyle(color: iconColor, fontWeight: FontWeight.bold)),
      );
    }
    return CircleAvatar(radius: radius, backgroundColor: fallbackColor, child: Icon(Icons.person, size: radius + 2, color: iconColor));
  }
}

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

enum _LoadState { loading, ready, error, empty }

class _BookingsScreenState extends State<BookingsScreen> {
  int _filter = 0; // 0=Próximas 1=Activas 2=Pasadas
  _LoadState _state = _LoadState.loading;
  List<ReservationData> _reservations = [];
  String? _error;

  static const _upcomingStatuses = {'PENDING', 'CONFIRMED', 'ACTIVE'};
  static const _pastStatuses = {'COMPLETED', 'CANCELLED'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      setState(() {
        _state = _LoadState.error;
        _error = 'No hay sesión activa.';
      });
      return;
    }
    try {
      // Vista de renter: siempre GET /reservations?renterId=... — esta pantalla
      // es role-fixed a renter, no hay ambigüedad sobre qué endpoint llamar.
      final paged = await ReservationService.getMyReservationsAsRenter(renterId: user.userId, size: 50);
      if (!mounted) return;
      setState(() {
        _reservations = paged.content;
        _state = _reservations.isEmpty ? _LoadState.empty : _LoadState.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.error;
        _error = 'No se pudieron cargar tus reservas.';
      });
    }
  }

  List<ReservationData> get _upcoming =>
      _reservations.where((r) => _upcomingStatuses.contains(r.status.toUpperCase())).toList();
  List<ReservationData> get _past =>
      _reservations.where((r) => _pastStatuses.contains(r.status.toUpperCase())).toList();

  void _goToBottomNav(int i) {
    switch (i) {
      case 0: context.go('/home'); break;
      case 1: context.go('/bookings'); break;
      case 2: context.go('/messages'); break;
      case 3: context.go('/profile'); break;
    }
  }

  void _openReservation(ReservationData r) {
    context.push('/reservation-detail', extra: r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text('Mis reservas',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                  const Spacer(),
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Icon(Icons.calendar_month_outlined, size: 20, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: ['Próximas', 'Activas', 'Pasadas'].asMap().entries.map((e) => Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _filter == e.key ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          e.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _filter == e.key ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(current: 1, onTap: _goToBottomNav),
    );
  }

  Widget _buildContent() {
    if (_state == _LoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_state == _LoadState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
            const SizedBox(height: 8),
            Text(_error ?? 'Error', style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_state == _LoadState.empty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
          children: const [
            Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Todavía no tienes reservas', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final upcoming = _upcoming;
    final past = _past;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          if ((_filter == 0 || _filter == 1) && upcoming.isNotEmpty) ...[
            ...upcoming.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ActiveBookingCard(reservation: r, onOpen: () => _openReservation(r)),
                )),
          ],
          if (_filter == 0 || _filter == 2) ...[
            if (past.isNotEmpty) ...[
              const Text('Anteriores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
              const SizedBox(height: 12),
              ...past.map((r) => _PastBookingCard(reservation: r, onOpen: () => _openReservation(r))),
            ],
          ],
        ],
      ),
    );
  }
}

class _ActiveBookingCard extends StatelessWidget {
  final ReservationData reservation;
  final VoidCallback onOpen;
  const _ActiveBookingCard({required this.reservation, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: kCyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: kCyan, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(reservation.status, style: const TextStyle(color: kCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  // Sprint 5 (US76/TS23) — prefer the vehicle's real catalog photo
                  // (ReservationResource.vehicle_image) over the pickup check-in photo,
                  // which only exists after a check-in has happened. Falls back to a
                  // generic icon, never a broken-image widget.
                  child: _vehicleThumb(reservation, width: 80, height: 55),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Reserva ${reservation.reservationCode}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Cobertura: ${reservation.coveragePlan}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _DateChip(label: 'Recoge', date: formatReservationDateTime(reservation.startDate)),
                Expanded(child: Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 8), color: Colors.white24)),
                _DateChip(label: 'Devuelve', date: formatReservationDateTime(reservation.endDate)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Sprint 5 (US76/TS23) — real owner photo when available
                // (CounterpartyResource.profile_image_url), initials fallback,
                // never a broken-image widget.
                _CounterpartyAvatar(counterparty: reservation.owner, radius: 16, fallbackColor: Colors.white24, iconColor: Colors.white70),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reservation.pickupLocation, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('S/ ${reservation.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onOpen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCyan, foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Abrir', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label, date;
  const _DateChip({required this.label, required this.date});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      Text(date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
    ],
  );
}

class _PastBookingCard extends StatelessWidget {
  final ReservationData reservation;
  final VoidCallback onOpen;
  const _PastBookingCard({required this.reservation, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _vehicleThumb(reservation, width: 64, height: 48),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reserva ${reservation.reservationCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                  Text('${formatReservationDateTime(reservation.startDate)} — ${formatReservationDateTime(reservation.endDate)} · S/ ${reservation.totalAmount.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

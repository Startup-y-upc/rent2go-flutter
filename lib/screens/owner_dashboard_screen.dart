import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/vehicle_service.dart';
import '../services/reservation_service.dart';
import '../models/vehicle_models.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  String _firstName = '';
  String _accountType = '';
  int _myId = 0;
  List<VehicleData> _vehicles = [];
  List<ReservationData> _reservations = [];
  double? _averageRating;
  bool _loadingReservations = true;
  String? _reservationsError;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadUser(), _loadVehicles(), _loadReservations(), _loadReputation()]);
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    if (mounted && user != null) {
      final name = user.fullName.trim().isNotEmpty
          ? user.fullName.trim().split(RegExp(r'\s+')).first
          : (user.username.isNotEmpty ? user.username : 'Usuario');
      setState(() {
        _firstName = name;
        _accountType = user.accountType;
        _myId = user.userId;
      });
    }
  }

  Future<void> _loadVehicles() async {
    try {
      final vehicles = await VehicleService.getMyVehicles();
      if (mounted) setState(() => _vehicles = vehicles);
    } catch (_) {
      // El dashboard sigue funcionando con el conteo en 0 si falla la carga.
    }
  }

  Future<void> _loadReservations() async {
    setState(() {
      _loadingReservations = true;
      _reservationsError = null;
    });
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingReservations = false;
          _reservationsError = 'No hay sesión activa.';
        });
      }
      return;
    }
    try {
      // Vista de owner: siempre GET /reservations/owner?ownerId=... — esta
      // pantalla es role-fixed a owner, no hay ambigüedad sobre el endpoint.
      final paged = await ReservationService.getMyReservationsAsOwner(ownerId: user.userId, size: 50);
      if (!mounted) return;
      setState(() {
        _reservations = paged.content;
        _loadingReservations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingReservations = false;
        _reservationsError = 'No se pudieron cargar tus reservas.';
      });
    }
  }

  Future<void> _loadReputation() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) return;
      final token = await AuthService.getToken();
      final uri = Uri.parse(
          'https://rent2go-backend-production.up.railway.app/api/v1/community-trust/users/${user.userId}/reputation');
      final response = await http.get(uri, headers: {if (token != null) 'Authorization': 'Bearer $token'});
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() => _averageRating = (data['averageRating'] as num?)?.toDouble());
      }
    } catch (_) {
      // Sin rating visible si falla — no se muestra un 4.9 falso.
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _roleLabel(String accountType) {
    switch (accountType.toUpperCase()) {
      case 'OWNER':
        return 'Propietario';
      case 'RENTER':
        return 'Arrendatario';
      default:
        return 'Usuario';
    }
  }

  Future<void> _openChatWithRenter(ReservationData reservation) async {
    if (!mounted) return;
    context.push('/chat', extra: {
      'name': reservation.renterDisplayName,
      'car': 'Reserva ${reservation.reservationCode}',
      'isOnline': false,
      'ownerId': _myId,
      'renterId': reservation.renterId,
      'vehicleId': reservation.vehicleId,
      'reservationId': reservation.id,
      'counterpartyPhotoUrl': reservation.renter?.profileImageUrl,
    });
  }

  Future<void> _confirmReservation(ReservationData r) async {
    try {
      await ReservationService.confirmReservation(r.id);
      _showFeedback('¡Reserva ${r.reservationCode} aceptada!');
      await _loadReservations();
    } catch (e) {
      _showFeedback('No se pudo aceptar la reserva.', isError: true);
    }
  }

  Future<void> _cancelReservation(ReservationData r) async {
    try {
      // No existe un endpoint de "reject" dedicado — cancel es la acción
      // terminal real del backend para "Rechazar" (confirmado por lectura directa).
      await ReservationService.cancelReservation(
        id: r.id,
        requestedById: _myId,
        reason: 'Rechazada por el propietario',
      );
      _showFeedback('Reserva ${r.reservationCode} rechazada');
      await _loadReservations();
    } catch (e) {
      _showFeedback('No se pudo rechazar la reserva.', isError: true);
    }
  }

  /// US37: confirma la entrega real del vehículo — POST /reservations/{id}/activate.
  Future<void> _activateReservation(ReservationData r) async {
    try {
      await ReservationService.activateReservation(r.id);
      _showFeedback('Entrega del vehículo confirmada.');
      await _loadReservations();
    } catch (e) {
      _showFeedback('No se pudo confirmar la entrega del vehículo.', isError: true);
    }
  }

  /// US37: confirma la devolución del vehículo — POST /reservations/{id}/confirm-return.
  Future<void> _confirmReturn(ReservationData r) async {
    try {
      await ReservationService.confirmReturn(id: r.id, actorId: _myId);
      _showFeedback('Devolución del vehículo confirmada.');
      await _loadReservations();
    } catch (e) {
      _showFeedback('No se pudo confirmar la devolución del vehículo.', isError: true);
    }
  }

  ReservationData? get _nextUpcoming {
    final upcoming = _reservations.where((r) =>
        ['CONFIRMED', 'ACTIVE'].contains(r.status.toUpperCase())).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  ReservationData? get _firstPending {
    final pending = _reservations.where((r) => r.status.toUpperCase() == 'PENDING').toList();
    return pending.isNotEmpty ? pending.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 24),
                    if (_loadingReservations)
                      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                    else if (_reservationsError != null)
                      _buildErrorCard(_reservationsError!)
                    else ...[
                      if (_nextUpcoming != null) ...[
                        const Text('Próxima actividad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 12),
                        _buildTodayActivityCard(_nextUpcoming!),
                        const SizedBox(height: 24),
                      ],
                      if (_firstPending != null) ...[
                        const Text('Solicitudes pendientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 12),
                        _buildPendingRequestCard(_firstPending!),
                      ],
                      if (_nextUpcoming == null && _firstPending == null)
                        _buildEmptyReservationsCard(),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200)),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent))),
            TextButton(onPressed: _loadReservations, child: const Text('Reintentar')),
          ],
        ),
      );

  Widget _buildEmptyReservationsCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.event_available_outlined, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('Sin reservas por ahora', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF1B1B2F),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, $_firstName',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _roleLabel(_accountType),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Panel de control',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.push('/owner/earnings'),
                child: Text(
                  'Ver detalle en Ganancias',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 60,
          right: 24,
          child: Row(
            children: [
              GestureDetector(
                key: const Key('owner_dashboard_history_button'),
                onTap: () => context.push('/owner/reservation-history'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.history, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Historial', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatCard(_vehicles.length.toString(), 'Vehículos'),
        _buildStatCard(_reservations.length.toString(), 'Reservas'),
        _buildStatCard(_averageRating != null ? _averageRating!.toStringAsFixed(1) : '—', 'Rating', isRating: true),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, {bool isRating = false}) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildTodayActivityCard(ReservationData reservation) {
    final isActive = reservation.status.toUpperCase() == 'ACTIVE';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Recogida - ${reservation.startDate}',
                  style: const TextStyle(
                    color: Color(0xFF00ACC1),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/reservation-detail', extra: reservation),
                child: const Text('Ver detalle', style: TextStyle(color: kCyan, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: reservation.pickupPhotos.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: reservation.pickupPhotos.first,
                        width: 80, height: 60, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(width: 80, height: 60, color: Colors.grey[300], child: const Icon(Icons.directions_car)),
                      )
                    : Container(width: 80, height: 60, color: Colors.grey[300], child: const Icon(Icons.directions_car)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reserva ${reservation.reservationCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      reservation.renterDisplayName,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    Text(
                      '${reservation.startDate} → ${reservation.endDate} · S/ ${reservation.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openChatWithRenter(reservation),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Mensaje'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                key: Key('owner_dashboard_lifecycle_action_${reservation.id}'),
                child: ElevatedButton(
                  onPressed: isActive
                      ? () => _showReturnDialog(reservation)
                      : () => _showDeliveryDialog(reservation),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    isActive ? 'Confirmar devolución' : 'Entregar vehículo',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeliveryDialog(ReservationData reservation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Confirmar entrega',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        content: const Text(
          '¿Estás en el punto de encuentro con el cliente?',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            key: const Key('confirm_delivery_button'),
            onPressed: () {
              Navigator.pop(context);
              _activateReservation(reservation);
            },
            child: const Text(
              'Sí, estoy aquí',
              style: TextStyle(
                  color: kCyan, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// US37: diálogo de confirmación de devolución, mismo patrón visual que
  /// _showDeliveryDialog — llama a POST /reservations/{id}/confirm-return.
  void _showReturnDialog(ReservationData reservation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Confirmar devolución',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        content: const Text(
          '¿El cliente ha devuelto el vehículo en el punto acordado?',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            key: const Key('confirm_return_button'),
            onPressed: () {
              Navigator.pop(context);
              _confirmReturn(reservation);
            },
            child: const Text(
              'Sí, fue devuelto',
              style: TextStyle(color: kCyan, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestCard(ReservationData reservation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 20, backgroundColor: Colors.black12, child: Icon(Icons.person, color: Colors.black45)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            reservation.renterDisplayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (reservation.renter?.kycVerified == true) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: kCyan),
                        ],
                      ],
                    ),
                    Text('${reservation.startDate} → ${reservation.endDate}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
              Text('S/ ${reservation.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _cancelReservation(reservation),
                  child: Text(
                    'Rechazar',
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _confirmReservation(reservation),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Aceptar reserva', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

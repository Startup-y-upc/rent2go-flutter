import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/reservation_service.dart';

/// US36: historial de reservas del owner consumiendo
/// GET /api/v1/reservations/owner/paged (paginación real de repositorio).
/// Reutiliza el patrón de tarjeta de reserva ya usado en owner_dashboard_screen.dart.
class OwnerReservationHistoryScreen extends StatefulWidget {
  const OwnerReservationHistoryScreen({super.key});

  @override
  State<OwnerReservationHistoryScreen> createState() => _OwnerReservationHistoryScreenState();
}

class _OwnerReservationHistoryScreenState extends State<OwnerReservationHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<ReservationData> _reservations = [];
  int _page = 1;
  int _totalPages = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No hay sesión activa.';
      });
      return;
    }
    try {
      final paged = await ReservationService.getOwnerReservationHistory(
        ownerId: user.userId,
        page: page,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _reservations = paged.content;
        _page = page;
        _totalPages = paged.totalPages;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar el historial de reservas.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B2F),
        elevation: 0,
        leading: IconButton(
          key: const Key('owner_history_back_button'),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Historial de reservas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(page: 1),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(key: Key('owner_history_loading'), child: CircularProgressIndicator(color: kCyan));
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            key: const Key('owner_history_error'),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200)),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                TextButton(onPressed: () => _load(page: _page), child: const Text('Reintentar')),
              ],
            ),
          ),
        ],
      );
    }
    if (_reservations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Center(
            key: Key('owner_history_empty'),
            child: Padding(
              padding: EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aún no tienes reservas registradas', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      key: const Key('owner_history_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _reservations.length + (_totalPages > 1 ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _reservations.length) {
          return _buildPager();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildHistoryCard(_reservations[index]),
        );
      },
    );
  }

  Widget _buildPager() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            key: const Key('owner_history_prev_page'),
            onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
            child: const Text('Anterior'),
          ),
          const SizedBox(width: 8),
          Text('Página $_page de $_totalPages', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('owner_history_next_page'),
            onPressed: _page < _totalPages ? () => _load(page: _page + 1) : null,
            child: const Text('Siguiente'),
          ),
        ],
      ),
    );
  }

  /// Reutiliza el mismo patrón visual (tarjeta blanca con sombra, chip de
  /// estado, monto y botón "Ver detalle") de owner_dashboard_screen.dart.
  Widget _buildHistoryCard(ReservationData reservation) {
    return Container(
      key: Key('owner_history_card_${reservation.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(reservation.status, style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const Spacer(),
              Text('S/ ${reservation.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Reserva ${reservation.reservationCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
          Text('Cliente #${reservation.renterId}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text('${reservation.startDate} → ${reservation.endDate}', style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/reservation-detail', extra: reservation),
              child: const Text('Ver detalle', style: TextStyle(color: kCyan, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
